#!/bin/bash
# scripts/ralph_circuit_breaker.sh - Circuit breaker pattern for Ralph autonomous loop

# Prevent multiple sourcing
[[ -n "${RALPH_CB_LOADED:-}" ]] && return 0
RALPH_CB_LOADED=1

# Source utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ralph_utils.sh"

# Circuit breaker state file
readonly CB_STATE_FILE=".ralph/state/circuit_breaker.json"

# Thresholds
readonly CB_NO_PROGRESS_THRESHOLD=3
readonly CB_SAME_ERROR_THRESHOLD=5
readonly CB_VALIDATION_FAIL_THRESHOLD=3

# Circuit breaker states
readonly CB_STATE_CLOSED="CLOSED"
readonly CB_STATE_HALF_OPEN="HALF_OPEN"
readonly CB_STATE_OPEN="OPEN"

# Initialize circuit breaker state
cb_init() {
    if [ ! -f "$CB_STATE_FILE" ]; then
        json_write "$CB_STATE_FILE" '{
            "state": "'$CB_STATE_CLOSED'",
            "consecutive_no_progress": 0,
            "consecutive_same_error": 0,
            "consecutive_validation_fails": 0,
            "last_error": null,
            "last_transition": "'$(timestamp_iso)'",
            "files_changed_history": []
        }'
    fi
}

# Get current circuit breaker state
cb_get_state() {
    json_read "$CB_STATE_FILE" '.state' "$CB_STATE_CLOSED"
}

# Check if circuit breaker should halt execution
cb_should_halt() {
    local state=$(cb_get_state)

    if [ "$state" = "$CB_STATE_OPEN" ]; then
        return 0  # Yes, halt
    fi

    return 1  # No, continue
}

# Record loop result and update circuit breaker
cb_record_result() {
    local files_changed=$1
    local error_msg=${2:-""}
    local validation_passed=${3:-"true"}

    local state=$(cb_get_state)
    local no_progress=$(json_read "$CB_STATE_FILE" '.consecutive_no_progress' '0')
    local same_error=$(json_read "$CB_STATE_FILE" '.consecutive_same_error' '0')
    local validation_fails=$(json_read "$CB_STATE_FILE" '.consecutive_validation_fails' '0')
    local last_error=$(json_read "$CB_STATE_FILE" '.last_error' 'null')

    # Check 1: No progress detection
    if [ "$files_changed" -eq 0 ]; then
        no_progress=$((no_progress + 1))
        log_warning "No progress: $no_progress/$CB_NO_PROGRESS_THRESHOLD iterations without file changes"

        if [ "$no_progress" -ge "$CB_NO_PROGRESS_THRESHOLD" ]; then
            state="$CB_STATE_OPEN"
            log_error "Circuit breaker OPEN: No progress for $CB_NO_PROGRESS_THRESHOLD iterations"
        elif [ "$no_progress" -eq 2 ]; then
            state="$CB_STATE_HALF_OPEN"
            log_warning "Circuit breaker HALF_OPEN: Monitoring for progress"
        fi
    else
        # Progress made - reset counter and return to CLOSED
        if [ "$no_progress" -gt 0 ]; then
            log_success "Progress resumed: $files_changed files changed"
        fi
        no_progress=0
        if [ "$state" = "$CB_STATE_HALF_OPEN" ]; then
            state="$CB_STATE_CLOSED"
            log_success "Circuit breaker CLOSED: Normal operation resumed"
        fi
    fi

    # Check 2: Same error detection
    if [ -n "$error_msg" ] && [ "$error_msg" != "null" ]; then
        if [ "$last_error" = "$error_msg" ]; then
            same_error=$((same_error + 1))
            log_warning "Same error repeated: $same_error/$CB_SAME_ERROR_THRESHOLD times"

            if [ "$same_error" -ge "$CB_SAME_ERROR_THRESHOLD" ]; then
                state="$CB_STATE_OPEN"
                log_error "Circuit breaker OPEN: Same error repeated $CB_SAME_ERROR_THRESHOLD times"
            fi
        else
            # Different error - reset counter
            same_error=1
            last_error="$error_msg"
        fi
    else
        # No error - reset counter
        same_error=0
        last_error="null"
    fi

    # Check 3: Validation failures
    if [ "$validation_passed" = "false" ]; then
        validation_fails=$((validation_fails + 1))
        log_warning "Validation failed: $validation_fails/$CB_VALIDATION_FAIL_THRESHOLD consecutive failures"

        if [ "$validation_fails" -ge "$CB_VALIDATION_FAIL_THRESHOLD" ]; then
            state="$CB_STATE_OPEN"
            log_error "Circuit breaker OPEN: Validation failed $CB_VALIDATION_FAIL_THRESHOLD times"
        fi
    else
        # Validation passed - reset counter
        if [ "$validation_fails" -gt 0 ]; then
            log_success "Validation passed after $validation_fails failures"
        fi
        validation_fails=0
    fi

    # Update state
    local escaped_error=$(echo "$last_error" | jq -Rs '.')
    json_write "$CB_STATE_FILE" "{
        \"state\": \"$state\",
        \"consecutive_no_progress\": $no_progress,
        \"consecutive_same_error\": $same_error,
        \"consecutive_validation_fails\": $validation_fails,
        \"last_error\": $escaped_error,
        \"last_transition\": \"$(timestamp_iso)\",
        \"files_changed_history\": $(jq ".files_changed_history += [$files_changed] | .[-10:]" "$CB_STATE_FILE" 2>/dev/null || echo "[$files_changed]")
    }"

    # Return new state
    echo "$state"
}

