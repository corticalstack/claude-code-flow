---
issue: 15
title: Test: Create a Python log parser CLI that analyzes error patterns
date: 2026-03-29
status: planning-complete
branch: feature/15-python-log-parser-cli
---

# Implementation Plan: Python Log Parser CLI (#15)

## Overview

Create a Python CLI tool that parses log files and analyzes error patterns. This is a test issue for validating the Ralph autonomous workflow.

**Deliverables:**
- `src/tools/logparser.py` — main CLI module
- `tests/test_logparser.py` — pytest test suite
- `tests/fixtures/` — sample log files
- `pyproject.toml` — project configuration (ruff, mypy, rich dependency)

---

## Requirements Summary

| Area | Requirement |
|------|-------------|
| CLI | `python -m src.tools.logparser <log-file> [--format json\|table]` |
| Parsing | `YYYY-MM-DD HH:MM:SS [LEVEL] message` format |
| Analysis | Level counts, top-5 errors, error rate, density periods, pattern detection |
| Output | JSON and rich Table |
| Quality | Type hints, Google docstrings, ruff + mypy passing |
| Exit codes | 0=success, 1=error |

---

## Implementation Phases

### Phase 1: Project Setup

**Goal:** Establish the Python package structure and project configuration.

**Files to create:**
- `pyproject.toml` — root-level project config with ruff, mypy settings and `rich` dependency
- `src/__init__.py` — empty package marker
- `src/tools/__init__.py` — empty package marker
- `tests/__init__.py` — empty package marker
- `tests/fixtures/valid_mixed.log` — sample log with mixed levels
- `tests/fixtures/errors_only.log` — log with ERROR/CRITICAL only
- `tests/fixtures/empty.log` — empty file
- `tests/fixtures/malformed.log` — log with some malformed lines

**`pyproject.toml` config:**
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "claude-code-flow-tools"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = ["rich>=13.0.0"]

[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.mypy]
python_version = "3.10"
disallow_untyped_defs = false
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
```

**Fixture file content (`valid_mixed.log`):**
```
2026-01-15 10:00:00 [INFO] Application started
2026-01-15 10:00:15 [DEBUG] Loading configuration
2026-01-15 10:00:16 [ERROR] Database connection failed: timeout
2026-01-15 10:00:20 [WARNING] Retrying connection
2026-01-15 10:00:25 [ERROR] Database connection failed: timeout
2026-01-15 10:00:30 [CRITICAL] Service unavailable
2026-01-15 10:01:00 [INFO] Health check passed
2026-01-15 10:01:05 [ERROR] Database connection failed: timeout
2026-01-15 10:01:10 [ERROR] Disk space low: 95% used
2026-01-15 10:01:15 [WARNING] Memory pressure detected
```

**Fixture file content (`errors_only.log`):**
```
2026-01-15 10:00:00 [ERROR] Service A failed
2026-01-15 10:00:30 [ERROR] Service B failed
2026-01-15 10:01:00 [CRITICAL] Total system failure
```

**Fixture file content (`malformed.log`):**
```
2026-01-15 10:00:00 [INFO] Valid line
not a valid log line
2026-01-15 [MISSINGTIME] partial line
2026-01-15 10:00:05 [ERROR] Another valid line
just some random text
```

---

### Phase 2: Core Implementation (`logparser.py`)

**Goal:** Implement all classes and the CLI entry point.

**File:** `src/tools/logparser.py`

**Module structure:**

```python
# Imports: re, json, argparse, sys, dataclasses, datetime, collections, pathlib, typing
# from rich.console import Console
# from rich.table import Table

@dataclass
class LogEntry:
    timestamp: datetime
    level: str
    message: str

class LogParser:
    """Parses a log file into LogEntry objects."""
    LOG_PATTERN = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$')
    VALID_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}

    def parse_file(self, path: Path) -> tuple[list[LogEntry], int]:
        """Returns (entries, malformed_count)."""

class LogAnalyzer:
    """Analyzes a list of LogEntry objects."""

    def count_by_level(self, entries: list[LogEntry]) -> dict[str, int]: ...
    def top_error_messages(self, entries: list[LogEntry], n: int = 5) -> list[tuple[str, int]]: ...
    def error_rate(self, entries: list[LogEntry]) -> float: ...
    def highest_density_periods(self, entries: list[LogEntry], n: int = 3) -> list[tuple[str, int]]: ...
    def detect_patterns(self, entries: list[LogEntry]) -> list[tuple[str, int]]: ...

