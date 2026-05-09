#!/bin/bash
# sentinel.sh
# Watches a target systemd service and restarts it if it goes down.
# Logs all restart events with timestamps and a running restart counter.

# ── Configuration ────────────────────────────────────────────────
TARGET_SERVICE="dummy-app"        # The service we're watching
CHECK_INTERVAL=10                 # Seconds between health checks
LOG_DIR="$HOME/sentinel-logs"     # Where restart events are recorded
LOG_FILE="$LOG_DIR/sentinel.log"  # The actual log file
RESTART_COUNT=0                   # Tracks how many times we've intervened

# ── Setup ────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sentinel started. Watching: $TARGET_SERVICE" | tee -a "$LOG_FILE"
logger -t sentinel "Started. Watching $TARGET_SERVICE every ${CHECK_INTERVAL}s"

# ── Watch Loop ───────────────────────────────────────────────────
while true; do

    # Ask systemd for the current state of the target service
    STATUS=$(systemctl is-active "$TARGET_SERVICE")

    if [ "$STATUS" != "active" ]; then
        # Service is down — log it, restart it, increment counter
        RESTART_COUNT=$((RESTART_COUNT + 1))

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERT] $TARGET_SERVICE is $STATUS. Restarting... (restart #$RESTART_COUNT)" | tee -a "$LOG_FILE"
        logger -t sentinel "ALERT — $TARGET_SERVICE is $STATUS. Restart attempt #$RESTART_COUNT"

        # Restart the service
        systemctl start "$TARGET_SERVICE"

        # Give it 3 seconds to come up, then confirm
        sleep 3
        CONFIRM=$(systemctl is-active "$TARGET_SERVICE")

        if [ "$CONFIRM" = "active" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $TARGET_SERVICE is back up after restart #$RESTART_COUNT" | tee -a "$LOG_FILE"
            logger -t sentinel "RECOVERY — $TARGET_SERVICE restored. Restart #$RESTART_COUNT succeeded"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAILED] $TARGET_SERVICE did not recover. Manual intervention required." | tee -a "$LOG_FILE"
            logger -t sentinel "FAILED — $TARGET_SERVICE did not recover after restart #$RESTART_COUNT"
        fi

    else
        # Service is healthy — silent check, no log spam
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $TARGET_SERVICE is active." | tee -a "$LOG_FILE"
    fi

    sleep "$CHECK_INTERVAL"
done
