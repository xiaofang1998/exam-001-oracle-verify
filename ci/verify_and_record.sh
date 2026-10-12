#!/bin/bash
# Run the submitted task end-to-end inside the Docker image and record the raw
# verifier evidence into $OUT_DIR (default: evidence/), then assert reward == 1.
#
# Usage, from the repository root:
#     bash ci/verify_and_record.sh exam_003 evidence
#
# What it proves, in one pass, with an explicit exit code (no continue-on-error):
#   * the image built from <task>/environment/Dockerfile is the one judged
#   * the submitted <task>/solution/solve.sh is what produces the fix
#     (verified by content: '//' must be gone, '/' must be present)
#   * <task>/tests/test.sh awards reward = 1 for it
#   * and awards reward = 0 for a hard-coded answer (anti-hard-coding)
#   * and awards reward = 0 for the image as shipped (anti-false-green)
#
# Evidence written to $OUT_DIR:
#   reward_after_solve.json   raw /logs/verifier/reward.json for the fixed run
#   verifier_output.log       full verifier stdout of that run
#   stats_before.py           /app/stats.py as the image ships it
#   stats_after_solve.py      /app/stats.py after solve.sh ran
#   solve_output.log          solve.sh's own stdout
#   reward_hardcoded.json     reward for the hard-coded answer (must be 0)
#   reward_buggy_image.json   reward for the untouched image (must be 0)
#   summary.txt               the numbers, one per line

set -euo pipefail

TASK_NAME="${1:-exam_003}"
OUT_DIR="${2:-evidence}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_DIR="$REPO_ROOT/$TASK_NAME"
IMAGE="${TASK_NAME}-env:evidence"

[ -d "$TASK_DIR/environment" ] || { echo "no such task: $TASK_DIR"; exit 1; }

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"

# evidence/README.md is checked into the repository and explains what the files
# prove. Rewrite it here so it survives the rm -rf above and stays alongside the
# evidence it describes.
cat > "$OUT_ABS/README.md" <<'MD'
# evidence/ —— 判分原始证据（由 CI 自动提交）

这个目录由 GitHub Actions 的 `exam_003 evidence (raw reward.json)` job 在
`ubuntu-latest`（自带 Docker）上生成并提交回来，**不经过人工编辑**（本文件除外，
它由 `ci/verify_and_record.sh` 在开始时重新写入）。
之所以提交回仓库，是为了让证据可以通过免认证的 raw 链接直接读取：

```
https://raw.githubusercontent.com/xiaofang1998/exam-001-oracle-verify/main/evidence/summary.txt
https://raw.githubusercontent.com/xiaofang1998/exam-001-oracle-verify/main/evidence/harbor_oracle_reward.json
```

## 文件

| 文件 | 来源 | 期望值 |
|---|---|---|
| `summary.txt` | `ci/verify_and_record.sh` 汇总 | `1 / 0 / 0` |
| `harbor_oracle_reward.json` | **真 Harbor oracle trial** 容器内 `/logs/verifier/reward.json`（从该 trial 的 artifact 原样取出） | `{"reward": 1}` |
| `reward_after_solve.json` | 纯 Docker 复核：容器内 `/logs/verifier/reward.json`（先跑提交的 `solve.sh`） | `{"reward": 1}` |
| `reward_hardcoded.json` | 同上，但把直接 `print` 答案的脚本交给判分器 | `{"reward": 0}` |
| `reward_buggy_image.json` | 同上，但用镜像里未修复的 `stats.py` | `{"reward": 0}` |
| `stats_before.py` | 镜像里 `/app/stats.py` 原样（`total // len(orders)`） | 展示 bug |
| `stats_after_solve.py` | 提交的 `solve.sh` 跑完后的 `/app/stats.py` | 只有真除 |
| `solve_output.log` | `solve.sh` 的完整 stdout | 含自检通过 |
| `verifier_output.log` | `tests/test.sh` 的完整 stdout | 含逐字段 PASS |

## 为什么这样算证明

- `harbor_oracle_reward.json` 是**真 Harbor oracle trial** 里判分程序写出的文件，
  从该 trial 上传的 artifact 里原样取出，不是人写的；内容为 `{"reward": 1}`
  即考试要求的 `reward = 1.0`。
- `reward_after_solve.json` 是同一判分流程在纯 Docker 下的独立复现，并且
  `stats_before.py` / `stats_after_solve.py` 之间的 `diff` 证明是提交的
  `solve.sh`（而不是测试脚手架）完成了修复。
- 反例存在的意义：如果判分器"恒绿"，硬编码答案那一例就会拿到 1；如果
  `solve.sh` 没起作用，未修复镜像那一例就不会是 0。三项 `1 / 0 / 0` 同时成立，
  才说明修复有效且判分器有判别力。
MD


for i in $(seq 5); do
    if docker pull python:3.11-slim; then break; fi
    echo "docker pull failed (attempt $i), retrying..."
    sleep 10
    [ "$i" = "5" ] && { echo "FAIL: cannot pull python:3.11-slim"; exit 1; }
