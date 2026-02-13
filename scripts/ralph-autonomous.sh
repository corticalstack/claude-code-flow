#!/bin/bash
# ralph-autonomous.sh - Autonomous workflow with retry loops and fresh Claude sessions
# Each attempt at an issue uses a FRESH Claude session with only compressed feedback from previous attempts

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/ralph_utils.sh"
source "$SCRIPT_DIR/ralph_state.sh"
source "$SCRIPT_DIR/ralph_circuit_breaker.sh"
source "$SCRIPT_DIR/ralph_github.sh"
source "$SCRIPT_DIR/ralph_priority.sh"
source "$SCRIPT_DIR/ralph_feedback.sh"

# Configuration
readonly MAX_ISSUE_ITERATIONS=10        # Process up to 10 different issues
readonly MAX_ATTEMPTS_PER_ISSUE=10      # Retry each issue up to 10 times with fresh sessions
readonly CLAUDE_TIMEOUT_SECONDS=1800    # 30 minutes per phase
readonly ENABLE_PR_REVIEW=true          # Enable @claude PR reviews before merge
readonly MAX_REVIEW_ITERATIONS=3        # Max feedback iterations per PR
readonly PR_REVIEW_TIMEOUT=600          # 10 minutes timeout for review
readonly PR_REVIEW_POLL_INTERVAL=30     # Check review status every 30 seconds
readonly ENABLE_PR_AUTO_MERGE=true      # Enable auto-merge after validation passes
readonly CREATE_DRAFT_PRS=false         # Don't create draft PRs - create ready-to-merge PRs
readonly RALPH_EXEMPT_LABEL="ralph-exempt"  # Issues with this label will be skipped by Ralph
readonly RALPH_VERBOSE_MODE=true           # Enable verbose output from Claude commands (shows tool calls, actions, progress)

# Parse command line arguments
SHOW_PRIORITIES=false
RESET_STATE=false
RESET_CIRCUIT=false
SHOW_STATUS=false
DRY_RUN=false
MONITOR_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --priorities)
            SHOW_PRIORITIES=true
            shift
            ;;
        --reset-state)
            RESET_STATE=true
            shift
            ;;
        --reset-circuit)
            RESET_CIRCUIT=true
            shift
            ;;
        --status)
            SHOW_STATUS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --monitor|-m)
            MONITOR_MODE=true
            shift
            ;;
        --help|-h)
            echo "Ralph Autonomous Loop - Retry Architecture"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Architecture:"
            echo "  - Processes issues one at a time"
            echo "  - Retries each issue up to $MAX_ATTEMPTS_PER_ISSUE times"
            echo "  - Each retry uses a FRESH Claude session with compressed feedback"
            echo "  - No human review needed - autonomous retry with learning"
            echo
            echo "Options:"
            echo "  --priorities        Show prioritized issue list and exit"
            echo "  --status            Show current status and exit"
            echo "  --reset-state       Reset state and active issues (preserves archives)"
            echo "  --reset-circuit     Reset circuit breaker to CLOSED"
            echo "  --dry-run           Show what would be done without executing"
            echo "  --monitor, -m       Launch with real-time monitoring dashboard in tmux"
            echo "  --help, -h          Show this help message"
            echo
            echo "Monitoring Mode:"
            echo "  Launch with --monitor to see a real-time dashboard in a split tmux session"
            echo "  - Left pane: Ralph execution logs"
            echo "  - Right pane: Live dashboard with task queue, progress, and status"
            echo "  - Detach: Ctrl+B then D"
            echo "  - Reattach: tmux attach -t ralph-monitor-*"
            echo
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Handle special modes
if [ "$SHOW_PRIORITIES" = true ]; then
    display_issue_priorities
    exit 0
fi

if [ "$SHOW_STATUS" = true ]; then
    cb_show_status
    echo "Session: $(get_session_id)"
    echo "Issue iteration: $(get_iteration)/$MAX_ISSUE_ITERATIONS"
    echo
    get_counters_summary | jq '.'
    exit 0
fi

if [ "$RESET_STATE" = true ]; then
    if confirm "Reset Ralph state? This will clear session, counters, and active issues (archives preserved)." "n"; then
        reset_state
    fi
    exit 0
fi

if [ "$RESET_CIRCUIT" = true ]; then
    if confirm "Reset circuit breaker to CLOSED state?" "n"; then
        cb_reset
    fi
    exit 0
fi

# Check dependencies
if ! check_dependencies; then
    log_error "Missing dependencies. Please install required tools."
    exit 1
fi

