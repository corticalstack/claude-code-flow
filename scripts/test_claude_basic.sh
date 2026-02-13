#!/bin/bash
#
# test_claude_basic.sh - Test if Claude CLI works at all
#

set -euo pipefail

echo "Testing Claude CLI basic functionality..."
echo

# Test 1: Check exit code
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Exit code check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
claude --dangerously-skip-permissions -p "Hello"
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Command succeeded (exit 0)"
    echo "⚠️  But produced no visible output!"
else
    echo "❌ Command failed with exit code: $EXIT_CODE"
fi
echo

# Test 2: Capture stderr
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Check stderr for errors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
OUTPUT=$(claude --dangerously-skip-permissions -p "Hello" 2>&1)
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
echo "Output length: ${#OUTPUT} characters"
if [ -n "$OUTPUT" ]; then
    echo "Output:"
    echo "<<<START>>>"
    echo "$OUTPUT"
    echo "<<<END>>>"
else
    echo "⚠️  NO OUTPUT AT ALL (not even errors)"
fi
echo

# Test 3: Without --dangerously-skip-permissions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Without --dangerously-skip-permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
timeout 5 claude -p "Hello" 2>&1 || echo "(Exit code: $?)"
echo

# Test 4: With --verbose flag
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: With --verbose"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
claude --dangerously-skip-permissions --verbose -p "Hello" 2>&1
echo "(Exit code: $?)"
echo

# Test 5: Interactive mode (just start it)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: Does interactive mode work?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Skipping - would require user input"
echo "Try manually: claude"
echo

# Test 6: Check Claude config
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: Claude configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Claude version:"
claude --version 2>&1 || echo "No version command"
echo
echo "Config location: ~/.claude/config.json"
if [ -f ~/.claude/config.json ]; then
    echo "Config exists:"
    jq '.' ~/.claude/config.json 2>/dev/null || cat ~/.claude/config.json
else
    echo "⚠️  No config file found"
fi
echo

# Test 7: Check permissions settings
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: Check permission mode setting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f ~/.claude/config.json ]; then
    PERM_MODE=$(jq -r '.permissionMode // "not set"' ~/.claude/config.json 2>/dev/null)
    echo "Permission mode: $PERM_MODE"

    if [ "$PERM_MODE" = "manual" ]; then
        echo "⚠️  Permission mode is MANUAL"
        echo "   This might cause --dangerously-skip-permissions to be ignored"
        echo "   Or it might be waiting for approval in a way we can't see"
    fi
else
    echo "No config to check"
fi
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DIAGNOSIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "If command exits 0 but produces no output:"
echo "  → Claude CLI is broken or misconfigured"
echo "  → --print mode may not be working"
echo "  → May need to reinstall Claude CLI"
echo
echo "If command hangs without --dangerously-skip-permissions:"
echo "  → Permission prompts are the issue"
echo "  → Need to fix permission mode"
echo
echo "Check if interactive mode works:"
echo "  → Run: claude"
echo "  → Type: Hello"
echo "  → If this works, issue is specific to --print mode"
echo
