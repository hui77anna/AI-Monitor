# Beta 2：切换黑屏的根因与修复

日期：2026-11-15。修复版本：`0.1.0-beta.2`，内部 Build `183`。

## 根因：改名后的扩展启动路径冲突

旧版将应用从 `/Applications/CodexBar Studio.app` 改名为 `/Applications/AI Monitor.app`，但继续使用同一个组件扩展 Bundle ID。系统 `chronod` 宿主中的 `launchd` 服务已经注册了旧路径；随后收到新路径注册时选择继续使用旧记录。旧应用已移走，扩展因找不到可执行文件而启动失败。

箭头切换触发组件重新加载，因此暴露为卡片只剩黑底；不是额度接口失败，也不是卡片绘制计算导致的崩溃。

### 关键系统日志（仅保留相关应用路径）

```text
Attempt to re-bootstrap service from different path, will use existing:
  service = com.steipete.codexbar.debug.widget
  existing = /Applications/CodexBar Studio.app/Contents/PlugIns/CodexBarWidget.appex
  conflicting = /Applications/AI Monitor.app/Contents/PlugIns/CodexBarWidget.appex

Could not find and/or execute program specified by service:
  2: No such file or directory:
  /Applications/CodexBar Studio.app/Contents/PlugIns/CodexBarWidget.appex/Contents/MacOS/CodexBarWidget
```

此前重启 `chronod` 后恢复，是因为旧启动服务记录被释放。它验证了故障链条，但不能代替产品安装身份修复。

## 修复内容

1. **独立的组件扩展身份**：构建时改为 `com.steipete.codexbar.debug.aimonitor.widget`，不复用旧 Studio 的启动服务。
2. **固定安装路径**：统一 `/Applications/AI Monitor.app`，后续在原位更新，避免运行中改名。
3. **构建产物校验**：若跳过构建却拿到旧扩展身份，立即拒绝打包；进一步核对主程序/组件版本、共享组、可执行文件与签名。
4. **明确迁移流程**：旧卡片移除后重新添加一次；账户读取和共享数据组保持兼容。提供带备份的开发者安装脚本，正常运行不靠自动重启系统服务掩盖故障。

## 真实桌面回归

全部在本机真实 NotificationCenter 桌面组件上点击箭头完成，使用实际账户快照。每次切换检查：目标提供方被选中、额度与历史内容存在、组件属于新的扩展 ID。

| 场景 | 切换次数 | 结果 |
| --- | ---: | --- |
| 大号组件连续往返 | 20 | 20 / 20 通过 |
| 主程序退出后 | 10 | 10 / 10 通过 |
| 主程序重新启动后 | 10 | 10 / 10 通过 |
| 主动结束组件扩展、由系统重新启动 | 10 | 10 / 10 通过 |
| 同路径原位重装后 | 10 | 10 / 10 通过 |
| **合计** | **60** | **60 / 60 通过，无黑屏** |

[逐次记录](switch-regression-0.1.0-beta.2.json) 只包含场景、目标提供方、通过状态、耗时与时间，不包含账户标识、额度或凭据。

另外，旧安装包被新增身份校验正确拒绝；新版身份、共享组与签名校验通过。`make check` 通过。测试期间的新扩展日志未出现旧路径冲突或扩展启动失败。

## 适用范围

这次证据定位并修复的是 **Studio 改名迁移导致的旧路径启动冲突**。首次安装不具备同样的旧路径前提，但新版仍使用独立身份防止继承此冲突。

60 次回归不是所有系统环境的零故障保证。另一台全新 Mac、不同 macOS 版本以及 Apple Developer ID 公证仍未完成；不将本机结果表述为全平台验收。新版本继续作为公开测试版分发。
