#!/bin/bash
# ralph_monitor.sh - Real-time monitoring dashboard for Ralph autonomous loop
# Simplified design matching reference implementation: left-border-only, no alignment issues

set -euo pipefail

# Configuration
readonly REFRESH_INTERVAL=2
readonly LOG_LINES=8
readonly STATUS_FILE=".ralph/status.json"
readonly PROGRESS_FILE=".ralph/progress.json"
readonly LOG_FILE="logs/ralph-tmux.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Terminal control
clear_screen() {
    clear
    printf '\033[?25l'  # Hide cursor
}

show_cursor() {
    printf '\033[?25h'  # Show cursor
}

# Cleanup on exit
cleanup() {
    show_cursor
    echo
    echo "Monitor stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Set pane title if running in tmux
if [ -n "${TMUX:-}" ]; then
    printf '\033]2;%s\033\\' "Ralph Task Monitoring Dashboard"
fi

# Main display function
display_dashboard() {
    # Build entire screen in one command substitution - key to no flicker!
    BUFFER=$(
        # Clear screen inside the buffer
        clear

        # Define queue file path (used in multiple sections)
        local queue_file=".ralph/task_queue.json"

        # CURRENT STATUS
        if [ -f "$STATUS_FILE" ]; then
        # Parse status data
        local loop_count=$(jq -r '.loop_count // "0"' "$STATUS_FILE" 2>/dev/null || echo "0")
        local current_task=$(jq -r '.current_task // null' "$STATUS_FILE" 2>/dev/null || echo "null")
        local status=$(jq -r '.status // "unknown"' "$STATUS_FILE" 2>/dev/null || echo "unknown")
        local phase=$(jq -r '.phase // "none"' "$STATUS_FILE" 2>/dev/null || echo "none")
        local calls_made=$(jq -r '.calls_made_this_hour // "0"' "$STATUS_FILE" 2>/dev/null || echo "0")
        local max_calls=$(jq -r '.max_calls_per_hour // "100"' "$STATUS_FILE" 2>/dev/null || echo "100")
        local cb_open=$(jq -r '.circuit_breaker_open // false' "$STATUS_FILE" 2>/dev/null || echo "false")

        # Check if task queue is empty to provide better context
        local has_issues=true
        if [ -f "$queue_file" ]; then
            local queue=$(jq -r '.queue // []' "$queue_file" 2>/dev/null || echo "[]")
            local queue_count=$(echo "$queue" | jq 'length' 2>/dev/null || echo "0")
            [ "$queue_count" -eq 0 ] && has_issues=false
        fi

        echo -e "${CYAN}┌─ Current Status ────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} Loop Count: ${WHITE}#$loop_count${NC}"

        # Show current issue if active
        if [ "$current_task" != "null" ] && [ -n "$current_task" ]; then
            echo -e "${CYAN}│${NC} Current GitHub Issue: ${WHITE}$current_task${NC}"
        fi

        # Show phase if not none and there are issues
        if [ "$phase" != "none" ] && [ "$has_issues" = true ]; then
            echo -e "${CYAN}│${NC} Phase: ${WHITE}${phase^}${NC}"
        fi

        # Status with color coding - show contextual message when no issues
        if [ "$has_issues" = false ] && [ "$status" = "running" ]; then
            echo -e "${CYAN}│${NC} Status: ${YELLOW}Waiting - No eligible issues${NC}"
        elif [ "$status" = "running" ]; then
            echo -e "${CYAN}│${NC} Status: ${GREEN}In Progress${NC}"
        elif [ "$status" = "idle" ]; then
            echo -e "${CYAN}│${NC} Status: ${YELLOW}Idle${NC}"
        elif [ "$status" = "interrupted" ] || [ "$status" = "error" ]; then
            echo -e "${CYAN}│${NC} Status: ${RED}${status^}${NC}"
        else
            echo -e "${CYAN}│${NC} Status: $status"
        fi

        echo -e "${CYAN}│${NC} API Calls: $calls_made/$max_calls"

        # Circuit breaker warning
        if [ "$cb_open" = "true" ]; then
            echo -e "${CYAN}│${NC} ${RED}⚠ Circuit Breaker: OPEN${NC}"
        fi

        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    else
        echo -e "${RED}┌─ Current Status ────────────────────────────────────────────────────────┐${NC}"
        echo -e "${RED}│${NC} Status file not found. Ralph may not be running."
        echo -e "${RED}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    fi
    echo

    # ========================================================================
    # TASK QUEUE (GitHub issues with phase tracking)
    # ========================================================================
    if [ -f "$queue_file" ]; then
        local queue=$(jq -r '.queue // []' "$queue_file" 2>/dev/null || echo "[]")
        local queue_count=$(echo "$queue" | jq 'length' 2>/dev/null || echo "0")

        if [ "$queue_count" -gt 0 ]; then
            echo -e "${GREEN}┌─ Task Queue (GitHub Issues) ───────────────────────────────────────────┐${NC}"

            # Table header (use fixed spacing for phase columns)
            printf "${GREEN}│${NC} %-6s %-35s %s %s %s %s  %-15s\n" "Issue" "Title" "R" "P" "I" "V" "Status"
            echo -e "${GREEN}│${NC} $(printf '─%.0s' {1..72})"

            # Display up to 10 issues
            local display_count=$((queue_count < 10 ? queue_count : 10))
            for i in $(seq 0 $((display_count - 1))); do
                local item=$(echo "$queue" | jq ".[$i]")
                local issue_num=$(echo "$item" | jq -r '.issue // ""')
                local title=$(echo "$item" | jq -r '.title // ""')
                local is_current=$(echo "$item" | jq -r '.is_current // false')
                local item_status=$(echo "$item" | jq -r '.status // "pending"')

                # Truncate title to fit in 35 chars
                if [ ${#title} -gt 35 ]; then
                    title="${title:0:32}..."
                fi

                # Get phase status
                local r_status=$(echo "$item" | jq -r '.phases.research.status // "pending"' 2>/dev/null || echo "pending")
                local r_attempts=$(echo "$item" | jq -r '.phases.research.attempts // 0' 2>/dev/null || echo "0")
                local p_status=$(echo "$item" | jq -r '.phases.planning.status // "pending"' 2>/dev/null || echo "pending")
                local p_attempts=$(echo "$item" | jq -r '.phases.planning.attempts // 0' 2>/dev/null || echo "0")
                local i_status=$(echo "$item" | jq -r '.phases.implementation.status // "pending"' 2>/dev/null || echo "pending")
                local i_attempts=$(echo "$item" | jq -r '.phases.implementation.attempts // 0' 2>/dev/null || echo "0")
                local v_status=$(echo "$item" | jq -r '.phases.validation.status // "pending"' 2>/dev/null || echo "pending")
                local v_attempts=$(echo "$item" | jq -r '.phases.validation.attempts // 0' 2>/dev/null || echo "0")

                # Convert to display chars
                local r_char="-"
                [ "$r_status" = "complete" ] && r_char="✓"
                [ "$r_status" = "in_progress" ] && r_char="$r_attempts"

                local p_char="-"
                [ "$p_status" = "complete" ] && p_char="✓"
                [ "$p_status" = "in_progress" ] && p_char="$p_attempts"

                local i_char="-"
                [ "$i_status" = "complete" ] && i_char="✓"
                [ "$i_status" = "in_progress" ] && i_char="$i_attempts"

                local v_char="-"
                [ "$v_status" = "complete" ] && v_char="✓"
                [ "$v_status" = "in_progress" ] && v_char="$v_attempts"

                # Status icon (short version)
                local status_short="Pending"
                [ "$item_status" = "in_progress" ] && status_short="In Progress"
                [ "$item_status" = "complete" ] && status_short="Complete"
                [ "$item_status" = "failed" ] && status_short="Failed"
                [ "$item_status" = "blocked" ] && status_short="Blocked"

                # Current indicator
                local indicator=" "
                [ "$is_current" = "true" ] && indicator="►"

                # Print row with proper formatting (use same spacing as header)
                printf "${GREEN}│${NC}${indicator}%-6s %-35s %s %s %s %s  %-15s\n" \
                    "$issue_num" "$title" "$r_char" "$p_char" "$i_char" "$v_char" "$status_short"
            done

            echo -e "${GREEN}│${NC}"
            echo -e "${GREEN}│${NC} Legend: R=Research P=Planning I=Implementation V=Validation"
            echo -e "${GREEN}│${NC}         ✓=Complete  #=Attempts  -=Pending  ►=Current"
            echo -e "${GREEN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            echo
        else
            # Empty queue - show helpful message
            echo -e "${YELLOW}┌─ Task Queue (GitHub Issues) ───────────────────────────────────────────┐${NC}"
            echo -e "${YELLOW}│${NC}"
            echo -e "${YELLOW}│${NC} ${WHITE}No eligible issues available${NC}"
            echo -e "${YELLOW}│${NC}"
            echo -e "${YELLOW}│${NC} Possible reasons:"
            echo -e "${YELLOW}│${NC}   • All open issues are labeled 'ralph-exempt'"
            echo -e "${YELLOW}│${NC}   • All open issues are blocked by dependencies"
            echo -e "${YELLOW}│${NC}   • No open issues in the repository"
            echo -e "${YELLOW}│${NC}   • Circuit breaker is open (check status above)"
            echo -e "${YELLOW}│${NC}"
            echo -e "${YELLOW}│${NC} ${CYAN}Next steps:${NC}"
            echo -e "${YELLOW}│${NC}   • Remove 'ralph-exempt' label from issues you want Ralph to process"
            echo -e "${YELLOW}│${NC}   • Create new issues for Ralph to work on"
            echo -e "${YELLOW}│${NC}   • If circuit breaker is open: ./ralph-autonomous.sh --reset-circuit"
            echo -e "${YELLOW}│${NC}"
            echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            echo
        fi
    else
        # Queue file doesn't exist
        echo -e "${YELLOW}┌─ Task Queue (GitHub Issues) ───────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC} ${WHITE}Task queue not initialized${NC}"
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC} Ralph may still be starting up or queue file is missing."
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────────────┘${NC}"
        echo
    fi

    # ========================================================================
    # LIVE PROGRESS (only shown when actively working)
    # ========================================================================
    if [ -f "$PROGRESS_FILE" ]; then
        local prog_status=$(jq -r '.status // "idle"' "$PROGRESS_FILE" 2>/dev/null || echo "idle")

        # Only show this section if actively working
        if [ "$prog_status" != "idle" ] && [ "$prog_status" != "stopped" ]; then
            local indicator=$(jq -r '.indicator // "⠋"' "$PROGRESS_FILE" 2>/dev/null || echo "⠋")
            local elapsed=$(jq -r '.elapsed_seconds // "0"' "$PROGRESS_FILE" 2>/dev/null || echo "0")
            local last_output=$(jq -r '.last_output // ""' "$PROGRESS_FILE" 2>/dev/null || echo "")

            echo -e "${YELLOW}┌─ Live Progress ─────────────────────────────────────────────────────────┐${NC}"
            echo -e "${YELLOW}│${NC} Status: $indicator ${GREEN}Working${NC} (${elapsed}s elapsed)"

            # Show last output if available
            if [ -n "$last_output" ]; then
                # Truncate long output
                if [ ${#last_output} -gt 60 ]; then
                    last_output="${last_output:0:60}..."
                fi
                echo -e "${YELLOW}│${NC} Output: $last_output"
            fi

            echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            echo
        fi
    fi

        # FOOTER (removed Recent Activity - it duplicates left pane)
        local timestamp=$(date '+%H:%M:%S')
        echo -e "${YELLOW}Controls: Ctrl+C to exit | Refreshes every ${REFRESH_INTERVAL}s | $timestamp${NC}"
    )

    # Output entire buffer at once - this is the key to no flicker!
    echo -ne "$BUFFER"
}

# Main loop
main() {
    # Check for jq dependency
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed"
        echo "Please install jq: sudo apt-get install jq (Debian/Ubuntu) or brew install jq (macOS)"
        exit 1
    fi

    # Set tmux pane title if in tmux
    if [ -n "${TMUX:-}" ]; then
        printf '\033]2;%s\033\\' 'Ralph Monitor'
    fi

    echo "Starting Ralph Monitor..."
    sleep 1

    # Main refresh loop
    while true; do
        display_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# Run
main