# Launch in tmux if monitoring mode is enabled
if [ "$MONITOR_MODE" = true ]; then
    # Check if tmux is installed
    if ! check_tmux_available; then
        show_tmux_install_instructions
        exit 1
    fi

    # Build session name
    SESSION_NAME="ralph-monitor-$(date +%Y%m%d-%H%M%S)-$$"

    # Get absolute paths
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    MONITOR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ralph_monitor.sh"
    WORK_DIR="$(pwd)"

    # Build arguments to pass to inner script (excluding --monitor)
    RALPH_ARGS=""
    if [ "$DRY_RUN" = true ]; then
        RALPH_ARGS="$RALPH_ARGS --dry-run"
    fi

    log_info "Starting Ralph with monitoring in tmux session: $SESSION_NAME"
    log_info "Debug: Passing RALPH_MONITOR_MODE=1 to tmux session"
    log_info "Debug: Script path: $SCRIPT_PATH"
    log_info "Debug: Args: $RALPH_ARGS"

    # Create logs directory
    mkdir -p logs

    # Launch tmux with two panes
    # Use environment variable to signal monitor mode to inner script
    cd "$WORK_DIR"

    # Build the command - prepend env var directly, redirect output to capture errors
    RALPH_CMD="RALPH_MONITOR_MODE=1 bash $SCRIPT_PATH $RALPH_ARGS 2>&1 | tee logs/ralph-tmux.log"

    log_info "Debug: Full command: $RALPH_CMD"

    # Check for Ralph tmux config file
    TMUX_CONFIG_PATH="$(dirname "$SCRIPT_PATH")/.tmux.ralph.conf"
    if [ -f "$TMUX_CONFIG_PATH" ]; then
        log_info "Using Ralph tmux configuration: $TMUX_CONFIG_PATH"
        TMUX_CONFIG_FLAG="-f $TMUX_CONFIG_PATH"
    else
        log_warning "Ralph tmux config not found, using default tmux settings"
        TMUX_CONFIG_FLAG=""
    fi

    # Create tmux session with split panes (create detached, then split, then attach)
    tmux $TMUX_CONFIG_FLAG new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" "$RALPH_CMD"

    # Set pane title for Ralph execution pane
    tmux select-pane -t "$SESSION_NAME":0.0 -T "Ralph Orchestrator"

    # Split window and create monitor dashboard pane
    tmux split-window -t "$SESSION_NAME" -h -c "$WORK_DIR" "bash $MONITOR_PATH"

    # Set pane title for monitor dashboard pane
    tmux select-pane -t "$SESSION_NAME":0.1 -T "Ralph Task Monitoring Dashboard"

    # Select Ralph execution pane as active
    tmux select-pane -t "$SESSION_NAME":0.0

    # Attach to the session (config already loaded at session creation)
    exec tmux attach-session -t "$SESSION_NAME"
fi

# Initialize state
init_state
cb_init
init_monitor_state

# Debug: Check if running in monitor mode
log_info "Debug: Script started with RALPH_MONITOR_MODE=${RALPH_MONITOR_MODE:-unset}"
if [ -n "${TMUX:-}" ]; then
    TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")
    log_info "Debug: Running in tmux session: $TMUX_SESSION"
fi

# Start session
SESSION_ID=$(start_session)

# Build and update initial task queue for monitoring (with priority sorting)
TASK_QUEUE=$(build_prioritized_task_queue)
update_task_queue "$TASK_QUEUE" 0
update_monitor_status "running" "initializing" "null"

# Helper function to get Claude flags based on configuration
get_claude_flags() {
    # CRITICAL: --allowedTools causes print mode to hang
    # Must use --dangerously-skip-permissions for autonomous execution
    local flags="--dangerously-skip-permissions"

    if [ "$RALPH_VERBOSE_MODE" = true ]; then
        flags="$flags --verbose --output-format stream-json"
    fi

    echo "$flags"
}

# Helper function to execute Claude with optional verbose parsing
execute_claude() {
    local timeout_seconds="$1"
    local prompt="$2"
    local log_file="$3"

    if [ "$RALPH_VERBOSE_MODE" = true ]; then
        # Verbose mode: use JSON streaming with parser for real-time tool visibility
        # Use stdbuf to force line-buffering for immediate output
        stdbuf -oL timeout "$timeout_seconds" claude $(get_claude_flags) --print "$prompt" 2>&1 | \
            stdbuf -oL "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/parse_claude_stream.sh" | \
            stdbuf -oL tee "$log_file"
    else
        # Normal mode: standard text output
        timeout "$timeout_seconds" claude --print "$prompt" 2>&1 | tee "$log_file"
    fi
}

# Trap signals for graceful shutdown
cleanup() {
    log_warning "Received interrupt signal, cleaning up..."
    update_session null "interrupted"
    update_monitor_status "interrupted" "none" "null" "User interrupted execution"
    cb_show_status
    show_summary "$(get_iteration)" \
                  "$(json_read "$RALPH_STATE_DIR/counters.json" '.successful_issues' '0')" \
                  "$(json_read "$RALPH_STATE_DIR/counters.json" '.failed_issues' '0')" \
                  "$(json_read "$RALPH_STATE_DIR/counters.json" '.blocked_issues' '0')"

    # Check if we're in a ralph-monitor tmux session (same detection as below)
    local in_ralph_tmux=false
    if [ -n "${TMUX:-}" ]; then
        local tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "")
        if [[ "$tmux_session" == ralph-monitor-* ]]; then
            in_ralph_tmux=true
        fi
    fi

    # Keep pane alive in monitor mode (check flag, env var, or tmux session)
    if [ "$MONITOR_MODE" = true ] || [ "${RALPH_MONITOR_MODE:-0}" = "1" ] || [ "$in_ralph_tmux" = true ]; then
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Interrupted. Monitor dashboard is still running in the right pane."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "Press Enter to close this pane..."
        read -r -p ""
    fi

    exit 130
}