# Display circuit breaker status
cb_show_status() {
    if [ ! -f "$CB_STATE_FILE" ]; then
        log_info "Circuit breaker: Not initialized"
        return
    fi

    local state=$(cb_get_state)
    local no_progress=$(json_read "$CB_STATE_FILE" '.consecutive_no_progress' '0')
    local same_error=$(json_read "$CB_STATE_FILE" '.consecutive_same_error' '0')
    local validation_fails=$(json_read "$CB_STATE_FILE" '.consecutive_validation_fails' '0')

    echo
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│              Circuit Breaker Status                         │"
    echo "├─────────────────────────────────────────────────────────────┤"

    case "$state" in
        "$CB_STATE_CLOSED")
            echo -e "│ State:              ${GREEN}CLOSED${NC} (Normal operation)                │"
            ;;
        "$CB_STATE_HALF_OPEN")
            echo -e "│ State:              ${YELLOW}HALF_OPEN${NC} (Monitoring)                  │"
            ;;
        "$CB_STATE_OPEN")
            echo -e "│ State:              ${RED}OPEN${NC} (Execution halted)                 │"
            ;;
    esac

    echo "│                                                             │"
    echo "│ No Progress:        $no_progress/$CB_NO_PROGRESS_THRESHOLD iterations                      │"
    echo "│ Same Error:         $same_error/$CB_SAME_ERROR_THRESHOLD repetitions                      │"
    echo "│ Validation Fails:   $validation_fails/$CB_VALIDATION_FAIL_THRESHOLD consecutive                      │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo

    if [ "$state" = "$CB_STATE_OPEN" ]; then
        echo -e "${RED}⚠️  Circuit breaker is OPEN - execution will not continue${NC}"
        echo
        echo "Possible recovery actions:"
        echo "  1. Review the issue and fix underlying problems"
        echo "  2. Reset circuit breaker: ralph --reset-circuit"
        echo "  3. Skip to next issue"
        echo
    fi
}

# Reset circuit breaker
cb_reset() {
    log_warning "Resetting circuit breaker..."

    json_write "$CB_STATE_FILE" '{
        "state": "'$CB_STATE_CLOSED'",
        "consecutive_no_progress": 0,
        "consecutive_same_error": 0,
        "consecutive_validation_fails": 0,
        "last_error": null,
        "last_transition": "'$(timestamp_iso)'",
        "files_changed_history": []
    }'

    log_success "Circuit breaker reset to CLOSED state"
}

# Get recovery suggestion based on circuit state
cb_get_recovery_suggestion() {
    local no_progress=$(json_read "$CB_STATE_FILE" '.consecutive_no_progress' '0')
    local same_error=$(json_read "$CB_STATE_FILE" '.consecutive_same_error' '0')
    local validation_fails=$(json_read "$CB_STATE_FILE" '.consecutive_validation_fails' '0')
    local last_error=$(json_read "$CB_STATE_FILE" '.last_error' 'null')

    if [ "$no_progress" -ge "$CB_NO_PROGRESS_THRESHOLD" ]; then
        echo "No progress detected. Suggestions:"
        echo "  - Check if issue requirements are clear"
        echo "  - Review @fix_plan.md for ambiguous tasks"
        echo "  - Consider breaking down the issue into smaller pieces"
        return
    fi

    if [ "$same_error" -ge "$CB_SAME_ERROR_THRESHOLD" ]; then
        echo "Same error repeated $same_error times:"
        echo "  Error: $last_error"
        echo
        echo "Suggestions:"
        echo "  - Review error message and fix root cause"
        echo "  - Check if dependencies are missing"
        echo "  - Consider if this issue has external blockers"
        return
    fi

    if [ "$validation_fails" -ge "$CB_VALIDATION_FAIL_THRESHOLD" ]; then
        echo "Validation failed $validation_fails times. Suggestions:"
        echo "  - Review validation failures in issue comments"
        echo "  - Check if tests are flaky or environment-specific"
        echo "  - Consider if implementation approach needs rethinking"
        return
    fi

    echo "Circuit breaker triggered for unknown reason. Review state:"
    cat "$CB_STATE_FILE" | jq '.'
}
