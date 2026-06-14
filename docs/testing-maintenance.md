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

当前主脚本已经拆成多个低风险模块。短期继续通过以下规则控制复杂度：

- 新增业务规则时，优先补 `-SelfTest`。
- 新增脚本时，必须能通过项目级语法检查。
- 新增资源时，更新 `Invoke-AutomatedChecks.ps1` 的资源检查。
- 新增隐藏交互时，同步更新帮助文案和 `docs/project-charter.md`。
- 不在 UI 渲染函数里直接写复杂数据规则；数据规则应放在任务或番茄相关函数中。
- `modules/UiText.ps1` 只放文案和文案选择函数。
- `modules/AppState.ps1` 放 `$App` 状态容器初始化和路径访问 helper；新增路径必须先进入 `$App.Paths`。
- `modules/Storage.ps1` 只放目录、文件、JSON、锁和通用对象 helper；业务模块通过 `Get-AppPath` 取路径。
- `modules/SettingsStore.ps1` 只放设置默认值、归一化、读取和保存。
- `modules/TaskModel.ps1` 放任务对象默认值、输入解析和任务结果对象。
- `modules/TaskStore.ps1` 只放任务读写和迁移保存。
- `modules/TaskQueries.ps1` 只放任务查询。
- `modules/TaskOrdering.ps1` 只放排序、插入和拖拽移动规则。
- `modules/TaskCommands.ps1` 只放新增、完成、归档、今日安排等命令。
- `modules/PomodoroEngine.ps1` 放番茄状态流转；不要放音频、UI 闪烁或记录写入细节。
- `modules/PomodoroRecords.ps1` 放番茄 JSONL 记录。
- `modules/PomodoroAudio.ps1` 放声音资源解析、试听和背景音控制。
- `modules/PomodoroEffects.ps1` 放番茄结束提醒的 UI 效果。
- `modules/UiTimer.ps1` 放日期刷新和全局 tick 入口。
- `modules/BottomChrome.ps1` 放底部导航显隐。
- `modules/WindowSize.ps1` 放单行/多行窗口高度和尺寸按钮。
- `modules/WindowDrag.ps1` 放窗口拖动。
- `modules/HelpSurface.ps1` 放帮助按钮、帮助菜单和帮助弹窗。
- `modules/WatermarkMode.ps1` 放水印模式、穿透和水印退出点。
- `modules/Views.Core.ps1` 放状态栏、通用按钮、导航和结果对象 UI 处理。
- `modules/Views.Task.ps1` 放任务列表渲染和列表交互入口。
- `modules/Views.Task.Controls.ps1` 放任务预览、链接打开和详情输入控件。
- `modules/Views.Task.ListDrawing.ps1` 放任务列表 owner-draw 绘制。
- `modules/Views.Timer.ps1` 放计时器视图和 timer label 更新。
- `modules/Views.More.ps1` 放更多页和已完成页。
- `modules/Views.Settings.ps1` 放设置页、设置行 helper 和音频选择控件。

资源策略：

- 普通状态 UI 定时器使用 1000ms，匹配秒级倒计时。
- 水印模式临时切到 250ms，用于保持穿透退出点的响应。
- 鼠标显隐依赖 MouseMove/MouseEnter 事件，避免用高频定时器轮询普通交互。

## 后续可维护性路线

当前已完成多轮模块化。后续拆分应聚焦继续降低模块之间的隐式耦合：

1. 将 UI 控件引用和计时状态继续从散落的 `$script:` 迁移到 `$App.Ui`、`$App.Window` 和 `$App.Timer`。
2. 继续减少 `TaskPomodoro.ps1` 中的 UI 初始化体积，保持它只负责路径、模块加载、初始化和主事件循环。
3. 为 `Views.Task.ps1`、`Views.Timer.ps1`、`Views.Settings.ps1` 建立更明确的手动冒烟清单。
4. 新增业务行为时优先返回结果对象，由 `Views.Core.ps1` 统一解释为 UI 行为。
5. 新增模块时同步更新模块加载顺序、行数门禁和架构边界检查。

拆分前的原则是：先用测试固定行为，再移动代码。不要在同一次改动里同时拆模块和改产品行为。
