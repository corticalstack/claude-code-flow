# Implementation Plan: Python Log Parser CLI (#15)

**Issue:** [#15 — Test: Create a Python log parser CLI that analyzes error patterns](https://github.com/anthropics/claude-code-flow/issues/15)
**Research:** [flow/research/2026-03-29-gh-15-description.md](../research/2026-03-29-gh-15-description.md)
**Branch:** `feature/15-python-log-parser-cli`

---

## Overview

Create a Python CLI tool (`src/tools/logparser.py`) that parses structured log files and analyzes error patterns, with JSON and rich table output formats. Includes a full pytest test suite, pyproject.toml config, and all required package init files.

This is a test issue for the Ralph autonomous workflow; code will be discarded after validation.

---

## Requirements Summary

- Parse log lines: `YYYY-MM-DD HH:MM:SS [LEVEL] message`
- Levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- CLI: `python -m src.tools.logparser <log-file> [--format json|table]`
- Analysis: counts by level, top-5 error messages, error rate, error density windows, pattern detection
- Output: JSON (structured) or table (rich library)
- Error handling: validate file, skip malformed lines, exit codes 0/1
- Code quality: type hints, Google docstrings, ruff clean, mypy strict

---

## Phase 1: Project Setup

**Goal:** Create package structure and project config so the module is importable and tooling works.

### Files to Create

1. **`pyproject.toml`** — minimal project config for mypy and ruff:
   ```toml
   [tool.mypy]
   python_version = "3.12"
   strict = true

   [tool.ruff]
   target-version = "py312"
   line-length = 88
   ```

2. **`src/__init__.py`** — empty package marker

3. **`src/tools/__init__.py`** — empty package marker

4. **`tests/__init__.py`** — empty package marker

### Verification
```bash
python -c "import src.tools"
```

---

## Phase 2: Core Implementation

**Goal:** Implement `src/tools/logparser.py` with all required functionality.

### File: `src/tools/logparser.py`

#### Data Structures
```python
@dataclass
class LogEntry:
    timestamp: datetime
    level: str
    message: str

@dataclass
class AnalysisResult:
    total_entries: int
    counts_by_level: dict[str, int]
    top_error_messages: list[tuple[str, int]]  # (message, count), top 5
    error_rate_per_minute: float               # (ERROR+CRITICAL) / time_span_minutes
    error_density_windows: list[tuple[str, int]]  # (minute_bucket_str, count), top 5
    repeated_patterns: list[tuple[str, int]]   # errors seen 2+ times
    time_span_minutes: float
    malformed_lines: int
```

#### Functions
1. **`parse_log_file(path: Path) -> tuple[list[LogEntry], int]`**
   - Regex: `^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$`
   - Skip malformed lines (count them, print warning to stderr)
   - Return `(entries, malformed_count)`

2. **`analyze(entries: list[LogEntry]) -> AnalysisResult`**
   - Count by level using `Counter`
   - Filter ERROR+CRITICAL for error analysis
   - Error rate = error_count / time_span_minutes (0 if < 2 entries or no time span)
   - Density windows: group timestamps by minute bucket (`HH:MM`), Counter, top 5
   - Repeated patterns: error messages appearing 2+ times, sorted by count desc

3. **`format_json(result: AnalysisResult) -> str`**
   - Return `json.dumps(dataclasses.asdict(result), indent=2)`
   - Note: convert tuples to lists for JSON serialization

4. **`format_table(result: AnalysisResult) -> None`**
   - Use `rich.console.Console` and `rich.table.Table`
   - Table 1: Counts by level
   - Table 2: Top error messages
   - Table 3: Error density windows
   - Summary panel: error rate, total entries, malformed lines

5. **`main() -> None`**
   - `argparse` with positional `log_file` and `--format {json,table}` (default: table)
   - Validate file exists → exit(1) with message if not
   - Call `parse_log_file` → `analyze` → `format_json` or `format_table`
   - Exit 0 on success

6. **`if __name__ == "__main__": main()`** — also add `__main__` block

### Module entry point
Add `src/tools/__main__.py` is NOT needed since we use `python -m src.tools.logparser` which calls `logparser.py` directly.

The `if __name__ == "__main__": main()` block in `logparser.py` handles `python -m src.tools.logparser`.

---

## Phase 3: Test Suite

**Goal:** Create `tests/test_logparser.py` with comprehensive pytest coverage.

### File: `tests/test_logparser.py`

#### Fixtures (using `tmp_path`)

```python
@pytest.fixture
def mixed_log(tmp_path) -> Path:
    # Valid log with DEBUG/INFO/WARNING/ERROR/CRITICAL entries
    # Include repeated errors for pattern detection
    # Time span: at least 2 minutes for error rate calculation

@pytest.fixture
def errors_only_log(tmp_path) -> Path:
    # All ERROR/CRITICAL entries

@pytest.fixture
def empty_log(tmp_path) -> Path:
    # Zero-byte file

@pytest.fixture
def malformed_log(tmp_path) -> Path:
    # Mix of valid and invalid lines
    # e.g., "not a log line", "2026-01-01 bad format", valid lines
```

#### Test Cases

**Parsing tests:**
- `test_parse_valid_log` — correct entry count and level detection
- `test_parse_empty_log` — returns empty list, zero malformed
- `test_parse_malformed_lines` — valid entries extracted, malformed counted
- `test_parse_file_not_found` — raises `FileNotFoundError` or `SystemExit(1)`

**Analysis tests:**
- `test_analyze_counts_by_level` — correct counts for each level
- `test_analyze_top_error_messages` — returns top 5 sorted by frequency
- `test_analyze_error_rate` — correct errors/min calculation
- `test_analyze_error_density` — correct top windows identified
- `test_analyze_repeated_patterns` — only shows messages appearing 2+ times
- `test_analyze_empty_entries` — handles empty list (zeros, no crash)

**Output format tests:**
- `test_format_json_valid` — output is valid JSON, contains expected keys
- `test_format_json_structure` — counts_by_level, top_error_messages present
- `test_format_table_no_exception` — runs without raising (captures stdout)

**CLI integration tests (using `subprocess` or `click.testing.CliRunner`):**
- `test_cli_default_format` — runs with sample log, exit 0
- `test_cli_json_format` — `--format json` returns valid JSON
- `test_cli_table_format` — `--format table` exits 0
- `test_cli_missing_file` — exits 1 with helpful message
- `test_cli_malformed_file` — exits 0 (partial parse, warnings to stderr)

---

## Phase 4: Validation

**Goal:** Verify all acceptance criteria pass before committing.

### Commands to Run
```bash
# Activate venv
source .venv/bin/activate

# Linting
ruff check src/ tests/

# Type checking
mypy src/ tests/

# Tests
pytest tests/test_logparser.py -v

# Manual smoke test
echo "2026-02-10 10:00:00 [INFO] App started
2026-02-10 10:00:15 [ERROR] DB failed: timeout
2026-02-10 10:01:00 [ERROR] DB failed: timeout
2026-02-10 10:01:30 [CRITICAL] Service down" > /tmp/sample.log

python -m src.tools.logparser /tmp/sample.log
python -m src.tools.logparser /tmp/sample.log --format json
python -m src.tools.logparser /tmp/nonexistent.log
```

### Expected Results
- `ruff check` → no errors
- `mypy` → no errors (strict mode)
- `pytest` → all tests pass
- CLI default (table) → rich table output, exit 0
- CLI json → valid JSON output, exit 0
- CLI missing file → error message, exit 1

---

## Success Criteria

- [ ] `src/tools/logparser.py` exists with complete implementation
- [ ] `src/__init__.py`, `src/tools/__init__.py`, `tests/__init__.py` exist
- [ ] `pyproject.toml` exists with mypy and ruff config
- [ ] `python -m src.tools.logparser sample.log` runs (table output)
- [ ] `python -m src.tools.logparser sample.log --format json` outputs valid JSON
- [ ] `python -m src.tools.logparser sample.log --format table` outputs rich table
- [ ] Missing file → exit 1 with helpful message
- [ ] Malformed lines → skipped with warning, continues parsing
- [ ] `pytest tests/test_logparser.py -v` → all pass
- [ ] `ruff check src/ tests/` → clean
- [ ] `mypy src/ tests/` → clean (strict)

---

## Files to Create (Summary)

| File | Action |
|------|--------|
| `pyproject.toml` | Create |
| `src/__init__.py` | Create |
| `src/tools/__init__.py` | Create |
| `src/tools/logparser.py` | Create |
| `tests/__init__.py` | Create |
| `tests/test_logparser.py` | Create |

**No existing files are modified.**

---

## Notes

- `.venv/` has `rich`, `pytest`, `ruff`, `mypy` already installed
- Cached `.pyc` files exist from prior attempts — source files are absent; implement fresh
- Use `sys.exit(1)` for CLI errors, not `raise SystemExit` in library functions
- `AnalysisResult.error_density_windows` stores top-5 minute buckets sorted by error count desc
- For `mypy` strict: annotate `dict[str, int]`, `list[tuple[str, int]]` explicitly; avoid bare `Any`
