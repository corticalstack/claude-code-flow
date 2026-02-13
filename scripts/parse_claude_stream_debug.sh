#!/bin/bash
#
# parse_claude_stream_debug.sh - Debug version with extensive logging
#
# This version logs every step to help identify where streaming breaks
#

set -euo pipefail

# Debug log file
DEBUG_LOG="/tmp/claude_parse_debug_$(date +%s).log"
exec 3>&2  # Save original stderr to fd 3

# Start debug logging
{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Parser Debug Log Started: $(date '+%Y-%m-%d %H:%M:%S.%3N')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PID: $$"
    echo "Debug log: $DEBUG_LOG"
    echo
} > "$DEBUG_LOG" 2>&1

# Function to log with timestamp
log_debug() {
    echo "[$(date '+%H:%M:%S.%3N')] $*" >> "$DEBUG_LOG" 2>&1
}

log_debug "Parser script started"
log_debug "Checking for jq..."
if command -v jq &> /dev/null; then
    log_debug "jq found: $(which jq)"
    log_debug "jq version: $(jq --version 2>&1)"
else
    log_debug "ERROR: jq not found!"
fi

# Disable buffering
export PYTHONUNBUFFERED=1
log_debug "PYTHONUNBUFFERED set to 1"

# ANSI color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Configuration
SHOW_SESSION_INFO=true
SHOW_TOOL_DETAILS=true
SHOW_THINKING=true

log_debug "Configuration: SESSION_INFO=$SHOW_SESSION_INFO, TOOLS=$SHOW_TOOL_DETAILS, THINKING=$SHOW_THINKING"
log_debug "Entering read loop..."

# Track statistics
line_count=0
json_valid=0
json_invalid=0
bytes_received=0

# Process each JSON line from stdin
while IFS= read -r line; do
    line_count=$((line_count + 1))
    bytes_received=$((bytes_received + ${#line}))

    log_debug "────────────────────────────────────────────────────────────────"
    log_debug "Line $line_count received (${#line} bytes, total: $bytes_received)"
    log_debug "First 100 chars: ${line:0:100}"

    # Skip empty lines
    if [ -z "$line" ]; then
        log_debug "Line $line_count: EMPTY (skipping)"
        continue
    fi

    # Validate JSON
    if echo "$line" | jq -u . > /dev/null 2>&1; then
        json_valid=$((json_valid + 1))
        log_debug "Line $line_count: Valid JSON ✓"
    else
        json_invalid=$((json_invalid + 1))
        log_debug "Line $line_count: INVALID JSON ✗"
        log_debug "Raw line: $line"
        echo "⚠️  Invalid JSON on line $line_count" >&3
        continue
    fi

    # Parse JSON type
    event_type=$(echo "$line" | jq -u -r '.type // empty' 2>/dev/null)
    log_debug "Event type: '$event_type'"

    case "$event_type" in
        "system")
            log_debug "Processing SYSTEM event"
            if [ "$SHOW_SESSION_INFO" = true ]; then
                model=$(echo "$line" | jq -u -r '.model // empty' 2>/dev/null)
                session=$(echo "$line" | jq -u -r '.session_id // empty' 2>/dev/null)
                log_debug "Model: $model, Session: $session"
                if [ -n "$model" ]; then
                    echo -e "${CYAN}[ℹ️  SESSION]${RESET} Model: $model | Session: ${session:0:8}..." >&3
                    log_debug "Printed session info to stderr"
                fi
            fi
            ;;

        "thinking")
            log_debug "Processing THINKING event"
            if [ "$SHOW_THINKING" = true ]; then
                thinking=$(echo "$line" | jq -u -r '.content // empty' 2>/dev/null)
                thinking_length=${#thinking}
                log_debug "Thinking content length: $thinking_length"
                if [ -n "$thinking" ]; then
                    echo -e "\n${GRAY}[💭 THINKING]${RESET} ${thinking:0:80}..." >&3
                    log_debug "Printed thinking block to stderr"
                fi
            fi
            ;;

        "assistant")
            log_debug "Processing ASSISTANT event"
            message_content=$(echo "$line" | jq -u -c '.message.content[]?' 2>/dev/null)
            content_count=$(echo "$message_content" | wc -l)
            log_debug "Assistant message has $content_count content items"

            item_num=0
            while IFS= read -r content_item; do
                [ -z "$content_item" ] && continue
                item_num=$((item_num + 1))
                log_debug "  Content item $item_num: ${content_item:0:80}"

                content_type=$(echo "$content_item" | jq -u -r '.type // empty' 2>/dev/null)
                log_debug "  Content type: '$content_type'"

                case "$content_type" in
                    "tool_use")
                        log_debug "  Processing TOOL_USE"
                        if [ "$SHOW_TOOL_DETAILS" = true ]; then
                            tool_name=$(echo "$content_item" | jq -u -r '.name // empty' 2>/dev/null)
                            tool_id=$(echo "$content_item" | jq -u -r '.id // empty' 2>/dev/null)
                            tool_input=$(echo "$content_item" | jq -u -c '.input // {}' 2>/dev/null)

                            log_debug "  Tool: $tool_name (ID: $tool_id)"
                            if [ -n "$tool_name" ]; then
                                echo -e "\n${YELLOW}[🔧 TOOL]${RESET} $tool_name ${GRAY}(${tool_id:0:12}...)${RESET}" >&3
                                echo -e "${GREEN}[📋 INPUT]${RESET} $tool_input" >&3
                                log_debug "  Printed tool info to stderr"
                            fi
                        fi
                        ;;

                    "text")
                        log_debug "  Processing TEXT"
                        text=$(echo "$content_item" | jq -u -r '.text // empty' 2>/dev/null)
                        text_length=${#text}
                        log_debug "  Text length: $text_length chars"
                        if [ -n "$text" ]; then
                            echo "$text"
                            log_debug "  Printed text to stdout"
                        fi
                        ;;

                    *)
                        log_debug "  Unknown content type: '$content_type'"
                        ;;
                esac
            done <<< "$message_content"
            ;;

        "result")
            log_debug "Processing RESULT event"
            result_text=$(echo "$line" | jq -u -r '.result // empty' 2>/dev/null)
            if [ -n "$result_text" ] && [ "$result_text" != "null" ]; then
                log_debug "Result: $result_text"
            fi
            ;;

        "")
            log_debug "Empty event type (possibly not JSON stream-json format)"
            ;;

        *)
            log_debug "Unknown event type: '$event_type'"
            log_debug "Full JSON: $line"
            ;;
    esac

    # Flush output
    log_debug "Flushing output buffers"
done

log_debug "────────────────────────────────────────────────────────────────"
log_debug "Read loop exited"
log_debug "Statistics:"
log_debug "  Total lines: $line_count"
log_debug "  Valid JSON: $json_valid"
log_debug "  Invalid JSON: $json_invalid"
log_debug "  Total bytes: $bytes_received"
log_debug "Parser script ending"

# Ensure final newline
echo ""

# Print debug summary
{
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Parser Debug Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Lines processed: $line_count"
    echo "Valid JSON: $json_valid"
    echo "Invalid JSON: $json_invalid"
    echo "Total bytes: $bytes_received"
    echo "End time: $(date '+%Y-%m-%d %H:%M:%S.%3N')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >> "$DEBUG_LOG" 2>&1

echo "🔍 Parser debug log: $DEBUG_LOG" >&3