# Handle unexpected errors to prevent silent crashes
error_handler() {
    local exit_code=$?
    log_error "Unexpected error occurred (exit code: $exit_code)"
    log_error "Last command: $BASH_COMMAND"
    log_error "Line: $BASH_LINENO"
    cleanup
    exit $exit_code
}

trap cleanup SIGINT SIGTERM
trap error_handler ERR

# ============================================================================
# OUTER LOOP: Process multiple issues
# ============================================================================
ISSUE_ITERATION=0

while [ "$ISSUE_ITERATION" -lt "$MAX_ISSUE_ITERATIONS" ]; do
    ISSUE_ITERATION=$((ISSUE_ITERATION + 1))
    increment_iteration

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "ISSUE ITERATION $ISSUE_ITERATION/$MAX_ISSUE_ITERATIONS"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check circuit breaker
    if cb_should_halt; then
        log_error "Circuit breaker is OPEN - halting execution"
        cb_show_status
        cb_get_recovery_suggestion
        break
    fi

    # Check rate limit
    if ! check_rate_limit; then
        log_warning "Rate limit reached - waiting for reset..."
        wait_with_countdown 3600 "Rate limit cooldown"
    fi

    # ========================================================================
    # STEP 1: Select next issue to work on
    # ========================================================================
    log_phase "Step 1: Selecting next issue"

    ISSUE=$(select_next_issue)
    if [ $? -ne 0 ] || [ -z "$ISSUE" ]; then
        log_info "No more issues to process"
        break
    fi

    ISSUE_TITLE=$(gh_get_issue_title "$ISSUE")
    show_iteration "$ISSUE_ITERATION" "$MAX_ISSUE_ITERATIONS" "$ISSUE"
    log_info "Title: $ISSUE_TITLE"

    update_session "$ISSUE" "selection"

    # Mark this issue as currently being worked on
    mark_issue_current "$ISSUE"

    # Check if already blocked
    if gh_is_issue_blocked "$ISSUE"; then
        log_warning "Issue #$ISSUE is blocked, skipping"
        increment_blocked
        add_history_entry "$ISSUE" "blocked" "skipped" "Issue is blocked by dependency"
        continue
    fi

    # Initialize feedback tracking for this issue
    init_issue_feedback "$ISSUE"

    # ========================================================================
    # INNER RETRY LOOP: Attempt same issue multiple times with fresh sessions
    # ========================================================================
    ATTEMPT=0
    ISSUE_SUCCEEDED=false

    while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS_PER_ISSUE" ]; do
        ATTEMPT=$((ATTEMPT + 1))

        echo
        log_info "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "┃ ATTEMPT $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE for Issue #$ISSUE"
        log_info "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo

        # Load feedback from all previous attempts
        FEEDBACK_CONTEXT=$(build_feedback_context "$ISSUE" "$ATTEMPT")

        # Check if issue was closed (by previous attempt or externally)
        if gh_is_issue_closed "$ISSUE"; then
            log_success "Issue #$ISSUE is already CLOSED - skipping further attempts"
            log_info "Issue was closed during previous attempt or externally"
            ISSUE_SUCCEEDED=true
            mark_issue_complete "$ISSUE"
            increment_successful
            add_history_entry "$ISSUE" "complete" "success" "Issue already closed (detected at attempt $ATTEMPT)"
            break  # Exit retry loop - issue is complete!
        fi

        # ====================================================================
        # PHASE: Research (only on attempt 1, cached thereafter)
        # ====================================================================
        if [ "$ATTEMPT" -eq 1 ]; then
            log_phase "Research Phase"
            update_session "$ISSUE" "research"
            update_monitor_status "running" "research" "$ISSUE"

            # Track research phase attempt
            increment_phase_attempt "$ISSUE" "research"

            RESEARCH_FILE=$(gh_check_research_exists "$ISSUE" || true)
            if [ -n "$RESEARCH_FILE" ]; then
                log_info "Research already exists: $RESEARCH_FILE"
            else
                log_info "Starting research for issue #$ISSUE"

                if [ "$DRY_RUN" = false ]; then
                    gh_update_label "$ISSUE" "research-in-progress" ""

                    log_info "Invoking /research_codebase skill in FRESH Claude session..."
                    increment_rate_limit
                    record_api_call

                    # FRESH CLAUDE SESSION - No prior context
                    PROMPT="Execute the /research_codebase command for GitHub issue #$ISSUE.

CRITICAL: You are in AUTONOMOUS mode.
- Do NOT use AskUserQuestion tool
- Make reasonable decisions and proceed
- When uncertain, choose conventional approaches
- Document any assumptions in the research document

