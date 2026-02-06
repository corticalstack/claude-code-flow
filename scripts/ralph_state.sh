#!/bin/bash
# scripts/ralph_state.sh - State management for Ralph autonomous loop

# Prevent multiple sourcing
[[ -n "${RALPH_STATE_LOADED:-}" ]] && return 0
RALPH_STATE_LOADED=1

# Source utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ralph_utils.sh"

# State directories
readonly RALPH_DIR=".ralph"
readonly RALPH_STATE_DIR="$RALPH_DIR/state"
readonly RALPH_ACTIVE_DIR="$RALPH_DIR/active"
readonly RALPH_ARCHIVE_DIR="$RALPH_DIR/archived"

# State file paths
readonly STATE_SESSION="$RALPH_STATE_DIR/session.json"
readonly STATE_COUNTERS="$RALPH_STATE_DIR/counters.json"
readonly STATE_HISTORY="$RALPH_STATE_DIR/history.json"
readonly STATE_RATE_LIMIT="$RALPH_STATE_DIR/rate_limit.json"
readonly STATE_CIRCUIT_BREAKER="$RALPH_STATE_DIR/circuit_breaker.json"

# Helper function to get issue-specific log directory
get_issue_log_dir() {
    local issue=$1
    local issue_dir="$RALPH_ACTIVE_DIR/$issue"

    # Create directory if it doesn't exist
    mkdir -p "$issue_dir"

    # Return the path
    echo "$issue_dir"
}

# Initialize state directory and files
init_state() {
    # Create directory structure
    mkdir -p "$RALPH_STATE_DIR"
    mkdir -p "$RALPH_ACTIVE_DIR"
    mkdir -p "$RALPH_ARCHIVE_DIR"

    # Initialize session state if not exists
    if [ ! -f "$STATE_SESSION" ]; then
        json_write "$STATE_SESSION" '{
            "session_id": null,
            "started_at": null,
            "last_active": null,
            "current_issue": null,
            "current_phase": null
        }'
    fi

    # Initialize counters if not exists
    if [ ! -f "$STATE_COUNTERS" ]; then
        json_write "$STATE_COUNTERS" '{
            "iteration": 0,
            "successful_issues": 0,
            "failed_issues": 0,
            "blocked_issues": 0,
            "total_api_calls": 0
        }'
    fi

    # Initialize history if not exists
    if [ ! -f "$STATE_HISTORY" ]; then
        echo '[]' > "$STATE_HISTORY"
    fi

    # Initialize rate limit if not exists
    if [ ! -f "$STATE_RATE_LIMIT" ]; then
        json_write "$STATE_RATE_LIMIT" '{
            "calls": 0,
            "window_start": "'$(date -u +"%Y-%m-%dT%H:00:00Z")'",
            "limit": 100
        }'
    fi

    log_info "State initialized in $RALPH_DIR (state/, active/, archived/)"
}

# Start new session
start_session() {
    local session_id="ralph_$(date +%Y%m%d_%H%M%S)_$$"
    local timestamp=$(timestamp_iso)

    json_write "$STATE_SESSION" "{
        \"session_id\": \"$session_id\",
        \"started_at\": \"$timestamp\",
        \"last_active\": \"$timestamp\",
        \"current_issue\": null,
        \"current_phase\": null
    }"

    log_success "Started session: $session_id"
    echo "$session_id"
}

# Update session activity
update_session() {
    local issue=${1:-null}
    local phase=${2:-null}
    local timestamp=$(timestamp_iso)

    local session_id=$(json_read "$STATE_SESSION" '.session_id' 'unknown')

    json_write "$STATE_SESSION" "{
        \"session_id\": \"$session_id\",
        \"started_at\": \"$(json_read "$STATE_SESSION" '.started_at' "$timestamp")\",
        \"last_active\": \"$timestamp\",
        \"current_issue\": $issue,
        \"current_phase\": \"$phase\"
    }"
}

# Get current session ID
get_session_id() {
    json_read "$STATE_SESSION" '.session_id' 'none'
}

# Increment iteration counter
increment_iteration() {
    local current=$(json_read "$STATE_COUNTERS" '.iteration' '0')
    local new=$((current + 1))

    local counters=$(jq ".iteration = $new" "$STATE_COUNTERS")
    json_write "$STATE_COUNTERS" "$counters"

    echo "$new"
}