done

echo "== building $IMAGE from $TASK_NAME/environment"
docker build -q -t "$IMAGE" "$TASK_DIR/environment" >/dev/null

reward_of () { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["reward"])' "$1"; }

# ---------------------------------------------------------------------------
# Case 1: run the submitted solve.sh in the real image, then the verifier.
# Each case gets its own host directory bind-mounted at /logs/verifier, so the
# three reward.json files never overwrite one another.
# ---------------------------------------------------------------------------
echo
echo "== case 1: submitted solve.sh + submitted tests/test.sh"
mkdir -p "$OUT_ABS/logs1/verifier"
docker run --rm \
    -v "$TASK_DIR/environment/stats.py:/shipped_stats.py:ro" \
    -v "$TASK_DIR/solution:/src/solution:ro" \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$OUT_ABS:/output" \
    -v "$OUT_ABS/logs1:/logs" \
    "$IMAGE" bash -c '
set -e
cp /shipped_stats.py /output/stats_before.py
cp -r /src/solution /solution && chmod +x /solution/solve.sh
/solution/solve.sh | tee /output/solve_output.log
cp /app/stats.py /output/stats_after_solve.py
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh | tee /output/verifier_output.log
'
cp "$OUT_ABS/logs1/verifier/reward.json" "$OUT_ABS/reward_after_solve.json"

echo
echo "--- proof that solve.sh (not the harness) applied the fix ---"
if diff -u "$OUT_ABS/stats_before.py" "$OUT_ABS/stats_after_solve.py"; then
    echo "FAIL: solve.sh changed nothing"
    exit 1
fi
if grep -qF 'total // len(orders)' "$OUT_ABS/stats_after_solve.py"; then
    echo "FAIL: '//' still present after solve.sh"
    exit 1
fi
if ! grep -qF 'total / len(orders)' "$OUT_ABS/stats_after_solve.py"; then
    echo "FAIL: real division missing after solve.sh"
    exit 1
fi

R1="$(reward_of "$OUT_ABS/reward_after_solve.json")"
echo "case 1 reward = $R1 (expected 1)"
[ "$R1" = "1" ] || { echo "FAIL: expected reward 1"; exit 1; }

# ---------------------------------------------------------------------------
# Case 2: hard-coded answer must be rejected.
# ---------------------------------------------------------------------------
echo
echo "== case 2: hard-coded answer must score 0"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

printf 'import json\nprint(json.dumps({"total_amount": 558, "average_amount": 111.6}))\n' \
    > "$SCRATCH/hardcoded_stats.py"
mkdir -p "$OUT_ABS/logs2/verifier"
docker run --rm \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$SCRATCH/hardcoded_stats.py:/hardcoded.py:ro" \
    -v "$OUT_ABS/logs2:/logs" \
    "$IMAGE" bash -c '
set -e
cp /hardcoded.py /app/stats.py
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh || true
'
cp "$OUT_ABS/logs2/verifier/reward.json" "$OUT_ABS/reward_hardcoded.json"
R2="$(reward_of "$OUT_ABS/reward_hardcoded.json")"
echo "case 2 reward = $R2 (expected 0)"
[ "$R2" = "0" ] || { echo "FAIL: hard-coded answer was not rejected"; exit 1; }

# ---------------------------------------------------------------------------
# Case 3: the image as shipped must fail.
# ---------------------------------------------------------------------------
echo
echo "== case 3: untouched image must score 0"
mkdir -p "$OUT_ABS/logs3/verifier"
docker run --rm \
    -v "$TASK_DIR/tests:/src/tests:ro" \
    -v "$OUT_ABS/logs3:/logs" \
    "$IMAGE" bash -c '
set -e
cp -r /src/tests /tests && chmod +x /tests/test.sh
/tests/test.sh || true
'
cp "$OUT_ABS/logs3/verifier/reward.json" "$OUT_ABS/reward_buggy_image.json"
R3="$(reward_of "$OUT_ABS/reward_buggy_image.json")"
echo "case 3 reward = $R3 (expected 0)"
[ "$R3" = "0" ] || { echo "FAIL: buggy image reported success"; exit 1; }

rm -rf "$OUT_ABS/logs1" "$OUT_ABS/logs2" "$OUT_ABS/logs3"

cat > "$OUT_ABS/summary.txt" <<EOF
task                          = $TASK_NAME
docker image                  = built from $TASK_NAME/environment/Dockerfile
solve.sh produced the fix     = yes (content-verified: '//' gone, '/' present)
reward_after_solve.sh         = $R1
reward_hardcoded_answer       = $R2
reward_buggy_image            = $R3
expected                      = 1 / 0 / 0
EOF

echo
echo "===== evidence summary ====="
cat "$OUT_ABS/summary.txt"
echo
echo "PASS: evidence recorded in $OUT_DIR (reward 1 / 0 / 0)"
