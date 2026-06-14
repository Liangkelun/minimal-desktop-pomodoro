# 自动化测试与可维护性安排

最后更新：2026-06-14

## 目标

当前版本先建立轻量但可重复的质量闸门，避免每次改动都只依赖手动打开窗口验证。

质量闸门覆盖四类风险：

- PowerShell 语法错误
- 必要资源缺失
- 本地运行时数据损坏
- 主脚本核心自测失败

## 一键检查

推荐在每次改动后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1
```

默认情况下，项目级脚本会在临时副本中运行 `TaskPomodoro.ps1 -SelfTest`。这样可以覆盖主脚本自测，同时避免写入当前工作区的 `data/` 和 `config/`。

如果正在运行应用，且担心自测写入运行时数据，可先运行只读检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1 -SkipSelfTest
```

只有在明确需要验证当前工作区数据恢复逻辑时，才使用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1 -SelfTestInPlace
```

如果要生成机器可读结果：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1 -ReportPath .\task-pomodoro\data\test-results\latest.json
```

`data/test-results/` 属于运行时产物，不应进入版本管理。

## 测试分层

### L0 语法检查

解析 `TaskPomodoro.ps1`、`modules/*.ps1` 和 `scripts/*.ps1`。这是最便宜的检查，应该在任何代码改动后立即运行。

### L1 资源检查

确认启动脚本、默认音频和应用图标存在且非空。资源缺失会直接影响普通用户启动体验。

### L2 数据文件检查

检查 `tasks.json`、`settings.json`、`pomodoros.jsonl` 是否可解析，并校验关键字段。这个检查只读取数据，不修改数据。

### L3 主脚本自测

运行：

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\task-pomodoro\TaskPomodoro.ps1 -SelfTest
```

当前自测覆盖任务过滤、今日安排、排序、插入、编辑、默认动作、列表选择、窗口行数、水印模式和归档。自测会保存并恢复用户数据，不能留下 `__selftest` 任务。

### L4 手动冒烟

涉及 UI 布局、水印穿透、窗口拖动、音频播放和长期常驻时，仍需要手动冒烟：

1. 启动应用。
2. 添加一个任务。
3. 安排到今日。
4. 从今日任务启动番茄钟。
5. 暂停、继续、停止。
6. 进入和退出水印模式。
7. 调整 1 行和 10 行窗口高度。
8. 关闭并重开，确认数据保留。

## 维护边界

当前主脚本已经开始拆出低风险模块。短期继续通过以下规则控制复杂度：

- 新增业务规则时，优先补 `-SelfTest`。
- 新增脚本时，必须能通过项目级语法检查。
- 新增资源时，更新 `Invoke-AutomatedChecks.ps1` 的资源检查。
- 新增隐藏交互时，同步更新帮助文案和 `docs/project-charter.md`。
- 不在 UI 渲染函数里直接写复杂数据规则；数据规则应放在任务或番茄相关函数中。
- `modules/UiText.ps1` 只放文案和文案选择函数。
- `modules/Storage.ps1` 只放路径、文件、JSON 和通用对象 helper。
- `modules/SettingsStore.ps1` 只放设置默认值、归一化、读取和保存。
- `modules/TaskStore.ps1` 放任务模型、任务状态变更、排序和任务格式化。
- `modules/PomodoroEngine.ps1` 放番茄状态机、番茄记录、音频和提醒触发。
- `modules/WindowBehavior.ps1` 放窗口拖动、尺寸、底栏显隐、水印和穿透行为。
- `modules/Views.Core.ps1` 放状态栏、通用按钮、导航和结果对象 UI 处理。
- `modules/Views.Task.ps1` 放任务列表、任务菜单、任务编辑入口。
- `modules/Views.Timer.ps1` 放计时器视图和 timer label 更新。
- `modules/Views.More.ps1` 放更多页和已完成页。
- `modules/Views.Settings.ps1` 放设置页、设置行 helper 和音频选择控件。

资源策略：

- 普通状态 UI 定时器使用 1000ms，匹配秒级倒计时。
- 水印模式临时切到 250ms，用于保持穿透退出点的响应。
- 鼠标显隐依赖 MouseMove/MouseEnter 事件，避免用高频定时器轮询普通交互。

## 后续可维护性路线

当前已完成第一轮模块化。后续拆分应聚焦降低模块之间的隐式耦合：

1. 将 `$script:` 全局状态逐步收敛到 `$App` 状态对象。
2. 继续减少 `PomodoroEngine.ps1` 对具体 WinForms 控件存在性的假设，尤其是提醒闪烁部分。
3. 为 `Views.Task.ps1`、`Views.Timer.ps1`、`Views.Settings.ps1` 建立更明确的手动冒烟清单。
4. 保持 `TaskPomodoro.ps1` 只负责路径、模块加载、初始化和主事件循环。
5. 新增业务行为时优先返回结果对象，由 `Views.Core.ps1` 统一解释为 UI 行为。

拆分前的原则是：先用测试固定行为，再移动代码。不要在同一次改动里同时拆模块和改产品行为。
