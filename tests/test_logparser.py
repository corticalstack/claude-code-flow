"""Tests for src/tools/logparser.py."""

import json
import sys
from pathlib import Path

import pytest

from src.tools.logparser import (
    LogAnalyzer,
    LogEntry,
    LogParser,
    OutputFormatter,
    main,
)

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def valid_log_path() -> Path:
    return FIXTURES_DIR / "valid_mixed.log"


@pytest.fixture
def errors_only_path() -> Path:
    return FIXTURES_DIR / "errors_only.log"


@pytest.fixture
def empty_log_path() -> Path:
    return FIXTURES_DIR / "empty.log"


@pytest.fixture
def malformed_log_path() -> Path:
    return FIXTURES_DIR / "malformed.log"


class TestLogParser:
    def test_parse_valid_file_count(self, valid_log_path: Path) -> None:
        entries, malformed = LogParser().parse_file(valid_log_path)
        assert len(entries) == 10
        assert malformed == 0

    def test_parse_returns_correct_levels(self, valid_log_path: Path) -> None:
        entries, _ = LogParser().parse_file(valid_log_path)
        levels = [e.level for e in entries]
        assert levels.count("INFO") == 2
        assert levels.count("DEBUG") == 1
        assert levels.count("ERROR") == 4
        assert levels.count("WARNING") == 2
        assert levels.count("CRITICAL") == 1

    def test_parse_empty_file(self, empty_log_path: Path) -> None:
        entries, malformed = LogParser().parse_file(empty_log_path)
        assert entries == []
        assert malformed == 0

    def test_parse_malformed_lines_skipped(self, malformed_log_path: Path) -> None:
        entries, malformed = LogParser().parse_file(malformed_log_path)
        assert len(entries) == 2
        assert malformed == 3

    def test_parse_file_not_found_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            LogParser().parse_file(tmp_path / "nonexistent.log")


class TestLogAnalyzer:
    def _get_entries(self, path: Path) -> list[LogEntry]:
        entries, _ = LogParser().parse_file(path)
        return entries

    def test_count_by_level(self, valid_log_path: Path) -> None:
        entries = self._get_entries(valid_log_path)
        counts = LogAnalyzer().count_by_level(entries)
        assert counts["ERROR"] == 4
        assert counts["CRITICAL"] == 1
        assert counts["INFO"] == 2
        assert counts["WARNING"] == 2
        assert counts["DEBUG"] == 1

    def test_top_error_messages(self, valid_log_path: Path) -> None:
        entries = self._get_entries(valid_log_path)
        top = LogAnalyzer().top_error_messages(entries, n=5)
        assert len(top) >= 1
        messages = [msg for msg, _ in top]
        assert "Database connection failed: timeout" in messages
        top_msg, top_count = top[0]
        assert top_msg == "Database connection failed: timeout"
        assert top_count == 3

    def test_error_rate_calculation(self, valid_log_path: Path) -> None:
        entries = self._get_entries(valid_log_path)
        rate = LogAnalyzer().error_rate(entries)
        assert rate > 0.0

    def test_error_rate_empty(self) -> None:
        rate = LogAnalyzer().error_rate([])
        assert rate == 0.0

    def test_highest_density_periods(self, valid_log_path: Path) -> None:
        entries = self._get_entries(valid_log_path)
        periods = LogAnalyzer().highest_density_periods(entries, n=3)
        assert len(periods) >= 1
        _, top_count = periods[0]
        assert top_count >= 1

    def test_detect_patterns(self, valid_log_path: Path) -> None:
        entries = self._get_entries(valid_log_path)
        patterns = LogAnalyzer().detect_patterns(entries)
        assert len(patterns) >= 1
        pattern_texts = [p for p, _ in patterns]
        assert any("Database connection failed" in p for p in pattern_texts)


class TestOutputFormatter:
    def test_json_output_structure(self, valid_log_path: Path) -> None:
        entries, _ = LogParser().parse_file(valid_log_path)
        analyzer = LogAnalyzer()
        analysis = {
            "level_counts": analyzer.count_by_level(entries),
            "top_errors": analyzer.top_error_messages(entries),
            "error_rate": analyzer.error_rate(entries),
            "density_periods": analyzer.highest_density_periods(entries),
            "patterns": analyzer.detect_patterns(entries),
        }
        output = OutputFormatter().to_json(entries, analysis)
        data = json.loads(output)
        assert "entries" in data
        assert "analysis" in data
        assert len(data["entries"]) == 10
        assert "level_counts" in data["analysis"]

    def test_table_output_runs_without_error(self, valid_log_path: Path, capsys: pytest.CaptureFixture) -> None:  # noqa: E501
        entries, _ = LogParser().parse_file(valid_log_path)
        analyzer = LogAnalyzer()
        analysis = {
            "level_counts": analyzer.count_by_level(entries),
            "top_errors": analyzer.top_error_messages(entries),
            "error_rate": analyzer.error_rate(entries),
            "density_periods": analyzer.highest_density_periods(entries),
            "patterns": analyzer.detect_patterns(entries),
        }
        OutputFormatter().to_table(entries, analysis)


class TestCLI:
    def test_main_table_output(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        log_file = tmp_path / "test.log"
        log_file.write_text(
            "2026-01-15 10:00:00 [INFO] App started\n"
            "2026-01-15 10:01:00 [ERROR] Something failed\n"
        )
        monkeypatch.setattr(sys, "argv", ["logparser", str(log_file)])
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0

    def test_main_json_output(
        self, tmp_path: Path, capsys: pytest.CaptureFixture, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        log_file = tmp_path / "test.log"
        log_file.write_text(
            "2026-01-15 10:00:00 [INFO] App started\n"
            "2026-01-15 10:01:00 [ERROR] Something failed\n"
        )
        monkeypatch.setattr(sys, "argv", ["logparser", str(log_file), "--format", "json"])
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert "entries" in data
        assert "analysis" in data

    def test_main_missing_file_exits_1(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(sys, "argv", ["logparser", str(tmp_path / "nonexistent.log")])
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 1