After completion, verify the research document was created in flow/research/ and output 'RESEARCH_COMPLETE'."

                    if execute_claude "$CLAUDE_TIMEOUT_SECONDS" "$PROMPT" "$(get_issue_log_dir $ISSUE)/research_attempt_${ATTEMPT}.log"; then
                        log_success "Research skill completed"

                        RESEARCH_FILE=$(gh_check_research_exists "$ISSUE" || true)
                        if [ -z "$RESEARCH_FILE" ]; then
                            save_attempt_feedback "$ISSUE" "$ATTEMPT" "research" "failed" "Research document not created" ""
                            log_error "Research document not found, will retry in next attempt"
                            continue  # RETRY with fresh session
                        fi

                        log_success "Research document created: $RESEARCH_FILE"
                        gh_update_label "$ISSUE" "research-complete" "research-in-progress"

                        # Mark research phase as complete
                        mark_phase_complete "$ISSUE" "research"
                    else
                        save_attempt_feedback "$ISSUE" "$ATTEMPT" "research" "timeout" "Research timed out after $CLAUDE_TIMEOUT_SECONDS seconds" ""
                        log_error "Research timed out, will retry in next attempt"
                        continue  # RETRY with fresh session
                    fi
                else
                    log_info "[DRY RUN] Would invoke /research_codebase for issue #$ISSUE"
                fi
            fi
        fi

        # ====================================================================
        # PHASE: Planning
        # ====================================================================
        log_phase "Planning Phase (Attempt $ATTEMPT)"
        update_session "$ISSUE" "planning"
        update_monitor_status "running" "planning" "$ISSUE"

        # Track planning phase attempt
        increment_phase_attempt "$ISSUE" "planning"

        PLAN_FILE=$(gh_check_plan_exists "$ISSUE" || true)

        if [ "$DRY_RUN" = false ]; then
            gh_update_label "$ISSUE" "planning-in-progress" "research-complete,ready-for-dev,in-progress"

            log_info "Invoking /create_plan skill in FRESH Claude session..."
            increment_rate_limit
            record_api_call

            # FRESH CLAUDE SESSION - With compressed feedback from previous attempts
            PLAN_PROMPT=$(build_plan_prompt "$ISSUE" "$ATTEMPT" "$FEEDBACK_CONTEXT")

            if execute_claude "$CLAUDE_TIMEOUT_SECONDS" "$PLAN_PROMPT" "$(get_issue_log_dir $ISSUE)/plan_attempt_${ATTEMPT}.log"; then
                log_success "Planning skill completed"

                PLAN_FILE=$(gh_check_plan_exists "$ISSUE" || true)
                if [ -z "$PLAN_FILE" ]; then
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "planning" "failed" "Plan document not created" ""
                    log_error "Plan document not found, will retry in next attempt"
                    continue  # RETRY with fresh session
                fi

                log_success "Plan document created: $PLAN_FILE"
                gh_update_label "$ISSUE" "ready-for-dev" "planning-in-progress"

                # Mark planning phase as complete
                mark_phase_complete "$ISSUE" "planning"
            else
                save_attempt_feedback "$ISSUE" "$ATTEMPT" "planning" "timeout" "Planning timed out after $CLAUDE_TIMEOUT_SECONDS seconds" ""
                log_error "Planning timed out, will retry in next attempt"
                continue  # RETRY with fresh session
            fi
        else
            log_info "[DRY RUN] Would invoke /create_plan for issue #$ISSUE"
        fi

        # ====================================================================
        # PHASE: Implementation
        # ====================================================================
        log_phase "Implementation Phase (Attempt $ATTEMPT)"
        update_session "$ISSUE" "implementation"
        update_monitor_status "running" "implementing" "$ISSUE"

        # Track implementation phase attempt
        increment_phase_attempt "$ISSUE" "implementation"

        if [ "$DRY_RUN" = false ]; then
            # Ensure we're on main branch
            if ! gh_is_on_main; then
                log_warning "Not on main branch, resetting..."
                gh_reset_to_main
            fi

            # Create or checkout feature branch
            BRANCH=$(gh_create_feature_branch "$ISSUE" "$ISSUE_TITLE")
            if [ $? -ne 0 ]; then
                save_attempt_feedback "$ISSUE" "$ATTEMPT" "git" "failed" "Failed to create feature branch" ""
                log_error "Failed to create branch, will retry in next attempt"
                continue  # RETRY with fresh session
            fi

            log_info "Working on branch: $BRANCH"
        else
            # Dry run - just log what would happen
            BRANCH="feature/${ISSUE}-dry-run"
            log_info "[DRY RUN] Would reset to main and create branch: $BRANCH"
        fi

        if [ "$DRY_RUN" = false ]; then
            gh_update_label "$ISSUE" "in-progress" "ready-for-dev"

            log_info "Invoking /implement_plan skill in FRESH Claude session..."
            increment_rate_limit
            record_api_call

            # FRESH CLAUDE SESSION - With compressed feedback from previous attempts
            IMPL_PROMPT=$(build_implement_prompt "$ISSUE" "$ATTEMPT" "$PLAN_FILE" "$FEEDBACK_CONTEXT")

            # Run claude command and capture exit status
            # Use 'set +e' temporarily to prevent script exit on failure
            set +e
            execute_claude "$CLAUDE_TIMEOUT_SECONDS" "$IMPL_PROMPT" "$(get_issue_log_dir $ISSUE)/implement_attempt_${ATTEMPT}.log"
            IMPL_EXIT_CODE=$?
            set -e

            if [ "$IMPL_EXIT_CODE" -eq 0 ]; then
                log_success "Implementation skill completed"

                # Check if files were changed
                FILES_CHANGED=$(count_changed_files)
                log_info "Files changed: $FILES_CHANGED"

                if [ "$FILES_CHANGED" -eq 0 ]; then
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "implementation" "no_changes" "No files changed during implementation" ""
                    log_warning "No files changed during implementation"

                    # Check if implementation closed the issue despite no file changes
                    # (e.g., feature already implemented, skill closed issue as complete)
                    if gh_is_issue_closed "$ISSUE"; then
                        log_success "Issue #$ISSUE was CLOSED by implementation skill (feature already complete)"
                        ISSUE_SUCCEEDED=true
                        mark_issue_complete "$ISSUE"
                        increment_successful
                        add_history_entry "$ISSUE" "complete" "success" "Issue closed by implementation skill (attempt $ATTEMPT)"
                        gh_reset_to_main
                        break  # Exit retry loop - issue is complete!
                    fi

                    log_info "Issue still open, will retry with different approach"
                    gh_reset_to_main
                    continue  # RETRY with fresh session
                fi

                log_info "Changes: $(git_changes_summary)"

                # Mark implementation phase as complete
                mark_phase_complete "$ISSUE" "implementation"
            else
                # Check what kind of error occurred
                IMPL_LOG="$(get_issue_log_dir $ISSUE)/implement_attempt_${ATTEMPT}.log"
                if [ "$IMPL_EXIT_CODE" -eq 124 ]; then
                    # Timeout
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "implementation" "timeout" "Implementation timed out after $CLAUDE_TIMEOUT_SECONDS seconds" ""
                    log_error "Implementation timed out after $CLAUDE_TIMEOUT_SECONDS seconds, will retry in next attempt"
                elif grep -q "No messages returned" "$IMPL_LOG" 2>/dev/null; then
                    # Claude CLI crashed
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "implementation" "crash" "Claude CLI crashed with 'No messages returned'" ""
                    log_error "Claude CLI crashed with 'No messages returned' error (exit code: $IMPL_EXIT_CODE)"
                    log_error "This is an internal Claude CLI error - will retry in next attempt"
                else
                    # Other error
                    ERROR_MSG=$(tail -5 "$IMPL_LOG" 2>/dev/null | head -2 | tr '\n' ' ')
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "implementation" "failed" "Implementation failed with exit code $IMPL_EXIT_CODE: $ERROR_MSG" ""
                    log_error "Implementation failed with exit code $IMPL_EXIT_CODE, will retry in next attempt"
                fi
                gh_reset_to_main
                continue  # RETRY with fresh session
            fi
        else
            log_info "[DRY RUN] Would invoke /implement_plan for $PLAN_FILE"
            FILES_CHANGED=5  # Fake for dry run
        fi

        # ====================================================================
        # PHASE: Validation
        # ====================================================================
        log_phase "Validation Phase (Attempt $ATTEMPT)"
        update_session "$ISSUE" "validation"
        update_monitor_status "running" "validating" "$ISSUE"

        # Track validation phase attempt
        increment_phase_attempt "$ISSUE" "validation"

        VALIDATION_PASSED=false

        if [ "$DRY_RUN" = false ]; then
            log_info "Invoking /validate_plan skill in FRESH Claude session..."
            increment_rate_limit
            record_api_call

            # FRESH CLAUDE SESSION - Validates implementation
            VALIDATE_PROMPT="Execute the /validate_plan command for plan file: $PLAN_FILE

