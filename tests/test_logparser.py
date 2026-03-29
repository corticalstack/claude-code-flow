"""Tests for src.tools.logparser."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import pytest

from src.tools.logparser import (
    AnalysisResult,
    LogEntry,
    analyze_entries,
    format_json,
    main,
    parse_log_file,
    parse_log_line,
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
2026-02-10 10:01:00 [INFO] Reconnecting
2026-02-10 10:01:05 [ERROR] Database connection failed: timeout
"""

ERRORS_ONLY_LOG_CONTENT = """\
2026-02-10 10:00:16 [ERROR] Disk full
2026-02-10 10:00:20 [ERROR] Disk full
2026-02-10 10:00:25 [CRITICAL] System crash
"""

EMPTY_LOG_CONTENT = ""

MALFORMED_LOG_CONTENT = """\
this is not a log line
2026-02-10 10:00:00 [INFO] Good line
BADLEVEL 2026-02-10 foo bar
2026-02-10 10:00:01 [BADLEVEL] unknown level
2026-02-10 10:00:02 [ERROR] Another good line
"""


@pytest.fixture
def mixed_log_file(tmp_path: Path) -> Path:
    """Fixture providing a log file with mixed levels."""
    p = tmp_path / "mixed.log"
    p.write_text(MIXED_LOG_CONTENT, encoding="utf-8")
    return p


@pytest.fixture
def errors_only_log_file(tmp_path: Path) -> Path:
    """Fixture providing a log file with error entries only."""
    p = tmp_path / "errors.log"
    p.write_text(ERRORS_ONLY_LOG_CONTENT, encoding="utf-8")
    return p


@pytest.fixture
def empty_log_file(tmp_path: Path) -> Path:
    """Fixture providing an empty log file."""
    p = tmp_path / "empty.log"
    p.write_text(EMPTY_LOG_CONTENT, encoding="utf-8")
    return p


@pytest.fixture
def malformed_log_file(tmp_path: Path) -> Path:
    """Fixture providing a log file with malformed lines."""
    p = tmp_path / "malformed.log"
    p.write_text(MALFORMED_LOG_CONTENT, encoding="utf-8")
    return p


# ---------------------------------------------------------------------------
# parse_log_line tests
# ---------------------------------------------------------------------------


class TestParseLogLine:
    """Tests for parse_log_line function."""

    def test_valid_info_line(self) -> None:
        entry = parse_log_line("2026-02-10 10:00:00 [INFO] Application started")
        assert entry is not None
        assert entry.level == "INFO"
        assert entry.message == "Application started"
        assert entry.timestamp == datetime(2026, 2, 10, 10, 0, 0)

    def test_valid_error_line(self) -> None:
        entry = parse_log_line("2026-02-10 10:00:16 [ERROR] Database connection failed: timeout")
        assert entry is not None
        assert entry.level == "ERROR"
        assert entry.message == "Database connection failed: timeout"

    def test_valid_critical_line(self) -> None:
        entry = parse_log_line("2026-02-10 10:00:30 [CRITICAL] Service unavailable")
        assert entry is not None
        assert entry.level == "CRITICAL"

    def test_valid_debug_line(self) -> None:
        entry = parse_log_line("2026-02-10 10:00:15 [DEBUG] Loading configuration")
        assert entry is not None
        assert entry.level == "DEBUG"

    def test_valid_warning_line(self) -> None:
        entry = parse_log_line("2026-02-10 10:00:20 [WARNING] Retrying connection")
        assert entry is not None
        assert entry.level == "WARNING"

    def test_malformed_returns_none(self) -> None:
        assert parse_log_line("this is not a log line") is None

    def test_unknown_level_returns_none(self) -> None:
        assert parse_log_line("2026-02-10 10:00:00 [BADLEVEL] message") is None

    def test_empty_string_returns_none(self) -> None:
        assert parse_log_line("") is None

    def test_missing_brackets_returns_none(self) -> None:
        assert parse_log_line("2026-02-10 10:00:00 INFO message") is None

    def test_leading_trailing_whitespace(self) -> None:
        entry = parse_log_line("  2026-02-10 10:00:00 [INFO] Application started  ")
        assert entry is not None
        assert entry.level == "INFO"


# ---------------------------------------------------------------------------
# parse_log_file tests
# ---------------------------------------------------------------------------


