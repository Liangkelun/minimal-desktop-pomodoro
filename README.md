# 极简桌面番茄

极简桌面番茄是一个 Windows 本地优先的任务提醒与番茄钟工具。它不是完整任务管理平台，而是一个常驻桌面的今日执行面板。

## 定位

核心工作流：

```text
任务库 -> 今日承诺 -> 当前执行 -> 番茄专注 -> 完成任务 / 归档任务
```

适合场景：

- 在 Windows 桌面长期写代码、写文档、研究或学习
- 希望今日任务一直可见
- 希望番茄钟和当前任务轻量绑定
- 不需要账号、云同步、团队协作或复杂项目管理

## 启动

直接运行：

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\task-pomodoro\TaskPomodoro.ps1
```

无控制台启动：

```text
task-pomodoro\StartTaskPomodoro.vbs
```

安装桌面快捷方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\InstallDesktopShortcutIcon.ps1
```

## 数据位置

运行时数据保存在本地：

```text
task-pomodoro/data/tasks.json
task-pomodoro/data/pomodoros.jsonl
task-pomodoro/config/settings.json
```

这些文件包含个人任务和本机设置，不进入版本管理，也不会放入发布包。

## 自动化检查

每次改动后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1
```

检查内容包括：

- PowerShell 语法
- 模块加载顺序
- 架构边界
- 文件行数阈值
- 必要资源
- 运行时数据结构
- 损坏数据恢复
- 主脚本自测

## 发布包

生成发布包：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\New-ReleasePackage.ps1
```

发布包会排除个人数据、设置、日志和临时文件。

## 虚化模式

点击右上角 `~` 进入虚化模式。虚化模式下只保留透明背景上的任务文字层，并可点击穿透；右上角 `△` 是退出点。

如果误入虚化模式，移动鼠标到窗口右上角，点击 `△` 退出。

## 当前限制

- 仅面向 Windows PowerShell 5.1 + WinForms。
- 不提供云同步、移动端、团队协作。
- UI 自动化仍以自测和手动冒烟为主。
- 虚化、窗口拖动和音频播放仍建议发布前手动验证。

## 许可证

本项目使用 MIT License。见 [LICENSE](LICENSE)。
