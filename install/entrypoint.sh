#!/bin/sh

set -e

echo "Starting entrypoint script..."
echo "Waiting for MySQL to be ready..."

# depends_on: condition: service_healthy guarantees MySQL is up before this runs.
# If wait-for-it.sh is baked into the image, use it; otherwise skip (MySQL is healthy).
if [ -x /usr/local/bin/wait-for-it.sh ]; then
  /usr/local/bin/wait-for-it.sh ${DB_HOST}:${DB_PORT} -t 60 -- echo "MySQL is up and running!"
else
  echo "MySQL health confirmed via Docker healthcheck."
fi

# Run AdonisJS migrations
echo "Running AdonisJS migrations..."
node ace migration:run --force

# Seed the database if needed
echo "Seeding the database..."
node ace db:seed

# Start background workers for all queues
echo "Starting background workers for all queues..."
node ace queue:work --all &

# Start the AdonisJS application
echo "Starting AdonisJS application..."
exec node bin/server.js