#!/bin/bash
# Calculate Ralph autonomous session runtime

SESSION_FILE=".ralph/state/session.json"
STATUS_FILE=".ralph/state/status.json"

# Check if Ralph is running
if [ ! -f "$SESSION_FILE" ]; then
    echo "Not started"
    exit 0
fi

# Check circuit breaker status
if [ -f "$STATUS_FILE" ]; then
    STATUS=$(jq -r '.status // "unknown"' "$STATUS_FILE" 2>/dev/null)
    CB_OPEN=$(jq -r '.circuit_breaker_open // false' "$STATUS_FILE" 2>/dev/null)

    if [ "$CB_OPEN" = "true" ]; then
        echo "PAUSED (Circuit Breaker)"
        exit 0
    fi

    if [ "$STATUS" = "interrupted" ]; then
        echo "Interrupted"
        exit 0
    fi
fi

# Get start time from session file
START_TIME=$(jq -r '.started_at // empty' "$SESSION_FILE" 2>/dev/null)

if [ -z "$START_TIME" ] || [ "$START_TIME" = "null" ]; then
    echo "00:00:00"
    exit 0
fi

# Convert ISO 8601 timestamp to epoch seconds
START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null)
if [ $? -ne 0 ]; then
    # Fallback for macOS date command
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s 2>/dev/null)
fi

if [ -z "$START_EPOCH" ]; then
    echo "00:00:00"
    exit 0
fi

# Calculate elapsed time
NOW_EPOCH=$(date +%s)
ELAPSED=$((NOW_EPOCH - START_EPOCH))

# Format as HH:MM:SS
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))
SECONDS=$((ELAPSED % 60))

printf "%02d:%02d:%02d" $HOURS $MINUTES $SECONDS
