# AI Monitor 截图与示例数据

当前首页图片于 2026-11-16 使用 Beta 3 / Build 184 对应组件源码生成。卡片内 Codex、Claude 为提供方名称，产品名称统一为 AI Monitor。使用新文件名，避免旧图片缓存。

首页图片由本项目当前 SwiftUI 视图通过 `ImageRenderer` 直接生成，使用测试中显式定义的合成数据。图片用于展示已实现的布局，不是账户连接或实时刷新成功的证明。

| 文件 | 内容 |
| --- | --- |
| `ai-monitor-beta3-codex-large.png` | Codex 大号额度与七日用量 |
| `ai-monitor-beta3-claude-large.png` | Claude 大号额度与七日用量 |
| `ai-monitor-beta3-claude-medium.png` | Claude 中号额度 |
| `ai-monitor-beta4-mac-status.png` | Mac 状态中号卡片 |

生成入口：[StudioWidgetRenderTests.swift](../../Tests/CodexBarTests/StudioWidgetRenderTests.swift)。测试用例名称保留原 Studio 名称以便追踪代码历史。

```sh
CODEXBAR_WIDGET_PROOF_DIR=/absolute/path/to/screenshots \
swift test --filter StudioWidgetRenderTests
```

截图使用暗色、中文环境和 2 倍渲染比例。卡片内时间随生成时刻变化，历史图使用固定日期示例。实际桌面由 WidgetKit 托管，尺寸、字体与系统染色效果可能随系统版本及设置变化。

不公开实际账户截图，避免在项目介绍中带出用户身份和使用记录。

Mac 状态截图已更新为 Beta 4 / Build 185，包含内存、Swap、压力等级及磁盘总容量。其余卡片外观未改动。