class OutputFormatter:
    """Renders analysis results."""

    def to_json(self, entries: list[LogEntry], analysis: dict) -> str: ...
    def to_table(self, entries: list[LogEntry], analysis: dict) -> None: ...

def main() -> None:
    """CLI entry point with argparse."""
```

**Key implementation details:**

- **Error rate:** `error_count / total_minutes` where total_minutes is span from first to last entry. Guard against division by zero (return 0.0 for <1 minute span or no entries).
- **Density periods:** Bucket by `timestamp.strftime("%Y-%m-%d %H:%M")` (1-minute windows). Count ERROR+CRITICAL per bucket. Return top N.
- **Pattern detection:** Normalize message by stripping trailing hex UUIDs, numbers, IPs. Group normalized messages, return those with count > 1.
- **JSON serialization:** Use `dataclasses.asdict()` and convert `datetime` to `.isoformat()` via a custom default function.
- **Malformed lines:** Skip silently, track count, print warning to stderr at the end if count > 0.
- **`if __name__ == "__main__":`** guard in logparser.py for `python -m` support.

**`main()` flow:**
1. Parse args (`log_file`, `--format` default `table`)
2. Validate file exists → exit(1) with message if not
3. `LogParser().parse_file(path)` → entries, malformed_count
4. `LogAnalyzer()` → build analysis dict
5. `OutputFormatter()` → render and print
6. Exit 0

---

### Phase 3: Test Suite (`test_logparser.py`)

**Goal:** Full pytest coverage for all features.

**File:** `tests/test_logparser.py`

**Test structure:**

```python
# Fixtures: valid_log_path, errors_only_path, empty_log_path, malformed_log_path
# (using pathlib.Path pointing to tests/fixtures/)

class TestLogParser:
    def test_parse_valid_file_count(self): ...
    def test_parse_returns_correct_levels(self): ...
    def test_parse_empty_file(self): ...
    def test_parse_malformed_lines_skipped(self): ...
    def test_parse_file_not_found_raises(self): ...

class TestLogAnalyzer:
    def test_count_by_level(self): ...
    def test_top_error_messages(self): ...
    def test_error_rate_calculation(self): ...
    def test_error_rate_empty(self): ...
    def test_highest_density_periods(self): ...
    def test_detect_patterns(self): ...

class TestOutputFormatter:
    def test_json_output_structure(self, capsys): ...
    def test_table_output_runs_without_error(self, capsys): ...

class TestCLI:
    def test_main_table_output(self, tmp_path): ...
    def test_main_json_output(self, tmp_path, capsys): ...
    def test_main_missing_file_exits_1(self, tmp_path): ...
```

---

### Phase 4: Quality Verification

**Goal:** Ensure all quality gates pass before completion.

**Commands to run (in order):**

```bash
# Install dependencies
pip install rich pytest mypy ruff

# Run tests
pytest tests/test_logparser.py -v

# Lint
ruff check src/ tests/

# Type check
mypy src/ tests/
```

**Expected outcomes:**
- All pytest tests pass (0 failures)
- ruff reports 0 errors
- mypy reports 0 errors (or only expected `[import]` ignores)

---

## File Change Summary

| File | Action |
|------|--------|
| `pyproject.toml` | Create |
| `src/__init__.py` | Create (empty) |
| `src/tools/__init__.py` | Create (empty) |
| `src/tools/logparser.py` | Create (~200 lines) |
| `tests/__init__.py` | Create (empty) |
| `tests/test_logparser.py` | Create (~150 lines) |
| `tests/fixtures/valid_mixed.log` | Create |
| `tests/fixtures/errors_only.log` | Create |
| `tests/fixtures/empty.log` | Create |
| `tests/fixtures/malformed.log` | Create |

---

## Success Criteria

- [x] `python -m src.tools.logparser tests/fixtures/valid_mixed.log` runs and prints a table
- [x] `python -m src.tools.logparser tests/fixtures/valid_mixed.log --format json` prints valid JSON
- [x] `python -m src.tools.logparser nonexistent.log` exits with code 1 and error message
- [x] `pytest tests/test_logparser.py -v` → all tests pass
- [x] `ruff check src/ tests/` → 0 errors
- [x] `mypy src/ tests/` → 0 errors

---

## Notes

- `rich` must be installed in the active environment before running the tool or tests
- The project root `pyproject.toml` is needed so `python -m src.tools.logparser` works correctly from the repo root
- This is a test issue; the generated code will be discarded after validation
