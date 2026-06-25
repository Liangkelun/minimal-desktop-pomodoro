# 自动化测试与可维护性安排

最后更新：2026-06-22

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

当前自测覆盖任务过滤、今日安排、排序、插入、编辑、默认动作、列表选择、窗口行数、虚化模式、翻译增强设置默认值/词典/生命周期/布局保持、3 分钟破冰启动（含可配置时长）和归档。自测会保存并恢复用户数据，不能留下 `__selftest` 任务。

### L4 手动冒烟

涉及 UI 布局、虚化穿透、窗口拖动、音频播放和长期常驻时，仍需要手动冒烟：

1. 启动应用。
2. 添加一个任务。
3. 安排到今日。
4. 从今日任务启动番茄钟，确认仍停留在今日任务页，并且当前任务行右侧显示 `mm:ss` 倒计时。
5. 番茄进入休息后，确认同一任务行右侧继续显示休息倒计时；独立番茄和独立休息不显示到任何任务行。
6. 在设置页调整“破冰启动”的时长、期间音乐和结束默认；从今日任务右键选择“先做 3 分钟”，确认右侧倒计时外形一致但不计入番茄，结束后可继续番茄、再做 3 分钟、完成或停止。
7. 暂停、继续、停止。
8. 进入和退出虚化模式。
9. 从 `~` 右键进入翻译，确认窗口布局和字号不变；双击 `public`、`true`、`example` 等英文单词时显示本地释义；进入或退出虚化不应改变翻译生命周期，点击 `停止翻译` 后翻译浮层、UIA timer 和可选剪贴板监听全部停止。
10. 启用剪贴板监听后，在翻译模式中手动复制英文单词可触发翻译；应用不写剪贴板、不模拟 `Ctrl+C`、不做复制恢复。
11. 右键 `翻译设置` 打开局部设置面板，保存后返回原窗口/翻译状态。
12. 调整 1 行和 10 行窗口高度。
13. 关闭并重开，确认数据保留。

### L5 资源采样

