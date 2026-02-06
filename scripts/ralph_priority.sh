#!/bin/bash
# scripts/ralph_priority.sh - Issue prioritization logic for Ralph autonomous loop

# Prevent multiple sourcing
[[ -n "${RALPH_PRIORITY_LOADED:-}" ]] && return 0
RALPH_PRIORITY_LOADED=1

# Source utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ralph_utils.sh"
source "$_LIB_DIR/ralph_github.sh"

# Priority levels
readonly PRIORITY_FOUNDATIONAL=1
readonly PRIORITY_FEATURE=2
readonly PRIORITY_INTEGRATION=3
readonly PRIORITY_ENHANCEMENT=4
readonly PRIORITY_TESTING=5

# Determine issue priority based on keywords
determine_priority() {
    local title=$1
    local body=$2

    local text="${title} ${body}"
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Priority 1: Foundational (creates structure)
    if echo "$text_lower" | grep -qE "structure|setup|scaffold|foundation|infrastructure|base|initial|directory|layout"; then
        echo "$PRIORITY_FOUNDATIONAL"
        return
    fi

    # Priority 5: Testing (requires everything else)
    if echo "$text_lower" | grep -qE "test|testing|e2e|qa|playwright|jest|coverage"; then
        echo "$PRIORITY_TESTING"
        return
    fi

    # Priority 3: Integration (connects components)
    if echo "$text_lower" | grep -qE "integrate|integration|connect|wire up|link|combine|streaming|real-time"; then
        echo "$PRIORITY_INTEGRATION"
        return
    fi

    # Priority 4: Enhancement (improves existing)
    if echo "$text_lower" | grep -qE "improve|enhance|optimize|refactor|update|markdown|render"; then
        echo "$PRIORITY_ENHANCEMENT"
        return
    fi

    # Priority 2: Feature (default for implementation work)
    if echo "$text_lower" | grep -qE "implement|add|create|build|feature|api|client"; then
        echo "$PRIORITY_FEATURE"
        return
    fi

    # Default to feature priority
    echo "$PRIORITY_FEATURE"
}

# Get priority name
get_priority_name() {
    local priority=$1

    case "$priority" in
        "$PRIORITY_FOUNDATIONAL")
            echo "Foundational"
            ;;
        "$PRIORITY_FEATURE")
            echo "Feature"
            ;;
        "$PRIORITY_INTEGRATION")
            echo "Integration"
            ;;
        "$PRIORITY_ENHANCEMENT")
            echo "Enhancement"
            ;;
        "$PRIORITY_TESTING")
            echo "Testing"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Annotate issues with priorities
annotate_issues_with_priority() {
    local issues_json=$1

    echo "$issues_json" | jq -c '.[] | {number, title, body, labels}' | while read -r issue; do
        local number=$(echo "$issue" | jq -r '.number')
        local title=$(echo "$issue" | jq -r '.title')
        local body=$(echo "$issue" | jq -r '.body // ""')

        local priority=$(determine_priority "$title" "$body")

        echo "$issue" | jq ". + {priority: $priority}"
    done | jq -s '.'
}

# Sort issues by priority and other criteria
sort_issues_by_priority() {
    local issues_json=$1

    # Annotate with priorities
    local annotated=$(annotate_issues_with_priority "$issues_json")

    # Sort by:
    # 1. Priority (ascending - lower number = higher priority)
    # 2. Has plan (ready-for-dev label)
    # 3. Has research (research-complete label)
    # 4. Issue number (ascending - older issues first)
    echo "$annotated" | jq 'sort_by(
        .priority,
        (.labels | map(select(.name == "ready-for-dev")) | length == 0),
        (.labels | map(select(.name == "research-complete")) | length == 0),
        .number
    )'
}

