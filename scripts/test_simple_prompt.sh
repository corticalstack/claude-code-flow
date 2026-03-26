#!/bin/bash
#
# test_simple_prompt.sh - Test with simple prompt (no tool use)
#

set -euo pipefail

echo "Testing if the PROMPT is causing the hang..."
echo "Using simple prompt without tool calls"
echo

# Simple prompt that doesn't require tool use
SIMPLE_PROMPT="Say hello in 3 words"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST: Simple prompt (no tools)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Prompt: '$SIMPLE_PROMPT'"
echo "Flags: --dangerously-skip-permissions -p"
echo "Format: default (text)"
echo "Timeout: 10 seconds"
echo

START=$(date +%s)
timeout 10 claude --dangerously-skip-permissions -p "$SIMPLE_PROMPT" 2>&1
EXIT_CODE=$?
END=$(date +%s)
DURATION=$((END - START))

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Result:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Exit code: $EXIT_CODE"
echo "Duration: ${DURATION}s"
echo

if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG - Even simple prompts hang!"
    echo
    echo "This means:"
    echo "  - Problem is NOT the output format"
    echo "  - Problem is NOT the tool calls"
    echo "  - Problem is with --print mode or --dangerously-skip-permissions"
    echo
    echo "Next test: Try WITHOUT --dangerously-skip-permissions"
    echo
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS - Simple prompts work fine"
    echo
    echo "This means:"
    echo "  - Basic --print mode works"
    echo "  - Problem is likely with TOOL CALLS"
    echo "  - When Claude tries to use tools (Read, etc), it may hang"
    echo "  - Possibly waiting for permission or hook execution"
    echo
    echo "Theory: --dangerously-skip-permissions may not be working"
    echo "Claude might be waiting for permission approval we can't see"
    echo
else
    echo "⚠️  ERROR - Exit code: $EXIT_CODE"
    echo "Check output above for error messages"
fi
echo

# Test without --dangerously-skip-permissions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST: Without --dangerously-skip-permissions flag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This will likely ask for permission..."
echo

timeout 5 claude -p "$SIMPLE_PROMPT" 2>&1 || echo "(Timed out or exited - expected)"
echo
echo "If you saw a permission prompt, --dangerously-skip-permissions IS needed"
echo
