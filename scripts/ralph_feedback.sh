#!/bin/bash
# scripts/ralph_feedback.sh - Feedback compression and context management for retry loops
# Enables fresh Claude sessions with minimal, compressed context from previous attempts

# Source dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ralph_state.sh"

# Initialize feedback tracking for an issue
init_issue_feedback() {
    local issue=$1
    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"

    if [ ! -f "$feedback_file" ]; then
        cat > "$feedback_file" <<EOF
{
  "issue": $issue,
  "total_attempts": 0,
  "attempts": []
}
EOF
    fi
}

# Save feedback from a single attempt
# Args: issue, attempt_number, phase, status, error_message, full_log
save_attempt_feedback() {
    local issue=$1
    local attempt=$2
    local phase=$3
    local status=$4
    local error_msg=$5
    local full_log=$6

    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Extract key details only (compression)
    local compressed_error=$(echo "$error_msg" | head -20 | tr '\n' ' ' | sed 's/  */ /g')

    # Build attempt entry using jq to ensure proper JSON escaping
    # This prevents jq syntax errors when error_summary contains quotes or special characters
    local temp_file="${feedback_file}.tmp"
    jq --arg attempt "$attempt" \
       --arg phase "$phase" \
       --arg status "$status" \
       --arg timestamp "$timestamp" \
       --arg error_summary "$compressed_error" \
       '.total_attempts = ($attempt | tonumber) |
        .attempts += [{
          attempt: ($attempt | tonumber),
          phase: $phase,
          status: $status,
          timestamp: $timestamp,
          error_summary: $error_summary
        }]' "$feedback_file" > "$temp_file"
    mv "$temp_file" "$feedback_file"

    log_info "Feedback saved for issue #$issue attempt $attempt"
}

# Extract validation errors from output (compression helper)
extract_validation_errors() {
    local output="$1"

    # Extract lines containing error keywords
    echo "$output" | grep -iE "error|failed|failure|exception|assertion" | head -30 | sed 's/^/  - /'

    # If no errors found, return generic message
    if [ $? -ne 0 ]; then
        echo "  - Validation failed (see logs for details)"
    fi
}

# Build feedback context for next attempt (minimal prompt construction)
build_feedback_context() {
    local issue=$1
    local current_attempt=$2

    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"

    if [ ! -f "$feedback_file" ] || [ "$current_attempt" -eq 1 ]; then
        echo ""  # No previous attempts
        return
    fi

    # Build compressed context from previous attempts
    local context="PREVIOUS ATTEMPTS:
"

    local prev_attempts=$(jq -r ".attempts[] | select(.attempt < $current_attempt) |
        \"Attempt \(.attempt): \(.phase) \(.status)
  Error: \(.error_summary)
\"" "$feedback_file")

    if [ -n "$prev_attempts" ]; then
        context="${context}${prev_attempts}
IMPORTANT: Analyze what went wrong in previous attempts and try a different approach.
If validation failed, focus on fixing those specific errors.
If merge failed, address the merge issues (draft PR, conflicts, etc.)."
    fi

    echo "$context"
}

# Build plan prompt with feedback context
build_plan_prompt() {
    local issue=$1
    local attempt=$2
    local feedback_context="$3"

    local base_prompt="Execute the /create_plan command for GitHub issue #$issue

This is attempt $attempt/$MAX_ATTEMPTS_PER_ISSUE."

    if [ -n "$feedback_context" ]; then
        base_prompt="$base_prompt

$feedback_context

Based on previous failures, create a plan that addresses the issues encountered."
    fi

    base_prompt="$base_prompt

After completion, verify the plan document was created in thoughts/plans/ and output 'PLAN_COMPLETE'."

    echo "$base_prompt"
}

# Build implementation prompt with feedback context
build_implement_prompt() {
    local issue=$1
    local attempt=$2
    local plan_file=$3
    local feedback_context="$4"

    local base_prompt="Execute the /implement_plan command for plan file: $plan_file

This is attempt $attempt/$MAX_ATTEMPTS_PER_ISSUE for GitHub issue #$issue."

    if [ -n "$feedback_context" ]; then
        base_prompt="$base_prompt

$feedback_context

Key points:
- If previous attempts had validation errors, fix those specific issues
- If previous attempts had no file changes, ensure you actually implement code
- If previous attempts had merge issues, ensure PR is created correctly
- Try a different implementation approach if previous attempts failed

Be thorough and ensure all implementation steps are completed."
    fi

    base_prompt="$base_prompt

After completion, output 'IMPLEMENTATION_COMPLETE'."

    echo "$base_prompt"
}

# Get failure summary for issue comment
get_failure_summary() {
    local issue=$1
    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"

    if [ ! -f "$feedback_file" ]; then
        echo "No attempt history found"
        return
    fi

    local total=$(jq -r '.total_attempts' "$feedback_file")
    local summary="Attempted $total times:

"

    # Group by phase
    local phases=$(jq -r '.attempts | group_by(.phase) | map({phase: .[0].phase, count: length, statuses: [.[].status] | unique}) | .[] | "- \(.phase): \(.count) attempts (\(.statuses | join(", ")))"' "$feedback_file")

    summary="${summary}${phases}

Most recent errors:"

    # Get last 3 attempts
    local recent=$(jq -r '.attempts[-3:] | .[] | "- Attempt \(.attempt) (\(.phase)): \(.error_summary | .[0:100])"' "$feedback_file")

    summary="${summary}
${recent}

Full logs available in .ralph/ directory."

    echo "$summary"
}

# Count specific failure types for analysis
count_failure_type() {
    local issue=$1
    local phase=$2
    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"

    if [ ! -f "$feedback_file" ]; then
        echo "0"
        return
    fi

    jq -r "[.attempts[] | select(.phase == \"$phase\" and .status == \"failed\")] | length" "$feedback_file"
}

# Check if issue is stuck in same phase
is_stuck_in_phase() {
    local issue=$1
    local phase=$2
    local threshold=${3:-5}  # Default: stuck if same phase fails 5+ times

    local count=$(count_failure_type "$issue" "$phase")

    if [ "$count" -ge "$threshold" ]; then
        return 0  # True: stuck
    else
        return 1  # False: not stuck
    fi
}

# Get suggested next approach based on failure patterns
suggest_next_approach() {
    local issue=$1
    local feedback_file="$(get_issue_log_dir $issue)/feedback.json"

    if [ ! -f "$feedback_file" ]; then
        echo "standard"
        return
    fi

    # Analyze failure patterns
    local validation_failures=$(count_failure_type "$issue" "validation")
    local implementation_failures=$(count_failure_type "$issue" "implementation")
    local merge_failures=$(count_failure_type "$issue" "merge")

    # Suggest approach based on patterns
    if [ "$validation_failures" -ge 3 ]; then
        echo "focus_on_tests"
    elif [ "$implementation_failures" -ge 3 ]; then
        echo "simpler_approach"
    elif [ "$merge_failures" -ge 3 ]; then
        echo "fix_pr_issues"
    else
        echo "standard"
    fi
}

# Clean up feedback files for completed/abandoned issues
# Note: Feedback is now archived with the entire issue directory (see archive_issue function)
cleanup_feedback() {
    local issue=$1
    # Feedback will be archived automatically with the entire issue directory
    # No action needed here - kept for backward compatibility
    log_info "Feedback for issue #$issue will be archived with issue directory"
}
