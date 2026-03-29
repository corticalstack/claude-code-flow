"""Python log parser CLI that analyzes error patterns in log files."""

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from rich.console import Console
from rich.table import Table

console = Console()


@dataclass
class LogEntry:
    """Represents a single parsed log entry.

    Attributes:
        timestamp: The datetime of the log entry.
        level: The log level (e.g., INFO, ERROR).
        message: The log message text.
    """

    timestamp: datetime
    level: str
    message: str


class LogParser:
    """Parses a log file into LogEntry objects.

    Expects lines in the format:
        YYYY-MM-DD HH:MM:SS [LEVEL] message
    """

    LOG_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$")
    VALID_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}

    def parse_file(self, path: Path) -> tuple[list[LogEntry], int]:
        """Parse a log file and return entries with malformed line count.

        Args:
            path: Path to the log file.

        Returns:
            A tuple of (list of LogEntry, count of malformed lines).

        Raises:
            FileNotFoundError: If the file does not exist.
        """
        if not path.exists():
            raise FileNotFoundError(f"Log file not found: {path}")

        entries: list[LogEntry] = []
        malformed_count = 0

        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            match = self.LOG_PATTERN.match(line)
            if match:
                timestamp_str, level, message = match.groups()
                try:
                    timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
                    entries.append(LogEntry(timestamp=timestamp, level=level, message=message))
                except ValueError:
                    malformed_count += 1
            else:
                malformed_count += 1

        return entries, malformed_count


class LogAnalyzer:
    """Analyzes a list of LogEntry objects for patterns and statistics."""

    ERROR_LEVELS = {"ERROR", "CRITICAL"}

    def count_by_level(self, entries: list[LogEntry]) -> dict[str, int]:
        """Count log entries by level.

        Args:
            entries: List of log entries to analyze.

        Returns:
            Dictionary mapping level name to count.
        """
        counter: Counter[str] = Counter(entry.level for entry in entries)
        return dict(counter)

    def top_error_messages(self, entries: list[LogEntry], n: int = 5) -> list[tuple[str, int]]:
        """Return the top N most frequent error/critical messages.

        Args:
            entries: List of log entries to analyze.
            n: Maximum number of results to return.

        Returns:
            List of (message, count) tuples sorted by count descending.
        """
        error_messages = [
            entry.message for entry in entries if entry.level in self.ERROR_LEVELS
        ]
        counter: Counter[str] = Counter(error_messages)
        return counter.most_common(n)

    def error_rate(self, entries: list[LogEntry]) -> float:
        """Calculate error rate as errors per minute.

        Args:
            entries: List of log entries to analyze.

        Returns:
            Errors per minute, or 0.0 if span is less than 1 minute or no entries.
        """
        if not entries:
            return 0.0

        error_count = sum(1 for e in entries if e.level in self.ERROR_LEVELS)
        timestamps = [e.timestamp for e in entries]
        span_seconds = (max(timestamps) - min(timestamps)).total_seconds()
        total_minutes = span_seconds / 60.0

        if total_minutes < 1.0:
            return 0.0

        return error_count / total_minutes

    def highest_density_periods(
        self, entries: list[LogEntry], n: int = 3
    ) -> list[tuple[str, int]]:
        """Find the top N 1-minute windows with the most errors.

        Args:
            entries: List of log entries to analyze.
            n: Maximum number of periods to return.

        Returns:
            List of (minute_bucket, count) tuples sorted by count descending.
        """
        buckets: Counter[str] = Counter()
        for entry in entries:
            if entry.level in self.ERROR_LEVELS:
                bucket = entry.timestamp.strftime("%Y-%m-%d %H:%M")
                buckets[bucket] += 1
        return buckets.most_common(n)

    def detect_patterns(self, entries: list[LogEntry]) -> list[tuple[str, int]]:
        """Detect repeated error message patterns by normalizing messages.

        Strips trailing hex UUIDs, numbers, and IPs from messages before grouping.

        Args:
            entries: List of log entries to analyze.

        Returns:
            List of (normalized_pattern, count) for patterns appearing more than once.
        """
        normalize_re = re.compile(
            r"(\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"
            r"|\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"
            r"|\b\d+\b)",
            re.IGNORECASE,
        )

        pattern_counts: Counter[str] = Counter()
        for entry in entries:
            if entry.level in self.ERROR_LEVELS:
                normalized = normalize_re.sub("<N>", entry.message).strip()
                normalized = re.sub(r"<N>(\s*<N>)+", "<N>", normalized)
                pattern_counts[normalized] += 1

        return [(pattern, count) for pattern, count in pattern_counts.items() if count > 1]


