#!/bin/bash
# Verifier entry point for exam_001.
#
# Runs the pytest-style checks in /tests/test_outputs.py and writes the trial
# reward (1 = pass, 0 = fail) to /logs/verifier/reward.txt, which Harbor reads.
#
# Paths/commands can be overridden through the environment for local testing;
# the graded run uses the defaults below.

set -u

REWARD_FILE="${REWARD_FILE:-/logs/verifier/reward.txt}"
REPORT_FILE="${REPORT_FILE:-/output/report.txt}"
TEST_FILE="${TEST_FILE:-/tests/test_outputs.py}"
OUTPUT_LOG="${OUTPUT_LOG:-/logs/verifier/test-output.log}"

mkdir -p "$(dirname "$REWARD_FILE")" "$(dirname "$OUTPUT_LOG")"

reward=0
if command -v python3 >/dev/null 2>&1; then
    if python3 "$TEST_FILE" > "$OUTPUT_LOG" 2>&1; then
        reward=1
    fi
    cat "$OUTPUT_LOG"
else
    # Minimal-image fallback (no Python): the same acceptance criteria with
    # POSIX tools only. environment/Dockerfile installs python3, so this branch
    # is only used if the task is run in an image without an interpreter.
    echo "python3 not found; falling back to the POSIX checks." | tee "$OUTPUT_LOG"
    if grep -q '^=== Top IP ===$' "$REPORT_FILE" &&
        grep -q '^192\.168\.1\.100: 5 requests$' "$REPORT_FILE" &&
        grep -q '^=== Status Code Distribution ===$' "$REPORT_FILE" &&
        grep -q '^200: 6$' "$REPORT_FILE" &&
        grep -q '^401: 1$' "$REPORT_FILE" &&
        grep -q '^404: 2$' "$REPORT_FILE" &&
        grep -q '^500: 1$' "$REPORT_FILE"; then
        reward=1
    fi
    cat "$OUTPUT_LOG"
fi

echo "reward=$reward"
echo "$reward" > "$REWARD_FILE"
exit 0
