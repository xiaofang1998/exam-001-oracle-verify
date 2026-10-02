#!/usr/bin/env python3
"""Standalone converter for the exam_001 log-analysis task.

Reads a Web server access log in Common Log Format and writes the report
described in instruction.md:

    === Top IP ===
    <ip>: <n> requests

    === Status Code Distribution ===
    <status>: <count>

Usage:
    oracle_convert.py [LOG_PATH] [REPORT_PATH]

LOG_PATH defaults to /data/access.log and REPORT_PATH to /output/report.txt,
which are the paths fixed by the task instructions.
"""

import re
import sys
from pathlib import Path

DEFAULT_LOG_PATH = "/data/access.log"
DEFAULT_REPORT_PATH = "/output/report.txt"

TOP_IP_HEADER = "=== Top IP ==="
STATUS_HEADER = "=== Status Code Distribution ==="

# Common Log Format:
#   IP - - [timestamp] "METHOD PATH PROTOCOL" STATUS [SIZE]
LOG_LINE_RE = re.compile(
    r'^(?P<ip>\S+)\s+\S+\s+\S+\s+\[[^\]]*\]\s+"[^"]*"\s+'
    r"(?P<status>[1-5][0-9][0-9])(?:\s+\S+)?\s*$"
)


def count_requests(text):
    """Return (per-IP request counts, per-status-code counts)."""
    ip_counts = {}
    status_counts = {}
    for line in text.splitlines():
        match = LOG_LINE_RE.match(line.strip())
        if match is None:
            continue
        ip = match.group("ip")
        status = match.group("status")
        ip_counts[ip] = ip_counts.get(ip, 0) + 1
        status_counts[status] = status_counts.get(status, 0) + 1
    return ip_counts, status_counts


def build_report(ip_counts, status_counts):
    """Render the report text. The result always ends with a newline."""
    lines = [TOP_IP_HEADER]

    if ip_counts:
        # Most requests first; ties are broken by IP so output is deterministic.
        best_ip = None
        best_count = -1
        for ip in sorted(ip_counts):
            count = ip_counts[ip]
            if count > best_count:
                best_ip = ip
                best_count = count
        lines.append("%s: %d requests" % (best_ip, best_count))

    lines.append("")
    lines.append(STATUS_HEADER)
    for status in sorted(status_counts):
        lines.append("%s: %d" % (status, status_counts[status]))

    return "\n".join(lines) + "\n"


def main(argv):
    log_path = Path(argv[1]) if len(argv) > 1 else Path(DEFAULT_LOG_PATH)
    report_path = Path(argv[2]) if len(argv) > 2 else Path(DEFAULT_REPORT_PATH)

    text = log_path.read_text(encoding="utf-8", errors="replace")
    ip_counts, status_counts = count_requests(text)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(build_report(ip_counts, status_counts), encoding="utf-8")

    print("Wrote %s (%d requests, %d distinct status codes)"
          % (report_path, sum(ip_counts.values()), len(status_counts)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