# Get current iteration
get_iteration() {
    json_read "$STATE_COUNTERS" '.iteration' '0'
}

# Increment successful issues counter
increment_successful() {
    local current=$(json_read "$STATE_COUNTERS" '.successful_issues' '0')
    local new=$((current + 1))

    local counters=$(jq ".successful_issues = $new" "$STATE_COUNTERS")
    json_write "$STATE_COUNTERS" "$counters"
}

# Increment failed issues counter
increment_failed() {
    local current=$(json_read "$STATE_COUNTERS" '.failed_issues' '0')
    local new=$((current + 1))

    local counters=$(jq ".failed_issues = $new" "$STATE_COUNTERS")
    json_write "$STATE_COUNTERS" "$counters"
}

# Increment blocked issues counter
increment_blocked() {
    local current=$(json_read "$STATE_COUNTERS" '.blocked_issues' '0')
    local new=$((current + 1))

    local counters=$(jq ".blocked_issues = $new" "$STATE_COUNTERS")
    json_write "$STATE_COUNTERS" "$counters"
}

# Record API call
record_api_call() {
    local current=$(json_read "$STATE_COUNTERS" '.total_api_calls' '0')
    local new=$((current + 1))

    local counters=$(jq ".total_api_calls = $new" "$STATE_COUNTERS")
    json_write "$STATE_COUNTERS" "$counters"
}

# Check rate limit
check_rate_limit() {
    local limit=$(json_read "$STATE_RATE_LIMIT" '.limit' '100')
    local calls=$(json_read "$STATE_RATE_LIMIT" '.calls' '0')
    local window_start=$(json_read "$STATE_RATE_LIMIT" '.window_start' '')

    # Check if we're in a new hour
    local current_hour=$(date -u +"%Y-%m-%dT%H:00:00Z")

    if [ "$window_start" != "$current_hour" ]; then
        # New hour - reset counter
        json_write "$STATE_RATE_LIMIT" "{
            \"calls\": 0,
            \"window_start\": \"$current_hour\",
            \"limit\": $limit
        }"
        return 0  # Can make call
    fi

    # Check if under limit
    if [ "$calls" -ge "$limit" ]; then
        log_warning "Rate limit reached: $calls/$limit calls this hour"
        return 1  # Cannot make call
    fi

    return 0  # Can make call
}

# Increment rate limit counter
increment_rate_limit() {
    local limit=$(json_read "$STATE_RATE_LIMIT" '.limit' '100')
    local calls=$(json_read "$STATE_RATE_LIMIT" '.calls' '0')
    local window_start=$(json_read "$STATE_RATE_LIMIT" '.window_start' '')
    local new_calls=$((calls + 1))

    json_write "$STATE_RATE_LIMIT" "{
        \"calls\": $new_calls,
        \"window_start\": \"$window_start\",
        \"limit\": $limit
    }"

    log_info "API calls this hour: $new_calls/$limit"
}

# Add entry to history
add_history_entry() {
    local issue=$1
    local phase=$2
    local status=$3
    local message=$4

    local entry=$(cat <<EOF
{
    "timestamp": "$(timestamp_iso)",
    "issue": $issue,
    "phase": "$phase",
    "status": "$status",
    "message": "$message",
    "files_changed": $(count_changed_files)
}
EOF
)

    # Append to history array (keep last 100 entries)
    local history=$(jq ". += [$entry] | .[-100:]" "$STATE_HISTORY" 2>/dev/null || echo "[$entry]")
    echo "$history" > "$STATE_HISTORY"
}

# Get recent history entries
get_recent_history() {
    local count=${1:-10}
    jq ".[-$count:]" "$STATE_HISTORY" 2>/dev/null || echo "[]"
}

# Get counters summary
get_counters_summary() {
    cat "$STATE_COUNTERS" 2>/dev/null || echo '{}'
}

# Reset all state
reset_state() {
    log_warning "Resetting Ralph state (preserving archives)..."

    # Only delete current state and active issues
    # Keep archived/ intact to preserve historical data
    rm -rf "$RALPH_STATE_DIR"   # Delete state/ only
    rm -rf "$RALPH_ACTIVE_DIR"  # Delete active/ only

    init_state

    log_success "State reset complete (archives preserved)"
}

