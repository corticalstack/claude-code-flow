#!/bin/bash
# scripts/ralph_utils.sh - Utility functions for Ralph autonomous loop

# Prevent multiple sourcing
[[ -n "${RALPH_UTILS_LOADED:-}" ]] && return 0
RALPH_UTILS_LOADED=1

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions (output to stderr to not interfere with command substitution)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_phase() {
    echo -e "${CYAN}[PHASE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Check if required commands exist
check_dependencies() {
    local missing_deps=()

    for cmd in gh jq git claude; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Create timestamp in ISO format
timestamp_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Calculate hours since a timestamp
hours_since() {
    local timestamp=$1
    local now=$(date -u +%s)
    local then=$(date -u -d "$timestamp" +%s 2>/dev/null || echo 0)

    if [ "$then" -eq 0 ]; then
        echo "999"  # Invalid timestamp = very old
        return
    fi

    local diff_seconds=$((now - then))
    local hours=$((diff_seconds / 3600))
    echo "$hours"
}

# Safe JSON read with default value
json_read() {
    local file=$1
    local path=$2
    local default=${3:-null}

    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi

    jq -r "$path // \"$default\"" "$file" 2>/dev/null || echo "$default"
}

# Safe JSON write
json_write() {
    local file=$1
    local content=$2

    # Ensure directory exists
    local dir=$(dirname "$file")
    mkdir -p "$dir" 2>/dev/null

    echo "$content" | jq '.' > "${file}.tmp" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "${file}.tmp" "$file"
        return 0
    else
        rm -f "${file}.tmp"
        log_error "Failed to write JSON to $file"
        return 1
    fi
}

# Count files changed in git working directory
count_changed_files() {
    # Staged + unstaged changes
    local staged=$(git diff --cached --name-only | wc -l)
    local unstaged=$(git diff --name-only | wc -l)
    local untracked=$(git ls-files --others --exclude-standard | wc -l)

    echo $((staged + unstaged + untracked))
}

# Extract git changes summary
git_changes_summary() {
    local changes=$(count_changed_files)

    if [ "$changes" -eq 0 ]; then
        echo "no changes"
        return
    fi

    local summary=""

    # Get modified files
    local modified=$(git diff --name-only | head -3)
    if [ -n "$modified" ]; then
        summary="${summary}Modified: $(echo "$modified" | tr '\n' ',' | sed 's/,$//')"
    fi

    # Get staged files
    local staged=$(git diff --cached --name-only | head -3)
    if [ -n "$staged" ]; then
        [ -n "$summary" ] && summary="${summary}; "
        summary="${summary}Staged: $(echo "$staged" | tr '\n' ',' | sed 's/,$//')"
    fi

    # Get untracked files
    local untracked=$(git ls-files --others --exclude-standard | head -3)
    if [ -n "$untracked" ]; then
        [ -n "$summary" ] && summary="${summary}; "
        summary="${summary}New: $(echo "$untracked" | tr '\n' ',' | sed 's/,$//')"
    fi

    echo "$summary ($changes files)"
}

# Prompt for user confirmation
confirm() {
    local prompt=$1
    local default=${2:-n}

    local options
    if [ "$default" = "y" ]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi

    read -p "$prompt $options " -n 1 -r
    echo

    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Wait with countdown timer
wait_with_countdown() {
    local seconds=$1
    local message=${2:-"Waiting"}

    for ((i=seconds; i>0; i--)); do
        printf "\r${message}... %02d:%02d remaining" $((i/60)) $((i%60))
        sleep 1
    done
    printf "\r${message}... done                    \n"
}

# Display header
show_header() {
    echo "╔════════════════════════════════════════════════════════════════╗" >&2
    echo "║                 Ralph Wiggum Autonomous Loop                   ║" >&2
    echo "║                   External Orchestrator v1.0                   ║" >&2
    echo "╚════════════════════════════════════════════════════════════════╝" >&2
    echo >&2
}

# Display iteration header
show_iteration() {
    local iteration=$1
    local max=$2
    local issue=$3

    echo >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  ITERATION $iteration/$max - Processing Issue #$issue" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo >&2
}

# Display completion summary
show_summary() {
    local iterations=$1
    local successful=$2
    local failed=$3
    local blocked=$4

    echo >&2
    echo "╔════════════════════════════════════════════════════════════════╗" >&2
    echo "║                    Ralph Completion Summary                    ║" >&2
    echo "╠════════════════════════════════════════════════════════════════╣" >&2
    echo "║ Total Iterations:     $(printf '%3d' $iterations)                                        ║" >&2
    echo "║ Successful:           $(printf '%3d' $successful)                                        ║" >&2
    echo "║ Failed:               $(printf '%3d' $failed)                                        ║" >&2
    echo "║ Blocked:              $(printf '%3d' $blocked)                                        ║" >&2
    echo "╚════════════════════════════════════════════════════════════════╝" >&2
    echo >&2
}
# Check if tmux is available
check_tmux_available() {
    command -v tmux &> /dev/null
}

# Show tmux installation instructions
show_tmux_install_instructions() {
    echo "Error: tmux is required for monitoring mode but is not installed" >&2
    echo >&2
    echo "Install tmux:" >&2
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/debian_version ]; then
                echo "  sudo apt-get install tmux" >&2
            elif [ -f /etc/redhat-release ]; then
                echo "  sudo yum install tmux" >&2
            else
                echo "  Use your package manager to install tmux" >&2
            fi
            ;;
        Darwin*)
            echo "  brew install tmux" >&2
            ;;
        *)
            echo "  Please install tmux using your system's package manager" >&2
            ;;
    esac
    echo >&2
}
