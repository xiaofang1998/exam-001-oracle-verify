#!/bin/bash
# Docker-only oracle check for exam_003 (no Harbor, no uv required).
#
# Run this on a machine with a working Docker daemon, from the repository root:
#
#     bash ci/docker_oracle_check_exam003.sh
#
# It builds exam_003/environment/Dockerfile and then reproduces what Harbor does:
#   * copy solution/ to /solution and execute /solution/solve.sh
#   * copy tests/   to /tests    and execute /tests/test.sh
#   * read /logs/verifier/reward.json   (exam_003's verifier writes reward.json)
#
# Three cases are run, so a green result proves the verifier really judges:
#   1. the submitted solve.sh runs against the image  -> reward 1
#      and solve.sh's edit is verified by content, not by trust:
#      the modified /app/stats.py must contain "total / len(orders)" and no
#      longer contain "total // len(orders)", checked by diffing against the file
#      the image ships.
#   2. the verifier must reject a hard-coded answer -> reward 0
#   3. the image as shipped (bug present) must fail  -> reward 0
#
# /app is an anonymous docker volume, so whatever solve.sh edits there is
# container-local and does not touch the repository checkout.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_DIR="$REPO_ROOT/exam_003"
IMAGE="exam003-env:local"

for i in $(seq 5); do
    if docker pull python:3.11-slim; then break; fi
    echo "docker pull failed (attempt $i), retrying in 10s..."
    sleep 10
    [ "$i" = "5" ] && { echo "FAIL: cannot pull python:3.11-slim"; exit 1; }
done

echo "== building $IMAGE from exam_003/environment"
docker build -t "$IMAGE" "$TASK_DIR/environment"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/logs/verifier"

# ---------------------------------------------------------------- case 1 ----
# Run the submitted solve.sh inside the real image, then run the verifier.
echo
echo "== case 1/3: run submitted solution/solve.sh, then tests/test.sh"
docker run --rm \
    -v "$TASK_DIR/solution:/src/solution:ro" \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$WORK:/output" \
    -v "$WORK/logs:/logs" \
    "$IMAGE" bash -c '
set -e
cp -r /src/solution /solution && chmod +x /solution/solve.sh
echo "----- solve.sh output -----"
/solution/solve.sh
echo "----- /app/stats.py after solve.sh -----"
cat /app/stats.py
cp /app/stats.py /output/stats_after_solve.py
echo "----- tests/test.sh output -----"
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh
'

echo "--- proof that solve.sh applied the fix (diff vs shipped stats.py) ---"
if diff -u "$TASK_DIR/environment/stats.py" "$WORK/stats_after_solve.py"; then
    echo "FAIL: solve.sh changed nothing"
    exit 1
fi
if grep -qF 'total // len(orders)' "$WORK/stats_after_solve.py"; then
    echo "FAIL: buggy integer division still present after solve.sh"
    exit 1
fi
if ! grep -qF 'total / len(orders)' "$WORK/stats_after_solve.py"; then
    echo "FAIL: expected real division not found after solve.sh"
    exit 1
fi

REWARD="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["reward"])' \
    "$WORK/logs/verifier/reward.json")"
echo "case 1 reward=$REWARD (expected 1)"
[ "$REWARD" = "1" ] || { echo "FAIL: expected reward 1"; exit 1; }

# ---------------------------------------------------------------- case 2 ----
# The verifier must refuse a hard-coded answer.
echo
echo "== case 2/3: hard-coded answer -> verifier must reject"
cat > "$WORK/hardcoded.py" <<'PY'
import json
print(json.dumps({"total_amount": 558, "average_amount": 111.6}))
PY
docker run --rm \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$WORK:/output" \
    -v "$WORK/logs:/logs" \
    -v "$WORK/hardcoded.py:/hardcoded.py:ro" \
    "$IMAGE" bash -c '
set -e
cp /hardcoded.py /app/stats.py
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh || true
'
REWARD2="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["reward"])' \
    "$WORK/logs/verifier/reward.json")"
echo "case 2 reward=$REWARD2 (expected 0)"
[ "$REWARD2" = "0" ] || { echo "FAIL: hard-coded answer was not rejected"; exit 1; }

# ---------------------------------------------------------------- case 3 ----
# The unmodified image must fail: nothing is "always green".
echo
echo "== case 3/3: image as shipped (bug present) -> verifier must fail"
docker run --rm \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$WORK:/output" \
    -v "$WORK/logs:/logs" \
    "$IMAGE" bash -c '
set -e
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh || true
'
REWARD3="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["reward"])' \
    "$WORK/logs/verifier/reward.json")"
echo "case 3 reward=$REWARD3 (expected 0)"
[ "$REWARD3" = "0" ] || { echo "FAIL: buggy image reported success"; exit 1; }

echo
echo "PASS: exam_003 docker pipeline is sound (reward 1 / 0 / 0)"
echo "      solve.sh: applied and content-verified"
echo "      verifier: accepts the fix, rejects hard-coding and the bug"
