#!/bin/bash
#
# debug_streaming.sh - Systematic debugging of Claude streaming output
#
# This script tests each component of the streaming pipeline to identify
# where the real-time output is breaking down.
#

set -euo pipefail

DEBUG_DIR="./debug_output"
mkdir -p "$DEBUG_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Claude Code Streaming Debug Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Test 1: Check if Claude CLI is available
echo "TEST 1: Checking Claude CLI availability..."
if command -v claude &> /dev/null; then
    echo "✅ Claude CLI found: $(which claude)"
    claude --version 2>&1 || echo "  (version command not available)"
else
    echo "❌ Claude CLI not found in PATH"
    exit 1
fi
echo

# Test 2: Check available flags
echo "TEST 2: Checking available Claude CLI flags..."
echo "Checking for --output-format flag..."
if claude --help 2>&1 | grep -q "output-format"; then
    echo "✅ --output-format flag available"
    echo "   Available formats:"
    claude --help 2>&1 | grep -A 1 "output-format" | head -3
else
    echo "❌ --output-format flag NOT found"
fi
echo

# Test 3: Test basic --print mode without streaming
echo "TEST 3: Testing basic --print mode (no streaming)..."
echo "Running: claude --print 'Say hello' (5 second timeout)"
timeout 5 claude --print "Say hello in 3 words" 2>&1 | tee "$DEBUG_DIR/test3_basic_print.log" || true
echo "✅ Basic print test complete"
echo "   Output saved to: $DEBUG_DIR/test3_basic_print.log"
echo

# Test 4: Test --verbose flag alone
echo "TEST 4: Testing --verbose flag..."
echo "Running: claude --verbose --print 'Say hello' (5 second timeout)"
timeout 5 claude --verbose --print "Say hello in 3 words" 2>&1 | tee "$DEBUG_DIR/test4_verbose.log" || true
echo "✅ Verbose test complete"
echo "   Output saved to: $DEBUG_DIR/test4_verbose.log"
echo

# Test 5: Test --output-format stream-json
echo "TEST 5: Testing --output-format stream-json..."
echo "Running: claude --output-format stream-json --print 'Say hello' (5 second timeout)"
timeout 5 claude --output-format stream-json --print "Say hello in 3 words" 2>&1 | tee "$DEBUG_DIR/test5_stream_json.log" || true
echo "✅ Stream JSON test complete"
echo "   Output saved to: $DEBUG_DIR/test5_stream_json.log"
echo "   Checking if output is valid JSON..."
if [ -s "$DEBUG_DIR/test5_stream_json.log" ]; then
    echo "   File has content, checking first few lines:"
    head -3 "$DEBUG_DIR/test5_stream_json.log"
    echo "   ..."
    echo "   Validating JSON lines..."
    line_count=0
    while IFS= read -r line; do
        line_count=$((line_count + 1))
        if echo "$line" | jq . > /dev/null 2>&1; then
            echo "   ✅ Line $line_count: Valid JSON"
        else
            echo "   ❌ Line $line_count: Invalid JSON: $line"
        fi
        [ $line_count -ge 3 ] && break
    done < "$DEBUG_DIR/test5_stream_json.log"
else
    echo "   ⚠️  File is empty or doesn't exist"
fi
echo

# Test 6: Test combined --verbose --output-format stream-json
echo "TEST 6: Testing --verbose --output-format stream-json combined..."
echo "Running: claude --verbose --output-format stream-json --print 'Say hello' (5 second timeout)"
timeout 5 claude --verbose --output-format stream-json --print "Say hello in 3 words" 2>&1 | tee "$DEBUG_DIR/test6_verbose_stream_json.log" || true
echo "✅ Combined flags test complete"
echo "   Output saved to: $DEBUG_DIR/test6_verbose_stream_json.log"
echo "   Checking output format..."
if [ -s "$DEBUG_DIR/test6_verbose_stream_json.log" ]; then
    echo "   First 3 lines:"
    head -3 "$DEBUG_DIR/test6_verbose_stream_json.log"
    echo "   ..."
