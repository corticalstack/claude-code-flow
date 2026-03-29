"""Tests for src.tools.logparser."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

from src.tools.logparser import (
    analyze,
    format_json,
    parse_log_file,
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

VALID_LOG_CONTENT = """\
2026-02-10 10:00:00 [DEBUG] Starting up
2026-02-10 10:00:05 [INFO] App started
2026-02-10 10:00:10 [WARNING] High memory usage
2026-02-10 10:00:15 [ERROR] DB failed: timeout
2026-02-10 10:01:00 [ERROR] DB failed: timeout
2026-02-10 10:01:10 [ERROR] DB failed: connection refused
2026-02-10 10:01:30 [CRITICAL] Service down
2026-02-10 10:02:00 [ERROR] DB failed: timeout
2026-02-10 10:02:15 [INFO] Reconnecting
"""


@pytest.fixture
def mixed_log(tmp_path: Path) -> Path:
    """Log file with multiple levels, repeated errors, and >2 min time span."""
    log_file = tmp_path / "mixed.log"
    log_file.write_text(VALID_LOG_CONTENT)
    return log_file


@pytest.fixture
def errors_only_log(tmp_path: Path) -> Path:
    """Log file containing only ERROR and CRITICAL entries."""
    content = """\
2026-02-10 10:00:00 [ERROR] Disk full
2026-02-10 10:00:30 [CRITICAL] OOM killed
2026-02-10 10:01:00 [ERROR] Disk full
"""
    log_file = tmp_path / "errors_only.log"
    log_file.write_text(content)
    return log_file


@pytest.fixture
def empty_log(tmp_path: Path) -> Path:
    """Zero-byte log file."""
    log_file = tmp_path / "empty.log"
    log_file.write_text("")
    return log_file


@pytest.fixture
def malformed_log(tmp_path: Path) -> Path:
    """Log file mixing valid and invalid lines."""
    content = """\
