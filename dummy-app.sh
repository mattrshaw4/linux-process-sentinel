#!/bin/bash
# dummy-app.sh
# Simulates a long-running application service.
# Prints a heartbeat every 5 seconds so we can confirm it's alive.

echo "dummy-app started. PID: $$"

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] dummy-app heartbeat — still running"
    sleep 5
done