class OutputFormatter:
    """Renders analysis results to JSON or rich table format."""

    def _datetime_default(self, obj: Any) -> Any:
        if isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

    def to_json(self, entries: list[LogEntry], analysis: dict[str, Any]) -> str:
        """Serialize entries and analysis to a JSON string.

        Args:
            entries: List of log entries.
            analysis: Dictionary of analysis results.

        Returns:
            Pretty-printed JSON string.
        """
        data = {
            "entries": [
                {**asdict(e), "timestamp": e.timestamp.isoformat()} for e in entries
            ],
            "analysis": analysis,
        }
        return json.dumps(data, indent=2, default=self._datetime_default)

    def to_table(self, entries: list[LogEntry], analysis: dict[str, Any]) -> None:
        """Print analysis results as rich tables to stdout.

        Args:
            entries: List of log entries.
            analysis: Dictionary of analysis results.
        """
        console.print(f"\n[bold]Log Analysis Report[/bold] — {len(entries)} entries parsed\n")

        level_table = Table(title="Log Level Counts", show_header=True)
        level_table.add_column("Level", style="cyan")
        level_table.add_column("Count", justify="right")
        for level, count in sorted(analysis["level_counts"].items()):
            level_table.add_row(level, str(count))
        console.print(level_table)

        console.print(f"\n[bold]Error Rate:[/bold] {analysis['error_rate']:.2f} errors/minute")

        if analysis["top_errors"]:
            error_table = Table(title="Top Error Messages", show_header=True)
            error_table.add_column("Message", style="red")
            error_table.add_column("Count", justify="right")
            for msg, count in analysis["top_errors"]:
                error_table.add_row(msg, str(count))
            console.print(error_table)

        if analysis["density_periods"]:
            density_table = Table(title="Highest Error Density Periods (1-min windows)")
            density_table.add_column("Period", style="yellow")
            density_table.add_column("Errors", justify="right")
            for period, count in analysis["density_periods"]:
                density_table.add_row(period, str(count))
            console.print(density_table)

        if analysis["patterns"]:
            pattern_table = Table(title="Repeated Error Patterns")
            pattern_table.add_column("Pattern", style="magenta")
            pattern_table.add_column("Count", justify="right")
            for pattern, count in analysis["patterns"]:
                pattern_table.add_row(pattern, str(count))
            console.print(pattern_table)


def main() -> None:
    """CLI entry point for the log parser.

    Usage:
        python -m src.tools.logparser <log_file> [--format json|table]
    """
    parser = argparse.ArgumentParser(description="Analyze error patterns in log files.")
    parser.add_argument("log_file", type=Path, help="Path to the log file to analyze.")
    parser.add_argument(
        "--format",
        choices=["json", "table"],
        default="table",
        help="Output format (default: table).",
    )
    args = parser.parse_args()

    log_path: Path = args.log_file
    if not log_path.exists():
        print(f"Error: file not found: {log_path}", file=sys.stderr)
        sys.exit(1)

    log_parser = LogParser()
    try:
        entries, malformed_count = log_parser.parse_file(log_path)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    if malformed_count > 0:
        print(
            f"Warning: {malformed_count} malformed line(s) skipped.", file=sys.stderr
        )

    analyzer = LogAnalyzer()
    analysis: dict[str, Any] = {
        "level_counts": analyzer.count_by_level(entries),
        "top_errors": analyzer.top_error_messages(entries),
        "error_rate": analyzer.error_rate(entries),
        "density_periods": analyzer.highest_density_periods(entries),
        "patterns": analyzer.detect_patterns(entries),
    }

    formatter = OutputFormatter()
    if args.format == "json":
        print(formatter.to_json(entries, analysis))
    else:
        formatter.to_table(entries, analysis)

    sys.exit(0)


if __name__ == "__main__":
    main()
