# Debugging Claude Code Streaming Output

This document provides a systematic approach to debugging why Claude Code streaming output is not appearing in real-time in the ralph-autonomous.sh left pane.

## Known Issues (from Research)

Based on web research of Claude Code GitHub issues, several streaming problems exist:

### Issue #733: Streaming output in `--verbose --print`
- **Status**: CLOSED (COMPLETED)
- **Solution**: Use `--output-format stream-json` (available since v0.2.66+)
- **Link**: https://github.com/anthropics/claude-code/issues/733

### Issue #4346: Live Streaming Text Output
- **Status**: CLOSED (NOT_PLANNED)
- **Workaround**: Use `claude --verbose -p "..." --output-format stream-json | jq -r ...`
- **Link**: https://github.com/anthropics/claude-code/issues/4346

### Issue #3187: claude code input stream json hang
- **Status**: Known issue with `--input-format stream-json` and `--output-format stream-json`
- **Impact**: Can cause segmentation faults and hangs
- **Link**: https://github.com/anthropics/claude-code/issues/3187

### Issue #1920: Missing Final Result Event
- **Problem**: Claude CLI fails to send final `{"type":"result",...}` event
- **Impact**: Process hangs indefinitely despite completing
- **Link**: https://github.com/anthropics/claude-code/issues/1920

### JSON Truncation Issue
- **Problem**: Claude Code CLI truncates JSON at fixed positions (4000, 6000, 8000, etc.)
- **Impact**: JSON parsing failures mid-stream
- **Note**: Direct Anthropic API doesn't have this issue

## Systematic Debugging Approach

### Step 1: Run Basic Streaming Test

```bash
./scripts/test_basic_streaming.sh
```

**What it tests:**
1. Exact command from GitHub issue #4346 (known working)
2. Raw stream-json output structure
3. With `stdbuf -oL` (like ralph-autonomous)
4. Full pipeline simulation

**Questions to answer:**
- Does basic streaming work with the GitHub recommended approach?
- Is output JSON or plain text?
- Does it appear gradually or all at once?
- Are we seeing JSON objects one per line?

### Step 2: Run Comprehensive Debug Analysis

```bash
./scripts/debug_streaming.sh
```

**What it tests:**
1. Claude CLI availability and version
2. Available flags (`--output-format`, etc.)
3. Basic `--print` mode without streaming
4. `--verbose` flag alone
5. `--output-format stream-json` alone
6. Combined `--verbose --output-format stream-json`
7. Real-time behavior with timestamps
8. `stdbuf` line-buffering
9. Parser with sample JSON
10. Full pipeline with instrumented parser

**Output location:** `./debug_output/`

**Key files to review:**
- `test7_realtime_timestamps.log` - If timestamps all at end, Claude CLI is buffering
- `test10` parser debug log at `/tmp/parse_debug.log` - Shows if parser receives real-time input

### Step 3: Test with Debug Parser

```bash
# Test the debug parser with real Claude output
timeout 10 claude --output-format stream-json -p "Count from 1 to 5" 2>&1 | \
    ./scripts/parse_claude_stream_debug.sh

# Check the debug log
cat /tmp/claude_parse_debug_*.log
```

**What to look for:**
- When do log entries appear? (Real-time or all at once)
- Are lines being received one at a time or in batches?
- Is JSON valid?
- Are events being parsed correctly?

### Step 4: Compare with Working Solution

From GitHub issue #4346, this is known to work:

```bash
claude --verbose -p "Your prompt" --output-format stream-json | \
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type? == "text") | .text'
```

**Test it:**
```bash
timeout 10 claude --verbose -p "Count from 1 to 5 with comments" --output-format stream-json | \
jq -u -r 'select(.type == "assistant") | .message.content[]? | select(.type? == "text") | .text'
```

If this works but our parser doesn't, the issue is in our parsing logic.

## Common Issues and Solutions

### Issue 1: `--print` Mode Buffers by Default
**Symptom**: No output until completion
**Solution**: Must use `--output-format stream-json` (not just `--verbose`)