not a log line
2026-01-01 bad format here
2026-02-10 10:00:00 [INFO] Valid line 1
2026-02-10 10:00:01 [ERROR] Valid error
random garbage %%##
2026-02-10 10:00:02 [INFO] Valid line 2
"""
    log_file = tmp_path / "malformed.log"
    log_file.write_text(content)
    return log_file


# ---------------------------------------------------------------------------
# Parsing tests
# ---------------------------------------------------------------------------


def test_parse_valid_log(mixed_log: Path) -> None:
    """Correct entry count and level detection from a well-formed log."""
    entries, malformed = parse_log_file(mixed_log)
    assert malformed == 0
    assert len(entries) == 9
    levels = [e.level for e in entries]
    assert "DEBUG" in levels
    assert "INFO" in levels
    assert "WARNING" in levels
    assert "ERROR" in levels
    assert "CRITICAL" in levels


def test_parse_empty_log(empty_log: Path) -> None:
    """Empty file returns empty list and zero malformed count."""
    entries, malformed = parse_log_file(empty_log)
    assert entries == []
    assert malformed == 0


def test_parse_malformed_lines(malformed_log: Path) -> None:
    """Valid entries are extracted; malformed lines are counted."""
    entries, malformed = parse_log_file(malformed_log)
    assert len(entries) == 3
    assert malformed == 3


def test_parse_file_not_found(tmp_path: Path) -> None:
    """Raises FileNotFoundError for missing file."""
    with pytest.raises(FileNotFoundError):
        parse_log_file(tmp_path / "nonexistent.log")


# ---------------------------------------------------------------------------
# Analysis tests
# ---------------------------------------------------------------------------


def test_analyze_counts_by_level(mixed_log: Path) -> None:
    """Counts for each level are correct."""
    entries, _ = parse_log_file(mixed_log)
    result = analyze(entries)
    assert result.counts_by_level["DEBUG"] == 1
    assert result.counts_by_level["INFO"] == 2
    assert result.counts_by_level["WARNING"] == 1
    assert result.counts_by_level["ERROR"] == 4
    assert result.counts_by_level["CRITICAL"] == 1


def test_analyze_top_error_messages(mixed_log: Path) -> None:
    """Top 5 error messages returned sorted by frequency descending."""
    entries, _ = parse_log_file(mixed_log)
    result = analyze(entries)
    assert len(result.top_error_messages) <= 5
    msgs = [msg for msg, _ in result.top_error_messages]
    # "DB failed: timeout" appears 3 times — must be first
    assert result.top_error_messages[0][0] == "DB failed: timeout"
    assert result.top_error_messages[0][1] == 3
    assert "DB failed: connection refused" in msgs


def test_analyze_error_rate(mixed_log: Path) -> None:
    """Error rate is calculated as (ERROR+CRITICAL) / time_span_minutes."""
    entries, _ = parse_log_file(mixed_log)
    result = analyze(entries)
    # 5 error/critical entries over ~2.25 minutes
    assert result.error_rate_per_minute > 0
    assert result.time_span_minutes > 0


def test_analyze_error_density(errors_only_log: Path) -> None:
    """Correct top windows identified from errors-only log."""
    entries, _ = parse_log_file(errors_only_log)
    result = analyze(entries)
    assert len(result.error_density_windows) > 0
    windows = [w for w, _ in result.error_density_windows]
    assert "10:00" in windows or "10:01" in windows


def test_analyze_repeated_patterns(mixed_log: Path) -> None:
    """Only messages appearing 2+ times appear in repeated_patterns."""
    entries, _ = parse_log_file(mixed_log)
    result = analyze(entries)
    for _, count in result.repeated_patterns:
        assert count >= 2
    msgs = [msg for msg, _ in result.repeated_patterns]
    assert "DB failed: timeout" in msgs
    # "DB failed: connection refused" appears only once — must not be included
    assert "DB failed: connection refused" not in msgs


def test_analyze_empty_entries() -> None:
    """Handles empty entry list without crashing; returns zero values."""
    result = analyze([])
    assert result.total_entries == 0
    assert result.counts_by_level == {}
    assert result.top_error_messages == []
    assert result.error_rate_per_minute == 0.0
    assert result.time_span_minutes == 0.0
    assert result.error_density_windows == []
    assert result.repeated_patterns == []


# ---------------------------------------------------------------------------
# Output format tests
# ---------------------------------------------------------------------------


def test_format_json_valid(mixed_log: Path) -> None:
    """format_json returns valid JSON."""
    entries, malformed = parse_log_file(mixed_log)
    result = analyze(entries)
    output = format_json(result)
    parsed = json.loads(output)
    assert isinstance(parsed, dict)


def test_format_json_structure(mixed_log: Path) -> None:
    """format_json output contains expected top-level keys."""
    entries, malformed = parse_log_file(mixed_log)
    result = analyze(entries)
    parsed = json.loads(format_json(result))
    assert "counts_by_level" in parsed
    assert "top_error_messages" in parsed
    assert "error_rate_per_minute" in parsed
    assert "total_entries" in parsed
    assert "malformed_lines" in parsed


def test_format_table_no_exception(
    mixed_log: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """format_table runs without raising an exception."""
    from src.tools.logparser import format_table

    entries, _ = parse_log_file(mixed_log)
    result = analyze(entries)
    # Should not raise
    format_table(result)


# ---------------------------------------------------------------------------
# CLI integration tests
# ---------------------------------------------------------------------------


def _run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    """Helper to run the CLI as a subprocess."""
    return subprocess.run(
        [sys.executable, "-m", "src.tools.logparser", *args],
        capture_output=True,
        text=True,
    )


def test_cli_default_format(mixed_log: Path) -> None:
    """CLI with no --format flag exits 0."""
    result = _run_cli(str(mixed_log))
    assert result.returncode == 0


def test_cli_json_format(mixed_log: Path) -> None:
    """CLI --format json returns valid JSON and exits 0."""
    result = _run_cli(str(mixed_log), "--format", "json")
    assert result.returncode == 0
    parsed = json.loads(result.stdout)
    assert "counts_by_level" in parsed


def test_cli_table_format(mixed_log: Path) -> None:
    """CLI --format table exits 0."""
    result = _run_cli(str(mixed_log), "--format", "table")
    assert result.returncode == 0


def test_cli_missing_file(tmp_path: Path) -> None:
    """CLI exits 1 with a helpful message when the file is missing."""
    result = _run_cli(str(tmp_path / "nonexistent.log"))
    assert result.returncode == 1
    assert "not found" in result.stderr.lower() or "error" in result.stderr.lower()


def test_cli_malformed_file(malformed_log: Path) -> None:
    """CLI exits 0 even when the log contains malformed lines (partial parse)."""
    result = _run_cli(str(malformed_log), "--format", "json")
    assert result.returncode == 0
    parsed = json.loads(result.stdout)
    assert parsed["total_entries"] == 3
