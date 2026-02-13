# Claude Code Output Formats

## Available Formats

Claude Code CLI supports three output formats via `--output-format`:

### 1. `text` (Default)
**Human-readable plain text output**

```bash
claude -p "Your prompt"
# or explicitly:
claude -p "Your prompt" --output-format text
```

**Output:**
```
[Plain text response from Claude]
```

**Pros:**
- Simple and reliable
- Human-readable
- No parsing needed for display

**Cons:**
- Hard to programmatically parse tool calls
- No structured data
- Can't easily extract specific information

**Use case:** Basic usage, human review, simple logging

---

### 2. `json` (Non-Streaming)
**Single JSON object with complete response**

```bash
claude -p "Your prompt" --output-format json
```

**Output:**
```json
{
  "session_id": "...",
  "turns": [...],
  "result": "...",
  "cost_usd": 0.05
}
```

**Pros:**
- Structured and parseable
- Reliable (doesn't hang)
- Can extract tool calls, thinking, costs
- Complete conversation history

**Cons:**
- **NO real-time streaming** - waits until completion
- No progress visibility during execution
- All-or-nothing output

**Use case:** Reliable automation, post-processing, when streaming isn't critical

---

### 3. `stream-json` (Streaming)
**Newline-delimited JSON (NDJSON) with real-time events**

```bash
claude -p "Your prompt" --output-format stream-json
```

**Output:**
```json
{"type":"system","subtype":"init","session_id":"...","tools":[...]}
{"type":"assistant","message":{"content":[{"type":"text","text":"..."}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read",...}]}}
{"type":"user","message":{"content":[{"type":"tool_result",...}]}}
{"type":"result","subtype":"success",...}
```

**Pros:**
- **Real-time streaming** - events appear as they happen
- Structured and parseable
- See tool calls, thinking, progress in real-time
- Great for monitoring and dashboards

**Cons:**
- ⚠️ **KNOWN BUG**: Hangs intermittently (GitHub issues #1920, #8126)
- Missing final result event causes indefinite hangs
- Unreliable for production automation
- Closed as "NOT_PLANNED" by Anthropic

**Use case:** Real-time monitoring, dashboards (when it works)

---

## Why Ralph Uses stream-json

### Original Intent

Ralph's autonomous loop uses `stream-json` to provide **real-time visibility** into Claude's execution:

1. **Progress monitoring** - See tool calls as they happen in tmux dashboard
2. **Early error detection** - Catch issues before waiting for completion
3. **User visibility** - Show what Ralph is doing in real-time
4. **Debugging** - Understand execution flow and timing

### The Problem

We're hitting **GitHub issues #1920 and #8126** - known bugs where stream-json:
- Fails to send final `{"type":"result",...}` event
- Causes process to hang indefinitely
- Intermittent behavior (sometimes works, sometimes doesn't)
- Marked as "NOT_PLANNED" - won't be fixed

### The Trade-off

**With stream-json:**
- ✅ Real-time visibility
- ❌ Unreliable (hangs)

**With json:**
- ✅ Reliable (no hangs)
- ❌ No real-time visibility

**With text:**
- ✅ Most reliable
- ❌ Hard to parse, no structure

---

## Fallback Strategy

### Option 1: Use `json` Format (Quick Fix)

Change `ralph-autonomous.sh` line 231:

```bash
# Before:
flags="$flags --verbose --output-format stream-json"

# After:
flags="$flags --verbose --output-format json"
```

**Impact:**
- ✅ No more hangs
- ❌ No real-time streaming
- ❌ Output appears only at completion
- ❌ No live dashboard updates

**When to use:** If you need reliability NOW and can sacrifice streaming

### Option 2: Remove output-format (Use Default Text)

```bash
# Just remove the flag entirely
flags="$flags --verbose"
```

**Impact:**
- ✅ Most reliable
- ❌ Harder to parse tool calls
- ❌ No structured data

**When to use:** If JSON parsing isn't critical

### Option 3: Migrate to Claude Agent SDK (Proper Solution)

See `flow/plans/2026-02-10-gh-13-ralph-claude-agent-sdk-migration.md`

**Impact:**
- ✅ Reliable streaming (direct API with SSE)
- ✅ Better error handling
- ✅ No CLI bugs
- ❌ Requires implementation work

**When to use:** For production-quality autonomous agent

---

## Testing Output Formats

Run the comprehensive test:

```bash
./scripts/test_output_formats.sh
```

This tests all three formats and shows:
- Which ones work vs hang
- Timing and reliability
- Output structure
- Recommendations

---

## References

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [What is --output-format in Claude Code](https://claudelog.com/faqs/what-is-output-format-in-claude-code/)
- [GitHub Issue #1920: Missing Final Result Event](https://github.com/anthropics/claude-code/issues/1920)
- [GitHub Issue #8126: Sometimes missing result](https://github.com/anthropics/claude-code/issues/8126)
- [Shipyard Claude Code Cheatsheet](https://shipyard.build/blog/claude-code-cheat-sheet/)