### Issue 2: jq Buffering
**Symptom**: Output appears in chunks
**Solution**: Use `jq -u` (unbuffered mode)

### Issue 3: Pipe Buffering
**Symptom**: Delays between stages
**Solution**: Use `stdbuf -oL` on each command in pipeline

### Issue 4: Invalid JSON
**Symptom**: Parser crashes or skips lines
**Check**: Debug parser log shows "INVALID JSON"
**Possible causes**:
- Claude CLI truncation bug
- Missing final result event
- Corrupted stream

### Issue 5: Parser Not Receiving Input
**Symptom**: Debug log shows 0 lines received
**Possible causes**:
- Claude CLI hanging
- Permission issues with `--dangerously-skip-permissions`
- Timeout too short

### Issue 6: Read Loop Waits for EOF
**Symptom**: Output only appears when command finishes
**Issue**: Bash `read` can wait for EOF before processing
**Solution**: Ensure proper line-buffering with `stdbuf -oL`

## Debugging Checklist

- [ ] Run `test_basic_streaming.sh` - Does GitHub's solution work?
- [ ] Run `debug_streaming.sh` - Where does streaming break?
- [ ] Check test7 timestamps - Is Claude CLI streaming?
- [ ] Check test10 parser log - Is parser receiving real-time input?
- [ ] Test with debug parser - When do log entries appear?
- [ ] Compare JSON structure - Does it match expected format?
- [ ] Check for truncated JSON - Are there incomplete lines?
- [ ] Verify jq version - Does it support `-u` flag?
- [ ] Test without parser - Does raw stream-json stream?
- [ ] Check tmux buffering - Is tmux delaying output?

## Expected vs Actual Behavior

### Expected Behavior (Working)
```
[09:30:00.100] Starting claude command...
[09:30:01.250] {"type":"system","model":"claude-sonnet-4-5"}
[09:30:01.251] {"type":"assistant","message":{"content":[...]}}
[09:30:02.500] {"type":"assistant","message":{"content":[...]}}
[09:30:03.750] Command completed
```

### Problematic Behavior (Buffered)
```
[09:30:00.100] Starting claude command...
[09:30:05.750] {"type":"system","model":"claude-sonnet-4-5"}
[09:30:05.750] {"type":"assistant","message":{"content":[...]}}
[09:30:05.750] {"type":"assistant","message":{"content":[...]}}
[09:30:05.750] Command completed
```

## Next Steps Based on Findings

### If basic streaming works but ralph doesn't:
- Issue is in our parser or pipeline configuration
- Compare working command with ralph's execute_claude()
- Check differences in flags, piping, or buffering

### If basic streaming doesn't work:
- Claude CLI version issue
- Known bug in stream-json
- System-level buffering (terminal, tmux)
- Need alternative approach (e.g., Claude Agent SDK)

### If JSON is invalid:
- Hit Claude CLI truncation bug
- Need to report issue or use API directly
- Consider using Claude Agent SDK instead

### If parser never receives input:
- Claude CLI is hanging (waiting for user input?)
- Permission issues
- Timeout too aggressive
- Check Claude CLI logs/errors

## Alternative: Claude Agent SDK

If streaming continues to be problematic, consider migrating to Claude Agent SDK:
- Direct API access with SSE streaming
- No CLI buffering issues
- Better error handling and observability
- See: `flow/plans/2026-02-10-gh-13-ralph-claude-agent-sdk-migration.md`

## Sources

- [Streaming output in --verbose --print · Issue #733](https://github.com/anthropics/claude-code/issues/733)
- [Live Streaming Text Output for CLI Conversations · Issue #4346](https://github.com/anthropics/claude-code/issues/4346)
- [claude code input stream json hang · Issue #3187](https://github.com/anthropics/claude-code/issues/3187)
- [Missing Final Result Event · Issue #1920](https://github.com/anthropics/claude-code/issues/1920)
- [CLI reference - Claude Code Docs](https://code.claude.com/docs/en/cli-reference)
- [Claude Code Cheatsheet](https://shipyard.build/blog/claude-code-cheat-sheet/)
