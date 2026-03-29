"""Log file parser CLI that analyzes error patterns.

Usage:
    python -m src.tools.logparser <log-file> [--format json|table]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import TextIO

_LEVELS = r"DEBUG|INFO|WARNING|ERROR|CRITICAL"
LOG_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(" + _LEVELS + r")\] (.+)$"
)

VALID_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
ERROR_LEVELS = {"ERROR", "CRITICAL"}


@dataclass
class LogEntry:
    """A single parsed log entry.

    Attributes:
        timestamp: Parsed datetime of the log entry.
        level: Log level string (DEBUG, INFO, WARNING, ERROR, CRITICAL).
        message: The log message text.
    """

    timestamp: datetime
    level: str
    message: str


@dataclass
class LogAnalysis:
    """Results of analyzing a log file.

    Attributes:
        total_entries: Total number of successfully parsed entries.
        malformed_count: Number of lines that could not be parsed.
        counts_by_level: Entry count per log level.
        top_errors: List of (message, count) tuples for most common errors.
        error_rate_per_minute: Errors per minute over the observed time window.
        peak_error_periods: List of (minute_str, error_count) for busiest minutes.
        repeated_errors: Messages that appear more than once at error/critical level.
    """

    total_entries: int = 0
    malformed_count: int = 0
    counts_by_level: dict[str, int] = field(default_factory=dict)
    top_errors: list[tuple[str, int]] = field(default_factory=list)
    error_rate_per_minute: float = 0.0
    peak_error_periods: list[tuple[str, int]] = field(default_factory=list)
    repeated_errors: list[tuple[str, int]] = field(default_factory=list)


def parse_log_line(line: str) -> LogEntry | None:
    """Parse a single log line into a LogEntry.

    Args:
        line: A raw log line string.

    Returns:
        A LogEntry if the line matches the expected format, otherwise None.
    """
    match = LOG_PATTERN.match(line.strip())
    if not match:
        return None
    ts_str, level, message = match.groups()
    try:
        timestamp = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None
    return LogEntry(timestamp=timestamp, level=level, message=message)


def analyze_logs(entries: list[LogEntry]) -> LogAnalysis:
    """Analyze a list of log entries for patterns and statistics.

    Args:
        entries: Parsed log entries to analyze.

    Returns:
        A LogAnalysis with counts, error rates, and pattern information.
    """
    analysis = LogAnalysis()
    analysis.total_entries = len(entries)

    level_counter: Counter[str] = Counter()
    error_messages: Counter[str] = Counter()
    errors_by_minute: dict[str, int] = defaultdict(int)
    first_ts: datetime | None = None
    last_ts: datetime | None = None

    for entry in entries:
        level_counter[entry.level] += 1
        if entry.level in ERROR_LEVELS:
            error_messages[entry.message] += 1
            minute_key = entry.timestamp.strftime("%Y-%m-%d %H:%M")
            errors_by_minute[minute_key] += 1

        if first_ts is None or entry.timestamp < first_ts:
            first_ts = entry.timestamp
        if last_ts is None or entry.timestamp > last_ts:
            last_ts = entry.timestamp

    analysis.counts_by_level = dict(level_counter)
    analysis.top_errors = error_messages.most_common(5)

    if first_ts and last_ts and first_ts != last_ts:
        duration_minutes = (last_ts - first_ts).total_seconds() / 60.0
        total_errors = sum(
            count for level, count in level_counter.items() if level in ERROR_LEVELS
        )
        analysis.error_rate_per_minute = (
            total_errors / duration_minutes if duration_minutes > 0 else 0.0
        )
    else:
        total_errors = sum(
            count for level, count in level_counter.items() if level in ERROR_LEVELS
        )
        analysis.error_rate_per_minute = float(total_errors)

    sorted_minutes = sorted(errors_by_minute.items(), key=lambda x: x[1], reverse=True)
    analysis.peak_error_periods = sorted_minutes[:5]

    analysis.repeated_errors = [
        (msg, count) for msg, count in error_messages.items() if count > 1
    ]

    return analysis


def read_log_file(path: Path) -> tuple[list[LogEntry], int]:
    """Read and parse all log entries from a file.

    Args:
        path: Path to the log file.

    Returns:
        A tuple of (parsed entries list, malformed line count).
    """
    entries: list[LogEntry] = []
    malformed = 0
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            if not line.strip():
                continue
            entry = parse_log_line(line)
            if entry is None:
                malformed += 1
            else:
                entries.append(entry)
    return entries, malformed


def format_json(analysis: LogAnalysis) -> str:
    """Render analysis results as JSON.

    Args:
        analysis: The computed log analysis.

    Returns:
        A formatted JSON string.
    """
    data = {
        "summary": {
            "total_entries": analysis.total_entries,
            "malformed_lines": analysis.malformed_count,
            "counts_by_level": analysis.counts_by_level,
            "error_rate_per_minute": round(analysis.error_rate_per_minute, 4),
        },
        "top_errors": [
            {"message": msg, "count": count} for msg, count in analysis.top_errors
        ],
        "peak_error_periods": [
            {"period": period, "error_count": count}
            for period, count in analysis.peak_error_periods
        ],
        "repeated_errors": [
            {"message": msg, "count": count} for msg, count in analysis.repeated_errors
        ],
    }
    return json.dumps(data, indent=2)


def format_table(analysis: LogAnalysis, out: TextIO = sys.stdout) -> None:
    """Render analysis results as a rich formatted table.

    Args:
        analysis: The computed log analysis.
        out: Output stream (defaults to stdout).
    """
    from rich.console import Console
    from rich.table import Table

    console = Console(file=out)

    console.print("\n[bold cyan]Log Analysis Summary[/bold cyan]")
    console.print(f"  Total entries   : {analysis.total_entries}")
    console.print(f"  Malformed lines : {analysis.malformed_count}")
    console.print(
        f"  Error rate      : {analysis.error_rate_per_minute:.4f} errors/min\n"
    )

    level_table = Table(
        title="Entries by Level", show_header=True, header_style="bold magenta"
    )
    level_table.add_column("Level", style="cyan")
    level_table.add_column("Count", justify="right")
    for level in ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]:
        count = analysis.counts_by_level.get(level, 0)
        style = "red" if level in ERROR_LEVELS else ""
        level_table.add_row(level, str(count), style=style)
    console.print(level_table)

    if analysis.top_errors:
        error_table = Table(
            title="Top 5 Error Messages", show_header=True, header_style="bold red"
        )
        error_table.add_column("Message")
        error_table.add_column("Count", justify="right")
        for msg, count in analysis.top_errors:
            error_table.add_row(msg, str(count))
        console.print(error_table)

    if analysis.peak_error_periods:
        peak_table = Table(
            title="Peak Error Periods", show_header=True, header_style="bold yellow"
        )
        peak_table.add_column("Period")
        peak_table.add_column("Errors", justify="right")
        for period, count in analysis.peak_error_periods:
            peak_table.add_row(period, str(count))
        console.print(peak_table)

    if analysis.repeated_errors:
        repeat_table = Table(
            title="Repeated Errors (Patterns)",
            show_header=True,
            header_style="bold orange3",
        )
        repeat_table.add_column("Message")
        repeat_table.add_column("Occurrences", justify="right")
        for msg, count in analysis.repeated_errors:
            repeat_table.add_row(msg, str(count))
        console.print(repeat_table)


def build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser.

    Returns:
        Configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog="logparser",
        description="Parse log files and analyze error patterns.",
    )
    parser.add_argument(
        "log_file",
        type=Path,
        help="Path to the log file to analyze.",
    )
    parser.add_argument(
        "--format",
        choices=["json", "table"],
        default="table",
        help="Output format: json or table (default: table).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point for the log parser CLI.

    Args:
        argv: Optional argument list (defaults to sys.argv[1:]).

    Returns:
        Exit code: 0 on success, 1 on error.
    """
    parser = build_parser()
    args = parser.parse_args(argv)

    log_path: Path = args.log_file
    if not log_path.exists():
        print(f"Error: file not found: {log_path}", file=sys.stderr)
        return 1
    if not log_path.is_file():
        print(f"Error: not a file: {log_path}", file=sys.stderr)
        return 1

    try:
        entries, malformed_count = read_log_file(log_path)
    except OSError as exc:
        print(f"Error reading file: {exc}", file=sys.stderr)
        return 1

    analysis = analyze_logs(entries)
    analysis.malformed_count = malformed_count

    if args.format == "json":
        print(format_json(analysis))
    else:
        format_table(analysis)

    return 0


if __name__ == "__main__":
    sys.exit(main())
