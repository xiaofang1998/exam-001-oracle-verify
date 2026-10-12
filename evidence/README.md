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
