#!/bin/bash
#
# quick_stream_test.sh - Quick 5-second test to verify streaming works
#

set -euo pipefail

echo "Quick Streaming Test - 5 seconds"
echo "=================================="
echo

echo "Test 1: Raw stream-json output (first 5 lines)"
echo "Expected: JSON objects appearing one at a time"
echo
timeout 5 claude -p "Say hello" --output-format stream-json 2>&1 | head -5
echo
echo "✅ Test 1 complete"
echo

echo "Test 2: With jq filtering (GitHub solution)"
echo "Expected: Text appearing gradually"
echo
timeout 5 claude --verbose -p "Count: 1, 2, 3" --output-format stream-json 2>&1 | \
jq --unbuffered -r 'select(.type == "assistant") | .message.content[]? | select(.type? == "text") | .text' || true
echo
echo "✅ Test 2 complete"
echo

echo "Test 3: Check if output appears immediately vs buffered"
echo "Expected: Timestamps should show output spread over time"
echo
{
    echo "[START $(date +%H:%M:%S)]"
    timeout 5 claude -p "Say: one, two, three" --output-format stream-json 2>&1 | head -3 | while read line; do
        echo "[$(date +%H:%M:%S)] Got line"
    done
    echo "[END $(date +%H:%M:%S)]"
} || true
echo
echo "If all timestamps are identical, output is buffered"
echo "If timestamps spread across seconds, streaming is working"
