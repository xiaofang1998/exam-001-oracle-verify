# GitHub Actions 云端 Harbor oracle 验证

这个仓库用来在 GitHub 免费跑测机上执行**真实的** `harbor trials start -a oracle`，
并断言 `reward == 1.0`。本机不需要 Docker、WSL2 或管理员权限。

```
.
├── .github/workflows/oracle-verify.yml       # 4 个 job：两个题目 × (真 Harbor + 纯 Docker)
├── ci/docker_oracle_check.sh                 # exam_001：只用 Docker 复现同一条流水线
├── ci/docker_oracle_check_exam003.sh         # exam_003：Docker 复核 + 反例（negative control）
├── exam_001/                                 # 题目一（提交包本体）
├── exam_003/                                 # 题目二（订单统计脚本修复）
└── README.md
```

## 四个 job

| job | 题目 | 做什么 |
|---|---|---|
| `harbor-oracle` | exam_001 | 真 Harbor v0.5.0 oracle trial，断言 reward |
| `docker-only-check` | exam_001 | 只用 Docker 复现 solve.sh + test.sh |
| `exam003-harbor-oracle` | exam_003 | 真 Harbor oracle trial，读 `/logs/verifier/reward.json` |
| `exam003-docker-check` | exam_003 | 跑提交的 `solve.sh`，再跑判分；外加两个反例 |

## exam_003（订单统计脚本修复）

任务：`/app/stats.py` 里平均金额用了整除 `total // len(orders)`（558 // 5 = 111），
应改成真除 `total / len(orders)`（→ 111.6）。`solution/solve.sh` 只改这一行，
不硬编码结果值，可重复执行。

`exam003-docker-check` 会依次验证三件事，任何一件不符合预期就失败：

1. **正常路径**：在按 `exam_003/environment/Dockerfile` 构建出的镜像里执行提交的
   `solution/solve.sh`，然后执行 `tests/test.sh` → 必须 `reward = 1`。
   同时用 `diff` 证明 `solve.sh` 真的改了 `/app/stats.py`（修改后不含 `//`，
   含 `/`），而不是"碰巧通过"。
2. **反硬编码**：把直接 `print` 答案的 `stats.py` 交给判分程序 → 必须 `reward = 0`。
3. **反假绿**：未修复的原始镜像交给判分程序 → 必须 `reward = 0`。

## 看结果

打开 `https://github.com/xiaofang1998/exam-001-oracle-verify/actions`：

- `exam003-harbor-oracle` 绿色 → 真 Harbor + 真 Docker 上 `reward = 1.0`。
- `exam003-docker-check` 绿色 → `solve.sh` 的行为与判分器的判别力都已确认。
- 页面底部 Artifacts 可下载 `harbor-oracle-trial-exam003`，里面有
  `verifier/reward.json`、判分明细和 `agent/oracle.txt`（solve.sh 的原始 stdout）。

## 备注

- `exam003-harbor-oracle` 默认克隆 Harbor 的 `main`（task.toml 声明
  `schema_version = "1.1"`），失败时回退到 `v0.5.0` 标签。
- `uv run` 首次同步依赖需要几分钟（harbor 依赖 litellm/datasets 等），
  `timeout-minutes: 45` 足够。
- 想手动重跑：Actions 页面 → 选中 workflow → `Run workflow`。