This is attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE.

Output validation results clearly with 'VALIDATION PASSED' or 'VALIDATION FAILED'."

            # Run claude command and capture exit status
            set +e
            VALIDATION_OUTPUT=$(execute_claude "$CLAUDE_TIMEOUT_SECONDS" "$VALIDATE_PROMPT" "$(get_issue_log_dir $ISSUE)/validate_attempt_${ATTEMPT}.log")
            VALIDATE_EXIT_CODE=$?
            set -e

            # Check if command failed
            if [ "$VALIDATE_EXIT_CODE" -ne 0 ]; then
                log_error "Validation skill failed with exit code $VALIDATE_EXIT_CODE"
                if echo "$VALIDATION_OUTPUT" | grep -q "No messages returned"; then
                    log_error "Claude CLI crashed during validation - will retry in next attempt"
                fi
                VALIDATION_PASSED=false
                cb_record_result "$FILES_CHANGED" "Validation skill crashed" "false"
            # Parse validation result
            elif echo "$VALIDATION_OUTPUT" | grep -qi "validation.*passed\|all.*checks.*passed\|validation:.*success"; then
                log_success "Validation passed!"
                VALIDATION_PASSED=true
                cb_record_result "$FILES_CHANGED" "" "true"

                # Mark validation phase as complete
                mark_phase_complete "$ISSUE" "validation"
            else
                # Extract validation errors for feedback
                VALIDATION_ERRORS=$(extract_validation_errors "$VALIDATION_OUTPUT")
                save_attempt_feedback "$ISSUE" "$ATTEMPT" "validation" "failed" "$VALIDATION_ERRORS" "$VALIDATION_OUTPUT"

                log_error "Validation failed:"
                echo "$VALIDATION_ERRORS"
                log_info "Will retry with different approach in next attempt"

                cb_record_result "$FILES_CHANGED" "validation_failed" "false"
                gh_reset_to_main
                continue  # RETRY with fresh session and validation feedback
            fi
        else
            log_info "[DRY RUN] Would invoke /validate_plan for $PLAN_FILE"
            VALIDATION_PASSED=true
        fi

        # ====================================================================
        # PHASE: Commit and Create PR
        # ====================================================================
        if [ "$VALIDATION_PASSED" = true ]; then
            log_phase "Commit and PR Phase (Attempt $ATTEMPT)"
            update_session "$ISSUE" "pr_creation"
            update_monitor_status "running" "pr_creation" "$ISSUE"

            if [ "$DRY_RUN" = false ]; then
                # Commit changes
                log_info "Invoking /autonomous_commit skill in FRESH Claude session..."
                increment_rate_limit
                record_api_call

                COMMIT_PROMPT="Execute the /autonomous_commit command. Create a commit for the changes implementing issue #$ISSUE.

