"""Log parser CLI tool that analyzes error patterns in log files.

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

try:
    from rich.console import Console
    from rich.table import Table

    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

LOG_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$")

VALID_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
ERROR_LEVELS = {"ERROR", "CRITICAL"}


@dataclass
class LogEntry:
    """A single parsed log entry.

    Attributes:
        timestamp: Datetime of the log entry.
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL).
        message: Log message text.
    """

    timestamp: datetime
    level: str
    message: str


@dataclass
class AnalysisResult:
    """Result of log file analysis.

    Attributes:
        total_entries: Total number of parsed log entries.
        level_counts: Count of entries per log level.
        top_errors: Top 5 most common error messages with counts.
        error_rate: Errors per minute over the log time span.
        peak_error_period: Time period (minute) with the most errors.
        repeated_patterns: Error messages that appear more than once.
        malformed_lines: Number of lines that could not be parsed.
        time_span_minutes: Total duration in minutes of the log.
    """

    total_entries: int = 0
    level_counts: dict[str, int] = field(default_factory=dict)
    top_errors: list[tuple[str, int]] = field(default_factory=list)
    error_rate: float = 0.0
    peak_error_period: str | None = None
    repeated_patterns: list[tuple[str, int]] = field(default_factory=list)
    malformed_lines: int = 0
    time_span_minutes: float = 0.0


def parse_log_line(line: str) -> LogEntry | None:
    """Parse a single log line into a LogEntry.

    Args:
        line: Raw log line string.

    Returns:
        LogEntry if line matches expected format, None otherwise.
    """
    match = LOG_PATTERN.match(line.strip())
    if not match:
        return None
    timestamp_str, level, message = match.groups()
    try:
        timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None
    if level not in VALID_LEVELS:
        return None
    return LogEntry(timestamp=timestamp, level=level, message=message)


def parse_log_file(file_path: Path) -> tuple[list[LogEntry], int]:
    """Parse all log entries from a file.

    Args:
        file_path: Path to the log file.

    Returns:
        Tuple of (list of LogEntry, count of malformed lines).
    """
    entries: list[LogEntry] = []
    malformed = 0
    with file_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = parse_log_line(line)
            if entry is None:
                malformed += 1
            else:
                entries.append(entry)
    return entries, malformed


def analyze_entries(entries: list[LogEntry], malformed_lines: int) -> AnalysisResult:
    """Analyze log entries and produce statistics.

    Args:
        entries: List of parsed LogEntry objects.
        malformed_lines: Count of lines that could not be parsed.

    Returns:
        AnalysisResult with all computed statistics.
    """
    result = AnalysisResult(
        total_entries=len(entries),
        malformed_lines=malformed_lines,
    )

    if not entries:
        return result

    # Count by level
    level_counts: Counter[str] = Counter(e.level for e in entries)
    result.level_counts = dict(level_counts)

    # Error messages
    error_messages = [e.message for e in entries if e.level in ERROR_LEVELS]
    error_counter: Counter[str] = Counter(error_messages)
    result.top_errors = error_counter.most_common(5)
    result.repeated_patterns = [
        (msg, cnt) for msg, cnt in error_counter.items() if cnt > 1
    ]

    # Time span
    timestamps = [e.timestamp for e in entries]
    first_ts = min(timestamps)
    last_ts = max(timestamps)
    delta_seconds = (last_ts - first_ts).total_seconds()
    result.time_span_minutes = delta_seconds / 60.0 if delta_seconds > 0 else 0.0

    # Error rate (errors per minute)
    total_errors = sum(1 for e in entries if e.level in ERROR_LEVELS)
    if result.time_span_minutes > 0:
        result.error_rate = total_errors / result.time_span_minutes
    elif total_errors > 0:
        result.error_rate = float(total_errors)

    # Peak error period (by minute bucket)
    minute_errors: dict[str, int] = defaultdict(int)
    for entry in entries:
        if entry.level in ERROR_LEVELS:
            bucket = entry.timestamp.strftime("%Y-%m-%d %H:%M")
            minute_errors[bucket] += 1

    if minute_errors:
        result.peak_error_period = max(minute_errors, key=lambda k: minute_errors[k])

    return result


def format_json(result: AnalysisResult) -> str:
    """Format analysis result as JSON.

    Args:
        result: AnalysisResult to format.

    Returns:
        JSON string representation.
    """
    data = {
        "summary": {
            "total_entries": result.total_entries,
            "malformed_lines": result.malformed_lines,
            "time_span_minutes": round(result.time_span_minutes, 2),
            "error_rate_per_minute": round(result.error_rate, 4),
        },
        "level_counts": result.level_counts,
        "top_errors": [
            {"message": msg, "count": cnt} for msg, cnt in result.top_errors
        ],
        "repeated_patterns": [
            {"message": msg, "count": cnt} for msg, cnt in result.repeated_patterns
        ],
        "peak_error_period": result.peak_error_period,
    }
    return json.dumps(data, indent=2)


def format_table(result: AnalysisResult) -> None:
    """Print analysis result as rich tables to stdout.

    Args:
        result: AnalysisResult to format.
    """
    if not RICH_AVAILABLE:
        print(
            "Error: 'rich' library is required for table output. Install with: pip install rich",
            file=sys.stderr,
        )
        sys.exit(1)

    console = Console()

    # Summary table
    summary_table = Table(title="Log Analysis Summary", show_header=True)
    summary_table.add_column("Metric", style="cyan")
    summary_table.add_column("Value", style="green")
    summary_table.add_row("Total Entries", str(result.total_entries))
    summary_table.add_row("Malformed Lines", str(result.malformed_lines))
    summary_table.add_row("Time Span (minutes)", f"{result.time_span_minutes:.2f}")
    summary_table.add_row("Error Rate (per minute)", f"{result.error_rate:.4f}")
    summary_table.add_row("Peak Error Period", result.peak_error_period or "N/A")
    console.print(summary_table)

    # Level counts table
    if result.level_counts:
        level_table = Table(title="Entries by Log Level", show_header=True)
        level_table.add_column("Level", style="cyan")
        level_table.add_column("Count", style="yellow")
        level_order = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        for level in level_order:
            if level in result.level_counts:
                level_table.add_row(level, str(result.level_counts[level]))
        console.print(level_table)

    # Top errors table
    if result.top_errors:
        errors_table = Table(title="Top Error Messages (Top 5)", show_header=True)
        errors_table.add_column("Message", style="red")
        errors_table.add_column("Count", style="yellow")
        for msg, cnt in result.top_errors:
            errors_table.add_row(msg, str(cnt))
        console.print(errors_table)

    # Repeated patterns table
    if result.repeated_patterns:
        patterns_table = Table(title="Repeated Error Patterns", show_header=True)
        patterns_table.add_column("Pattern", style="magenta")
        patterns_table.add_column("Occurrences", style="yellow")
        for msg, cnt in sorted(result.repeated_patterns, key=lambda x: -x[1]):
            patterns_table.add_row(msg, str(cnt))
        console.print(patterns_table)


def main(argv: list[str] | None = None) -> int:
    """Entry point for the log parser CLI.

    Args:
        argv: Command line arguments (defaults to sys.argv[1:]).

    Returns:
        Exit code (0 = success, 1 = error).
    """
    parser = argparse.ArgumentParser(
        description="Parse log files and analyze error patterns.",
        prog="python -m src.tools.logparser",
    )
    parser.add_argument("log_file", help="Path to the log file to analyze")
    parser.add_argument(
        "--format",
        choices=["json", "table"],
        default="json",
        help="Output format: json (default) or table",
    )

    args = parser.parse_args(argv)

    log_path = Path(args.log_file)
    if not log_path.exists():
        print(f"Error: File not found: {log_path}", file=sys.stderr)
        return 1
    if not log_path.is_file():
        print(f"Error: Not a file: {log_path}", file=sys.stderr)
        return 1

    try:
        entries, malformed = parse_log_file(log_path)
    except OSError as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        return 1

    result = analyze_entries(entries, malformed)

    if args.format == "json":
        print(format_json(result))
    else:
        format_table(result)

    return 0


if __name__ == "__main__":
    sys.exit(main())
