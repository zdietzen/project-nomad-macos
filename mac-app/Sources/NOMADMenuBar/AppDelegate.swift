import AppKit

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var statusCheckTimer: Timer?
    private var isRunning: Bool = false
    private var isLoading: Bool = false

    // Path to Docker CLI — Docker Desktop installs here on macOS
    private let dockerPath = "/usr/local/bin/docker"
    private let altDockerPath = "/opt/homebrew/bin/docker"

    // ── Lifecycle ────────────────────────────────────────────────────────────

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar–only agent (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        startStatusPolling()
    }

    // ── Status Item Setup ────────────────────────────────────────────────────

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateButtonAppearance()
        rebuildMenu()
    }

    private func updateButtonAppearance() {
        guard let button = statusItem.button else { return }
        if isLoading {
            button.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "NOMAD Loading")
        } else if isRunning {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "NOMAD Running")
        } else {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right.slash", accessibilityDescription: "NOMAD Stopped")
        }
        button.image?.isTemplate = true  // Adapts to light/dark menu bar
    }

    // ── Menu Construction ────────────────────────────────────────────────────

    private func rebuildMenu() {
        let menu = NSMenu()

        // ── Status header ──────────────────────────────────────────────
        let statusTitle: String
        if isLoading {
            statusTitle = "⟳  Working..."
        } else if isRunning {
            statusTitle = "●  N.O.M.A.D. Running"
        } else {
            statusTitle = "○  N.O.M.A.D. Stopped"
        }
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // ── Primary action ─────────────────────────────────────────────
        if isLoading {
            let loadingItem = NSMenuItem(title: "Please wait...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
        } else {
            let toggleTitle = isRunning ? "Stop N.O.M.A.D." : "Start N.O.M.A.D."
            let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleNomad), keyEquivalent: "s")
            toggleItem.target = self
            menu.addItem(toggleItem)
        }

        // ── Dashboard link ─────────────────────────────────────────────
        let dashItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashItem.target = self
        dashItem.isEnabled = isRunning
        menu.addItem(dashItem)

        // ── Logs link ──────────────────────────────────────────────────
        let logsItem = NSMenuItem(title: "View Logs (Dozzle)", action: #selector(openLogs), keyEquivalent: "l")
        logsItem.target = self
        logsItem.isEnabled = isRunning
        menu.addItem(logsItem)

        menu.addItem(.separator())

        // ── Update ─────────────────────────────────────────────────────
        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(updateNomad), keyEquivalent: "u")
        updateItem.target = self
        updateItem.isEnabled = !isLoading
        menu.addItem(updateItem)

        menu.addItem(.separator())

        // ── Quit ───────────────────────────────────────────────────────
        menu.addItem(NSMenuItem(title: "Quit Menu Bar App", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    @objc private func toggleNomad() {
        let action = isRunning ? "stop" : "start"
        isLoading = true
        updateButtonAppearance()
        rebuildMenu()
        runNomadScript(action) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.checkStatus()
            }
        }
    }

    @objc private func openDashboard() {
        NSWorkspace.shared.open(URL(string: "http://localhost:8080")!)
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(URL(string: "http://localhost:9999")!)
    }

    @objc private func updateNomad() {
        isLoading = true
        updateButtonAppearance()
        rebuildMenu()
        runNomadScript("update") { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.checkStatus()
            }
        }
    }

    // ── Script Runner ────────────────────────────────────────────────────────

    private func runNomadScript(_ action: String, completion: @escaping () -> Void) {
        let scriptPath = "/opt/project-nomad/\(action)_nomad_mac.sh"
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = [scriptPath]

            // Pipe output to avoid blocking
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                // Script not found or failed — ignore silently
            }
            completion()
        }
    }

    // ── Status Polling ───────────────────────────────────────────────────────

    private func startStatusPolling() {
        checkStatus()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }

    private func checkStatus() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let running = self.isContainerRunning("nomad_admin")
            DispatchQueue.main.async {
                self.isLoading = false
                self.isRunning = running
                self.updateButtonAppearance()
                self.rebuildMenu()
            }
        }
    }

    private func isContainerRunning(_ containerName: String) -> Bool {
        let dockerBin = FileManager.default.fileExists(atPath: dockerPath) ? dockerPath : altDockerPath
        guard FileManager.default.fileExists(atPath: dockerBin) else { return false }

        let task = Process()
        task.launchPath = dockerBin
        task.arguments = ["inspect", "--format={{.State.Running}}", containerName]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()  // discard errors

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return false
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
}
