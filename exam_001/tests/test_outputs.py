"""Output tests for exam_001 (Web server access log analysis).

The graded artifact is ``/output/report.txt``. It must contain the two sections
described in instruction.md::

    === Top IP ===
    <ip>: <n> requests

    === Status Code Distribution ===
    <status>: <count>

The expected values below are the exact counts of the access log baked into
``environment/Dockerfile``.

This module is executed directly by ``tests/test.sh`` (``python3
/tests/test_outputs.py``) and is also a valid pytest module, so it can be run
with ``pytest /tests/test_outputs.py`` as well.
"""

from __future__ import annotations

import re
from pathlib import Path

REPORT_PATH = Path("/output/report.txt")

TOP_IP_HEADER = "=== Top IP ==="
STATUS_HEADER = "=== Status Code Distribution ==="

EXPECTED_TOP_IP = "192.168.1.100"
EXPECTED_TOP_IP_COUNT = 5
EXPECTED_STATUS_COUNTS = {"200": 6, "401": 1, "404": 2, "500": 1}

TOP_IP_LINE_RE = re.compile(r"^(\S+): (\d+) requests$")
STATUS_LINE_RE = re.compile(r"^(\d{3}): (\d+)$")


def _report_text() -> str:
    assert REPORT_PATH.exists(), "Missing report file: %s" % REPORT_PATH
    text = REPORT_PATH.read_text(encoding="utf-8", errors="replace")
    assert text.strip(), "Report file is empty: %s" % REPORT_PATH
    return text


def _report_lines() -> list[str]:
    # Tolerate CRLF line endings, which are easy to introduce by accident.
    return [line.rstrip("\r") for line in _report_text().split("\n")]


def _parse_sections() -> dict[str, list[str]]:
    """Map each ``=== ... ===`` header to the non-empty lines below it."""
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in _report_lines():
        stripped = line.strip()
        if stripped.startswith("===") and stripped.endswith("==="):
            current = stripped
            sections.setdefault(current, [])
        elif stripped and current is not None:
            sections[current].append(stripped)
    return sections


def test_report_exists_and_is_not_empty() -> None:
    """The solution must write /output/report.txt."""
    _report_text()


def test_top_ip_section_exists() -> None:
    """The report must contain the '=== Top IP ===' section."""
    assert TOP_IP_HEADER in _parse_sections(), (
        "Missing section %r in %s:\n%s" % (TOP_IP_HEADER, REPORT_PATH, _report_text())
    )


def test_top_ip_is_the_most_frequent_ip() -> None:
    """The Top IP section must name 192.168.1.100 with its 5 requests."""
    body = _parse_sections().get(TOP_IP_HEADER, [])
    assert len(body) == 1, "Expected exactly one line under %r, got %r" % (
        TOP_IP_HEADER,
        body,
    )
    match = TOP_IP_LINE_RE.match(body[0])
    assert match is not None, "Malformed Top IP line: %r" % body[0]
    assert match.group(1) == EXPECTED_TOP_IP, "Top IP should be %s, got %s" % (
        EXPECTED_TOP_IP,
        match.group(1),
    )
    assert int(match.group(2)) == EXPECTED_TOP_IP_COUNT, (
        "Top IP count should be %d, got %s" % (EXPECTED_TOP_IP_COUNT, match.group(2))
    )


def test_status_section_exists() -> None:
    """The report must contain the '=== Status Code Distribution ===' section."""
    assert STATUS_HEADER in _parse_sections(), (
        "Missing section %r in %s:\n%s" % (STATUS_HEADER, REPORT_PATH, _report_text())
    )


def test_status_code_distribution_is_correct() -> None:
    """Every status code of the access log must be reported with its count."""
    body = _parse_sections().get(STATUS_HEADER, [])
    parsed: dict[str, int] = {}
    for line in body:
        match = STATUS_LINE_RE.match(line)
        assert match is not None, "Malformed status line: %r" % line
        code = match.group(1)
        assert code not in parsed, "Duplicate status code line: %r" % line
        parsed[code] = int(match.group(2))
    assert parsed == EXPECTED_STATUS_COUNTS, "Status distribution should be %r, got %r" % (
        EXPECTED_STATUS_COUNTS,
        parsed,
    )


def test_report_has_only_the_expected_structure() -> None:
    """All report content must live in the two expected sections."""
    headers: list[str] = []
    current: str | None = None
    for line in _report_lines():
        stripped = line.strip()
        if stripped.startswith("===") and stripped.endswith("==="):
            headers.append(stripped)
            current = stripped
        elif stripped:
            assert current is not None, "Content before any section header: %r" % stripped
            if current == TOP_IP_HEADER:
                assert TOP_IP_LINE_RE.match(stripped), "Malformed Top IP line: %r" % stripped
            else:
                assert STATUS_LINE_RE.match(stripped), "Malformed status line: %r" % stripped
    assert headers == [TOP_IP_HEADER, STATUS_HEADER], "Unexpected sections: %r" % headers


def _iter_tests():
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            yield name, value


def run_all() -> int:
    """Run every check (used when this file is executed without pytest)."""
    failures = 0
    total = 0
    for name, test in _iter_tests():
        total += 1
        try:
            test()
        except Exception as exc:  # noqa: BLE001 - report any check failure
            failures += 1
            print("FAIL: %s: %s" % (name, exc))
        else:
            print("PASS: %s" % name)
    print("%d/%d checks passed" % (total - failures, total))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(run_all())
