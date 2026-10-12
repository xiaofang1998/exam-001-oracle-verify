#!/usr/bin/env python3
"""
订单统计脚本

读取 /app/orders.json，输出总金额和平均金额。

运行：python3 /app/stats.py
输出：JSON 格式的统计结果
"""

import json


def summarize(orders):
    """
    统计规则：
        total_amount   = 所有订单 amount 之和
        average_amount = total_amount / 订单条数，保留 1 位小数
    """
    total = 0
    for order in orders:
        total += order["amount"]

    average = total // len(orders)

    return {
        "total_amount": total,
        "average_amount": round(average, 1),
    }


with open("/app/orders.json", encoding="utf-8") as f:
    orders = json.load(f)["orders"]

print(json.dumps(summarize(orders)))
