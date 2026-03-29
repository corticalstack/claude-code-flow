---
issue: 15
title: Test: Create a Python log parser CLI that analyzes error patterns
date: 2026-03-29
status: research-complete
---

# Issue #15 Research: Python Log Parser CLI

## Issue Summary

Create a Python CLI tool (`src/tools/logparser.py`) that parses log files and analyzes error patterns. This is a test issue for validating the Ralph autonomous workflow — the generated code will be discarded after validation.

**Labels:** `enhancement`, `research-in-progress`, `ralph-test`

## Requirements

### CLI Tool
- File: `src/tools/logparser.py`
- Entry point: `python -m src.tools.logparser <log-file> [--format json|table]`
- Log line format: `YYYY-MM-DD HH:MM:SS [LEVEL] message`
- Supported levels: DEBUG, INFO, WARNING, ERROR, CRITICAL

### Analysis Features
1. Count total log entries by level
2. Find top 5 most common error messages
3. Calculate error rate (errors per minute)
4. Identify time periods with highest error density
5. Detect repeated error patterns

### Output Formats
- `json`: structured data with counts, patterns, timestamps
- `table`: formatted table using `rich` library
- Summary statistics in both formats

### Error Handling
- Validate file existence
- Handle malformed log lines gracefully
- Helpful error messages; exit codes: 0=success, 1=error

### Testing
- File: `tests/test_logparser.py`
- Fixtures: valid mixed-level log, errors-only log, empty log, malformed lines
- Test JSON and table output, error detection, pattern analysis

### Code Quality
- Type hints on all functions
- Google-style docstrings
- `ruff check src/ tests/` must pass
- `mypy src/ tests/` must pass

## Relevant Existing Files

### No `src/` or `tests/` directories exist yet
Both directories need to be created from scratch. The repo is a template repository with no Python application code.

### `scripts/ralph_sdk/pyproject.toml`
Already declares relevant dependencies:
- `rich>=13.0.0` — required for table output
- `pytest>=7.4.0`, `pytest-asyncio`, `pytest-cov` — test tooling
- `mypy>=1.5.0`, `ruff>=0.1.0` — code quality tools
- `ruff` config: `line-length = 100`, `target-version = "py310"`
- `mypy` config: `python_version = "3.10"`, `disallow_untyped_defs = false`

Note: The project will need its own `pyproject.toml` (or `setup.cfg`) at the repo root, or the `src/` tree must be accessible as a package.

## Architecture Notes

### Package Structure
```
src/
  __init__.py
  tools/
    __init__.py
    logparser.py
tests/
  __init__.py
  test_logparser.py
  fixtures/
    valid_mixed.log
    errors_only.log
    empty.log
    malformed.log
```

### Module Design (`logparser.py`)
```
LogEntry        - dataclass: timestamp, level, message
LogParser       - parses file → List[LogEntry]
LogAnalyzer     - analysis methods (counts, rates, patterns, density)
OutputFormatter - renders JSON or rich Table
main()          - argparse CLI entry point
```

### Key Implementation Details

**Parsing regex:**
```python
re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$')
```

**Error rate (errors per minute):**
- Filter entries with level ERROR or CRITICAL
- Compute time span from first to last entry
- `error_rate = error_count / total_minutes`

**Highest error density periods:**
- Bucket entries into 1-minute windows
- Return top N windows by error count

**Error pattern detection:**
- Group by normalized message (strip trailing numbers/UUIDs)
- Report groups with count > 1

**rich table output:**
```python
from rich.console import Console
from rich.table import Table
```

**JSON output:**
```python
import json
# serialize dataclasses with dataclasses.asdict()
# datetime → isoformat()
```

### Exit Codes
- `0` — success
- `1` — file not found, parse failure, or unexpected error

## Implementation Considerations

1. **No project-level `pyproject.toml`** — need to create one at repo root (or minimal `setup.cfg`) so `python -m src.tools.logparser` works and `mypy`/`ruff` can find the source.

2. **`rich` availability** — `rich` is listed in `scripts/ralph_sdk/pyproject.toml` but not at the repo root. The implementation plan must include installing `rich` (e.g., `pip install rich`) or adding a root-level `pyproject.toml`.

3. **Malformed line handling** — skip lines that don't match the regex, optionally log a warning count at the end.

4. **Empty file edge case** — return zero counts, no error rate (division by zero guard needed).

5. **`mypy` strictness** — `disallow_untyped_defs = false` is lenient, but all public functions should still carry type hints per the issue requirements.

6. **Test fixtures** — use `tmp_path` pytest fixture or checked-in fixture files under `tests/fixtures/`.

7. **`__main__.py`** — to support `python -m src.tools.logparser`, add `src/tools/__main__.py` that calls `main()`, or ensure `logparser.py` has the `if __name__ == "__main__"` guard.

## Acceptance Criteria Mapping

| Criterion | File(s) |
|-----------|---------|
| `src/tools/logparser.py` exists | `src/tools/logparser.py` |
| Parse log files (default output) | `main()` + `LogParser` |
| JSON output | `OutputFormatter.to_json()` |
| Table output | `OutputFormatter.to_table()` |
| All tests pass | `tests/test_logparser.py` |
| Handles errors gracefully | `LogParser` + `main()` |
| `ruff check` passes | Code style compliance |
| `mypy` passes | Type annotations |
