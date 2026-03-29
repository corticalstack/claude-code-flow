"""Tests for src/tools/logparser.py."""

from __future__ import annotations

import json
from io import StringIO
from pathlib import Path

import pytest

from src.tools.logparser import (
    LogEntry,
    analyze_logs,
    build_parser,
    format_json,
    format_table,
    main,
    parse_log_line,
    read_log_file,
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

MIXED_LOG_CONTENT = """\
2026-02-10 10:00:00 [INFO] Application started
2026-02-10 10:00:15 [DEBUG] Loading configuration
2026-02-10 10:00:16 [ERROR] Database connection failed: timeout
2026-02-10 10:00:20 [WARNING] Retrying connection
2026-02-10 10:00:25 [ERROR] Database connection failed: timeout
2026-02-10 10:00:30 [CRITICAL] Service unavailable
2026-02-10 10:01:00 [INFO] Recovered
2026-02-10 10:01:05 [ERROR] Database connection failed: timeout
"""

ERRORS_ONLY_LOG_CONTENT = """\
2026-02-10 11:00:00 [ERROR] Disk full
2026-02-10 11:00:10 [ERROR] Disk full
2026-02-10 11:00:20 [CRITICAL] System crash
"""

EMPTY_LOG_CONTENT = ""

MALFORMED_LOG_CONTENT = """\
2026-02-10 10:00:00 [INFO] Valid line
this is not a valid log line
[ALSO INVALID]
2026-02-10 10:00:05 [DEBUG] Another valid line
"""


@pytest.fixture
def tmp_mixed_log(tmp_path: Path) -> Path:
    """Log file with mixed log levels."""
    p = tmp_path / "mixed.log"
    p.write_text(MIXED_LOG_CONTENT)
    return p


@pytest.fixture
def tmp_errors_only_log(tmp_path: Path) -> Path:
    """Log file containing only error/critical lines."""
    p = tmp_path / "errors.log"
    p.write_text(ERRORS_ONLY_LOG_CONTENT)
    return p


@pytest.fixture
def tmp_empty_log(tmp_path: Path) -> Path:
    """Empty log file."""
    p = tmp_path / "empty.log"
    p.write_text(EMPTY_LOG_CONTENT)
    return p


@pytest.fixture
def tmp_malformed_log(tmp_path: Path) -> Path:
    """Log file with some malformed lines."""
    p = tmp_path / "malformed.log"
    p.write_text(MALFORMED_LOG_CONTENT)
    return p


# ---------------------------------------------------------------------------
# parse_log_line
# ---------------------------------------------------------------------------


def test_parse_log_line_valid_info() -> None:
    entry = parse_log_line("2026-02-10 10:00:00 [INFO] Application started")
    assert entry is not None
    assert entry.level == "INFO"
    assert entry.message == "Application started"


def test_parse_log_line_valid_error() -> None:
    entry = parse_log_line(
        "2026-02-10 10:00:16 [ERROR] Database connection failed: timeout"
    )
    assert entry is not None
    assert entry.level == "ERROR"
    assert entry.message == "Database connection failed: timeout"


def test_parse_log_line_valid_critical() -> None:
    entry = parse_log_line("2026-02-10 10:00:30 [CRITICAL] Service unavailable")
    assert entry is not None
    assert entry.level == "CRITICAL"


def test_parse_log_line_invalid_returns_none() -> None:
    assert parse_log_line("this is not a valid log line") is None
    assert parse_log_line("[ALSO INVALID]") is None
    assert parse_log_line("") is None


def test_parse_log_line_all_levels() -> None:
    for level in ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]:
        line = f"2026-02-10 10:00:00 [{level}] test message"
        entry = parse_log_line(line)
        assert entry is not None
        assert entry.level == level


# ---------------------------------------------------------------------------
# read_log_file
# ---------------------------------------------------------------------------


def test_read_log_file_mixed(tmp_mixed_log: Path) -> None:
    entries, malformed = read_log_file(tmp_mixed_log)
    assert malformed == 0
    assert len(entries) == 8


def test_read_log_file_empty(tmp_empty_log: Path) -> None:
    entries, malformed = read_log_file(tmp_empty_log)
    assert entries == []
    assert malformed == 0


def test_read_log_file_malformed(tmp_malformed_log: Path) -> None:
    entries, malformed = read_log_file(tmp_malformed_log)
    assert malformed == 2
    assert len(entries) == 2


def test_read_log_file_errors_only(tmp_errors_only_log: Path) -> None:
    entries, malformed = read_log_file(tmp_errors_only_log)
    assert malformed == 0
    assert len(entries) == 3
    assert all(e.level in {"ERROR", "CRITICAL"} for e in entries)


# ---------------------------------------------------------------------------
# analyze_logs
# ---------------------------------------------------------------------------


