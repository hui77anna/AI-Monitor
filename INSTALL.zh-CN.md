# AI Monitor 安装说明

适用：macOS 14+，Apple Silicon Mac。Intel 不适用。版本 0.1.0-beta.1（内部构建 182，CodexBar 基线 0.84.1）。

## 安装

1. 从本仓库 Releases 下载 DMG，打开后将 AI Monitor.app 拖到 Applications。
2. 退出旧 CodexBar Studio，再打开 AI Monitor。应用常驻菜单栏，不会弹出普通主窗口。
3. 若 macOS 提示无法验证开发者，本版尚未公证。确认文件来源与 SHA256 后，可参考 [Apple 官方允许打开说明](https://support.apple.com/zh-cn/102445)，在“系统设置 → 隐私与安全性”中查看是否提供“仍要打开”。不要全局关闭 Gatekeeper。
4. 若系统仍拒绝运行或没有允许选项，请停止安装并报告具体系统提示；可自行从源码签名构建。本版只完成开发机器验证，尚无另一台干净 Mac 验收。

## 接入自己的额度

先安装并登录你自己的 Codex / Claude Code。打开菜单栏 AI Monitor（部分菜单仍标 CodexBar）的设置，启用 Codex、Claude。

Claude 如自动来源无数据，可选 CLI 来源，使用已登录的 Claude Code。登录失效需在 Claude Code 重新登录。钥匙串授权只在你选择对应读取方式且信任应用时允许，不需要把密码或令牌发给项目作者。

开发者账户、配置、用量历史不会随安装包分发。首次打开不保证已有数据；平台账户必须支持相应额度信息。

## 添加桌面组件

桌面右键 → 编辑小组件 → 搜索 AI Monitor：

- Mac 状态：中号。
- AI Monitor 用量：添加大号，编辑组件选择 Codex。
- AI Monitor 用量：再添加中号或大号，选择 Claude。

可在 macOS 的桌面与程序坞设置中选择小组件全彩样式。系统染色/单色模式会改变颜色。

如果刚安装后列表未出现，先确认应用已运行，再关闭并重新打开小组件库。已有 Studio 组件沿用相同内部身份；不要同时保留两个应用副本。

额度按上游取数和系统调度更新，不是实时仪表盘。无历史时显示空状态，不会拿示例图充当真实数据。