# Select next issue to work on
select_next_issue() {
    log_info "Selecting next issue to work on..."

    # Fetch open issues
    local open_issues=$(gh_fetch_open_issues 20)

    if [ -z "$open_issues" ] || [ "$open_issues" = "[]" ]; then
        log_info "No open issues found"
        return 1
    fi

    local issue_count=$(echo "$open_issues" | jq 'length')
    log_info "Found $issue_count open issues"

    # Filter out exempt issues (ralph-exempt label)
    local exempt_label="${RALPH_EXEMPT_LABEL:-ralph-exempt}"
    local non_exempt=$(echo "$open_issues" | jq --arg exempt_label "$exempt_label" '[
        .[] | select(.labels | map(.name) | contains([$exempt_label]) | not)
    ]')

    local exempt_count=$((issue_count - $(echo "$non_exempt" | jq 'length')))
    if [ "$exempt_count" -gt 0 ]; then
        log_info "Skipped $exempt_count exempt issues (labeled '$exempt_label')"
    fi

    local non_exempt_count=$(echo "$non_exempt" | jq 'length')
    if [ "$non_exempt_count" -eq 0 ]; then
        log_warning "All remaining issues are exempt"
        return 1
    fi

    # Filter out blocked issues
    local unblocked=$(gh_filter_unblocked_issues "$non_exempt")

    local unblocked_count=$(echo "$unblocked" | jq 'length')
    if [ "$unblocked_count" -eq 0 ]; then
        log_warning "All remaining issues are blocked"
        return 1
    fi

    log_info "$unblocked_count unblocked issues"

    # Sort by priority
    local sorted=$(sort_issues_by_priority "$unblocked")

    # Select top issue
    local selected=$(echo "$sorted" | jq '.[0]')

    if [ -z "$selected" ] || [ "$selected" = "null" ]; then
        log_error "Failed to select issue"
        return 1
    fi

    local number=$(echo "$selected" | jq -r '.number')
    local title=$(echo "$selected" | jq -r '.title')
    local priority=$(echo "$selected" | jq -r '.priority')
    local priority_name=$(get_priority_name "$priority")

    log_success "Selected Issue #$number: $title"
    log_info "Priority: $priority_name ($priority)"

    echo "$number"
    return 0
}

# Build task queue with priority sorting for monitoring
build_prioritized_task_queue() {
    local exempt_label="${RALPH_EXEMPT_LABEL:-ralph-exempt}"
    local issues=$(gh_fetch_open_issues 20)

    if [ $? -ne 0 ] || [ -z "$issues" ] || [ "$issues" = "[]" ]; then
        echo "[]"
        return 0
    fi

    # Filter out issues with ralph-exempt label
    local non_exempt=$(echo "$issues" | jq --arg exempt_label "$exempt_label" '[
        .[] | select(.labels | map(.name) | contains([$exempt_label]) | not)
    ]')

    # Filter out blocked issues
    local unblocked=$(gh_filter_unblocked_issues "$non_exempt")

    if [ -z "$unblocked" ] || [ "$unblocked" = "[]" ]; then
        echo "[]"
        return 0
    fi

    # Sort by priority
    local sorted=$(sort_issues_by_priority "$unblocked")

    # Build task queue structure with phase tracking
    local queue=$(echo "$sorted" | jq '[
        .[] |
        {
            issue: ("#" + (.number | tostring)),
            title: .title,
            status: "pending",
            is_current: false,
            phases: {
                research: { status: "pending", attempts: 0 },
                planning: { status: "pending", attempts: 0 },
                implementation: { status: "pending", attempts: 0 },
                validation: { status: "pending", attempts: 0 }
            }
        }
    ]')

    echo "$queue"
}

# Display prioritized issue list
display_issue_priorities() {
    log_info "Analyzing issue priorities..."

    # Fetch open issues
    local open_issues=$(gh_fetch_open_issues 20)

    if [ -z "$open_issues" ] || [ "$open_issues" = "[]" ]; then
        log_info "No open issues found"
        return
    fi

    # Filter out blocked issues
    local unblocked=$(gh_filter_unblocked_issues "$open_issues")

    # Sort by priority
    local sorted=$(sort_issues_by_priority "$unblocked")

    echo
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Prioritized Issue List                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo

    local count=1
    echo "$sorted" | jq -c '.[]' | while read -r issue; do
        local number=$(echo "$issue" | jq -r '.number')
        local title=$(echo "$issue" | jq -r '.title' | cut -c1-45)
        local priority=$(echo "$issue" | jq -r '.priority')
        local priority_name=$(get_priority_name "$priority")

        local has_research=""
        if gh_check_research_exists "$number" >/dev/null 2>&1; then
            has_research="📄"
        fi

        local has_plan=""
        if gh_check_plan_exists "$number" >/dev/null 2>&1; then
            has_plan="📋"
        fi

        printf "%2d. #%-3d %-15s %s %s %s\n" "$count" "$number" "[$priority_name]" "$has_research" "$has_plan" "$title"
        count=$((count + 1))
    done

    echo
    echo "Legend: 📄 = Research exists, 📋 = Plan exists"
    echo
}
