# 截图与示例数据

首页图片由本项目当前 SwiftUI 视图通过 `ImageRenderer` 直接生成，使用测试中显式定义的合成数据。图片用于展示已实现的布局，不是账户连接或实时刷新成功的证明。

| 文件 | 内容 |
| --- | --- |
| `codex-large-sample.png` | Codex 大号额度与七日用量 |
| `claude-large-sample.png` | Claude 大号额度与七日用量 |
| `claude-medium-sample.png` | Claude 中号额度 |
| `mac-status-sample.png` | Mac 状态中号卡片 |

生成入口：[StudioWidgetRenderTests.swift](../../Tests/CodexBarTests/StudioWidgetRenderTests.swift)。测试用例名称保留原 Studio 名称以便追踪代码历史。

```sh
CODEXBAR_WIDGET_PROOF_DIR=/absolute/path/to/screenshots \
swift test --filter StudioWidgetRenderTests
```

截图使用暗色、中文环境和 2 倍渲染比例。卡片内时间随生成时刻变化，历史图使用固定日期示例。实际桌面由 WidgetKit 托管，尺寸、字体与系统染色效果可能随系统版本及设置变化。

不公开实际账户截图，避免在项目介绍中带出用户身份和使用记录。
