#!/bin/bash
# Docker-only oracle check for exam_001 (no Harbor, no uv required).
#
# Run this on a machine with a working Docker daemon, from the repository root:
#
#     bash ci/docker_oracle_check.sh exam_001
#
# It builds environment/Dockerfile and then reproduces what Harbor does:
#   * copy solution/ to /solution and execute /solution/solve.sh
#   * copy tests/ to /tests and execute /tests/test.sh
#   * read /logs/verifier/reward.txt
# Expected result: reward = 1.0
#
# The host directories are mounted read-only and copied inside the container
# (exactly like Harbor's upload_dir + chmod), so Unix exec bits on the host do
# not matter.

set -euo pipefail

TASK_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/exam_001}"
TASK_DIR="$(cd "$TASK_DIR" && pwd)"
IMAGE="exam001-env:local"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
mkdir -p "$OUT_DIR/logs/verifier"

echo "== task dir: $TASK_DIR"
echo "== building image from $TASK_DIR/environment"
docker build -t "$IMAGE" "$TASK_DIR/environment"

echo "== running solve.sh + test.sh inside the image"
docker run --rm \
    -v "$TASK_DIR/solution:/src/solution:ro" \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$OUT_DIR:/output" \
    -v "$OUT_DIR/logs:/logs" \
    "$IMAGE" bash -c '
set -e
cp -r /src/solution /solution && chmod +x /solution/solve.sh
/solution/solve.sh
echo "===== /output/report.txt produced by the solution ====="
cat /output/report.txt
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh
'

echo "===== verifier log ====="
cat "$OUT_DIR/logs/verifier/test-output.log" 2>/dev/null || true

REWARD="$(tr -d ' \r\n' < "$OUT_DIR/logs/verifier/reward.txt")"
echo "===== reward: $REWARD ====="
if [ "$(printf '%.1f' "$REWARD")" = "1.0" ]; then
    echo "PASS: oracle reward is 1.0"
else
    echo "FAIL: expected reward 1.0"
    exit 1
fi