class TestParseLogFile:
    """Tests for parse_log_file function."""

    def test_mixed_log_file(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        assert len(entries) == 8
        assert malformed == 0

    def test_errors_only_log_file(self, errors_only_log_file: Path) -> None:
        entries, malformed = parse_log_file(errors_only_log_file)
        assert len(entries) == 3
        assert malformed == 0

    def test_empty_log_file(self, empty_log_file: Path) -> None:
        entries, malformed = parse_log_file(empty_log_file)
        assert entries == []
        assert malformed == 0

    def test_malformed_log_file(self, malformed_log_file: Path) -> None:
        entries, malformed = parse_log_file(malformed_log_file)
        # "this is not a log line", "BADLEVEL 2026-02-10 foo bar",
        # "2026-02-10 10:00:01 [BADLEVEL] unknown level" are malformed
        assert malformed == 3
        assert len(entries) == 2


# ---------------------------------------------------------------------------
# analyze_entries tests
# ---------------------------------------------------------------------------


class TestAnalyzeEntries:
    """Tests for analyze_entries function."""

    def test_empty_entries(self) -> None:
        result = analyze_entries([], malformed_lines=0)
        assert result.total_entries == 0
        assert result.level_counts == {}
        assert result.top_errors == []
        assert result.error_rate == 0.0
        assert result.peak_error_period is None

    def test_level_counts(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        assert result.level_counts["INFO"] == 2
        assert result.level_counts["DEBUG"] == 1
        assert result.level_counts["WARNING"] == 1
        assert result.level_counts["ERROR"] == 3
        assert result.level_counts["CRITICAL"] == 1

    def test_top_errors(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        # "Database connection failed: timeout" appears 3 times
        top = dict(result.top_errors)
        assert top.get("Database connection failed: timeout") == 3

    def test_top_errors_max_five(self) -> None:
        entries = [
            LogEntry(datetime(2026, 1, 1, 0, 0, i), "ERROR", f"Error {i}") for i in range(10)
        ]
        result = analyze_entries(entries, malformed_lines=0)
        assert len(result.top_errors) <= 5

    def test_error_rate_calculation(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        # Time span from 10:00:00 to 10:01:05 = 65 seconds = 65/60 minutes
        # Errors: 3 ERROR + 1 CRITICAL = 4
        expected_rate = 4 / (65 / 60)
        assert abs(result.error_rate - expected_rate) < 0.01

    def test_error_rate_zero_for_no_errors(self) -> None:
        entries = [
            LogEntry(datetime(2026, 1, 1, 0, 0, 0), "INFO", "start"),
            LogEntry(datetime(2026, 1, 1, 0, 1, 0), "DEBUG", "debug"),
        ]
        result = analyze_entries(entries, malformed_lines=0)
        assert result.error_rate == 0.0

    def test_peak_error_period(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        # 3 errors in 10:00, 1 in 10:01
        assert result.peak_error_period == "2026-02-10 10:00"

    def test_repeated_patterns_detected(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        repeated_msgs = {msg for msg, _ in result.repeated_patterns}
        assert "Database connection failed: timeout" in repeated_msgs

    def test_malformed_lines_count(self, malformed_log_file: Path) -> None:
        entries, malformed = parse_log_file(malformed_log_file)
        result = analyze_entries(entries, malformed)
        assert result.malformed_lines == 3

    def test_single_entry_no_time_span(self) -> None:
        entries = [LogEntry(datetime(2026, 1, 1, 0, 0, 0), "ERROR", "boom")]
        result = analyze_entries(entries, malformed_lines=0)
        assert result.time_span_minutes == 0.0
        # Still should report error rate as total errors
        assert result.error_rate == 1.0


# ---------------------------------------------------------------------------
# format_json tests
# ---------------------------------------------------------------------------


class TestFormatJson:
    """Tests for format_json function."""

    def test_json_output_is_valid(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        output = format_json(result)
        data = json.loads(output)
        assert "summary" in data
        assert "level_counts" in data
        assert "top_errors" in data
        assert "repeated_patterns" in data
        assert "peak_error_period" in data

    def test_json_summary_fields(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        output = format_json(result)
        data = json.loads(output)
        summary = data["summary"]
        assert summary["total_entries"] == 8
        assert summary["malformed_lines"] == 0
        assert "time_span_minutes" in summary
        assert "error_rate_per_minute" in summary

    def test_json_empty_result(self) -> None:
        result = AnalysisResult()
        output = format_json(result)
        data = json.loads(output)
        assert data["summary"]["total_entries"] == 0
        assert data["top_errors"] == []

    def test_json_top_errors_structure(self, mixed_log_file: Path) -> None:
        entries, malformed = parse_log_file(mixed_log_file)
        result = analyze_entries(entries, malformed)
        output = format_json(result)
        data = json.loads(output)
        for item in data["top_errors"]:
            assert "message" in item
            assert "count" in item


# ---------------------------------------------------------------------------
# CLI (main) tests
# ---------------------------------------------------------------------------


class TestMain:
    """Tests for the main() CLI entry point."""

    def test_missing_file_returns_error(self, tmp_path: Path) -> None:
        exit_code = main([str(tmp_path / "nonexistent.log")])
        assert exit_code == 1

    def test_json_output_success(
        self, mixed_log_file: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        exit_code = main([str(mixed_log_file), "--format", "json"])
        assert exit_code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert data["summary"]["total_entries"] == 8

    def test_default_format_is_json(
        self, mixed_log_file: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        exit_code = main([str(mixed_log_file)])
        assert exit_code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert "summary" in data

    def test_empty_log_file_succeeds(
        self, empty_log_file: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        exit_code = main([str(empty_log_file), "--format", "json"])
        assert exit_code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert data["summary"]["total_entries"] == 0

    def test_malformed_lines_reported(
        self, malformed_log_file: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        exit_code = main([str(malformed_log_file), "--format", "json"])
        assert exit_code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert data["summary"]["malformed_lines"] == 3

    def test_errors_only_log(
        self, errors_only_log_file: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        exit_code = main([str(errors_only_log_file), "--format", "json"])
        assert exit_code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert data["summary"]["total_entries"] == 3
        assert data["level_counts"].get("ERROR") == 2
        assert data["level_counts"].get("CRITICAL") == 1
