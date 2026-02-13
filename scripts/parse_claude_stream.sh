#!/bin/bash
#
# parse_claude_stream.sh
#
# Parses Claude Code --verbose --output-format stream-json output to show tool calls
# This enables verbose visibility into Claude's operations during Ralph autonomous mode
#
# Usage: claude --verbose --output-format stream-json --print "prompt" | ./parse_claude_stream.sh
#

set -euo pipefail

# Disable buffering for immediate output
export PYTHONUNBUFFERED=1

# Configuration
SHOW_SESSION_INFO=true
SHOW_TOOL_DETAILS=true
SHOW_THINKING=true

# ANSI color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Process each JSON line from stdin
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Parse JSON type (use unbuffered jq)
    event_type=$(echo "$line" | jq -u -r '.type // empty' 2>/dev/null)

    case "$event_type" in
        "system")
            # Show session initialization info
            if [ "$SHOW_SESSION_INFO" = true ]; then
                model=$(echo "$line" | jq -u -r '.model // empty' 2>/dev/null)
                session=$(echo "$line" | jq -u -r '.session_id // empty' 2>/dev/null)
                if [ -n "$model" ]; then
                    echo -e "${CYAN}[ℹ️  SESSION]${RESET} Model: $model | Session: ${session:0:8}..." >&2
                fi
            fi
            ;;

        "thinking")
            # Show thinking blocks (extended thinking mode)
            if [ "$SHOW_THINKING" = true ]; then
                thinking=$(echo "$line" | jq -u -r '.content // empty' 2>/dev/null)
                if [ -n "$thinking" ]; then
                    echo -e "\n${GRAY}[💭 THINKING]${RESET} $thinking" >&2
                fi
            fi
            ;;

        "assistant")
            # Parse assistant messages for tool uses and text
            message_content=$(echo "$line" | jq -u -c '.message.content[]?' 2>/dev/null)

            while IFS= read -r content_item; do
                [ -z "$content_item" ] && continue

                content_type=$(echo "$content_item" | jq -u -r '.type // empty' 2>/dev/null)

                case "$content_type" in
                    "tool_use")
                        if [ "$SHOW_TOOL_DETAILS" = true ]; then
                            tool_name=$(echo "$content_item" | jq -u -r '.name // empty' 2>/dev/null)
                            tool_id=$(echo "$content_item" | jq -u -r '.id // empty' 2>/dev/null)
                            tool_input=$(echo "$content_item" | jq -u -c '.input // {}' 2>/dev/null)

                            if [ -n "$tool_name" ]; then
                                echo -e "\n${YELLOW}[🔧 TOOL]${RESET} $tool_name ${GRAY}(${tool_id:0:12}...)${RESET}" >&2
                                echo -e "${GREEN}[📋 INPUT]${RESET} $tool_input" >&2
                            fi
                        fi
                        ;;

                    "text")
                        text=$(echo "$content_item" | jq -u -r '.text // empty' 2>/dev/null)
                        if [ -n "$text" ]; then
                            echo "$text"
                        fi
                        ;;
                esac
            done <<< "$message_content"
            ;;

        "result")
            # Final result - extract the result text
            result_text=$(echo "$line" | jq -u -r '.result // empty' 2>/dev/null)
            if [ -n "$result_text" ] && [ "$result_text" != "null" ]; then
                # Result was already printed, just ensure newline
                :
            fi
            ;;
    esac
done

# Ensure final newline
echo ""
