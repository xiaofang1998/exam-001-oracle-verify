#!/bin/bash
# ============================================================
# Harbor 判分程序（verifier）
#   · 模型看不到 tests/ 目录，这里的内容对被测模型是隐藏的
#   · 唯一的硬性要求：把分数写进 /logs/verifier/reward.json
#     文件里只能有 reward 一个字段，值是 0~1 的小数
#     （要输出各项明细，另开一个文件，比如 breakdown.json）
# ============================================================

REWARD_FILE="/logs/verifier/reward.json"
mkdir -p /logs/verifier

echo '{"reward": 0}' > "$REWARD_FILE"

python3 << 'PYEOF'
import json
import subprocess

REWARD_FILE = "/logs/verifier/reward.json"
EXPECTED = {"total_amount": 558, "average_amount": 111.6}
TOLERANCE = 0.001          # 允许 0.1% 相对误差


def write_reward(value):
    with open(REWARD_FILE, "w") as f:
        json.dump({"reward": value}, f)
    print(f"reward = {value}")


# ---------- 1. 反硬编码：源码里不许直接写死答案 ----------
with open("/app/stats.py", encoding="utf-8") as f:
    source = f.read()

for banned in ("558", "111.6"):
    if banned in source:
        print(f"FAIL: 源码里出现了硬编码的结果值 {banned}")
        raise SystemExit

# ---------- 2. 跑一次被测程序 ----------
run = subprocess.run(
    ["python3", "/app/stats.py"],
    capture_output=True, text=True, timeout=30,
)

if run.returncode != 0:
    print("FAIL: 程序没跑起来")
    print(run.stderr[:300])
    raise SystemExit

print("程序输出：", run.stdout.strip())

# ---------- 3. 逐字段比对 ----------
try:
    actual = json.loads(run.stdout.strip())
except Exception:
    print("FAIL: 输出不是合法 JSON")
    raise SystemExit

all_pass = True
for key, expected in EXPECTED.items():
    got = actual.get(key)
    if not isinstance(got, (int, float)) or isinstance(got, bool):
        print(f"  {key}: FAIL（字段缺失或不是数字，实际 {got!r}）")
        all_pass = False
        continue
    rel_err = abs(got - expected) / abs(expected)
    ok = rel_err <= TOLERANCE
    print(f"  {key}: {'PASS' if ok else 'FAIL'}"
          f"（期望 {expected}，实际 {got}，相对误差 {rel_err:.2e}）")
    all_pass = all_pass and ok

write_reward(1 if all_pass else 0)
PYEOF