This is attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE and validation has passed."

                if execute_claude 300 "$COMMIT_PROMPT" "$(get_issue_log_dir $ISSUE)/commit_attempt_${ATTEMPT}.log"; then
                    log_success "Commit created"
                else
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "commit" "failed" "Commit creation failed" ""
                    log_error "Commit failed, will retry in next attempt"
                    gh_reset_to_main
                    continue  # RETRY with fresh session
                fi

                # Push branch
                log_info "Pushing branch to remote..."
                if git push -u origin "$BRANCH" 2>&1 | tee "$(get_issue_log_dir $ISSUE)/push_attempt_${ATTEMPT}.log"; then
                    log_success "Branch pushed"
                else
                    PUSH_ERROR=$(tail -5 "$(get_issue_log_dir $ISSUE)/push_attempt_${ATTEMPT}.log")
                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "push" "failed" "Git push failed: $PUSH_ERROR" ""
                    log_error "Push failed, will retry in next attempt"
                    gh_reset_to_main
                    continue  # RETRY with fresh session
                fi

                # Check if PR already exists
                EXISTING_PR=$(gh_check_pr_exists "$BRANCH")
                if [ -n "$EXISTING_PR" ]; then
                    log_info "PR already exists: #$EXISTING_PR"
                    PR_NUMBER="$EXISTING_PR"

                    # Mark PR as ready if it's draft
                    if gh pr view "$PR_NUMBER" --json isDraft --jq '.isDraft' | grep -q "true"; then
                        log_info "Marking PR as ready for review..."
                        gh pr ready "$PR_NUMBER" || true
                    fi
                else
                    # Create PR (NOT as draft)
                    log_info "Creating pull request..."

                    PR_DRAFT_FLAG=""
                    if [ "$CREATE_DRAFT_PRS" = true ]; then
                        PR_DRAFT_FLAG="--draft"
                    fi

                    PR_OUTPUT=$(gh pr create \
                        --title "Closes #$ISSUE: $ISSUE_TITLE" \
                        --body "$(cat <<EOF
## Summary

Implements #$ISSUE

## Automated Verification
✅ All validation checks passed
✅ Tests pass
✅ Implementation matches plan

## Attempts
This succeeded on attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE

## Changes
$(git log --oneline origin/main.."$BRANCH")

---
🤖 Generated by Ralph Wiggum autonomous loop
EOF
)" \
                        $PR_DRAFT_FLAG \
                        2>&1)

                    PR_NUMBER=$(echo "$PR_OUTPUT" | grep -oP 'pull/\K[0-9]+')

                    if [ -n "$PR_NUMBER" ]; then
                        log_success "PR created: #$PR_NUMBER"
                        gh_update_label "$ISSUE" "pr-submitted" "in-progress"
                    else
                        save_attempt_feedback "$ISSUE" "$ATTEMPT" "pr_creation" "failed" "Failed to create PR: $PR_OUTPUT" ""
                        log_error "Failed to create PR, will retry in next attempt"
                        gh_reset_to_main
                        continue  # RETRY with fresh session
                    fi
                fi

                # Update issue with PR link
                PR_URL=$(gh_get_pr_url "$PR_NUMBER")
                gh_add_comment "$ISSUE" "PR created: $PR_URL (attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE)"

                # ============================================================
                # PHASE: PR Review (if enabled)
                # ============================================================
                if [ "$ENABLE_PR_REVIEW" = true ]; then
                    log_phase "PR Review Phase (Attempt $ATTEMPT)"
                    update_session "$ISSUE" "pr_review"
                    update_monitor_status "running" "pr_review" "$ISSUE"

                    # Request @claude review
                    log_info "Requesting @claude review for PR #$PR_NUMBER..."
                    gh pr comment "$PR_NUMBER" --body "@claude Please review this PR and approve it or request changes"

                    # Poll for review completion
                    log_info "Polling for review completion (timeout: ${PR_REVIEW_TIMEOUT}s)..."
                    REVIEW_START_TIME=$(date +%s)
                    REVIEW_DECISION=""
                    REVIEW_ITERATION=1

                    while [ $REVIEW_ITERATION -le $MAX_REVIEW_ITERATIONS ]; do
                        log_info "Review iteration $REVIEW_ITERATION/$MAX_REVIEW_ITERATIONS"

                        POLL_ELAPSED=0
                        REVIEW_DECISION=""

                        # Poll for review (10 minute timeout, check every 30 seconds)
                        while [ $POLL_ELAPSED -lt $PR_REVIEW_TIMEOUT ]; do
                            sleep $PR_REVIEW_POLL_INTERVAL
                            POLL_ELAPSED=$(($(date +%s) - REVIEW_START_TIME))

                            # Check review status
                            REVIEW_STATE=$(gh pr view "$PR_NUMBER" --json reviewDecision --jq '.reviewDecision // "PENDING"')

                            log_info "Review status: $REVIEW_STATE (${POLL_ELAPSED}s elapsed)"

                            if [ "$REVIEW_STATE" = "APPROVED" ]; then
                                REVIEW_DECISION="APPROVED"
                                log_success "PR approved by @claude!"
                                break 2  # Exit both loops
                            elif [ "$REVIEW_STATE" = "CHANGES_REQUESTED" ]; then
                                REVIEW_DECISION="CHANGES_REQUESTED"
                                log_info "Changes requested by @claude"
                                break  # Exit polling loop, handle feedback
                            fi
                        done

                        # Handle timeout
                        if [ -z "$REVIEW_DECISION" ]; then
                            log_warn "Review timeout after ${PR_REVIEW_TIMEOUT}s"
                            gh_update_label "$ISSUE" "needs-human-review" "pr-submitted"
                            gh_add_comment "$ISSUE" "⚠️ @claude review timed out. Needs human review."
                            REVIEW_DECISION="TIMEOUT"
                            break
                        fi

                        # Handle changes requested
                        if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ]; then
                            log_info "Handling feedback iteration $REVIEW_ITERATION/$MAX_REVIEW_ITERATIONS"

                            # Use /handle_pr_feedback to implement changes
                            log_info "Invoking /handle_pr_feedback in FRESH Claude session..."
                            increment_rate_limit
                            record_api_call

                            FEEDBACK_PROMPT="Execute the /handle_pr_feedback command for PR #$PR_NUMBER.