# Archive completed issue from active to archived
archive_issue() {
    local issue=$1

    # Determine archive month
    local archive_month=$(date +%Y-%m)
    local archive_dir="$RALPH_ARCHIVE_DIR/$archive_month"
    local issue_active_dir="$RALPH_ACTIVE_DIR/$issue"
    local issue_archive_dir="$archive_dir/$issue"

    # Check if issue directory exists in active
    if [ ! -d "$issue_active_dir" ]; then
        log_warning "Issue #$issue directory not found in active/, skipping archive"
        return 0
    fi

    # Create archive directory for this month
    mkdir -p "$archive_dir"

    # Move entire issue directory to archive
    log_info "Archiving issue #$issue to $archive_month/"
    mv "$issue_active_dir" "$issue_archive_dir"

    log_success "Issue #$issue archived to $issue_archive_dir"
}

# Clean old state files (older than 7 days)
clean_old_state() {
    find "$RALPH_STATE_DIR" -name "*.json" -type f -mtime +7 -delete 2>/dev/null
    log_info "Cleaned old state files"
}

# ============================================================================
# MONITOR STATE FUNCTIONS - Real-time dashboard support
# ============================================================================

# Monitor file paths (for real-time dashboard)
readonly STATE_MONITOR_STATUS="$RALPH_DIR/status.json"
readonly STATE_MONITOR_PROGRESS="$RALPH_DIR/progress.json"
readonly STATE_MONITOR_TASK_QUEUE="$RALPH_DIR/task_queue.json"

# Initialize monitor state files
init_monitor_state() {
    json_write "$STATE_MONITOR_STATUS" '{
        "timestamp": "'$(timestamp_iso)'",
        "loop_count": 0,
        "current_task": null,
        "total_tasks": 0,
        "completed_tasks": 0,
        "failed_tasks": 0,
        "status": "idle",
        "phase": "none",
        "calls_made_this_hour": 0,
        "max_calls_per_hour": 100,
        "next_reset": null,
        "circuit_breaker_open": false,
        "exit_reason": ""
    }'

    json_write "$STATE_MONITOR_PROGRESS" '{
        "status": "idle",
        "phase": "none",
        "indicator": "",
        "elapsed_seconds": 0,
        "last_output": "",
        "timestamp": "'$(timestamp_iso)'"
    }'

    json_write "$STATE_MONITOR_TASK_QUEUE" '{
        "queue": [],
        "success_rate": 0,
        "timestamp": "'$(timestamp_iso)'"
    }'

    log_info "Monitor state initialized (status.json, progress.json, task_queue.json)"
}

# Update monitor status file
update_monitor_status() {
    local status=${1:-idle}
    local phase=${2:-none}
    local current_task=${3:-null}
    local exit_reason=${4:-}

    local iteration=$(get_iteration)
    local successful=$(json_read "$STATE_COUNTERS" '.successful_issues' '0')
    local failed=$(json_read "$STATE_COUNTERS" '.failed_issues' '0')
    local total_tasks=$((successful + failed))
    local completed=$successful

    # If currently working on a task, include it in total count
    if [ "$current_task" != "null" ] && [ -n "$current_task" ]; then
        total_tasks=$((total_tasks + 1))
    fi

    local calls_made=$(json_read "$STATE_RATE_LIMIT" '.calls' '0')
    local max_calls=$(json_read "$STATE_RATE_LIMIT" '.limit' '100')
    local window_start=$(json_read "$STATE_RATE_LIMIT" '.window_start' '')

    local next_reset="N/A"
    if [ -n "$window_start" ]; then
        next_reset=$(date -u -d "$window_start + 1 hour" "+%H:%M" 2>/dev/null || echo "N/A")
    fi

    local cb_file="$RALPH_STATE_DIR/circuit_breaker.json"
    local cb_open="false"
    if [ -f "$cb_file" ]; then
        cb_open=$(json_read "$cb_file" '.state' 'CLOSED')
        [ "$cb_open" = "OPEN" ] && cb_open="true" || cb_open="false"
    fi

    json_write "$STATE_MONITOR_STATUS" "{
        \"timestamp\": \"$(timestamp_iso)\",
        \"loop_count\": $iteration,
        \"current_task\": $current_task,
        \"total_tasks\": $total_tasks,
        \"completed_tasks\": $completed,
        \"failed_tasks\": $failed,
        \"status\": \"$status\",
        \"phase\": \"$phase\",
        \"calls_made_this_hour\": $calls_made,
        \"max_calls_per_hour\": $max_calls,
        \"next_reset\": \"$next_reset\",
        \"circuit_breaker_open\": $cb_open,
        \"exit_reason\": \"$exit_reason\"
    }"
}

