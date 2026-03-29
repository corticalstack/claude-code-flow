# Research: GitHub Issue #15 — Python Log Parser CLI

## Issue Summary

**Title:** Test: Create a Python log parser CLI that analyzes error patterns
**Labels:** `enhancement`, `research-in-progress`, `ralph-test`
**Purpose:** Test issue for validating the Ralph autonomous workflow (generated code will be discarded after validation).

## Requirements

### Files to Create
- `src/tools/logparser.py` — main CLI implementation
- `tests/test_logparser.py` — pytest test suite
- `src/__init__.py` and `src/tools/__init__.py` — package init files (likely needed)

### CLI Interface
```
python -m src.tools.logparser <log-file> [--format json|table]
```

### Log Line Format
```
YYYY-MM-DD HH:MM:SS [LEVEL] message
```
Supported levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

### Analysis Features
1. Count total log entries by level
2. Top 5 most common error messages
3. Error rate (errors per minute)
4. Time periods with highest error density
5. Detect repeated error patterns

### Output Formats
- **JSON**: structured data with counts, patterns, timestamps
- **Table**: formatted table using `rich` library
- Summary statistics at the end of both formats

### Error Handling
- Validate file existence before parsing
- Handle malformed log lines gracefully (skip with warning, continue)
- Helpful error messages; exit code 0 = success, 1 = error

### Code Quality Requirements
- Type hints on all functions
- Google-style docstrings
- Argument validation
- `ruff` linting passes
- `mypy` type checking passes

## Existing Codebase State

### What Exists
- `.venv/` with Python 3.12 and relevant packages installed:
  - `rich 14.3.3` — for table output
  - `pytest 9.0.2` — for tests
  - `ruff 0.15.8` — for linting
  - `mypy 1.19.1` — for type checking
- `src/tools/__pycache__/logparser.cpython-312.pyc` — compiled cache from a prior run (source no longer present)
- `tests/__pycache__/test_logparser.cpython-312-pytest-9.0.2.pyc` — compiled test cache from prior run
- `flow/research/`, `flow/plans/`, `flow/prs/` directories exist (empty, `.gitkeep` only)

### What Does NOT Exist
- `src/__init__.py`
- `src/tools/__init__.py`
- `src/tools/logparser.py`
- `tests/__init__.py`
- `tests/test_logparser.py`
- `pyproject.toml` / `setup.py` / `requirements.txt` — no Python project config found

### No Existing Patterns to Follow
This is a template repo; there is no existing Python application code to mirror. The `src/` and `tests/` directories only contain `__pycache__` artifacts.

## Architecture Notes

### Module Structure
```
src/
  __init__.py
  tools/
    __init__.py
    logparser.py
tests/
  __init__.py
  test_logparser.py
```

### logparser.py Design
```python
# Core components:
# 1. LogEntry dataclass — parsed log line
# 2. parse_log_file(path: Path) -> list[LogEntry] — parsing with graceful skip on malformed
# 3. analyze(entries: list[LogEntry]) -> AnalysisResult — all statistics
# 4. format_json(result: AnalysisResult) -> str — JSON output
# 5. format_table(result: AnalysisResult) -> None — rich table output
# 6. main() — argparse CLI entry point
```

### Key Implementation Decisions
- Use `re` for log line parsing (regex: `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)`)
- Use `dataclasses.dataclass` for `LogEntry` and `AnalysisResult`
- Use `datetime.datetime` for timestamp parsing and error rate calculation
- Error rate = total ERROR+CRITICAL entries / total time span in minutes
- Error density: group by minute bucket, find top periods
- Pattern detection: `Counter` on error message strings, filtered to ERROR/CRITICAL
- Table output with `rich.table.Table` and `rich.console.Console`

### pyproject.toml
Since no project config exists, create a minimal `pyproject.toml` for tool configuration:
```toml
[tool.mypy]
python_version = "3.12"
strict = true

[tool.ruff]
target-version = "py312"
```

## Test Fixtures Needed
1. Valid log file with mixed levels (DEBUG/INFO/WARNING/ERROR/CRITICAL)
2. Log file with errors only
3. Empty log file
4. File with malformed lines mixed with valid ones

Use `tmp_path` pytest fixture to create temp log files in tests.

## Acceptance Criteria Checklist
- [ ] `src/tools/logparser.py` created with full implementation
- [ ] `python -m src.tools.logparser sample.log` runs successfully
- [ ] `--format json` outputs valid JSON
- [ ] `--format table` outputs rich table
- [ ] `pytest tests/test_logparser.py -v` passes
- [ ] Handles missing file (exit 1, helpful message)
- [ ] Handles malformed lines (skip, continue)
- [ ] `ruff check src/ tests/` passes
- [ ] `mypy src/ tests/` passes

## Implementation Considerations

1. **No pyproject.toml exists** — need to create one for mypy/ruff config, or pass flags on CLI
2. **__init__.py files needed** — for `python -m src.tools.logparser` to work as a module
3. **`rich` available** in `.venv` — use `Console` and `Table` from `rich`
4. **Error density window** — issue says "time periods with highest error density"; implement as 1-minute buckets, report top 3-5 windows
5. **mypy strict mode** — with strict=True, need to be careful with `Optional` types and `Any`; `rich` has stubs so should type-check cleanly
