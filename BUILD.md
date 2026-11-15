# 构建 AI Monitor

macOS、完整 Xcode、仓库要求的 Swift 工具链、Apple Silicon 和可用的 Apple 签名证书。依赖版本由原项目 Package.resolved 锁定。

```sh
APP_TEAM_ID=YOUR_TEAM_ID \
AI_MONITOR_SIGNING_IDENTITY=YOUR_CERTIFICATE_SHA1 \
./Scripts/package_ai_monitor.sh
```

输出 `AI Monitor.app`。当前脚本构建 arm64 debug 基线，并保留 CodexBar 内部标识与原有数据路径；安装显示名与组件目录名为 AI Monitor。应用包中不含运行时账户配置。

证书与团队 ID 必须由构建者自行提供，仓库不包含私钥。脚本签名不等于公证；面向普通用户的正式发行还需合适的 Developer ID 签名、公证和异机验收。

本版变更：Sources/CodexBarWidget 中的定制外观与本机状态卡片、相关渲染测试、Scripts/package_ai_monitor.sh、version.env。额度提供方、核心读取逻辑和依赖清单沿用上游基线。

构建号 182；面向本定制版的 GitHub 版本为 0.1.0-beta.1。主程序内部保留上游版本 0.84.1，方便追踪兼容性。
