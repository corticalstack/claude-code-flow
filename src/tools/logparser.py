"""Python log parser CLI that analyzes error patterns in structured log files."""

import argparse
import dataclasses
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

LOG_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$")


@dataclass
class LogEntry:
    """A single parsed log line.

    Attributes:
        timestamp: The datetime of the log entry.
        level: The log level (e.g. DEBUG, INFO, WARNING, ERROR, CRITICAL).
        message: The log message text.
    """

    timestamp: datetime
    level: str
    message: str


@dataclass
class AnalysisResult:
    """The result of analyzing a collection of log entries.

    Attributes:
        total_entries: Total number of successfully parsed entries.
        counts_by_level: Mapping from log level to count.
        top_error_messages: Top 5 error/critical messages with their counts.
        error_rate_per_minute: Rate of ERROR+CRITICAL entries per minute.
        error_density_windows: Top 5 one-minute windows by error count.
        repeated_patterns: Error messages appearing 2 or more times.
        time_span_minutes: Total time span of entries in minutes.
        malformed_lines: Number of lines that could not be parsed.
    """

    total_entries: int
    counts_by_level: dict[str, int]
    top_error_messages: list[tuple[str, int]]
    error_rate_per_minute: float
    error_density_windows: list[tuple[str, int]]
    repeated_patterns: list[tuple[str, int]]
    time_span_minutes: float
    malformed_lines: int


def parse_log_file(path: Path) -> tuple[list[LogEntry], int]:
    """Parse a structured log file into a list of LogEntry objects.

    Args:
        path: Path to the log file to parse.

    Returns:
        A tuple of (entries, malformed_count) where entries is the list of
        successfully parsed LogEntry objects and malformed_count is the number
        of lines that could not be parsed.

    Raises:
        FileNotFoundError: If the path does not exist.
    """
    entries: list[LogEntry] = []
    malformed_count = 0

    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            match = LOG_PATTERN.match(line)
            if match:
                timestamp_str, level, message = match.groups()
                try:
                    timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    malformed_count += 1
                    print(f"WARNING: malformed timestamp: {line!r}", file=sys.stderr)
                    continue
                entries.append(
                    LogEntry(timestamp=timestamp, level=level, message=message)
                )
            else:
                malformed_count += 1
                print(f"WARNING: malformed line: {line!r}", file=sys.stderr)

    return entries, malformed_count


def analyze(entries: list[LogEntry]) -> AnalysisResult:
    """Analyze a list of log entries for error patterns.

    Args:
        entries: The list of LogEntry objects to analyze.

    Returns:
        An AnalysisResult containing counts, error rate, density windows,
        and repeated patterns.
    """
    counts_by_level: dict[str, int] = dict(Counter(e.level for e in entries))

    error_entries = [e for e in entries if e.level in ("ERROR", "CRITICAL")]
    error_messages = [e.message for e in error_entries]

    message_counter: Counter[str] = Counter(error_messages)
    top_error_messages: list[tuple[str, int]] = message_counter.most_common(5)

    if len(entries) >= 2:
        timestamps = [e.timestamp for e in entries]
        delta = (max(timestamps) - min(timestamps)).total_seconds()
        time_span_minutes = delta / 60.0
    else:
        time_span_minutes = 0.0

    if time_span_minutes > 0:
        error_rate_per_minute = len(error_entries) / time_span_minutes
    else:
        error_rate_per_minute = 0.0

    minute_buckets: Counter[str] = Counter(
        e.timestamp.strftime("%H:%M") for e in error_entries
    )
    error_density_windows: list[tuple[str, int]] = minute_buckets.most_common(5)

    repeated_patterns: list[tuple[str, int]] = [
        (msg, count) for msg, count in message_counter.most_common() if count >= 2
    ]

    return AnalysisResult(
        total_entries=len(entries),
        counts_by_level=counts_by_level,
        top_error_messages=top_error_messages,
        error_rate_per_minute=error_rate_per_minute,
        error_density_windows=error_density_windows,
        repeated_patterns=repeated_patterns,
        time_span_minutes=time_span_minutes,
        malformed_lines=0,
    )


def format_json(result: AnalysisResult) -> str:
    """Serialize an AnalysisResult to a pretty-printed JSON string.

    Args:
        result: The AnalysisResult to serialize.

    Returns:
        A JSON string representation of the result.
    """
    raw = dataclasses.asdict(result)
    # dataclasses.asdict converts tuples to lists, which is correct for JSON
    return json.dumps(raw, indent=2)


def format_table(result: AnalysisResult) -> None:
    """Print an AnalysisResult as rich tables to stdout.

    Args:
        result: The AnalysisResult to display.
    """
    console = Console()

    level_table = Table(title="Log Counts by Level")
    level_table.add_column("Level", style="bold")
    level_table.add_column("Count", justify="right")
    for level, count in sorted(result.counts_by_level.items()):
        level_table.add_row(level, str(count))
    console.print(level_table)

    error_table = Table(title="Top Error Messages")
    error_table.add_column("Message")
    error_table.add_column("Count", justify="right")
    for msg, count in result.top_error_messages:
        error_table.add_row(msg, str(count))
    console.print(error_table)

    density_table = Table(title="Error Density Windows (Top 5 Minutes)")
    density_table.add_column("Minute")
    density_table.add_column("Error Count", justify="right")
    for window, count in result.error_density_windows:
        density_table.add_row(window, str(count))
    console.print(density_table)

    summary = (
        f"Total entries: {result.total_entries}  |  "
        f"Malformed lines: {result.malformed_lines}  |  "
        f"Error rate: {result.error_rate_per_minute:.2f}/min  |  "
        f"Time span: {result.time_span_minutes:.2f} min"
    )
    console.print(Panel(summary, title="Summary"))


def main() -> None:
    """Entry point for the log parser CLI.

    Parses command-line arguments, reads the log file, analyzes entries,
    and prints results in the requested format. Exits with code 1 on error.
    """
    parser = argparse.ArgumentParser(
        description="Analyze error patterns in structured log files."
    )
    parser.add_argument("log_file", help="Path to the log file to analyze.")
    parser.add_argument(
        "--format",
        choices=["json", "table"],
        default="table",
        help="Output format: json or table (default: table).",
    )
    args = parser.parse_args()

    log_path = Path(args.log_file)
    if not log_path.exists():
        print(f"Error: file not found: {log_path}", file=sys.stderr)
        sys.exit(1)

    entries, malformed_count = parse_log_file(log_path)
    result = analyze(entries)
    result = dataclasses.replace(result, malformed_lines=malformed_count)

    if args.format == "json":
        print(format_json(result))
    else:
        format_table(result)

    sys.exit(0)


if __name__ == "__main__":
    main()
