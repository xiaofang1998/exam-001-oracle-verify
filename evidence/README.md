# evidence/ —— 判分原始证据（由 CI 自动提交）

这个目录由 GitHub Actions 的 `exam_003 evidence (raw reward.json)` job 在
`ubuntu-latest`（自带 Docker）上自动生成并提交回来，**不经过人工编辑**。
之所以提交回仓库，是为了让证据可以通过免认证的 raw 链接直接读取：

```
https://raw.githubusercontent.com/xiaofang1998/exam-001-oracle-verify/main/evidence/summary.txt
https://raw.githubusercontent.com/xiaofang1998/exam-001-oracle-verify/main/evidence/reward_after_solve.json
```

## 文件

| 文件 | 来源 | 期望值 |
|---|---|---|
| `summary.txt` | `ci/verify_and_record.sh` 汇总 | 三个数字 |
| `reward_after_solve.json` | 容器内 `/logs/verifier/reward.json`（先跑提交的 `solve.sh`） | `{"reward": 1}` |
| `reward_hardcoded.json` | 同上，但把直接 `print` 答案的脚本交给判分器 | `{"reward": 0}` |
| `reward_buggy_image.json` | 同上，但用镜像里未修复的 `stats.py` | `{"reward": 0}` |
| `stats_before.py` | 镜像里 `/app/stats.py` 原样（`total // len(orders)`） | 展示 bug |
| `stats_after_solve.py` | 提交的 `solve.sh` 跑完后的 `/app/stats.py` | 只有真除 |
| `solve_output.log` | `solve.sh` 的完整 stdout | 含自检通过 |
| `verifier_output.log` | `tests/test.sh` 的完整 stdout | 含逐字段 PASS |

## 为什么这样算证明

- `reward_after_solve.json` 是容器内判分程序**实际写出**的文件，不是人写的；
  内容为 `{"reward": 1}` 即 `reward = 1.0`。
- 反例存在的意义：如果判分器是"恒绿"的，硬编码答案那一例就会拿到 1；
  如果 `solve.sh` 没起作用，镜像原样那一例就会拿到 0 之外的意外结果。
  三项 `1 / 0 / 0` 同时成立，才说明修复有效且判分器有判别力。
- 与 `harbor trials start -a oracle` 的关系：Harbor 的 oracle trial 做的正是
  同一件事——把 `solution/` 上传到容器并执行 `solve.sh`，再执行 `tests/test.sh`
  读 `/logs/verifier/reward.json`。这里的脚本是同一流程的显式复现，并且把
  `solve.sh` 是否真的改了文件用 `diff` 单独验了一遍。
