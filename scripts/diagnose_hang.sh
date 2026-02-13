#!/bin/bash
#
# diagnose_hang.sh - Diagnose why Claude CLI is hanging
#

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Claude CLI Hang Diagnosis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Test 1: Basic --print without stream-json
echo "TEST 1: Basic --print (text format) - 5 second timeout"
echo "Command: timeout 5 claude -p 'Say hello'"
echo "Expected: Should work and return text quickly"
echo
timeout 5 claude -p "Say hello in 2 words" 2>&1
EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE (0=success, 124=timeout)"
echo
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG: Basic --print is hanging!"
    echo "This suggests a fundamental Claude CLI issue, not streaming-specific"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS: Basic --print works fine"
    echo "Issue is specific to stream-json or verbose mode"
else
    echo "⚠️  ERROR: Unexpected exit code $EXIT_CODE"
fi
echo

# Test 2: --output-format json (not stream-json)
echo "TEST 2: --output-format json (non-streaming) - 5 second timeout"
echo "Command: timeout 5 claude -p 'Say hello' --output-format json"
echo "Expected: Should work and return JSON quickly"
echo
timeout 5 claude -p "Say hello in 2 words" --output-format json 2>&1
EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE"
echo
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG: JSON format is hanging!"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS: JSON format works"
fi
echo

# Test 3: --output-format stream-json (the problematic one)
echo "TEST 3: --output-format stream-json - 5 second timeout"
echo "Command: timeout 5 claude -p 'Say hello' --output-format stream-json | head -3"
echo "Expected: May hang (this is the issue we're debugging)"
echo
timeout 5 claude -p "Say hello in 2 words" --output-format stream-json 2>&1 | head -3
EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE"
echo
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG: stream-json is hanging!"
    echo "This matches GitHub issue #3187"
    echo "Possible causes:"
    echo "  - Claude CLI bug with stream-json"
    echo "  - Waiting for more input/interaction"
    echo "  - Missing final event (issue #1920)"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS: stream-json produced output!"
    echo "The hang may be in the pipeline, not Claude CLI"
fi
echo

# Test 4: With --verbose flag
echo "TEST 4: --verbose flag - 5 second timeout"
echo "Command: timeout 5 claude --verbose -p 'Say hello'"
echo
timeout 5 claude --verbose -p "Say hello in 2 words" 2>&1
EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE"
echo
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG: --verbose is hanging!"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS: --verbose works"
fi
echo

# Test 5: Combined --verbose --output-format stream-json
echo "TEST 5: --verbose --output-format stream-json - 5 second timeout"
echo "Command: timeout 5 claude --verbose -p 'Say hello' --output-format stream-json | head -3"
echo
timeout 5 claude --verbose -p "Say hello in 2 words" --output-format stream-json 2>&1 | head -3
EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE"
echo
if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ HUNG: Combined flags hanging!"
    echo "This is the exact configuration ralph-autonomous uses"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ WORKS: Combined flags work!"
fi
echo

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnosis Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Which tests succeeded?"
echo "  - If only Test 1 works: Issue with output formats"
echo "  - If Tests 1-2 work: Issue specific to stream-json"
echo "  - If all hang: Fundamental Claude CLI issue (permissions?)"
echo "  - If none work: Check Claude CLI installation/configuration"
echo
echo "Known issues from GitHub:"
echo "  - Issue #3187: stream-json hangs with certain configurations"
echo "  - Issue #1920: Missing final result events cause indefinite hangs"
echo "  - May need --dangerously-skip-permissions flag"
echo
echo "Next steps if stream-json hangs:"
echo "  1. This is a known Claude CLI bug"
echo "  2. Consider using --output-format json (non-streaming)"
echo "  3. Consider migrating to Claude Agent SDK for reliable streaming"
echo "  4. Report to GitHub if not already documented"
