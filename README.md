<div align="center">

# AI Monitor

### AI 额度，一眼掌握。

为 macOS 桌面设计的 Codex / Claude 用量组件。
额度、重置时间、七日用量与 Mac 状态，在熟悉的桌面上集中呈现。

[![macOS](https://img.shields.io/badge/macOS-14%2B-20232a?style=flat-square&logo=apple&logoColor=white)](INSTALL.zh-CN.md)
[![Architecture](https://img.shields.io/badge/芯片-Apple%20Silicon-6256c7?style=flat-square)](INSTALL.zh-CN.md)
[![Release](https://img.shields.io/badge/版本-0.1.0%20Beta%2014-d98963?style=flat-square)](https://github.com/hui77anna/AI-Monitor/releases/tag/v0.1.0-beta.14)
[![License](https://img.shields.io/badge/License-MIT-337f76?style=flat-square)](LICENSE)

**[下载安装包](https://github.com/hui77anna/AI-Monitor/releases/download/v0.1.0-beta.14/AI-Monitor-0.1.0-beta.14-macos-arm64.dmg)** · [安装指南](INSTALL.zh-CN.md) · [架构设计](ARCHITECTURE.md) · [发布记录](https://github.com/hui77anna/AI-Monitor/releases)

基于 [CodexBar](https://github.com/steipete/CodexBar) 的社区 UI 定制项目 · SwiftUI / WidgetKit 原生组件

</div>

> **Beta 14 · Build 197**：修复 Claude 读取偶尔失败（例如 Claude Code 自动更新时）后卡片显示“暂无额度数据”的问题：现在继续显示上次的额度，5 分钟后自动重试；连续失败才逐步放慢到最长 1 小时。
>
> **Beta 13 · Build 196**：组件库只保留“切换器”和“用量”两种组件。Mac 状态统一由每秒刷新的桌面实时悬浮卡片显示（打开应用自动出现），不再提供约 5 分钟才更新的定时小组件，避免误加。修复多显示器时实时卡片重启后跳到其他屏幕的问题：现在会记住确切位置，位置不可见时自动回到主屏幕。
>
> **Beta 12 · Build 194**：组件库为“切换器”“用量”“Mac 状态”三种组件；Mac 状态小组件（约 5 分钟更新）与每秒刷新的桌面悬浮卡片可二选一或同时使用。
>
> **Beta 11 · Build 192**：组件库精简为“切换器”和“用量”两种组件（原有 9 种、约 20 个尺寸选项），移除重复的用量历史、Mac 状态小组件，以及订阅账户用不上的指标、消耗趋势、账户用量组件；升级后桌面上的空白旧卡片右键移除即可。
>
> **Beta 10 · Build 191**：改为优化编译的正式版（Release），内存占用约降低 25%、CPU 约降低 70%，安装包从 280 MB 缩小到 115 MB。存储“可用空间”改为与 Finder 一致（包含系统可回收空间）。实时 Mac 卡片可在“设置 › 通用”中关闭，或右键卡片隐藏；锁屏、休眠或被全屏窗口遮挡时自动暂停采样，外接显示器断开后自动回到可见位置。Claude 后台读取失败时退避 15 分钟起、最长 1 小时，避免频繁重试被限流。修复上游 OpenAI 网页缓存清理在 macOS 26 上的崩溃。

## 桌面预览

**当前下载版本：AI Monitor Beta 14（Build 197）** · [下载 macOS 安装包](https://github.com/hui77anna/AI-Monitor/releases/download/v0.1.0-beta.14/AI-Monitor-0.1.0-beta.14-macos-arm64.dmg)

安装后在“编辑小组件”左侧选择 **AI Monitor**。旧 Studio 用户若仍看到旧名称，请参阅[名称缓存处理说明](INSTALL.zh-CN.md#升级后左侧仍显示-codexbar-studio)。

<table>
<tr>
<td width="50%" align="center"><strong>AI Monitor · Codex · 额度与七日用量</strong></td>
<td width="50%" align="center"><strong>AI Monitor · Claude · 额度与七日用量</strong></td>
</tr>
<tr>
<td><img src="docs/ai-monitor/ai-monitor-beta3-codex-large.png" alt="Codex 大号卡片：分段额度条、重置时间与紫色七日用量图" width="100%"></td>
<td><img src="docs/ai-monitor/ai-monitor-beta3-claude-large.png" alt="Claude 大号卡片：橙色额度条与七日用量图" width="100%"></td>
</tr>
<tr>
<td align="center"><strong>AI Monitor · Mac 实时悬浮卡片</strong></td>
<td align="center"><strong>AI Monitor · 紧凑布局 · Claude 中号卡片</strong></td>
</tr>
<tr>
<td><img src="docs/ai-monitor/ai-monitor-live-mac.png" alt="Mac 实时悬浮卡片：CPU、内存、Swap、压力与可用存储" width="100%"></td>
<td><img src="docs/ai-monitor/ai-monitor-beta3-claude-medium.png" alt="Claude 中号卡片：五小时与每周额度" width="100%"></td>
</tr>
</table>

<sub>以上图片于 2026-11-16 从实际 SwiftUI 组件代码渲染：额度卡片对应 Beta 3，Mac 状态为 Beta 6 实时悬浮卡片；额度卡片外观未改动，使用明确的示例数据展示布局，不是设计稿，也不是任何用户的实际额度。实际显示内容取决于账户、数据来源和系统配色。[截图生成方式](docs/ai-monitor/SCREENSHOTS.md)</sub>

## 为日常使用设计

| 能力 | 使用体验 |
| --- | --- |
| **额度概览** | 分段进度条显示来源提供的额度比例，配合重置时间查看当前用量窗口。 |
| **七日用量** | 大号卡片提供 token 历史图，保留日期空缺，区分无记录与零用量。 |
| **精简组件库** | 组件库只提供“切换器”和“用量”（小／中／大）；Mac 状态由每秒刷新的实时悬浮卡片显示，打开应用自动出现。 |
| **本机状态** | 实时悬浮卡片：CPU / 内存约每秒更新、磁盘每 30 秒更新。 |
| **原生桌面集成** | 通过 macOS 小组件库添加；支持系统全彩、单色与染色外观。 |
| **成熟的接入基础** | 复用 CodexBar 的提供方适配、账户处理与刷新机制，无需另开一套中转程序。 |

## 三步开始

1. **安装应用**：下载 DMG，将 `AI Monitor.app` 拖入“应用程序”，然后打开。应用常驻菜单栏。
2. **连接账户**：先在 Codex / Claude Code 中登录自己的账户，再在应用设置中启用对应提供方。
3. **添加组件**：桌面右键 → **编辑小组件** → 搜索 **AI Monitor**，添加“用量”或“切换器”。

Mac 实时悬浮卡片在应用启动时自动出现，无需从小组件库添加。推荐组合：Codex 大号 + Claude 中号 + Mac 实时悬浮卡片。使用大号卡片可以查看更多历史记录；首次安装没有历史时，图表可能为空。

> **当前发布状态：公开测试版。** 支持 Apple Silicon 与 macOS 14+；Intel 暂不支持。安装包已完成本机签名、运行与完整性检查，尚未做 Apple Developer ID 公证或异机安装验收。首次启动可能需要按 macOS 提示确认。[安装与故障排查](INSTALL.zh-CN.md)

## 数据从哪里来

AI Monitor 定制桌面展示，额度读取沿用 CodexBar。主程序取回并整理数据，通过本机 App Group 快照交给 WidgetKit；Mac 状态卡片直接采样本机系统指标。

```mermaid
flowchart LR
    A["Codex / Claude 数据来源"] --> B["CodexBar 接入与刷新逻辑"]
    B --> C["本机共享快照"]
    C --> D["AI Monitor 桌面卡片"]
    E["macOS 系统计数器"] --> F["Mac 状态采样"]
    F --> D
    G["WidgetKit 系统调度"] -. "控制实际展示时机" .-> D
```

**准确性与更新速度是两件事。** 本定制版不重新估算平台额度；数据是否完整取决于来源，何时显示取决于取数缓存、刷新周期与系统调度。Claude CLI 后台路径有 5 分钟最小间隔；Mac 实时悬浮卡片的 CPU / 内存约每秒采样、磁盘每 30 秒读取；AI 额度不代表秒级实时。

[阅读架构、数据口径与刷新机制 →](ARCHITECTURE.md)

## 更新频率

| 组件 | 数据多久更新 | 说明 |
| --- | --- | --- |
| **Codex 额度**（切换器／用量卡片） | 约 **5 分钟** | 应用每 5 分钟取一次新额度，取到后立即通知桌面组件刷新。 |
| **Claude 额度**（切换器／用量卡片） | 约 **5 分钟** | 同上；偶尔读取失败时继续显示上次的额度（右上角显示数据时间），5 分钟后重试；连续失败才逐步放慢，最长 1 小时，避免被平台限流。 |
| **7 日用量柱状图**（大号用量卡片） | 约 **15 分钟** | 统计本机 token 记录，计算量较大，间隔较长。 |
| **Mac 实时悬浮卡片** | CPU、内存 **每 1 秒**；存储每 30 秒 | 应用自带的桌面卡片，实时显示；可在“设置 › 通用”中开关。 |

- 以上是应用取数据的间隔。桌面小组件何时重绘由 macOS 决定，偶尔会稍晚；即使没收到刷新通知，组件最长 30 分钟也会自行刷新一次。
- 卡片右上角的时间是这份数据的更新时间，可据此判断数据新旧。
- 需要立即查看最新数据时，点击菜单栏的 AI Monitor 图标，再点“刷新”。

## 项目与发布信息

| 项目 | 当前状态 |
| --- | --- |
| 对外版本 | `0.1.0-beta.14` |
| 应用内部版本 | `0.84.1` / Build `190`，保留上游版本以追踪兼容性 |
| 上游基线 | [steipete/CodexBar · 7447bc7](https://github.com/steipete/CodexBar/commit/7447bc77c2497323d9c41e40164ce705533493c8) |
| 主要变更 | 桌面卡片 UI、Mac 实时状态、Claude 五分钟额度缓存、显示名称与打包脚本 |
| 更新方式 | 从本仓库 Releases 手动下载，当前不启用自动更新 |
| 问题反馈 | [GitHub Issues](https://github.com/hui77anna/AI-Monitor/issues) |

安装包不附带开发者的账户配置、登录凭据或用量历史。额度查询仍需用户自己的授权；开源代码可供审阅，但不等于独立安全审计。[安全与隐私说明](SECURITY-AI-MONITOR.md)

<details>
<summary><strong>常见问题</strong></summary>

**安装后就是截图里的 UI 吗？**
是同一套组件视图。数值、可用字段与历史记录来自你的账户；系统单色或染色设置会改变颜色。

**这是 CodexBar 官方版本吗？**
不是。AI Monitor 是基于 CodexBar 的社区定制版，原名 CodexBar Studio，保留上游数据能力并修改桌面展示。

**是否需要同时运行原版 CodexBar？**
不需要。AI Monitor 包含完整主程序。请退出旧 CodexBar Studio，避免重复运行；本版保留主程序账户设置兼容性，并沿用 CodexBar 配置路径；组件已采用独立扩展标识，旧卡片需重新添加一次。

**为什么数字没有立即变化？**
提供方缓存、后台轮询与 WidgetKit 分别控制不同阶段。平台额度与本地 token 记录的更新时机也不同，详情见架构文档。

**能看到其他人的用量吗？**
安装包不会提供其他人的账户或数据。默认展示本机已授权数据来源的结果。

</details>

## 文档与致谢

[安装指南](INSTALL.zh-CN.md) · [架构设计](ARCHITECTURE.md) · [源码构建](BUILD.md) · [版本验证](docs/ai-monitor/RELEASE-VALIDATION.md) · [安全说明](SECURITY-AI-MONITOR.md)

感谢 [CodexBar](https://github.com/steipete/CodexBar) 作者及贡献者提供基础实现。本项目保留 [MIT 许可证与上游版权声明](LICENSE)，原项目文档见 [README.upstream.md](README.upstream.md)。产品标识归各自权利人；本项目与 OpenAI、Anthropic 及参考图片作者不存在官方合作关系。
