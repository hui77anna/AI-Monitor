# 版本验证

## 0.1.0-beta.2 / Build 183

修复安装改名后的扩展旧路径冲突，已完成 60 次真实桌面切换，覆盖主程序退出/重启、扩展冷启动与原位重装。构建校验、签名、共享组检查及 `make check` 通过。[根因与完整回归记录](BLACK-SCREEN-FIX.md)。

## 0.1.0-beta.1 / Build 182（历史记录）

验证日期：2026-11-15。应用内部版本 `0.84.1`，构建号 `182`。

本页将已完成的本机检查与尚未覆盖的场景分别列出。验证结果只适用于本次构建与对应环境，不代表正式兼容性认证。

## 已完成

| 检查 | 结果与范围 |
| --- | --- |
| 构建 | Apple Silicon arm64 主程序与 WidgetKit 扩展成功打包。 |
| 代码规范与仓库检查 | `make check` 通过；SwiftLint 检查 3221 个文件，无违规。 |
| 组件布局与数据边界 | 专项渲染测试验证分段比例、越界数值与日期空缺，并生成页面展示图片。 |
| 签名完整性 | `codesign --verify --deep --strict` 通过。 |
| 安装镜像完整性 | `hdiutil verify` 通过。 |
| 本机运行 | 改名后的 AI Monitor 主程序运行，桌面组件归属名称更新，Mac 状态正常显示。 |
| 真实额度链路 | 同一数据接入实现此前完成本机 Codex / Claude 实际数据读取及 Claude 后台刷新验证；公开资料不包含账户截图。 |
| 上游复用 | 提供方核心代码、Package.swift 与 Package.resolved 对照上游基线保持一致。 |
| 公共发布 | Release 可公开访问，GitHub 记录的安装包 SHA256 与本地文件一致。 |

## 尚未完成

- Apple Developer ID 签名与公证。
- 另一台全新 Mac 上的首次安装、授权与组件添加验收。
- Intel 架构构建和验证。
- 多个 macOS 版本、不同套餐与不同账户来源的完整兼容性矩阵。
- 独立渗透测试或第三方安全审计。

## 发布文件

`AI-Monitor-0.1.0-beta.1-macos-arm64.dmg`

```text
SHA256 cd2e6bbe75d57d513d278079db92ba6697c799fd03be180b5d2da2125289ee08
```

安装包和源码均来自 [公开发布页](https://github.com/hui77anna/AI-Monitor/releases/tag/v0.1.0-beta.1)。本次文档完善不重新打包应用，不改变该版本的二进制文件。