# Update live progress file
update_progress() {
    local status=${1:-idle}
    local phase=${2:-none}
    local last_output=${3:-}
    local elapsed=${4:-0}

    local indicator=$(get_spinner_frame)
    last_output=$(echo "$last_output" | sed 's/"/\\"/g' | head -c 200)

    json_write "$STATE_MONITOR_PROGRESS" "{
        \"status\": \"$status\",
        \"phase\": \"$phase\",
        \"indicator\": \"$indicator\",
        \"elapsed_seconds\": $elapsed,
        \"last_output\": \"$last_output\",
        \"timestamp\": \"$(timestamp_iso)\"
    }"
}

# Update task queue file
update_task_queue() {
    local queue_json=$1
    local success_rate=${2:-0}

    if ! echo "$queue_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
        queue_json="[]"
    fi

    local content=$(cat <<EOF
{
    "queue": $queue_json,
    "success_rate": $success_rate,
    "timestamp": "$(timestamp_iso)"
}
EOF
)

    json_write "$STATE_MONITOR_TASK_QUEUE" "$content"
}

# Get spinner frame (Braille pattern spinner)
get_spinner_frame() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local index=$((RANDOM % ${#frames[@]}))
    echo "${frames[$index]}"
}

# Mark an issue as the currently active one
mark_issue_current() {
    local issue=$1

    if [ ! -f "$STATE_MONITOR_TASK_QUEUE" ]; then
        return 0
    fi

    local queue=$(jq -r '.queue // []' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "[]")

    # Mark all issues as not current, then mark the specified one as current and in_progress
    local updated_queue=$(echo "$queue" | jq --arg issue "#$issue" '
        map(
            if .issue == $issue then
                .is_current = true |
                .status = "in_progress"
            else
                .is_current = false
            end
        )
    ')

    local success_rate=$(jq -r '.success_rate // 0' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "0")
    update_task_queue "$updated_queue" "$success_rate"
}

# Increment phase attempt count and mark as in_progress
increment_phase_attempt() {
    local issue=$1
    local phase=$2

    if [ ! -f "$STATE_MONITOR_TASK_QUEUE" ]; then
        return 0
    fi

    local queue=$(jq -r '.queue // []' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "[]")

    local updated_queue=$(echo "$queue" | jq --arg issue "#$issue" --arg phase "$phase" '
        map(
            if .issue == $issue then
                .phases[$phase].attempts += 1 |
                .phases[$phase].status = "in_progress"
            else
                .
            end
        )
    ')

    local success_rate=$(jq -r '.success_rate // 0' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "0")
    update_task_queue "$updated_queue" "$success_rate"
}

# Mark a phase as complete
mark_phase_complete() {
    local issue=$1
    local phase=$2

    if [ ! -f "$STATE_MONITOR_TASK_QUEUE" ]; then
        return 0
    fi

    local queue=$(jq -r '.queue // []' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "[]")

    local updated_queue=$(echo "$queue" | jq --arg issue "#$issue" --arg phase "$phase" '
        map(
            if .issue == $issue then
                .phases[$phase].status = "complete"
            else
                .
            end
        )
    ')

    local success_rate=$(jq -r '.success_rate // 0' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "0")
    update_task_queue "$updated_queue" "$success_rate"
}

# Mark an issue as complete
mark_issue_complete() {
    local issue=$1

    if [ ! -f "$STATE_MONITOR_TASK_QUEUE" ]; then
        return 0
    fi

    local queue=$(jq -r '.queue // []' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "[]")

    # Mark the issue as complete and no longer current
    local updated_queue=$(echo "$queue" | jq --arg issue "#$issue" '
        map(
            if .issue == $issue then
                .is_current = false |
                .status = "complete"
            else
                .
            end
        )
    ')

    local success_rate=$(jq -r '.success_rate // 0' "$STATE_MONITOR_TASK_QUEUE" 2>/dev/null || echo "0")
    update_task_queue "$updated_queue" "$success_rate"
}
