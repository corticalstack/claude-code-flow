#!/bin/bash
#
# test_basic_streaming.sh - Test if basic Claude streaming works
#
# Based on GitHub issue #733 and #4346 solutions
#

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing Claude Code Streaming (GitHub Issue #733 Solution)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Test 1: Exact command from GitHub issue
echo "TEST 1: Using exact command from GitHub issue #4346"
echo "Command: claude --verbose -p '...' --output-format stream-json | jq -r ..."
echo "Expecting: Real-time streaming text output"
echo

echo "Running (10 second timeout):"
timeout 10 claude --verbose -p "Count from 1 to 5, with a brief comment after each number" --output-format stream-json 2>&1 | \
jq --unbuffered -r 'select(.type == "assistant") | .message.content[]? | select(.type? == "text") | .text' || true

echo
echo "✅ Test 1 complete"
echo

# Test 2: Raw stream-json to see actual structure
echo "TEST 2: Raw stream-json output (first 10 lines)"
echo "This shows what Claude CLI actually outputs"
echo

timeout 5 claude -p "Say hello" --output-format stream-json 2>&1 | head -10 || true

echo
echo "✅ Test 2 complete"
echo

# Test 3: With stdbuf like ralph-autonomous uses
echo "TEST 3: With stdbuf -oL (like ralph-autonomous.sh)"
echo

timeout 5 stdbuf -oL claude -p "Say hello" --output-format stream-json 2>&1 | head -5 || true

echo
echo "✅ Test 3 complete"
echo

# Test 4: Full pipeline like ralph uses (simplified)
echo "TEST 4: Simulating ralph-autonomous pipeline"
echo "Pipeline: claude --dangerously-skip-permissions --verbose --output-format stream-json --print"
echo

timeout 5 claude --dangerously-skip-permissions --verbose --output-format stream-json -p "Say hello" 2>&1 | head -10 || true

echo
echo "✅ Test 4 complete"
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analysis Questions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "1. Did Test 1 show text appearing gradually (streaming)?"
echo "   - YES: Basic streaming works, issue is in our parser"
echo "   - NO: Claude CLI may not be streaming even with stream-json"
echo
echo "2. Did Test 2 show JSON objects, one per line?"
echo "   - YES: stream-json is working correctly"
echo "   - NO: --output-format stream-json may not be working"
echo
echo "3. Did output appear immediately or all at once?"
echo "   - Immediately: Streaming works, buffering is not the issue"
echo "   - All at once: Output is buffered somewhere"
echo
echo "4. Was output JSON or plain text?"
echo "   - JSON: stream-json flag is working"
echo "   - Plain text: flag may not be applied correctly"
echo
