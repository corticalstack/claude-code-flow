#!/bin/bash
#
# test_output_formats.sh - Test all available --output-format options
#

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Claude Code Output Format Comparison"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Available formats:"
echo "  1. text        - Human-readable (default)"
echo "  2. json        - Single JSON object (non-streaming)"
echo "  3. stream-json - NDJSON streaming (real-time)"
echo
echo "Testing with: 'Read the file scripts/ralph_utils.sh and tell me what it does'"
echo

# Test prompt that will invoke a tool (Read)
PROMPT="Read the file scripts/ralph_utils.sh and tell me the first function name"

# Test 1: Default (text format)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Default (text format)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: claude -p '...' (no --output-format flag)"
echo "Expected: Human-readable text output"
echo
START=$(date +%s)
timeout 10 claude --dangerously-skip-permissions -p "$PROMPT" 2>&1 | head -20
EXIT_CODE=${PIPESTATUS[0]}
END=$(date +%s)
DURATION=$((END - START))
echo
echo "Exit code: $EXIT_CODE"
echo "Duration: ${DURATION}s"
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG (timeout)"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS"
fi
echo

# Test 2: --output-format text (explicit)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: --output-format text"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: claude -p '...' --output-format text"
echo "Expected: Same as default"
echo
START=$(date +%s)
timeout 10 claude --dangerously-skip-permissions -p "$PROMPT" --output-format text 2>&1 | head -20
EXIT_CODE=${PIPESTATUS[0]}
END=$(date +%s)
DURATION=$((END - START))
echo
echo "Exit code: $EXIT_CODE"
echo "Duration: ${DURATION}s"
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG (timeout)"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS"
fi
echo

# Test 3: --output-format json (non-streaming)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: --output-format json (CRITICAL TEST)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: claude -p '...' --output-format json"
echo "Expected: Single JSON object (waits until complete)"
echo "Key: This is our FALLBACK if stream-json hangs"
echo
START=$(date +%s)
timeout 10 claude --dangerously-skip-permissions -p "$PROMPT" --output-format json 2>&1 | jq --unbuffered '.' 2>&1 | head -30
EXIT_CODE=${PIPESTATUS[0]}
END=$(date +%s)
DURATION=$((END - START))
echo
echo "Exit code: $EXIT_CODE"
echo "Duration: ${DURATION}s"
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG (timeout)"
    echo "⚠️  Even non-streaming JSON hangs - this is bad"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS - This is our fallback option!"
    echo "📝 Note: No real-time streaming, but doesn't hang"
fi
echo

# Test 4: --output-format stream-json (the problematic one)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: --output-format stream-json (EXPECTED TO HANG)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: claude -p '...' --output-format stream-json"
echo "Expected: May hang (GitHub issues #1920, #8126)"
echo
START=$(date +%s)
timeout 10 claude --dangerously-skip-permissions -p "$PROMPT" --output-format stream-json 2>&1 | head -10
EXIT_CODE=${PIPESTATUS[0]}
END=$(date +%s)
DURATION=$((END - START))
echo
echo "Exit code: $EXIT_CODE"
echo "Duration: ${DURATION}s"
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG (timeout) - Confirmed GitHub issue"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS - Interesting, stream-json works for you!"
    echo "May be intermittent - try running again"
fi
echo

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY & RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Format Comparison:"
echo
echo "1. text (default)"
echo "   Pros: Simple, reliable, human-readable"
echo "   Cons: Hard to parse tool calls/progress"
echo "   Use case: Basic logging, human review"
echo
echo "2. json (non-streaming)"
echo "   Pros: Parseable, structured, doesn't hang"
echo "   Cons: NO real-time streaming (waits until complete)"
echo "   Use case: Reliable automation without streaming"
echo
echo "3. stream-json (streaming)"
echo "   Pros: Real-time streaming, structured, parseable"
echo "   Cons: KNOWN BUG - hangs intermittently"
echo "   Use case: Ideal but unreliable"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RECOMMENDATION FOR RALPH:"
echo
echo "If Test 3 (json) works:"
echo "  → Use --output-format json as temporary fallback"
echo "  → No streaming but reliable and parseable"
echo "  → Can extract tool calls from final JSON"
echo "  → Simple fix: Change line 231 in ralph-autonomous.sh"
echo
echo "If Test 3 also hangs:"
echo "  → Use text format or no flag"
echo "  → OR migrate to Claude Agent SDK (proper solution)"
echo
echo "Why we wanted stream-json:"
echo "  - Real-time visibility of tool calls"
echo "  - Progress monitoring in tmux dashboard"
echo "  - Detect issues early vs waiting for completion"
echo
echo "What we lose with json format:"
echo "  - Real-time streaming (output appears only at end)"
echo "  - Live progress monitoring"
echo "  - But we GAIN: reliability (no hangs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
