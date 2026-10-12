#!/bin/bash
set -euo pipefail

# ============================================================
# 修复 /app/stats.py 中的平均金额计算错误
#
# bug：average 使用了整除 //，558 // 5 = 111
# 正确：使用真除 /，558 / 5 = 111.6（再按原有 round(..., 1) 保留 1 位小数）
#
# 只改这一处运算，不改变程序结构，也不硬编码任何结果值。
# ============================================================

target_file="/app/stats.py"

incorrect_expr="total // len(orders)"
correct_expr="total / len(orders)"

if [ ! -f "$target_file" ]; then
    echo "ERROR: 找不到 $target_file" >&2
    exit 1
fi

# 幂等：只有仍然是错误写法时才替换
if grep -qF "$incorrect_expr" "$target_file"; then
    sed -i 's|total // len(orders)|total / len(orders)|' "$target_file"
    echo "已修复：$incorrect_expr  ->  $correct_expr"
else
    echo "无需修改：未发现错误写法（可能已修复）"
fi

# 自检 1：正确写法必须存在，错误写法必须消失
grep -qF "$correct_expr" "$target_file" || {
    echo "ERROR: 未匹配到正确写法 $correct_expr" >&2
    exit 1
}
if grep -qF "$incorrect_expr" "$target_file"; then
    echo "ERROR: 仍存在错误写法 $incorrect_expr" >&2
    exit 1
fi

# 自检 2：修改后脚本仍能正常运行，且输出为合法 JSON
output="$(python3 "$target_file")"
echo "stats.py 输出：$output"

printf '%s' "$output" | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert isinstance(data.get("total_amount"), (int, float)), "total_amount 缺失"
assert isinstance(data.get("average_amount"), (int, float)), "average_amount 缺失"
if abs(data["average_amount"] - 111.6) / 111.6 > 0.001:
    raise SystemExit("average_amount 不正确: %r" % (data["average_amount"],))
print("自检通过：total_amount=%s average_amount=%s" % (data["total_amount"], data["average_amount"]))
'

echo "solve.sh 完成"
