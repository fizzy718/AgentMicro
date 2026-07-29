# AgentMicro 发布与在线更新

本文件描述 AgentMicro 自己的发布链路。它与根目录的 CodexBar 发布流程相互独立，
不能复用 CodexBar 的 appcast、Ed25519 密钥或签名身份配置。

## 一次性准备

1. AgentMicro 独立公开仓库为
   [`fizzy718/AgentMicro`](https://github.com/fizzy718/AgentMicro)，本地 `origin`
   指向该仓库；`upstream` 指向
   [`steipete/CodexBar`](https://github.com/steipete/CodexBar)。
2. 在 Apple Developer 账户创建并安装 `Developer ID Application` 证书。
3. 准备 App Store Connect API Key 的 Key ID、Issuer ID 和 P8 私钥。
4. 生成 AgentMicro 专属 Sparkle 密钥：

   ```bash
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account agentmicro
   ```

   命令输出的公钥写入 `.mac-release.env`；私钥保留在钥匙串。若需要 CI 发布，使用
   `-x` 导出后放入 CI Secret，导出文件不得提交仓库。
5. 复制 `.mac-release.env.example` 为 `.mac-release.env`，填写仓库、feed、Bundle ID、
   公钥和 Developer ID 身份。Apple P8 优先在发布 shell 或 CI Secret 中导出。

推荐 feed：

```text
https://raw.githubusercontent.com/fizzy718/AgentMicro/main/agentmicro-appcast.xml
```

## 版本

`agentmicro-version.env` 是 AgentMicro 独立版本事实源：

```bash
AGENTMICRO_VERSION=0.1.0
AGENTMICRO_BUILD_NUMBER=1
```

每次发布必须同时提高用户版本或构建号；Sparkle 使用 `CFBundleVersion` 判断更新顺序。

## 本地准备发布

先确保工作树干净，再执行：

```bash
./Scripts/release_agentmicro.sh
```

该命令会：

1. 为 arm64 与 x86_64 构建 universal `AgentMicro.app`。
2. 注入 AgentMicro feed 和公钥。
3. 对 Sparkle 嵌套组件及应用执行 Developer ID hardened-runtime 签名。
4. 提交 Apple 公证、等待结果并 staple。
5. 生成 `.build/agentmicro-release/<version>/AgentMicro-macos-universal-<version>.zip`。
6. 使用 AgentMicro 专属私钥生成或更新 `agentmicro-appcast.xml`。

命令默认不上传、不提交。检查 ZIP、签名、公证结果与 appcast 后再发布。

## 发布

确认配置和产物后执行：

```bash
./Scripts/release_agentmicro.sh --publish
```

`--publish` 会创建 GitHub Release、上传 ZIP，只暂存并提交
`agentmicro-appcast.xml`，然后推送到 `AGENTMICRO_FEED_BRANCH`。脚本拒绝存在其他未提交
修改的工作树，也拒绝覆盖已经存在的同版本 Release。

## GitHub Actions 一键发布

仓库的 `Release AgentMicro` 工作流把正式发布放在 GitHub 托管的 macOS runner 上完成，
不需要自建更新服务器。GitHub Release 托管 ZIP，仓库 main 分支的
`agentmicro-appcast.xml` 是 Sparkle 更新清单。

先在 GitHub 仓库创建名为 `agentmicro-release` 的 Environment。建议给该 Environment
增加 required reviewer，避免误触正式发布。配置两个 Environment variables：

- `AGENTMICRO_PUBLIC_ED_KEY`：AgentMicro Sparkle Ed25519 公钥。
- `AGENTMICRO_SIGNING_IDENTITY`：完整 Developer ID Application 身份名称。

再配置六个 Environment secrets：

- `AGENTMICRO_DEVELOPER_ID_P12_BASE64`：Developer ID 证书与私钥导出的 P12，经
  `base64 < certificate.p12 | pbcopy` 编码后的内容。
- `AGENTMICRO_DEVELOPER_ID_P12_PASSWORD`：P12 导出密码。
- `AGENTMICRO_SPARKLE_PRIVATE_KEY_BASE64`：Sparkle 导出私钥文件经 base64 编码后的内容。
- `APP_STORE_CONNECT_KEY_ID`：App Store Connect API Key ID。
- `APP_STORE_CONNECT_ISSUER_ID`：App Store Connect Issuer ID。
- `APP_STORE_CONNECT_API_KEY_P8`：P8 私钥完整内容。

配置完成后：

1. 在 `agentmicro-version.env` 提高版本号或构建号，并按 `feat → dev → main` 合入。
2. 打开 GitHub 仓库的 **Actions → Release AgentMicro → Run workflow**。
3. 输入与 `agentmicro-version.env` 完全一致的版本号。
4. 工作流会验证源码、临时安装证书、构建 universal 应用、签名、公证、创建 GitHub
   Release，并把新 appcast 提交回 main。

工作流不会把 P12、P8 或 Sparkle 私钥写入仓库。每次 runner 结束前还会删除临时
Keychain 和密钥文件。

首次闭环验证需要两个版本：

1. 安装正式签名、公证且已经嵌入 feed 的旧版本。
2. 发布构建号更高的新版本。
3. 在旧版本设置页执行“检查更新”。
4. 验证发现版本、下载、Ed25519 校验、替换应用和重新启动。

## 安全约束

- `.mac-release.env`、P8、P12 和 Sparkle 私钥都不能提交。
- AgentMicro 不得使用 CodexBar 的 `appcast.xml` 或旧 AGCY 公钥。
- 正式发布后不要随意更换 Bundle ID、Developer ID 团队或 Ed25519 公钥。
- 开发包继续使用 ad-hoc 签名，并明确显示“尚未配置软件更新源”。
- 发布前运行 `make check`；CI 只验证代码，不能替代本地证书、公证和跨版本更新验收。