else
    echo "   ⚠️  File is empty"
fi
echo

# Test 7: Test real-time output with timestamps
echo "TEST 7: Testing real-time output behavior..."
echo "Running a command with timestamp logging to check buffering..."
{
    echo "[$(date +%H:%M:%S.%3N)] Starting claude command..."
    timeout 10 claude --output-format stream-json --print "Count from 1 to 3, saying each number" 2>&1 | while IFS= read -r line; do
        echo "[$(date +%H:%M:%S.%3N)] $line"
    done
    echo "[$(date +%H:%M:%S.%3N)] Command completed"
} | tee "$DEBUG_DIR/test7_realtime_timestamps.log" || true
echo "✅ Timestamp test complete"
echo "   Check timestamps in: $DEBUG_DIR/test7_realtime_timestamps.log"
echo "   If timestamps are all at the end, output is buffered"
echo

# Test 8: Test with stdbuf
echo "TEST 8: Testing with stdbuf line-buffering..."
echo "Running: stdbuf -oL claude --output-format stream-json --print 'Say hello' (5 second timeout)"
timeout 5 stdbuf -oL claude --output-format stream-json --print "Say hello in 3 words" 2>&1 | tee "$DEBUG_DIR/test8_stdbuf.log" || true
echo "✅ stdbuf test complete"
echo "   Output saved to: $DEBUG_DIR/test8_stdbuf.log"
echo

# Test 9: Test parse script with sample JSON
echo "TEST 9: Testing parse_claude_stream.sh with sample input..."
cat > "$DEBUG_DIR/test9_sample_input.json" << 'EOF'
{"type":"system","model":"claude-sonnet-4-5","session_id":"test123"}
{"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","id":"tool_abc123","input":{"file_path":"/test"}}]}}
EOF

echo "Sample JSON input:"
cat "$DEBUG_DIR/test9_sample_input.json"
echo
echo "Running through parser:"
cat "$DEBUG_DIR/test9_sample_input.json" | ./scripts/parse_claude_stream.sh 2>&1 | tee "$DEBUG_DIR/test9_parser_output.log"
echo "✅ Parser test complete"
echo

# Test 10: Test full pipeline with debug parser
echo "TEST 10: Creating instrumented parser for pipeline testing..."
cat > "$DEBUG_DIR/debug_parser.sh" << 'EOF'
#!/bin/bash
exec 3>&2  # Save stderr to fd 3
exec 2>>/tmp/parse_debug.log  # Redirect stderr to debug log

echo "[PARSER DEBUG $(date +%H:%M:%S.%3N)] Parser started" >&2
echo "[PARSER DEBUG $(date +%H:%M:%S.%3N)] Waiting for input..." >&2

line_count=0
while IFS= read -r line; do
    line_count=$((line_count + 1))
    echo "[PARSER DEBUG $(date +%H:%M:%S.%3N)] Received line $line_count: ${line:0:80}..." >&2
    echo "$line"  # Echo through to stdout
done

echo "[PARSER DEBUG $(date +%H:%M:%S.%3N)] Parser finished, processed $line_count lines" >&2
EOF
chmod +x "$DEBUG_DIR/debug_parser.sh"

echo "Running full pipeline with debug parser:"
echo "> /tmp/parse_debug.log" > /tmp/parse_debug.log  # Clear log
timeout 5 claude --output-format stream-json --print "Say hello in 3 words" 2>&1 | "$DEBUG_DIR/debug_parser.sh" | head -20 || true
echo
echo "Parser debug log:"
cat /tmp/parse_debug.log
echo "✅ Pipeline test complete"
echo

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Debug Analysis Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "All test outputs saved to: $DEBUG_DIR/"
echo
echo "Next steps:"
echo "1. Review test outputs to see where streaming breaks"
echo "2. Check test7 timestamps - if all at end, Claude CLI itself is buffering"
echo "3. Check test10 parser debug log - if no real-time lines, input isn't streaming"
echo "4. Compare test outputs to identify which flags cause issues"
echo
echo "Files to review:"
ls -lh "$DEBUG_DIR/"