在需要评估常驻资源占用时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Measure-RuntimeFootprint.ps1 -DurationSeconds 300 -SampleSeconds 5 -ReportPath .\task-pomodoro\reports\runtime-footprint.json
```

静止态、番茄钟进行中、破冰启动进行中分别采样。脚本会输出 working set、private memory 和 CPU 的 min/max/avg，并可用阈值参数让检查失败。


## 维护边界

当前主脚本已经拆成多个低风险模块。短期继续通过以下规则控制复杂度：

- 新增业务规则时，优先补 `-SelfTest`。
- 新增脚本时，必须能通过项目级语法检查。
- 新增资源时，更新 `Invoke-AutomatedChecks.ps1` 的资源检查。
- 新增隐藏交互时，同步更新帮助文案和 `docs/project-charter.md`。
- 窗口、虚化和翻译相关切片还必须同时覆盖两类断言：主窗口布局/任务字号/当前视图保持不变，以及 timer/listener/浮层/缓存能在停止路径统一释放。
- 不在 UI 渲染函数里直接写复杂数据规则；数据规则应放在任务或番茄相关函数中。
- `modules/UiText.ps1` 只放文案和文案选择函数。
- `modules/AppState.ps1` 放 `$App` 状态容器初始化和路径访问 helper；新增路径必须先进入 `$App.Paths`。
- `modules/Storage.ps1` 只放目录、文件、JSON、锁和通用对象 helper；业务模块通过 `Get-AppPath` 取路径。
- `modules/SettingsSchema.ps1` 放设置默认值、归一化和输入裁剪规则。
- `modules/SettingsStore.ps1` 只放设置读取、重置和保存，不承载 schema 规则。
- `modules/TaskModel.ps1` 放任务对象默认值、输入解析和任务结果对象。
- `modules/TaskStore.ps1` 只放任务读写和迁移保存。
- `modules/TaskQueries.ps1` 只放任务查询。
- `modules/TaskOrdering.ps1` 只放排序、插入和拖拽移动规则。
- `modules/TaskCommands.ps1` 只放新增、完成、归档、今日安排等任务命令；不得调用番茄或破冰状态机。
- `modules/TaskWorkflow.ps1` 放任务 UI 意图到任务命令的轻量工作流包装，不承载 WinForms 控件；普通任务默认动作在这里安排今日，今日页启动番茄由 UI 调 Pomodoro UI wrapper。
- `modules/AppResultEvents.ps1` 放 result object 的中立事件构造、合并和分发入口；`modules/PomodoroEvents.ps1` 放番茄事件对象 facade、语义构造函数和记录事件字段构造；二者都不承载具体音频、记录落盘、任务保存或 UI 副作用。
- `modules/PomodoroSession.ps1` 放番茄会话选项、轮次、自动下一轮覆盖和当前阶段时长选择；当前阶段判断和运行态秒数、计划分钟、结束时间写入应委托 `PomodoroRuntime.ps1`；Engine、设置对话框和自测只能通过 session facade 读取/推进连续轮次。
- `modules/PomodoroPlanning.ps1` 放任务剩余番茄估算、预计番茄补全规则、启动任务绑定对象，以及休息结束后的下一轮决策对象；Engine 和 Workflow 不应直接读写任务估算字段来决定当前绑定、补写计划或下一轮。
- `modules/PomodoroCoordinator.ps1` 放 result event 的番茄/计时副作用 handler，包括音频、提醒、记录、任务番茄计数和任务变更导致的计时器清理。
- `modules/PomodoroEngine.ps1` 放番茄状态机分支，只返回状态结果和事件；运行态字段写入委托 `PomodoroRuntime.ps1`，运行态读取通过 `PomodoroRuntime.Queries.ps1` 快照，不直接播放音频、闪烁 UI、写记录或保存任务。
- `modules/SelfTest.Pomodoro.ps1` 和 `modules/SelfTest.Tasks.ps1` 可验证番茄运行态结果，但断言应通过 `PomodoroRuntime.Queries.ps1` facade，而不是直接读取 runtime 私有字段。
- `modules/PomodoroWorkflow.ps1` 放番茄应用工作流编排、暂停/继续选择、完成通知发布、追加预计番茄入口，以及任务变更导致计时器失效的编排；运行态状态和当前任务读取应通过 `PomodoroRuntime.ps1` facade。
- `modules/PomodoroInlineCountdown.ps1` 放任务行倒计时只读投影，通过 `PomodoroRuntime.ps1` 查询快照，不启动计时、不写记录、不切换视图。
- `modules/PomodoroRuntime.ps1` 放番茄运行态字段写入 facade、阶段启动/暂停/继续/idle work 重置、设置/会话时长变更、设置保存后的运行态刷新、运行中 tick、剩余秒数推进、背景音淡出阶段传递和完成防重入；不直接刷新 UI 控件或弹对话框。
- `modules/PomodoroRuntime.Queries.ps1` 放番茄运行态只读查询 facade；可读取 runtime 私有字段，但不得写字段、播放音频、保存设置或渲染 UI；timer view、engine 和自测断言都应通过这里读取运行态。
- `modules/PomodoroRecords.ps1` 放番茄 JSONL 记录。
- `modules/AudioCatalog.ps1` 放内置音频目录、显示名和来源元数据。
- `modules/PomodoroAudio.ps1` 放声音资源解析、试听、背景音控制和最后 8 秒淡出；淡出策略接收阶段参数，不直接读取番茄运行态字段。
- `modules/PomodoroEffects.ps1` 放番茄结束提醒的 UI 效果。
- `modules/UiTimer.ps1` 放日期刷新和全局 tick 入口。
- `modules/PomodoroStarter.ps1` 放破冰状态机分支，只返回事件；运行态字段写入委托 `PomodoroRuntime.ps1`，运行态判断委托 `PomodoroRuntime.Queries.ps1`，不直接控制音频。
- `modules/BottomChrome.ps1` 放底部导航显隐。
- `modules/WindowSize.ps1` 放单行/多行窗口高度换算和尺寸按钮状态；运行中窗口高度、padding 和最小尺寸读写应委托 `WindowStateCoordinator.ps1`。
- `modules/HelpSurface.ps1` 放帮助按钮、帮助菜单和帮助弹窗。
- `modules/WatermarkGhostSurface.ps1` 放虚化状态的透明背景文字层。
- `modules/WindowStateCoordinator.ps1` 放主窗口位置、尺寸、置顶、透明度、窗口字段持久化选择和虚化前布局快照保存/恢复。
- `modules/WindowPlacement.ps1` 放窗口启动/恢复时的安全落点和屏幕工作区计算；不读写设置，不触碰虚化、翻译或任务行数尺寸。
- `modules/WindowChrome.ps1` 放运行中主窗体 chrome facade：透明度、置顶、虚化标志、退出热区和点击穿透；虚化模块不得直接访问这些 `Form` chrome 字段。
- `modules/WindowDrag.ps1` 放窗口拖动手势和位移计算；运行中窗口位置读取/写入应委托 `WindowStateCoordinator.ps1`，不直接访问 `Form.Location`。
- `modules/WatermarkRuntime.ps1` 放虚化 runtime 对外 facade。
- `modules/WatermarkMode.ps1` 放虚化模式和虚化布局生命周期，不创建 `~` 按钮，不直接写主窗体 chrome。
- `modules/WatermarkToggleButton.ps1` 放 `~` 按钮创建、显隐、拖动手势和退出区域命中判断。
- `modules/WatermarkMode.Menu.ps1` 放 `~` 菜单接线，不直接读取翻译 runtime 私有变量。
- `modules/TranslationRuntime.ps1` 放翻译 runtime、启动/停止、活动状态、UIA timer、listener 接线、设置暂停/恢复、只读状态 facade 和统一清理边界。
- `modules/TranslationWorkflow.ps1` 放翻译请求编排、防抖、最近请求/已显示状态和翻译完成/失败通知；私有状态使用 `TranslationWorkflow*` 命名。
- `modules/TranslationBridge.ps1` 放翻译 selection/workflow/surface 的中立接线：注册通知 handler、转发文本请求和处理选区 tick；不拥有 timer、词典或 API provider。
- `modules/TranslationRules.ps1` 放文本过滤、选择分类和翻译结果对象模型。
- `modules/TranslationLookup.ps1` 放内存缓存、本地词典、在线 provider 查询顺序和未命中提示选择。
- `modules/TranslationDictionary.ps1` 放本地词典路径、加载、词形候选、短释义转换和离线查词。
- `modules/TranslationSurface.ps1` 放短释义浮层、详细面板、字体、定位、显示/隐藏 timer 和释放逻辑，私有状态使用 `TranslationSurface*` 命名，不修改主窗口布局或任务字号。
- `modules/TranslationSelection.ps1` 放 UIA 选区读取、可选只读剪贴板监听和文本回调接线，不写剪贴板。
- `modules/TranslationProviders.ps1` 放自定义接口、DeepL、百度、字符额度和最近错误更新，不承载 UI 或取词。
- `modules/WatermarkTranslation.ps1` 暂作翻译历史兼容入口，只保留旧函数名 wrapper；通知/选区/surface 接线属于 `TranslationBridge.ps1`，启动/停止资源所有权属于 `TranslationRuntime.ps1`。
- `modules/WatermarkTranslation.Surface.ps1` 只保留历史兼容 wrapper，新浮层实现不得继续写回该文件。
- `modules/TranslationSettings.ps1` 放局部翻译设置对话框、设置控件、测试连接和词典导入；不直接拥有 runtime timer/listener，不写主窗口字段。
- `modules/WatermarkTranslation.Settings.ps1` 只保留历史设置函数名 wrapper；翻译设置 UI 实现已收敛到 `TranslationSettings.ps1`。
- `modules/TranslationPlatform.ps1` 放 DPAPI、Win32 native type、无焦点浮层基类和点击穿透等平台 helper；不承载取词、查询或 UI 策略。
- `modules/WatermarkTranslation.Platform.ps1` 只保留历史平台函数名 wrapper；UIA/剪贴板读取已收敛到 `TranslationSelection.ps1`。
- `modules/WatermarkTranslation.Dictionary.ps1` 只保留历史词典函数名兼容 wrapper；本地词典实现已收敛到 `TranslationDictionary.ps1`。
- `scripts/AutomatedChecks.LegacyTranslation.ps1` 固化 `WatermarkTranslation*` compatibility-only 规则，禁止真实翻译实现回流到历史虚化命名文件。
- `modules/Views.Core.ps1` 放状态栏、通用按钮、导航和结果对象 UI 处理。
- `modules/Views.Task.ps1` 放任务列表视图装配和事件绑定入口。
- `modules/Views.Task.Interactions.ps1` 放任务列表默认点击动作和 Mouse/Drag/DoubleClick 高层交互流程；不得直接调用任务命令或番茄状态机，不内联 WinForms 手势 mechanics。
- `modules/Views.Task.Gestures.ps1` 放任务列表点击/拖动手势 mechanics：双击区域、点击状态、拖动阈值、拖拽数据和目标索引；不得调用菜单、workflow、编辑器或任务渲染。
- `modules/Views.Task.Items.ps1` 放任务查询结果到 ListBox item 的 UI 投影、显示编号和空列表占位；不得创建控件或调用任务/番茄 workflow。
- `modules/Views.Task.Events.ps1` 放任务列表 Mouse/Drag/DoubleClick/Selection 事件接线；不得创建布局、投影 item 或构造菜单。
- `modules/Views.Task.Controls.ps1` 放任务预览、链接打开和详情输入控件。
- `modules/Views.Task.ListDrawing.ps1` 放任务列表 owner-draw 绘制。
- `modules/Views.Timer.ps1` 放计时器视图和 timer label 更新；不承载跨视图番茄启动/完成动作包装；通过 `PomodoroRuntime.Queries.ps1` 的 timer view 快照读取运行态。
- `modules/Views.Timer.Actions.ps1` 放番茄启动、追加番茄提示、自动完成等 UI 动作包装；可用输入框/消息框，但必须委托给 `PomodoroWorkflow`，运行态判断应通过 `PomodoroRuntime.Queries.ps1`。
- `modules/Views.Timer.Starter.ps1` 放 3 分钟破冰结束后的动作对话框；当前绑定任务读取应通过 `PomodoroRuntime.Queries.ps1` facade。
- `modules/Views.More.ps1` 放更多页和已完成页。
- `modules/Views.Settings.ps1` 放设置页布局和保存按钮接线。
- `modules/Views.Settings.Controls.ps1` 放设置行 helper、音频选择控件和通用控件 helper。
- `modules/Views.Settings.Starter.ps1` 放破冰启动的简化设置区。
- `modules/Views.Settings.Apply.ps1` 放设置控件到 `$script:Settings`、音频状态和保存流程的映射；不得拥有番茄运行态秒数、计划分钟或结束时间字段写入。

检查耗时说明：

- 完整 `Invoke-AutomatedChecks.ps1` 当前可能耗时 5 分钟以上，主要成本来自主脚本 `-SelfTest` 的 WinForms/任务流程冒烟。日常小切片优先先跑相关 `AutomatedChecks.*` 边界检查、语法检查和 `git diff --check`，收口时再跑完整检查；窗口状态边界检查已拆入 `AutomatedChecks.WindowState.ps1`，任务列表/菜单边界检查已拆入 `AutomatedChecks.TaskMenu.ps1`，设置视图边界检查已拆入 `AutomatedChecks.SettingsView.ps1`，翻译模块边界检查已拆入 `AutomatedChecks.WatermarkTranslation.ps1`，音频和通知边界检查已拆入 `AutomatedChecks.AudioPlayback.ps1` 与 `AutomatedChecks.NotificationHub.ps1`。
- 如果完整检查超时但分项检查和主脚本 `-SelfTest` 单独通过，应优先提高本地命令超时或拆分检查，而不是把超时解释为功能失败。
架构报警器：

- 自动检查中的 `File size guardrails` 分为硬门禁和软告警。
- 硬门禁用于核心状态、业务规则、持久化、番茄/翻译/虚化 runtime、设置存储、事件和边界检查脚本；这些文件超限时自动检查失败，必须拆分或解释后调整阈值。
- 软告警用于 UI 视图、文案表、模块加载顺序、发布脚本和检查编排；这些文件自然会随界面与资源清单增长，超限时只输出 `WARN`，不阻断自动检查。
- 软告警不是忽略项。发布前需要确认增长原因：如果只是文案、控件行或清单扩展，可以保留；如果开始混入状态机、持久化、副作用编排，应迁回对应 workflow/runtime/core 模块。
- 调整阈值时优先维护职责边界，再改数字。不要为了通过检查单纯抬高硬门禁。

资源策略：

- 普通状态 UI 定时器使用 1000ms，匹配秒级倒计时。
- 虚化模式临时切到 250ms，用于保持穿透退出点的响应。
- 翻译增强只在开启后使用 300ms UIA 轮询；剪贴板监听默认关闭，启用后只读用户复制造成的变化。
- 鼠标显隐依赖 MouseMove/MouseEnter 事件，避免用高频定时器轮询普通交互。
- 任务行倒计时只在已有 1000ms tick 中失效当前列表绘制，不新增高频 timer，不读写 JSON。
- 新增内置音频必须同步更新 `docs/audio-sources.md` 和音频目录自检。

## 后续可维护性路线

当前已完成多轮模块化。后续拆分应聚焦继续降低模块之间的隐式耦合：

1. 将 UI 控件引用和计时状态继续从散落的 `$script:` 迁移到 `$App.Ui`、`$App.Window` 和 `$App.Timer`。
2. 继续减少 `TaskPomodoro.ps1` 中的 UI 初始化体积，保持它只负责路径、模块加载、初始化和主事件循环。
3. 为 `Views.Task.ps1`、`Views.Timer.ps1`、`Views.Settings.ps1` 建立更明确的手动冒烟清单。
4. 新增业务行为时优先返回结果对象，由 `Views.Core.ps1` 统一解释为 UI 行为。
5. 新增模块时同步更新模块加载顺序、软硬架构报警器和架构边界检查。
6. 常驻资源相关改动后，补跑 `Measure-RuntimeFootprint.ps1`，并记录静止态、番茄钟过程和破冰启动过程的采样结果。


拆分前的原则是：先用测试固定行为，再移动代码。不要在同一次改动里同时拆模块和改产品行为。

## 收集箱与执行连续性测试

本轮新增 `收集`、行为事件、执行记录和昨日接续后，自动/自测至少覆盖：

- `inbox.json` 和 `behavior-events.jsonl` 缺失时自动初始化。
- 收集项新增、删除、转任务、安排今日行为正确，并写入对应行为事件。
- 任务创建、安排今日、取消今日、任务启动、番茄开始、番茄完成/中断、任务完成/取消写入最小行为事件。
- 执行记录可以从任务、番茄记录和行为事件聚合出已启动未完成、已完成/已取消两类任务；旧数据缺少事件时仍能显示。
- 昨日接续选择 `是` 时保留昨日 Today 未完成项；选择 `否` 时清空 Today；同一天不重复提示。
- 收集箱、执行记录和昨日接续不得影响普通任务、今日、番茄、虚化和翻译原有自测。

手动冒烟补充：

1. 切到底部 `收集` 页，输入新想法。
2. 双击收集项转为正式任务，确认从收集页消失并出现在任务页。
3. 右键收集项选择安排今日，确认新任务出现在 Today。
4. 启动并完成一个番茄，确认执行记录显示最近推进和完成信息。
5. 模拟跨日，分别验证昨日接续 `是` 和 `否`。
6. 确认翻译模式、虚化模式和剪贴板内容不受影响。
## 恢复统计与执行统计自测

本轮新增恢复统计和执行统计后，自动/自测至少覆盖：

- 同一任务 `pomodoro_interrupted -> pomodoro_started` 计为 1 次恢复成功；其他任务的开始不计入恢复。
- 加权中断次数按 0-5 分钟、5-10 分钟、超过 10 分钟或未接续分别计 1/2/3。
- 昨日接续提示统计昨日恢复成功次数，但不展示加权中断次数。
- 执行统计四行摘要包含恢复统计、番茄统计、启动/最近时间和专注时长。
- `执行统计` 的说明通过 `?` 打开，不与统计正文混排。