This is review iteration $REVIEW_ITERATION/$MAX_REVIEW_ITERATIONS for issue #$ISSUE (attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE).

The command should:
1. Fetch @claude's review feedback
2. Update the implementation plan with PR Review Updates
3. Implement the requested changes
4. Run tests
5. Commit and push
6. Request re-review

After completion, output 'FEEDBACK_HANDLED' if successful."

                            if execute_claude "$CLAUDE_TIMEOUT_SECONDS" "$FEEDBACK_PROMPT" "$(get_issue_log_dir $ISSUE)/pr_feedback_iteration_${REVIEW_ITERATION}_attempt_${ATTEMPT}.log"; then
                                # Check if feedback was handled
                                if grep -q "FEEDBACK_HANDLED" "$(get_issue_log_dir $ISSUE)/pr_feedback_iteration_${REVIEW_ITERATION}_attempt_${ATTEMPT}.log"; then
                                    log_success "Feedback implemented, requesting re-review..."

                                    # Re-request review for next iteration
                                    gh pr comment "$PR_NUMBER" --body "@claude I've addressed your feedback. Please re-review."

                                    # Reset timer for next poll
                                    REVIEW_START_TIME=$(date +%s)
                                    REVIEW_ITERATION=$((REVIEW_ITERATION + 1))

                                    # Continue to next iteration of review loop
                                    continue
                                else
                                    log_error "Feedback handling didn't complete properly"
                                    save_attempt_feedback "$ISSUE" "$ATTEMPT" "pr_feedback" "failed" "Failed to handle PR feedback properly" ""
                                    gh_update_label "$ISSUE" "needs-human-review" "pr-submitted"
                                    gh_add_comment "$ISSUE" "⚠️ Failed to handle @claude feedback. Needs human review."
                                    break
                                fi
                            else
                                log_error "Failed to execute /handle_pr_feedback"
                                save_attempt_feedback "$ISSUE" "$ATTEMPT" "pr_feedback" "failed" "Failed to execute handle_pr_feedback command" ""
                                gh_update_label "$ISSUE" "needs-human-review" "pr-submitted"
                                gh_add_comment "$ISSUE" "⚠️ Failed to process @claude feedback. Needs human review."
                                break
                            fi
                        fi
                    done

                    # Check if we exhausted iterations without approval
                    if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ] && [ $REVIEW_ITERATION -gt $MAX_REVIEW_ITERATIONS ]; then
                        log_warn "Exhausted review iterations ($MAX_REVIEW_ITERATIONS) without approval"
                        gh_update_label "$ISSUE" "needs-human-review" "pr-submitted"
                        gh_add_comment "$ISSUE" "⚠️ PR still has requested changes after $MAX_REVIEW_ITERATIONS iterations. Needs human review."
                        REVIEW_DECISION="NEEDS_HUMAN"
                    fi

                    # Only proceed to merge if approved
                    if [ "$REVIEW_DECISION" != "APPROVED" ]; then
                        log_info "PR not approved, skipping auto-merge. Decision: $REVIEW_DECISION"
                        mark_issue_complete "$ISSUE"
                        increment_successful
                        add_history_entry "$ISSUE" "complete" "needs_review" "PR created but needs human review (attempt $ATTEMPT)"
                        ISSUE_SUCCEEDED=true
                        gh_reset_to_main
                        break  # Exit retry loop, move to next issue
                    fi
                fi

                # ============================================================
                # PHASE: Merge PR (if auto-merge enabled and review approved)
                # ============================================================
                if [ "$ENABLE_PR_AUTO_MERGE" = true ]; then
                    log_phase "Merge Phase (Attempt $ATTEMPT)"

                    log_info "Auto-merge enabled, merging PR #$PR_NUMBER..."

                    if gh_merge_pr "$PR_NUMBER" "$ISSUE"; then
                        log_success "PR merged successfully!"

                        # Close issue with success comment
                        gh_close_issue "$ISSUE" "✅ Completed and merged via PR #$PR_NUMBER

