#!/bin/bash
#
# fix_print_mode.sh - Debug and fix why --print mode produces no output
#

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fixing Claude CLI --print Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Problem: 'claude --print' returns immediately with no output"
echo "Goal: Make --print mode work for autonomous Ralph execution"
echo

# Step 1: Check Claude version and installation
echo "STEP 1: Check Claude installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
claude --version 2>&1 || echo "No --version flag"
echo
which claude
ls -la $(which claude)
echo

# Step 2: Check current config
echo "STEP 2: Check Claude configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CONFIG_FILE="$HOME/.claude/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo "Config file exists: $CONFIG_FILE"
    echo "Current config:"
    jq '.' "$CONFIG_FILE" 2>/dev/null || cat "$CONFIG_FILE"
    echo

    # Check specific settings
    PERM_MODE=$(jq -r '.permissionMode // "not set"' "$CONFIG_FILE" 2>/dev/null)
    echo "Permission mode: $PERM_MODE"

    if [ "$PERM_MODE" = "manual" ]; then
        echo "⚠️  WARNING: permissionMode is 'manual'"
        echo "   This may cause issues with --dangerously-skip-permissions"
    fi
else
    echo "⚠️  No config file found at $CONFIG_FILE"
    echo "   Claude might not be configured properly"
fi
echo

# Step 3: Try different --print variations
echo "STEP 3: Test different --print command variations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Test 3a: Basic --print"
echo "Command: claude --print 'Hello'"
timeout 3 claude --print "Hello" 2>&1 | cat -v || echo "(Exit: $?)"
echo

echo "Test 3b: With quotes variations"
echo "Command: claude --print \"Hello\""
timeout 3 claude --print "Hello" 2>&1 | cat -v || echo "(Exit: $?)"
echo

echo "Test 3c: With -p shorthand"
echo "Command: claude -p 'Hello'"
timeout 3 claude -p 'Hello' 2>&1 | cat -v || echo "(Exit: $?)"
echo

echo "Test 3d: Stdin instead of argument"
echo "Command: echo 'Hello' | claude --print"
timeout 3 echo "Hello" | claude --print 2>&1 | cat -v || echo "(Exit: $?)"
echo

# Step 4: Check for hooks that might interfere
echo "STEP 4: Check for hooks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HOOKS_DIR="$HOME/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    echo "Hooks directory exists: $HOOKS_DIR"
    ls -la "$HOOKS_DIR"
    echo

    # Check for print-mode hook
    if [ -f "$HOOKS_DIR/pre-print.sh" ] || [ -f "$HOOKS_DIR/post-print.sh" ]; then
        echo "⚠️  Print-related hooks found - these may interfere"
    fi
else
    echo "No hooks directory"
fi
echo

# Step 5: Test with explicit model
echo "STEP 5: Test with explicit model specification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: claude --print 'Hello' --model sonnet"
timeout 3 claude --print "Hello" --model sonnet 2>&1 | cat -v || echo "(Exit: $?)"
echo

# Step 6: Check environment variables
echo "STEP 6: Check environment variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
env | grep -i claude || echo "No CLAUDE env vars"
env | grep -i anthropic || echo "No ANTHROPIC env vars"
echo

# Step 7: Recommendations based on findings
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Based on the tests above:"
echo
echo "If ALL --print tests produce no output:"
echo "  → --print mode may not be supported in your Claude version"
echo "  → Or Claude installation is broken"
echo "  → Try: Reinstall Claude Code"
echo
echo "If permission mode is 'manual':"
echo "  → Try changing to 'auto' or 'allow-all'"
echo "  → Edit $CONFIG_FILE"
echo "  → Set: {\"permissionMode\": \"allow-all\"}"
echo
echo "If hooks exist:"
echo "  → Try temporarily moving hooks directory"
echo "  → mv ~/.claude/hooks ~/.claude/hooks.backup"
echo
echo "If stdin version works:"
echo "  → Ralph could pipe prompts instead of using arguments"
echo "  → echo \"prompt\" | claude --print"
echo
