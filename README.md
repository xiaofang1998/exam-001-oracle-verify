# exam_001 —— GitHub Actions 云端 oracle 验证

这个目录是**可直接推送的仓库内容**，用来在 GitHub 免费跑测机上执行真实的
`harbor trials start -p exam_001 -a oracle`，并断言 `reward == 1.0`。
本机不需要安装 Docker，也不需要管理员权限。

```
ci_push/
├── .github/workflows/oracle-verify.yml   # 两个 job：真实 Harbor oracle + 纯 Docker 复核
├── ci/docker_oracle_check.sh             # 只用 Docker 复现同一条流水线
├── exam_001/                             # 提交包本体（与 exam_001.zip 内容一致）
└── README.md
```

## 步骤 1：创建一个空仓库

在 https://github.com/new 新建一个仓库（Public 最省事，Private 也够用，免费额度
2000 分钟/月，这个 workflow 大约跑 5–8 分钟）。**不要**勾选添加 README/.gitignore。

## 步骤 2：把 `ci_push/` 推上去

在本机 PowerShell 里执行（把 `<你的用户名>` 和 `<仓库名>` 换成实际值）：

```powershell
cd C:\workpath\zhunru\ci_push
git init -b main
git add -A
git commit -m "exam_001: harbor oracle verification"
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

推送时若提示密码，请填 **Personal Access Token**（GitHub 已不接受账号密码）：
Settings → Developer settings → Personal access tokens → 勾选 `repo` 权限即可。

## 步骤 3：看结果

打开 `https://github.com/<你的用户名>/<仓库名>/actions`，等 `exam_001 oracle
verification` 跑完：

- **harbor-oracle**（主验证）：日志里应出现 `PASS: oracle reward = 1.0`，
  以及 `=== Status Code Distribution ===` 的判分输出。
- **docker-only-check**（独立复核）：只用 Docker 复现同一流水线，输出
  `PASS: oracle reward is 1.0`。
- 页面底部 Artifacts 可下载 `harbor-oracle-trial`，里面有
  `verifier/reward.txt`、`verifier/test-stdout.txt` 等原始证据。

只要 `harbor-oracle` 这个 job 是绿色的，就说明 reward = 1.0 已在真实 Docker +
真实 Harbor v0.5.0 上得到确认。

## 常见问题

- **uv 安装慢/失败**：重跑一次即可；workflow 已固定 Harbor `v0.5.0` 标签。
- **`uv run` 首次同步依赖需要几分钟**（harbor 依赖 litellm/datasets 等），
  `timeout-minutes: 45` 足够。
- **想手动重跑**：Actions 页面 → 选中 workflow → `Run workflow`。
- **不想用命令行推送**：也可以在 GitHub 仓库页面用 "uploading an existing file"
  把 `ci_push/` 里的文件逐个拖上去（注意 `.github/workflows/` 这两层目录结构要保留）。