Succeeded on attempt $ATTEMPT/$MAX_ATTEMPTS_PER_ISSUE
Autonomous cycle: Research → Plan → Implement → Validate → Review → Merge

---
🤖 Generated by Ralph Wiggum autonomous loop"

                        log_success "Issue #$ISSUE completed and closed"

                        # Archive the issue directory
                        archive_issue "$ISSUE"

                        mark_issue_complete "$ISSUE"
                        increment_successful
                        add_history_entry "$ISSUE" "complete" "success" "PR merged and issue closed (attempt $ATTEMPT)"

                        ISSUE_SUCCEEDED=true
                        gh_reset_to_main
                        break  # Exit retry loop, issue complete!
                    else
                        # Merge failed - capture reason and retry
                        MERGE_ERROR=$(tail -10 "$(get_issue_log_dir $ISSUE)/merge.log" 2>/dev/null || echo "Merge failed")
                        save_attempt_feedback "$ISSUE" "$ATTEMPT" "merge" "failed" "PR merge failed: $MERGE_ERROR" ""

                        log_error "Merge failed, will retry in next attempt with fix"
                        log_info "Error: $MERGE_ERROR"

                        gh_reset_to_main
                        continue  # RETRY with fresh session to fix merge issue
                    fi
                else
                    # Auto-merge disabled - PR created, issue complete
                    log_success "PR created successfully, awaiting manual merge"
                    gh_update_label "$ISSUE" "pr-submitted" "in-progress"
                    mark_issue_complete "$ISSUE"
                    increment_successful
                    add_history_entry "$ISSUE" "complete" "success" "PR created and ready for review (attempt $ATTEMPT)"

                    ISSUE_SUCCEEDED=true
                    gh_reset_to_main
                    break  # Exit retry loop, issue complete!
                fi
            else
                log_info "[DRY RUN] Would commit changes and create PR"
                mark_issue_complete "$ISSUE"
                increment_successful
                ISSUE_SUCCEEDED=true
                break
            fi
        fi
    done  # End of retry loop for this issue

    # ========================================================================
    # Post-retry analysis
    # ========================================================================
    if [ "$ISSUE_SUCCEEDED" = false ]; then
        log_error "Issue #$ISSUE failed after $MAX_ATTEMPTS_PER_ISSUE attempts"
        log_info "Feedback summary saved in .ralph/active/${ISSUE}/feedback.json"

        increment_failed
        add_history_entry "$ISSUE" "exhausted" "failed" "Failed after $MAX_ATTEMPTS_PER_ISSUE attempts"

        # Add issue comment with failure summary
        FAILURE_SUMMARY=$(get_failure_summary "$ISSUE")
        gh_add_comment "$ISSUE" "## ⚠️ Issue Failed After $MAX_ATTEMPTS_PER_ISSUE Attempts

$FAILURE_SUMMARY

This issue has been deferred. It may be retried later or require different approach.

---
🤖 Generated by Ralph Wiggum autonomous loop"

        gh_update_label "$ISSUE" "deferred" "in-progress,planning-in-progress,research-in-progress"
    fi

    echo
    log_info "Issue iteration $ISSUE_ITERATION complete"
    echo
done  # End of outer issue loop

# Show final summary
log_success "Ralph autonomous loop complete"
show_summary "$ISSUE_ITERATION" \
             "$(json_read "$RALPH_STATE_DIR/counters.json" '.successful_issues' '0')" \
             "$(json_read "$RALPH_STATE_DIR/counters.json" '.failed_issues' '0')" \
             "$(json_read "$RALPH_STATE_DIR/counters.json" '.blocked_issues' '0')"

# Debug: Log environment check
log_info "Keep-alive check: MONITOR_MODE=$MONITOR_MODE, RALPH_MONITOR_MODE=${RALPH_MONITOR_MODE:-0}"

# Check if we're in a ralph-monitor tmux session (fallback detection)
IN_RALPH_TMUX=false
if [ -n "${TMUX:-}" ]; then
    TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "")
    if [[ "$TMUX_SESSION" == ralph-monitor-* ]]; then
        IN_RALPH_TMUX=true
        log_info "Detected ralph-monitor tmux session: $TMUX_SESSION"
    fi
fi

# Keep pane alive in monitor mode (check flag, env var, or tmux session name)
if [ "$MONITOR_MODE" = true ] || [ "${RALPH_MONITOR_MODE:-0}" = "1" ] || [ "$IN_RALPH_TMUX" = true ]; then
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph execution complete. Monitor dashboard is still running in the right pane."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Commands:"
    echo "  Ctrl+B → (arrow)  - Switch to monitor pane"
    echo "  Ctrl+C            - Exit this pane"
    echo "  Ctrl+B D          - Detach from session"
    echo
    echo "Press Ctrl+C to close this pane, or press Enter to view logs..."

    # Wait for user input or Ctrl+C
    read -r -p "" || true

    # If user pressed Enter, keep pane alive indefinitely
    echo
    echo "Keeping pane alive. Press Ctrl+C to exit."
    while true; do
        sleep 3600
    done
fi

exit 0
