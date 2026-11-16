# 构建 AI Monitor

[返回首页](README.md) · [架构设计](ARCHITECTURE.md)

## 环境

需要 Apple Silicon Mac、完整 Xcode、Swift 6.2 或满足仓库要求的更新工具链，以及可用的 Apple 签名证书。依赖版本由原项目 Package.resolved 锁定。

## 打包

```sh
APP_TEAM_ID=YOUR_TEAM_ID \
AI_MONITOR_SIGNING_IDENTITY=YOUR_CERTIFICATE_SHA1 \
./Scripts/package_ai_monitor.sh
```

输出 `AI Monitor.app`。当前脚本构建 arm64 debug 基线，并保留 CodexBar 内部标识与原有数据路径；安装显示名与组件目录名为 AI Monitor。应用包中不含运行时账户配置。

证书与团队 ID 必须由构建者自行提供，仓库不包含私钥。脚本签名不等于公证；面向普通用户的正式发行还需合适的 Developer ID 签名、公证和异机验收。

本版变更：Sources/CodexBarWidget 中的定制外观与本机状态卡片、相关渲染测试、Scripts/package_ai_monitor.sh、version.env。额度提供方、核心读取逻辑和依赖清单沿用上游基线。

构建号 183；面向本定制版的 GitHub 版本为 0.1.0-beta.4。主程序内部保留上游版本 0.84.1，方便追踪兼容性。

## 界面验证

组件截图由视图代码直接渲染，生成步骤见 [截图说明](docs/ai-monitor/SCREENSHOTS.md)。版本验证范围见 [验证记录](docs/ai-monitor/RELEASE-VALIDATION.md)。

## 安装与包校验

打包脚本现在强制使用 AI Monitor 独立组件标识，拒绝从旧 Studio 扩展产物跳过构建。签名后验证扩展身份、可执行文件、主程序与组件版本、共享组权限及更新开关。

```sh
python3 Scripts/verify_ai_monitor_bundle.py 'AI Monitor.app'
python3 Scripts/install_ai_monitor.py 'AI Monitor.app'
```

安装脚本将应用固定放到 `/Applications/AI Monitor.app`。替换前保留备份，精确退出主程序；对同身份、同路径的后续更新保留现有注册，对旧 Studio 扩展执行迁移注册。旧卡片需要从组件库重新添加一次。
