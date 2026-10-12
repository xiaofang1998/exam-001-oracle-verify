# 订单统计脚本修复

## 任务描述

同事写了一个订单统计脚本，读取订单数据后输出总金额和平均金额。
脚本能正常运行、没有语法错误，但**平均金额算错了**。

## 当前状态

代码在 `/app/stats.py`，数据在 `/app/orders.json`，运行方式：

```bash
python3 /app/stats.py
```

## 计算规则

- `total_amount` = 所有订单的 `amount` 相加
- `average_amount` = `total_amount` ÷ 订单条数，保留 1 位小数

## 期望输出

程序应输出如下 JSON（允许 0.1% 相对误差）：

```json
{"total_amount": 558, "average_amount": 111.6}
```

## 约束

- 不要把结果值硬编码进代码，必须真算出来
- 保持程序结构不变，只修那处计算错误

## 提交

将你的修复方案写入 `solution/solve.sh`