def test_analyze_logs_counts_by_level(tmp_mixed_log: Path) -> None:
    entries, _ = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    assert analysis.counts_by_level.get("INFO", 0) == 2
    assert analysis.counts_by_level.get("DEBUG", 0) == 1
    assert analysis.counts_by_level.get("WARNING", 0) == 1
    assert analysis.counts_by_level.get("ERROR", 0) == 3
    assert analysis.counts_by_level.get("CRITICAL", 0) == 1


def test_analyze_logs_top_errors(tmp_mixed_log: Path) -> None:
    entries, _ = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    assert len(analysis.top_errors) <= 5
    # Most common error is "Database connection failed: timeout" (3 times)
    assert analysis.top_errors[0][0] == "Database connection failed: timeout"
    assert analysis.top_errors[0][1] == 3


def test_analyze_logs_repeated_errors(tmp_mixed_log: Path) -> None:
    entries, _ = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    repeated_msgs = [msg for msg, _ in analysis.repeated_errors]
    assert "Database connection failed: timeout" in repeated_msgs


def test_analyze_logs_error_rate(tmp_mixed_log: Path) -> None:
    entries, _ = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    assert analysis.error_rate_per_minute > 0


def test_analyze_logs_empty() -> None:
    analysis = analyze_logs([])
    assert analysis.total_entries == 0
    assert analysis.counts_by_level == {}
    assert analysis.top_errors == []
    assert analysis.error_rate_per_minute == 0.0


def test_analyze_logs_no_errors() -> None:
    entries = [
        LogEntry(
            timestamp=__import__("datetime").datetime(2026, 1, 1, 10, 0, 0),
            level="INFO",
            message="all good",
        )
    ]
    analysis = analyze_logs(entries)
    assert analysis.error_rate_per_minute == 0.0
    assert analysis.top_errors == []


def test_analyze_logs_peak_periods(tmp_errors_only_log: Path) -> None:
    entries, _ = read_log_file(tmp_errors_only_log)
    analysis = analyze_logs(entries)
    assert len(analysis.peak_error_periods) >= 1


# ---------------------------------------------------------------------------
# format_json
# ---------------------------------------------------------------------------


def test_format_json_structure(tmp_mixed_log: Path) -> None:
    entries, malformed = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    analysis.malformed_count = malformed
    output = format_json(analysis)
    data = json.loads(output)
    assert "summary" in data
    assert "top_errors" in data
    assert "peak_error_periods" in data
    assert "repeated_errors" in data
    assert data["summary"]["total_entries"] == 8
    assert data["summary"]["malformed_lines"] == 0


def test_format_json_empty_log(tmp_empty_log: Path) -> None:
    entries, malformed = read_log_file(tmp_empty_log)
    analysis = analyze_logs(entries)
    analysis.malformed_count = malformed
    output = format_json(analysis)
    data = json.loads(output)
    assert data["summary"]["total_entries"] == 0
    assert data["top_errors"] == []


# ---------------------------------------------------------------------------
# format_table
# ---------------------------------------------------------------------------


def test_format_table_runs_without_error(tmp_mixed_log: Path) -> None:
    entries, malformed = read_log_file(tmp_mixed_log)
    analysis = analyze_logs(entries)
    analysis.malformed_count = malformed
    buf = StringIO()
    format_table(analysis, out=buf)
    output = buf.getvalue()
    assert "Log Analysis Summary" in output or len(output) > 0


# ---------------------------------------------------------------------------
# main (CLI integration)
# ---------------------------------------------------------------------------


def test_main_default_format(tmp_mixed_log: Path) -> None:
    rc = main([str(tmp_mixed_log)])
    assert rc == 0


def test_main_json_format(
    tmp_mixed_log: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    rc = main([str(tmp_mixed_log), "--format", "json"])
    assert rc == 0
    captured = capsys.readouterr()
    data = json.loads(captured.out)
    assert data["summary"]["total_entries"] == 8


def test_main_table_format(tmp_mixed_log: Path) -> None:
    rc = main([str(tmp_mixed_log), "--format", "table"])
    assert rc == 0


def test_main_missing_file() -> None:
    rc = main(["/nonexistent/path/to/file.log"])
    assert rc == 1


def test_main_empty_log(
    tmp_empty_log: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    rc = main([str(tmp_empty_log), "--format", "json"])
    assert rc == 0
    captured = capsys.readouterr()
    data = json.loads(captured.out)
    assert data["summary"]["total_entries"] == 0


def test_main_malformed_log(
    tmp_malformed_log: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    rc = main([str(tmp_malformed_log), "--format", "json"])
    assert rc == 0
    captured = capsys.readouterr()
    data = json.loads(captured.out)
    assert data["summary"]["malformed_lines"] == 2


# ---------------------------------------------------------------------------
# build_parser
# ---------------------------------------------------------------------------


def test_build_parser_defaults() -> None:
    parser = build_parser()
    args = parser.parse_args(["sample.log"])
    assert args.format == "table"
    assert str(args.log_file) == "sample.log"


def test_build_parser_json_format() -> None:
    parser = build_parser()
    args = parser.parse_args(["sample.log", "--format", "json"])
    assert args.format == "json"
