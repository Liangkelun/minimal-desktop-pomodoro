# 架构调整执行计划

最后更新：2026-06-22

## 目标

本计划把 [架构主文档](architecture.md) 中的 `Clean-lite + Event-lite` 目标拆成可逐步落地的代码切片。每一轮调整都必须先明确文档边界，再修改代码，再补自动检查或自测，避免通过局部补丁继续扩大耦合。

本轮不做完整 Clean Architecture 重写，不引入 Command Bus、Repository Port 或通用 Event Bus。优先解决当前最影响稳定性的架构问题：主窗口状态写入分散、虚化和翻译能力边界不清、设置保存容易带出窗口副作用。

## 执行状态总览

状态表示“边界是否已建立并进入自动检查/维护范围”，不表示相关历史模块已经完全重写。

| 切片 | 状态 | 后续关注点 |
| --- | --- | --- |
| 1. 窗口状态写入单点化 | 已建立 | 继续禁止翻译/局部设置顺带覆盖主窗口字段。 |
| 2. 虚化/翻译 runtime 正交化 | 已建立 | 翻译启动不得复用虚化进入流程；进入/退出虚化不得启动、停止或读取翻译生命周期。 |
| 3. 设置保存策略分层 | 已建立 | 新增设置保存路径必须选对 `SettingsWorkflow` facade。 |
| 4. 轻量事件通知 | 已建立 | 事件只做横切通知，不隐藏主业务顺序。 |
| 5. 任务 UI 工作流 facade | 已建立 | Views 中新增任务突变继续走 `TaskWorkflow`。 |
| 6. 番茄 UI 工作流 facade | 已建立 | UI 仍保留对话框，状态机调用继续经 `PomodoroWorkflow`。 |
| 7. WatermarkRuntime facade | 已建立 | 外部模块不得直接调用虚化实现函数。 |
| 8. TranslationWorkflow 事件化 | 已建立 | 翻译结果展示继续经通知和 surface facade。 |
| 9. PomodoroFinished 通知 | 已建立 | 不替代既有番茄结果事件，只作横切补充。 |
| 10. TranslationRuntime 设置暂停/恢复 | 已建立 | 翻译设置 UI 不直接持有 timer/listener。 |
| 11. 翻译模块去虚化命名与浮层边界 | 已建立 | 中立 `Translation*` 边界已覆盖浮层、取词、provider、规则、查询和 runtime；历史 `WatermarkTranslation*` 文件只保留兼容实现落点。 |
| 12. PomodoroRuntime tick 边界 | 已建立 | 番茄运行中 tick 已从 `UiTimer.ps1` 收敛到 `PomodoroRuntime.ps1`；后续继续迁移 `$script:` 状态所有权。 |
| 13. 任务默认动作跨领域边界 | 已建立 | `TaskCommands.ps1` 只保留任务命令；今日页默认启动番茄由 UI 调 `Start-PomodoroFromUi`，普通任务默认安排今日由 `TaskWorkflow` 编排。 |
| 14. AppResultEvents 中立边界 | 已建立 | 通用 result event 构造、合并和分发入口从 `PomodoroCoordinator.ps1` 拆到 `AppResultEvents.ps1`；番茄/计时副作用 handler 仍由 `PomodoroCoordinator.ps1` 承担。 |
| 15. 计时器 UI 动作包装边界 | 已建立 | `Views.Timer.ps1` 只保留计时器视图和标签刷新；`Start-PomodoroFromUi` / `Complete-PomodoroFromUi` 等跨视图 UI 动作移入 `Views.Timer.Actions.ps1`。 |
| 16. 任务列表交互策略边界 | 已建立 | `Views.Task.ps1` 只保留任务列表视图装配；默认点击动作和点击状态重置移入 `Views.Task.Interactions.ps1`，供列表、hover/拖动等模块复用。 |
| 17. 任务列表数据投影边界 | 已建立 | 将任务查询结果到 ListBox item 的 UI 投影移入 `Views.Task.Items.ps1`；`Views.Task.ps1` 不再直接选择今日/普通任务集合、编号或添加空占位行。 |
| 18. 任务列表事件接线边界 | 已建立 | 将任务列表 Mouse/Drag/DoubleClick 等事件注册移入 `Views.Task.Events.ps1`；`Views.Task.ps1` 只创建控件、填充 item 并调用注册函数。 |
| 19. 任务列表事件处理策略边界 | 已建立 | `Views.Task.Events.ps1` 只注册事件；MouseDown/Move/Drop/DoubleClick 等具体处理迁入 `Views.Task.Interactions.ps1`。 |
| 20. 任务列表点击手势判定边界 | 已建立 | 将双击、重命名候选和最后点击状态更新拆成 `Views.Task.Interactions.ps1` 内的命名 helper，降低 MouseDown 主流程复杂度。 |
| 21. 任务列表拖动判定边界 | 已建立 | 将拖动阈值、拖拽数据读取和目标索引计算拆成 `Views.Task.Interactions.ps1` 内的命名 helper，降低 MouseMove/DragDrop 复杂度。 |
| 22. 任务列表手势 mechanics 边界 | 已建立 | 将点击/拖动手势 helper 从 `Views.Task.Interactions.ps1` 迁入 `Views.Task.Gestures.ps1`；Interactions 只保留高层交互流程。 |
| 23. 虚化切换按钮 chrome 边界 | 已建立 | 将 `~` 按钮创建、显隐、拖动手势和命中判断从 `WatermarkMode.ps1` 迁入 `WatermarkToggleButton.ps1`；WatermarkMode 只保留虚化状态和布局生命周期。 |
| 24. 虚化布局快照归属边界 | 已建立 | 将虚化前窗口视图、位置、尺寸、置顶、透明度和内容区快照的保存/恢复/清理收敛到 `WindowStateCoordinator.ps1`；WatermarkMode 只请求快照操作。 |
| 25. 翻译浮层实现归属边界 | 已建立 | 将短释义浮层、详细面板、字体、定位和隐藏 timer 的实现迁入 `TranslationSurface.ps1`；历史 `WatermarkTranslation.Surface.ps1` 只保留兼容 wrapper。 |
| 26. 翻译 workflow 状态边界 | 已建立 | 将翻译请求防抖、已显示签名和最近来源状态的读写收敛到 `TranslationWorkflow.ps1`；runtime、surface 和历史入口只调用 workflow 状态函数。 |
| 27. 翻译 runtime 状态命名边界 | 已建立 | 将翻译活动标志和 UIA timer 句柄改为 `TranslationRuntime` 私有状态；自测和外部模块只能通过 runtime facade 读取。 |
| 28. 翻译启动零布局写入审计 | 已建立 | 翻译启动/停止/恢复路径不得调用主窗口布局、字号、视图、虚化进入或设置主保存路径；已进入静态边界检查。 |
| 29. 翻译字号与浮层状态隔离 | 已建立 | 翻译字号、短释义位置和详细面板位置只能属于 `TranslationSurface`/翻译设置；已用边界检查禁止复用任务字号或主窗口位置。 |
| 30. 历史翻译兼容层瘦身 | 已建立 | `WatermarkTranslation.Dictionary.ps1` 已退化为兼容 wrapper；本地词典实现进入 `TranslationDictionary.ps1`，lookup/selftest/runtime 调用中立函数。 |
| 31. 翻译私有状态中立命名 | 已建立 | `TranslationWorkflow.ps1` 和 `TranslationSurface.ps1` 内部状态改用中立 `Translation*` 命名；旧 `WatermarkTranslation*` 只保留为兼容函数名。 |
| 32. 翻译桥接层中立化 | 已建立 | `TranslationBridge.ps1` 接管 selection -> workflow -> notification -> surface 接线；`WatermarkTranslation.ps1` 退化为旧函数 wrapper。 |
| 33. 翻译设置对话框中立化 | 已建立 | `TranslationSettings.ps1` 接管翻译设置 UI、测试连接和词典导入；`WatermarkTranslation.Settings.ps1` 只保留旧函数 wrapper。 |
| 34. 翻译平台适配器中立化 | 已建立 | `TranslationPlatform.ps1` 接管 DPAPI、Win32 native type 和平台 helper；`WatermarkTranslation.Platform.ps1` 只保留旧函数 wrapper。 |
| 35. 虚化退出不拥有翻译生命周期 | 已建立 | `WatermarkMode.ps1` 退出虚化只恢复虚化视觉和主窗口状态，不再停止 `TranslationRuntime`；翻译由用户菜单、应用关闭或翻译 runtime 自己清理。 |
| 36. 番茄运行态字段写入 facade | 已建立 | `PomodoroRuntime.ps1` 接管启动阶段、暂停/继续、回到 idle work 和当前绑定任务的字段写入；`PomodoroEngine.ps1` / `PomodoroStarter.ps1` 保留状态机分支但不再散写 timer 运行态字段。 |
| 37. 设置/会话时长变更写入 facade | 已建立 | `Views.Settings*.ps1` 和 `PomodoroSession.ps1` 的时长变更写入已委托给 `PomodoroRuntime.ps1`；设置/会话层不再散写 `SecondsRemaining`、`CurrentPhasePlannedMinutes` 或 `PomodoroEndAt`。 |
| 38. 任务行倒计时运行态查询 facade | 已建立 | `PomodoroInlineCountdown.ps1` 已通过 `PomodoroRuntime.ps1` 查询快照获取倒计时状态，只在表现层格式化文本。 |
| 39. 会话时长阶段查询 facade | 已建立 | `PomodoroSession.ps1` 只通过 `PomodoroRuntime.ps1` 判断当前阶段；会话层不得直接读取 `TimerPhase`。 |
| 40. 背景音淡出阶段参数边界 | 已建立 | `PomodoroAudio.ps1` 的淡出策略接收阶段参数，不直接读取 `TimerPhase`；当前阶段由 `PomodoroRuntime.ps1` 传入。 |
| 41. 番茄工作流运行态快照 facade | 已建立 | `PomodoroWorkflow.ps1` 通过 `PomodoroRuntime.ps1` 查询暂停/运行状态、当前任务和完成通知快照，不直接读取 runtime 私有字段。 |
| 42. 设置保存后的番茄运行态刷新 facade | 已建立 | 设置页和破冰设置对话框只通知 `PomodoroRuntime.ps1` 刷新运行态；不直接读取 `TimerState` 或 `TimerPhase`。 |
| 43. 番茄运行态查询子边界 | 已建立 | 只读查询 facade 从 `PomodoroRuntime.ps1` 拆入 `PomodoroRuntime.Queries.ps1`，避免运行态核心文件膨胀。 |
| 44. 破冰状态机运行态查询 facade | 已建立 | `PomodoroStarter.ps1` 通过 `PomodoroRuntime.Queries.ps1` 判断 idle/starter 和当前任务，不直接读取 runtime 私有字段。 |
| 45. 计时器动作与任务菜单运行态查询 facade | 已建立 | `Views.Timer.Actions.ps1` 和 `Views.Task.Menu.ps1` 通过 `PomodoroRuntime.Queries.ps1` 判断 idle/starter/paused，不直接读取 runtime 私有字段。 |
| 46. 计时器视图运行态快照 facade | 已建立 | `Views.Timer.ps1` 通过 `PomodoroRuntime.Queries.ps1` 的 timer view 快照刷新标签和按钮状态，不直接读取 runtime 私有字段。 |
| 47. 破冰完成 UI 当前任务查询 facade | 已建立 | `Views.Timer.Starter.ps1` 通过 `PomodoroRuntime.Queries.ps1` 获取当前绑定任务 id，不直接读取 runtime 私有字段。 |
| 48. 番茄 Engine 运行态读取快照 facade | 已建立 | `PomodoroEngine.ps1` 通过 `PomodoroRuntime.Queries.ps1` 的 Engine 快照读取 state、phase、current task 和 started-at，不直接读取 runtime 私有字段。 |
| 49. 自测番茄运行态断言查询 facade | 已建立 | `SelfTest.Pomodoro.ps1` 和 `SelfTest.Tasks.ps1` 通过 `PomodoroRuntime.Queries.ps1` 断言运行态，不直接读取 runtime 私有字段。 |
| 50. 番茄会话轮次 facade | 已建立 | `PomodoroEngine.ps1`、`Views.Timer.SettingsDialog.ps1` 和自测通过 `PomodoroSession.ps1` facade 读取/推进连续轮次，不直接访问 session 私有字段。 |
| 51. 窗口拖动位置写入 facade | 已建立 | `WindowDrag.ps1` 只负责拖动手势和位移计算，通过 `WindowStateCoordinator.ps1` 读取/写入主窗口位置，不直接访问 `Form.Location`。 |
| 52. 窗口行数尺寸 facade | 已建立 | `WindowSize.ps1` 只负责任务行数到窗口高度的换算和尺寸按钮状态，通过 `WindowStateCoordinator.ps1` 读取/写入运行中窗口高度与最小尺寸。 |
| 53. 窗口安全落点边界 | 已建立 | `Get-SafeWindowLocation` 已从 `WindowSize.ps1` 迁入窗口状态边界的 `WindowPlacement.ps1`；行数尺寸模块不再依赖屏幕工作区。 |
| 54. 窗口/虚化 chrome facade | 已建立 | `WindowChrome.ps1` 接管运行中主窗体透明度、置顶、虚化标志、退出热区和点击穿透；虚化模块不再直接写这些 `Form` chrome 字段。 |
| 55. 历史翻译 wrapper 防回退 | 已建立 | `WatermarkTranslation*` 已由专门自动检查固化为兼容 wrapper：不得新增 WinForms、UIA、网络、DPAPI、词典解析、剪贴板写入、通知接线或 runtime 私有状态。 |
| 56. 自动检查窗口状态边界拆分 | 已建立 | `Invoke-WindowStateBoundaryCheck` 从通用 `AutomatedChecks.Boundaries.ps1` 拆入 `AutomatedChecks.WindowState.ps1`，让窗口状态检查和窗口架构切片同边界维护。 |
| 57. 自动检查任务菜单边界拆分 | 已建立 | `Invoke-TaskMenuHelperBoundaryCheck` 和 AST 函数名 helper 从通用边界脚本拆入 `AutomatedChecks.TaskMenu.ps1`，让任务列表/菜单 UI 子边界独立维护。 |
| 58. 自动检查设置视图边界拆分 | 已建立 | `Invoke-SettingsViewBoundaryCheck` 从通用边界脚本拆入 `AutomatedChecks.SettingsView.ps1`，让设置页行构造、保存 workflow 和 starter 设置检查独立维护。 |
| 59. 自动检查翻译模块边界拆分 | 已建立 | `Invoke-WatermarkTranslationBoundaryCheck` 从通用边界脚本拆入 `AutomatedChecks.WatermarkTranslation.ps1`，让翻译历史兼容/中立模块边界独立维护。 |
| 60. 自动检查音频/通知边界拆分 | 已建立 | `Invoke-AudioPlaybackBoundaryCheck` 和 `Invoke-NotificationHubBoundaryCheck` 分别迁入 `AutomatedChecks.AudioPlayback.ps1` 与 `AutomatedChecks.NotificationHub.ps1`，通用边界脚本不再承载具体边界。 |
| 61. 完成度审计与窗口 chrome 残留写入收口 | 已建立 | 新增 `architecture-completion-audit.md` 记录第 60 切片后的达标状态；`WatermarkToggleButton.ps1` 和 `Views.Settings.Apply.ps1` 的点击穿透/置顶写入改走 `WindowChrome.ps1`，并补自动检查防回退。 |
| 62. 番茄 tick 完成入口边界 | 已建立 | `UiTimer.ps1` 只接收 runtime tick 结果并委托 UI action wrapper；完成 guard 的释放进入 `Views.Timer.Actions.ps1`，避免全局 UI tick 编排层直接管理番茄 runtime 完成防重入。 |
| 63. 番茄操作结果对象边界 | 已建立 | 新增 `PomodoroResults.ps1` 拥有 `New-PomodoroOperationResult`；`PomodoroEngine.ps1` 只保留状态机分支，不再承载被 Starter/Workflow/UI action 复用的结果对象 schema。 |
| 64. 番茄时间格式化边界 | 已建立 | 新增 `PomodoroFormat.ps1` 拥有 `Format-Time`；`PomodoroEngine.ps1` 不再承载被计时器视图和行内倒计时复用的文本格式化 helper。 |
| 65. 设置保存调用点意图命名 | 已建立 | 新增 `Save-AppLifecycleSettings` 与 `Save-AppRuntimeSettings`；重启/更新前保存、每日归档时间戳和首次快捷方式提示不再裸调 `Save-Settings`，调用点按是否允许同步窗口字段显式选择 facade。 |
| 66. 番茄事件对象边界 | 已建立 | 新增 `PomodoroEvents.ps1` 拥有 `New-PomodoroEvent` 与 `Add-PomodoroResultEvents`；`PomodoroCoordinator.ps1` 只执行 result event 副作用，Engine/Starter/Workflow 不再依赖副作用执行器来创建事件。 |
| 67. 番茄事件语义 helper 边界 | 已建立 | `PomodoroEvents.ps1` 增加背景音、开始音、提醒、记录追加和任务番茄数递增的语义构造函数；状态机不再手写 result event 类型字符串或记录事件字段 shape。 |
| 68. 番茄下一轮计划决策边界 | 已建立 | `PomodoroPlanning.ps1` 接管休息结束后是否还有下一轮、下一轮绑定任务和任务剩余番茄判断；`PomodoroEngine.ps1` 只消费决策对象并执行状态转换。 |
| 69. 番茄记录事件语义边界 | 已建立 | `PomodoroEvents.ps1` 接管工作完成、休息完成、中断和跳过休息的记录事件构造，包括 planned/actual/result 字段；`PomodoroEngine.ps1` 不再计算记录事件字段 shape。 |
| 70. 番茄启动任务绑定边界 | 已建立 | `PomodoroPlanning.ps1` 接管启动番茄时的任务查找与绑定对象构造；`PomodoroEngine.ps1` 不再直接调用 `Get-TaskById` 来决定当前任务绑定。 |
| 71. 任务变更计时器失效 workflow 边界 | 已建立 | `PomodoroWorkflow.ps1` 接管 `TaskTimerInvalidated` 后是否停止当前计时器的编排；`PomodoroCoordinator.ps1` 只转发事件，`PomodoroEngine.ps1` 不再承载任务变更清理入口。 |
| 72. 番茄计划补全规则边界 | 已建立 | `PomodoroPlanning.ps1` 接管启动前是否需要预计番茄、启动时补写预计番茄、休息后是否需要追加预计和追加预计番茄；`PomodoroWorkflow.ps1` 只保留 UI 意图编排。 |
| 73. 破冰启动任务绑定边界 | 已建立 | `PomodoroPlanning.ps1` 接管破冰启动时的任务查找与绑定对象构造；`PomodoroStarter.ps1` 只消费绑定对象并执行破冰状态转换，不再直接调用 `Get-TaskById`。 |
| 74. 番茄状态机事件集合边界 | 已建立 | `PomodoroEventSets.ps1` 接管工作开始、暂停、继续、中断、工作完成、休息开始和休息完成对应的事件集合构造；`PomodoroEngine.ps1` 只调用语义化集合 helper，不再拼接底层事件数组或读取开始音设置。 |
| 75. 主脚本保存语义入口边界 | 已建立 | `TaskPomodoro.ps1` 的数据检查保存和窗体关闭保存必须通过 `SettingsWorkflow.ps1` 的命名 facade：数据检查保留窗口字段，应用关闭走生命周期保存；主脚本不再裸调 `Save-Settings`。 |
| 76. 破冰状态机事件集合边界 | 已建立 | `PomodoroEventSets.ps1` 接管破冰开始、停止和完成对应的事件集合构造；`PomodoroStarter.ps1` 只调用语义化集合 helper，不再直接构造底层背景音事件。 |
| 77. 历史翻译 wrapper 显式瘦身审计 | 已建立 | `AutomatedChecks.LegacyTranslation.ps1` 为 `WatermarkTranslation*` 兼容文件增加专属行数预算和实现禁用检查；历史 wrapper 保留旧函数名转发能力，但不得重新承载真实实现。 |
| 78. 破冰文案格式化边界 | 已建立 | `PomodoroFormat.ps1` 接管破冰菜单和完成对话框文案 helper；`PomodoroStarter.ps1` 只保留破冰状态机与运行态转换，不再拼接中英文标签或持有编码文案片段。 |
| 79. 破冰完成默认动作边界 | 已建立 | `PomodoroWorkflow.ps1` 接管破冰完成对话框默认动作读取与兜底；`PomodoroStarter.ps1` 不再读取 `StarterDefaultAction` 设置，只负责破冰状态转换。 |
| 80. 破冰时长读取边界 | 已建立 | `PomodoroSession.ps1` 接管破冰分钟数读取与秒数派生，和工作/休息分钟数同属时长规则边界；`PomodoroStarter.ps1` 不再读取 `StarterMinutes` 设置。 |
| 81. 最终达标审计 | 已建立 | `architecture-completion-audit.md` 改为达标结论；剩余历史 wrapper、runtime 内部 `$script:` 字段、自测夹具直连和状态机分支作为有意保留实现细节，不再作为本轮阻塞项。 |

## 阶段性收口：第 60 切片后

截至第 60 切片，目标架构中最容易导致用户可见异常的主线已经完成七成多：虚化/翻译生命周期已正交化，翻译核心模块已迁入中立命名并由 wrapper 防回退检查固化，番茄运行态读写已收敛到 runtime/query/session facade，设置保存策略已分层，窗口位置、高度、最小尺寸、屏幕安全落点和运行中 chrome 写入已进入窗口状态边界；质量闸门已从通用边界脚本拆向同名子边界，窗口状态、任务菜单、设置视图、翻译模块、音频播放和通知 hub 检查已经独立。

本轮目标架构调整主线已完成。后续不再继续按单个字段做小切片；只有发现真实高风险耦合、用户可见异常、资源泄漏或质量闸门难以维护时，再按高风险边界做中等切片。每个切片仍遵守“先文档、后代码、再检查”。

## 后续维护规则

本轮目标架构调整已经达标，后续不继续追逐形式上的分层纯度。维护时遵守以下规则：

1. 以 `architecture-completion-audit.md` 为准维护达标矩阵，不再重复写“做审计”占位项。
2. 已收口边界不得回流：窗口状态、虚化、翻译、设置保存、任务 UI、番茄 UI、音频播放、通知 hub 和历史 wrapper 都有对应自动检查。
3. 新增或调整功能仍遵守“先文档、后代码、再检查”；只有发现真实高风险耦合、用户可见异常、资源泄漏或质量闸门难以维护时，才新增架构切片。

## 第一轮切片：窗口状态写入单点化

### 问题

`SettingsStore.ps1` 当前直接读取 `WatermarkPreviousWindowWidth`、`WatermarkPreviousWindowHeight`、`WatermarkPreviousWindowLocation`、`WatermarkPreviousTopMost` 和 `WatermarkPreviousOpacity`。这让设置存储层理解虚化运行期细节，违反目标架构中的 `WindowStateCoordinator` 边界，也让翻译/设置保存更容易间接污染主窗口位置和字号。

### 调整

- 新增 `WindowStateCoordinator.ps1`。
- 将“应该把哪个窗口状态写入 settings”的判断移动到该模块。
- `SettingsStore.ps1` 只调用窗口状态协调函数，不再直接读取 `WatermarkPrevious*`。
- `ModuleLoadOrder.ps1` 保证 `WindowStateCoordinator.ps1` 在 `SettingsStore.ps1` 之前加载。
- 自动边界检查禁止 `SettingsStore.ps1` 再次出现 `WatermarkPrevious*` 和直接窗口字段写入逻辑。

### 验收

- `Save-Settings` 默认仍会持久化普通窗口位置、尺寸、置顶和不透明度。
- 虚化状态下 `Save-Settings` 仍保存虚化前的实化窗口状态，而不是虚化折叠状态。
- `Save-Settings -PreserveWindow` 不修改窗口字段。
- 翻译设置保存继续使用 `-PreserveWindow`，不得影响主窗口位置、尺寸或任务字号。
- 自动检查覆盖模块加载顺序和设置存储边界。

## 第二轮切片：虚化/翻译 runtime 正交化

### 问题

虚化是视觉与点击穿透能力，翻译是取词、查询和浮层能力。二者可组合，但不应互相拥有。当前模块名和部分调用路径仍容易把“虚化-翻译”理解成虚化的子模式：`WatermarkMode.ps1` 和 `WatermarkMode.Menu.ps1` 直接调用 `Start-WatermarkTranslationMode` / `Stop-WatermarkTranslationMode`，并直接读取翻译运行期变量。

### 调整

- 新增 `TranslationRuntime.ps1` 作为中立 facade。
- `TranslationRuntime.ps1` 暂时委托既有 `WatermarkTranslation*.ps1` 实现，避免一次性重命名全部翻译文件。
- `WatermarkMode.Menu.ps1` 的翻译菜单只调用 `TranslationRuntime` 公开 facade；`WatermarkMode.ps1` 不调用翻译 runtime 启停或活动状态。
- `ModuleLoadOrder.ps1` 保证 `TranslationRuntime.ps1` 在 `WatermarkTranslation.ps1` 之后、`WatermarkMode.Menu.ps1` 之前加载。
- 自动边界检查禁止虚化模块直接调用 `Start-WatermarkTranslationMode` / `Stop-WatermarkTranslationMode` 或读取 `$script:WatermarkTranslationMode`。

### 验收

- 虚化模块不再直接依赖 `WatermarkTranslation*` runtime 函数和变量。
- 启动翻译仍不改变主窗口位置、尺寸、任务字号、当前视图或虚化布局。
- 停止翻译仍不退出虚化；进入或退出虚化也不停止翻译，只有显式翻译菜单动作或应用关闭才改变翻译生命周期。
- 菜单语义保持不变：`翻译/停止翻译/翻译设置` 仍可用。
- 自动检查覆盖 facade 加载顺序和虚化/翻译正交边界。

## 第三轮切片：设置保存策略分层

### 问题

`Save-Settings` 同时承担底层持久化和调用方策略：默认会同步主窗口状态，`-PreserveWindow` 才保留窗口字段。调用点如果直接选择参数，容易把“翻译设置保存”“API 字符计数保存”“词典路径保存”误写成主窗口状态保存，也让调用意图不清楚。

### 调整

- 新增 `SettingsWorkflow.ps1` 作为设置保存策略 facade。
- `Save-GeneralSettings`：用于全局设置页、番茄默认设置等用户可见通用设置保存，允许同步主窗口状态。
- `Save-SettingsPreservingWindowState`：用于运行期状态或局部设置保存，保留窗口字段。
- `Save-TranslationSettings`：用于翻译设置对话框保存，必须保留窗口字段。
- `Save-TranslationRuntimeSettings`：用于翻译 API 字符计数、最近错误等运行期翻译字段，必须保留窗口字段。
- `Save-TranslationDictionarySettings`：用于导入词典路径，必须保留窗口字段。
- 暂不替换所有历史 `Save-Settings` 调用；本轮先迁移设置 UI 与翻译相关调用，再用边界检查防止翻译模块直接调用底层保存。

### 验收

- 翻译设置对话框、词典导入、API 字符计数保存不修改主窗口位置、尺寸、任务字号或当前视图。
- 全局设置页保存仍能应用任务字号、透明度、置顶、音频和番茄配置。
- `WatermarkTranslation*.ps1` 不直接调用 `Save-Settings`；必须通过设置 workflow facade。
- `Views.Settings*.ps1` 的主保存路径使用 `Save-GeneralSettings`，而不是直接调用底层保存函数。
- 自动检查覆盖 `SettingsWorkflow.ps1` 加载顺序和翻译保存边界。

## 第四轮切片：轻量事件通知

### 问题

当前已经存在 `New-AppEvent` / `Invoke-AppResultEvents`，它主要服务任务和番茄结果对象，用来把任务变更和计时器清理等操作串起来。它不是通用事件总线，也不应被扩大成隐藏主流程的机制。

目标架构中的 `Event-lite` 只用于少量横切通知。通知应同步、进程内、命名清楚、无订阅时零副作用；如果执行顺序重要，继续使用 workflow 明确编排。

### 调整

- 新增 `NotificationHub.ps1`，提供 `Publish-AppNotification`、`Register-AppNotificationHandler` 和 `Clear-AppNotificationHandlers`。
- `NotificationHub.ps1` 不依赖 WinForms、文件 IO、网络、窗口状态或翻译 API。
- 本轮只接入 `SettingsChanged`：`SettingsWorkflow.ps1` 在保存后发布通知，通知数据包含 `Scope` 和 `PreserveWindow`。
- 暂不改造任务/番茄结果事件；它们继续使用既有 `AppEvent` 结果对象机制。
- 暂不事件化翻译结果显示或番茄结束流程，避免一次引入过多间接调用。

### 验收

- 无订阅者时，`SettingsChanged` 通知不改变任何用户可见行为。
- 通知 handler 异常不阻断设置保存；错误只记录到运行期 `NotificationLastError`。
- `SettingsWorkflow.ps1` 不直接依赖具体 handler，只调用 `Publish-AppNotification`。
- 自动检查覆盖 `NotificationHub.ps1` 加载顺序、文件大小和禁止依赖 WinForms/IO/网络/窗口状态。
- 自测至少覆盖注册 handler、发布通知、清理 handler 的基本 roundtrip。

## 第五轮切片：任务 UI 工作流 facade

### 问题

任务视图和任务右键动作当前仍直接调用 `Add-Task`、`Complete-Task`、`Set-TaskTitle`、`Move-TaskInView`、`Delete-Task` 等任务突变函数。UI 层因此同时承担用户交互、任务命令选择、持久化结果触发和局部渲染判断，继续扩大 `Views.*` 的半业务层倾向。

番茄启动相关路径暂不并入本切片：`Start-PomodoroFromUi` 当前包含输入框、消息框和今日视图保留等 UI 语义，应在后续 `PomodoroWorkflow` 切片中单独拆分，不能为了抽象把 UI 行为搬进无 UI 的任务 workflow。

### 调整

- 新增 `TaskWorkflow.ps1` 作为任务 UI 意图的应用层 facade。
- 本轮只迁移纯任务突变：新增、完成/取消完成、今日安排/取消安排、结束、删除、重命名、置顶和拖拽排序。
- `Views.Task.ps1`、`Views.Task.Edit.ps1`、`Views.Task.Menu.Actions.ps1` 不再直接调用任务突变函数，改为调用 `Invoke-Task*Workflow`。
- `TaskWorkflow.ps1` 不依赖 WinForms、消息框、输入框、状态栏或渲染函数；它只编排既有任务命令并返回结果。
- 新增独立的 `AutomatedChecks.TaskWorkflow.ps1`，避免继续扩大已有边界检查文件。

### 验收

- 任务视图新增、勾选完成、双击/默认动作、拖拽排序和右键任务操作保持现有行为。
- 任务 UI 文件不得直接调用任务突变函数；必须通过 `TaskWorkflow.ps1`。
- `TaskWorkflow.ps1` 不出现 `System.Windows.Forms`、`MessageBox`、`InputBox`、`Set-Status` 或 `Render-CurrentView`。
- `ModuleLoadOrder.ps1` 保证 `TaskWorkflow.ps1` 在任务命令之后、任务视图之前加载。
- 自动检查覆盖任务 workflow 边界和文件大小。

## 第六轮切片：番茄 UI 工作流 facade

### 问题

`Views.Timer.ps1`、`Views.Timer.Starter.ps1` 和任务右键动作仍直接调用 `Start-Pomodoro`、`Pause-Pomodoro`、`Stop-Pomodoro`、`Complete-Pomodoro`、`Start-TaskStarter`、`Complete-TaskStarter` 等番茄/破冰状态机函数。UI 层因此同时承担控件渲染、用户输入、状态机选择、破冰完成后的后续动作和事件合并，继续阻碍目标架构中的 `PomodoroWorkflow` 边界。

`Start-PomodoroFromUi` 中的预计番茄输入框、无效提示，以及 `Show-TaskStarterDoneDialog` 中的完成后选择对话框仍是 UI 责任。本切片不把 WinForms 对话框搬入 workflow，也不重写番茄核心状态机。

### 调整

- 新增 `PomodoroWorkflow.ps1` 作为番茄 UI 意图的应用层 facade。
- 本轮迁移 UI 层直接状态机调用：开始、暂停/继续、停止、完成、破冰开始、破冰完成后再次破冰、转番茄、完成任务。
- `Views.Timer.ps1` 保留输入框/消息框，只把校验后的动作委托给 `Invoke-Pomodoro*Workflow`。
- `Views.Timer.Starter.ps1` 保留完成后选择对话框，只把选择结果委托给 `Invoke-TaskStarter*Workflow`。
- 新增独立的 `AutomatedChecks.PomodoroWorkflow.ps1`，避免继续扩大已有边界检查文件。

### 验收

- 从今日任务启动番茄时仍保留今日任务页，任务行倒计时继续只读显示。
- 番茄页开始、暂停/继续、停止、完成保持现有行为。
- 破冰完成后的“开始番茄 / 再做一次 / 完成任务 / 停止”保持现有行为。
- `PomodoroWorkflow.ps1` 不出现 `System.Windows.Forms`、`MessageBox`、`InputBox`、`Set-Status` 或 `Render-CurrentView`。
- `Views.Timer.ps1`、`Views.Timer.Starter.ps1`、`Views.Task.Menu.Actions.ps1` 不再直接调用番茄/破冰状态机函数；必须通过 workflow facade。
- 自动检查覆盖 `PomodoroWorkflow.ps1` 加载顺序、UI-free 边界和文件大小。

## 第七轮切片：WatermarkRuntime facade

### 问题

目标架构要求虚化是独立运行期能力，但当前外部模块仍直接调用 `Toggle-WatermarkMode`、`Update-WatermarkClickThrough`、`Update-WatermarkToggleButton`、`Get-WatermarkModeOpacity`，并直接读取 `$script:WatermarkMode` 来判断虚化状态。这样会让设置、菜单、帮助、底部栏等 UI 模块继续知道虚化实现细节，也会给翻译叠加能力留下错误复用虚化布局流程的入口。

本切片不重写虚化实现，不拆 `WatermarkMode.ps1` 内部控件和布局逻辑。先新增 `WatermarkRuntime.ps1` 作为对外 facade，把外部模块的虚化运行态访问收敛到少量明确函数。

### 调整

- 新增 `WatermarkRuntime.ps1`，提供 `Test-WatermarkRuntimeActive`、`Start-WatermarkRuntime`、`Stop-WatermarkRuntime`、`Toggle-WatermarkRuntime`、`Update-WatermarkRuntimeToggleButton`、`Update-WatermarkRuntimeClickThrough`、`Suspend-WatermarkRuntimeClickThrough` 和 `Get-WatermarkRuntimeOpacity`。
- `WatermarkMode.ps1` 继续拥有具体虚化实现；`WatermarkRuntime.ps1` 暂时委托既有实现函数。
- `WatermarkMode.Menu.ps1`、设置应用、底部栏、帮助/快捷方式入口等外部模块改用 runtime facade。
- `ModuleLoadOrder.ps1` 保证 `WatermarkMode.ps1` 先加载具体实现，`WatermarkRuntime.ps1` 再加载 facade，外部菜单和 UI 模块之后加载。
- 自动检查禁止外部 UI 模块直接调用虚化实现函数。

### 验收

- `~` 左键虚化/实化转换和右键菜单行为保持不变。
- 设置页调整透明度、保存设置和底部栏刷新仍能正确更新虚化按钮。
- 翻译设置或翻译运行态如果需要恢复点击穿透，只能通过 `WatermarkRuntime` facade。
- 外部模块不得直接调用 `Enter-WatermarkMode`、`Exit-WatermarkMode`、`Toggle-WatermarkMode`、`Update-WatermarkClickThrough`、`Update-WatermarkToggleButton` 或 `Get-WatermarkModeOpacity`。
- 自动检查覆盖 facade 加载顺序、外部调用边界和文件大小。

## 第八轮切片：TranslationWorkflow 事件化

### 问题

`WatermarkTranslation.ps1` 当前仍把翻译流程串在一起：文本过滤、防抖、缓存查询、本地词典/API 查询和浮层显示都在同一条函数链里完成。目标架构中的 `TranslationWorkflow` 还没有落地，`Event-lite` 也只接入了 `SettingsChanged`，导致翻译编排和 overlay surface 仍然直接耦合。

本切片不重写 UIA 监听、剪贴板监听、本地词典或 API provider，也不改变浮层视觉。先新增 `TranslationWorkflow.ps1`：它只编排翻译请求并发布 `TranslationCompleted` / `TranslationFailed` 通知；现有浮层渲染通过通知 handler 接上。

### 调整

- 新增 `TranslationWorkflow.ps1`，提供 `Invoke-TranslationWorkflowRequest`。
- `Invoke-TranslationWorkflowRequest` 负责文本归一、过滤、防抖、缓存查询和选择发布 `TranslationCompleted` / `TranslationFailed`。
- `TranslationWorkflow.ps1` 不直接调用 `Show-WatermarkTranslationResult`，不创建 WinForms，不读 UIA，不碰剪贴板。
- `WatermarkTranslation.ps1` 在启动翻译时注册翻译通知 handler，在停止翻译时清理 handler。
- `Show-WatermarkTranslationText` 保留为兼容入口，但只委托给 `TranslationWorkflow`。
- 新增 `AutomatedChecks.TranslationWorkflow.ps1`，覆盖 workflow 加载顺序、通知边界和禁止直接浮层渲染。

### 验收

- UIA/剪贴板取到英文后仍显示原有短释义和详细释义浮层。
- 中文、纯数字、过长文本和重复选择仍按原策略忽略或隐藏。
- 本地未收录、API 不可用等提示仍显示，但经 `TranslationFailed` 通知进入浮层。
- `TranslationWorkflow.ps1` 不出现 `Show-WatermarkTranslationResult`、`Ensure-WatermarkTranslationForms`、`System.Windows.Forms`、`Get-WatermarkTranslationSelection`、剪贴板或 UIA 读取逻辑。
- 自动检查覆盖 `TranslationWorkflow.ps1` 加载顺序、事件发布和文件大小。

## 第九轮切片：PomodoroFinished 通知

### 问题

目标架构中的 `Event-lite` 计划覆盖 `SettingsChanged`、`TranslationCompleted` / `TranslationFailed` 和 `PomodoroFinished`。前两类通知已经落地，但番茄完成仍只通过既有 result events 驱动音频、记录、提醒和 UI 刷新。这样并不是错误，但目标架构中的横切通知还缺少番茄完成这个稳定事件。

本切片不替换 `New-AppEvent` / `Invoke-AppResultEvents`，也不迁移音频播放、番茄记录、任务番茄数递增或提醒触发顺序。`PomodoroFinished` 只是同步、进程内、无订阅零副作用的通知，用于后续把状态提示、统计刷新或轻量外部响应从主流程里分离出来。

### 调整

- `PomodoroWorkflow.ps1` 在工作番茄完成并成功进入后续状态后发布 `PomodoroFinished`。
- 通知数据包含完成前的 `TaskId`、`TaskTitle`、`StartedAt`、`EndedAt`、`PlannedMinutes` 和 workflow result。
- `Complete-Break`、破冰完成、手动停止和中断不发布 `PomodoroFinished`。
- 不新增默认订阅者，不改变现有用户可见行为。
- 扩展 `AutomatedChecks.PomodoroWorkflow.ps1`，确认通知由 workflow 发布，且不绕过既有 result events。

### 验收

- 完成一个工作番茄后，现有记录、音频、提醒、休息启动和 UI 刷新保持原行为。
- 未订阅 `PomodoroFinished` 时无用户可见变化。
- `PomodoroWorkflow.ps1` 不直接播放音频、不写番茄记录、不直接刷新 UI。
- 自动检查覆盖 `PomodoroFinished` 发布、workflow 边界和文件大小。

## 第十轮切片：TranslationRuntime 设置暂停/恢复边界

### 问题

翻译设置对话框打开和关闭时，仍容易直接碰翻译运行期细节，例如 UIA timer、剪贴板 listener 或 `$script:WatermarkTranslationMode`。这会让设置 UI 知道 runtime 内部资源结构，也容易在保存设置时误触发主窗口布局、点击穿透或翻译监听恢复顺序问题。

本切片不改变翻译设置项和 UI。目标只是把“打开设置时暂停监听、关闭设置后按当前状态恢复”的生命周期决策收敛到 `TranslationRuntime.ps1`。

### 调整

- `TranslationRuntime.ps1` 新增设置对话框专用 facade，例如 `Suspend-TranslationRuntimeForSettings` 与 `Resume-TranslationRuntimeAfterSettings`。
- `WatermarkTranslation.Settings.ps1` 不再直接读写翻译 runtime 变量，不直接停止/启动 UIA timer 或剪贴板 listener。
- 关闭设置后由 `TranslationRuntime` 按当前翻译状态和最新 `TranslationClipboardListenerEnabled` 设置决定是否恢复监听。
- 点击穿透暂停/恢复仍通过 `WatermarkRuntime` facade，不能直接调用虚化实现函数。
- 自动边界检查禁止设置对话框直接访问翻译 timer、剪贴板 listener 和 runtime 私有变量。

### 验收

- 打开翻译设置时，取词监听暂停，设置窗口可正常交互。
- 保存或取消翻译设置后，主窗口位置、尺寸、任务字号、当前视图不变。
- 如果翻译原本开启，关闭设置后继续翻译；如果翻译原本关闭，关闭设置后不启动翻译。
- 剪贴板监听只在翻译开启且用户启用该设置时恢复。
- `WatermarkTranslation.Settings.ps1` 不出现 `WatermarkTranslationTimer`、`WatermarkTranslationClipboardTimer`、`Start-WatermarkTranslationClipboardListener`、`Stop-WatermarkTranslationClipboardListener` 或 `$script:WatermarkTranslationMode`。

## 第十一轮切片：翻译模块去虚化命名与浮层边界

### 问题

目标架构已经把虚化和翻译定义为两个独立 runtime，但部分历史文件名和文档仍使用 `WatermarkTranslation*`。如果继续在这些文件里扩展功能，后续开发者容易把翻译当成虚化的子模式，继续复用虚化布局、主窗口定位或任务字号设置。

此外，短释义浮层、详细面板和主窗口之间的定位关系必须固定：翻译浮层可以贴近选区或主窗口，但不能拥有或覆盖主窗口位置。

### 调整

- 保留历史文件名作为兼容落点，但新增或扩展逻辑优先放到中立 facade：`TranslationRuntime.ps1`、`TranslationWorkflow.ps1`、`TranslationSurface.ps1`、`TranslationSelection.ps1`、`TranslationProviders.ps1`。
- `TranslationSurface.ps1` 已从中立 facade 推进为翻译浮层实现所有者；`WatermarkTranslation.Surface.ps1` 只保留旧函数名兼容 wrapper。
- `WatermarkTranslation.ps1` 只调用 `Show-TranslationSurfaceResult`、`Hide-TranslationSurfaces`、`Dispose-TranslationSurfaces` 等中立 facade，不再直接调用旧 `Show-WatermarkTranslationResult` / `Hide-WatermarkTranslationSurfaces` / `Dispose-WatermarkTranslationSurfaces`。
- 本轮第二步新增 `TranslationSelection.ps1`，作为 UIA 选区读取和可选只读剪贴板监听的中立 adapter；`WatermarkTranslation.ps1` 只传入文本处理回调，不直接读取 UIA、剪贴板或剪贴板 sequence。
- 本轮第三步新增 `TranslationProviders.ps1`，作为自定义接口、DeepL、百度和字符额度的中立 provider adapter；`WatermarkTranslation.ps1` 不直接调用 `Invoke-RestMethod`、DPAPI 解密或 provider endpoint。
- 本轮第四步新增 `TranslationRules.ps1` 与 `TranslationLookup.ps1`，前者承载文本过滤和翻译结果模型，后者承载缓存、本地词典与在线 provider 的查询编排；`WatermarkTranslation.ps1` 不再定义选择分类、提示结果或查译结果函数。
- 本轮第五步把翻译 timer、启动/停止、暂停/恢复和统一清理迁入 `TranslationRuntime.ps1`；`Start-WatermarkTranslationMode` / `Stop-WatermarkTranslationMode` 只保留为兼容 wrapper，不再拥有运行期资源。
- 文档、帮助和设置文案统一使用 `翻译` 或 `翻译增强`，不再把生产功能称为 `虚化-翻译`。
- 详细翻译面板默认贴近主窗口下方；如后续支持拖动，只能保存为翻译面板位置设置，不能复用主窗口位置字段。
- 翻译字号只读写 `TranslationFontSize`；任务列表字号只读写 `TaskFontSize`。
- 自动检查继续禁止翻译模块调用窗口尺寸、任务行数、视图切换、虚化进入布局和剪贴板写入相关 API。

### 验收

- 翻译可以在实化状态和虚化状态分别开启，启动/停止翻译均不改变主窗口布局。
- 单词附近短释义和主窗口下方详细面板均不抢焦点、不阻断下方窗口操作。
- 翻译核心监听模块不直接调用 `WatermarkTranslation.Surface.ps1` 的旧实现函数。
- 翻译核心监听模块不直接调用 UIA、`Clipboard` 或 `GetClipboardSequenceNumber`；取词和只读剪贴板监听必须经 `TranslationSelection.ps1`。
- 翻译核心监听模块不直接调用 `Invoke-RestMethod`、`Unprotect-TranslationSecret` 或具体 provider endpoint；在线翻译必须经 `TranslationProviders.ps1`。
- 翻译核心监听模块不直接定义文本过滤、提示结果模型、缓存或词典/API 查询编排；这些必须经 `TranslationRules.ps1` 和 `TranslationLookup.ps1`。
- 翻译核心监听模块不直接拥有 timer、启动/停止、暂停/恢复和资源释放；这些必须经 `TranslationRuntime.ps1`。
- 翻译设置不会显示或保存主窗口定位字段。
- 新增翻译代码不直接依赖 `WatermarkMode.ps1` 内部变量或实现函数。
- 用户可见文案不再用 `虚化-翻译` 表达当前生产能力，历史文档或文件名除外。

## 第十二轮切片：PomodoroRuntime tick 边界

### 问题

`UiTimer.ps1` 当前既负责全局 UI tick 编排，又直接读取和推进番茄运行态：计算剩余秒数、处理完成防重入、更新背景音淡出，并决定任务行倒计时是否失效。这让 UI tick 层继续知道番茄 runtime 细节，也让后续排查 timer 资源和状态推进时缺少单一边界。

本切片不重写番茄状态机，不迁移 `Start-Pomodoro` / `Stop-Pomodoro` 等领域状态变化，也不把 UI 对话框、`Update-TimerLabels` 或 ListBox 刷新搬入 runtime。

### 调整

- 新增 `PomodoroRuntime.ps1`。
- `PomodoroRuntime.ps1` 只负责运行中 tick：计算剩余秒数、更新 `SecondsRemaining`、触发背景音淡出、返回是否需要完成或刷新 UI，并维护 `TimerCompletionInProgress` 防重入。
- `UiTimer.ps1` 继续负责全局 tick 顺序、状态栏日期、每日归档、虚化/底栏/尺寸按钮刷新，以及根据 runtime 返回值调用 UI 刷新或完成 UI 包装函数。
- `PomodoroRuntime.ps1` 不直接调用 `Update-TimerLabels`、`TaskListBox.Invalidate()`、`Invoke-AppActionResult`、`Complete-PomodoroFromUi`、消息框或视图渲染。
- 自动检查覆盖加载顺序和边界：`PomodoroRuntime.ps1` 在 `PomodoroEngine.ps1`、`PomodoroStarter.ps1`、`PomodoroWorkflow.ps1` 之后、`UiTimer.ps1` 之前加载；`UiTimer.ps1` 不再直接计算 `PomodoroEndAt` 或操作 `TimerCompletionInProgress`。

### 验收

- 番茄运行、暂停、继续、完成、休息和 3 分钟破冰行为保持现有结果。
- 每秒标签刷新和任务行倒计时仍工作，但 `UiTimer.ps1` 不再拥有番茄剩余时间计算和完成防重入。
- `PomodoroRuntime.ps1` 不依赖 WinForms 控件、不弹窗、不直接触发 UI action result。
- 自动检查和完整自测通过。

## 第十三轮切片：任务默认动作跨领域边界

### 问题

`TaskCommands.ps1` 曾经承载任务默认动作，这让纯任务命令层间接理解“今日页双击启动番茄、普通任务页双击安排今日”的 UI 语义。任务命令层因此容易跨到番茄领域，也会让后续点击策略继续扩散到基础命令模块。

本切片不改变双击行为，只把“默认点击该做什么”的决策放回 UI workflow 边界：普通任务页默认安排今日由 `TaskWorkflow` 编排，今日页启动番茄仍由 UI 调用番茄 UI wrapper。

### 调整

- 从 `TaskCommands.ps1` 移除任务默认动作入口。
- `TaskWorkflow.ps1` 只保留普通任务页默认安排今日的 `Invoke-TaskDefaultWorkflow`。
- 今日页默认启动番茄不进入任务 workflow，继续经 `Start-PomodoroFromUi`。
- 自动检查禁止 `TaskCommands.ps1` 调用番茄或破冰状态机。

### 验收

- 普通任务页双击未完成任务仍安排到今日。
- 今日任务页双击未完成任务仍启动番茄 UI 流程。
- 已完成任务默认点击无副作用。
- `TaskCommands.ps1` 不出现 `Invoke-TaskDefaultAction` 或番茄/破冰状态机调用。

## 第十四轮切片：AppResultEvents 中立边界

### 问题

通用 result event 构造和分发曾经落在 `PomodoroCoordinator.ps1`，导致任务、设置或其它领域如果想复用 result event，就需要依赖番茄协调器。这样会把番茄副作用 handler 和通用 result object 边界混在一起。

本切片不改变既有 result event 的执行顺序，也不迁移音频、记录或 UI 刷新 handler，只拆出中立构造、合并和分发入口。

### 调整

- 新增 `AppResultEvents.ps1`，提供 `New-AppEvent`、`Add-AppResultEvents` 和 `Invoke-AppResultEvents`。
- `PomodoroCoordinator.ps1` 继续拥有番茄/计时副作用 handler，并通过中立入口分发。
- `ModuleLoadOrder.ps1` 确保 `AppResultEvents.ps1` 先于需要创建 result event 的 workflow 加载。
- 自动检查覆盖中立模块不得包含音频、记录、任务保存或 UI 副作用。

### 验收

- 任务和番茄 workflow 仍能返回并分发原有 result events。
- 番茄完成后的音频、记录、提醒、任务番茄数递增和 UI 刷新保持原行为。
- `AppResultEvents.ps1` 不承担具体副作用 handler。

## 第十五轮切片：计时器 UI 动作包装边界

### 问题

`Views.Timer.ps1` 既渲染计时器视图，又包含从其它视图启动番茄、追加预计番茄和自动完成番茄的 UI 包装逻辑。这样会让计时器视图文件变成跨视图动作集，也让任务列表默认动作必须依赖计时器渲染文件。

本切片不下沉输入框、消息框或视图保留判断；这些仍是 UI 责任。目标只是让计时器视图渲染和跨视图 UI 动作包装分离。

### 调整

- 新增 `Views.Timer.Actions.ps1`。
- `Start-PomodoroFromUi`、`Confirm-AdditionalPomodorosFromUi`、`Complete-PomodoroFromUi` 移入该模块。
- `Views.Timer.ps1` 只保留计时器视图渲染和 label 更新。
- 自动检查禁止 `Views.Timer.ps1` 重新定义跨视图 UI 动作包装。

### 验收

- 从今日任务启动番茄时仍保留今日页。
- 计时器页按钮行为不变。
- 自动完成番茄仍经 UI wrapper 调用 workflow，并正确释放完成防重入状态。
- `Views.Timer.Actions.ps1` 可使用 UI 对话框，但必须委托 `PomodoroWorkflow` 执行业务状态变化。

## 第十六轮切片：任务列表交互策略边界

### 问题

`Views.Task.ps1` 内部同时负责列表装配、默认点击动作和点击状态重置。默认点击动作还跨越任务与番茄两个领域：普通任务页是安排今日，今日任务页是启动番茄。若这类策略继续散落在列表事件里，后续 hover、拖动、双击和重命名逻辑会继续复制同一套状态判断。

本切片不重写鼠标事件，也不改变双击、复选框、拖动排序或内联重命名行为。目标是先把可复用的交互策略函数移出视图壳。

### 调整

- 新增 `Views.Task.Interactions.ps1`。
- `Invoke-TaskListDefaultClickAction` 负责列表默认点击动作：Ctrl 打开链接、今日页启动番茄、普通任务页委托 `TaskWorkflow`。
- `Reset-TaskListClickState` 负责重置列表点击状态，供列表、hover/拖动等模块复用。
- `Views.Task.ps1` 继续持有具体鼠标事件接线，但不再定义这些策略函数。
- 自动检查覆盖加载顺序、函数归属和禁止交互策略模块直接调用任务命令或番茄状态机。

### 验收

- 双击普通任务、今日任务、Ctrl 打开链接、点击复选框、拖动排序和重命名行为保持不变。
- `Views.Task.ps1` 不定义 `Invoke-TaskListDefaultClickAction` 或 `Reset-TaskListClickState`。
- `Views.Task.Interactions.ps1` 不构造菜单、不渲染任务视图、不直接调用任务命令或番茄状态机。

## 第十七轮切片：任务列表数据投影边界

### 问题

`Views.Task.ps1` 仍直接选择 `Get-TodayTasks` 或 `Get-OpenTasks`，并在渲染函数里完成编号、`Format-TaskLine` 和空占位行添加。这个逻辑不是领域查询，也不是事件接线，而是任务数据到 ListBox item 的 UI 投影。如果继续放在视图壳中，`Render-TaskView` 会持续承担“查询、投影、装配、事件绑定”四类职责。

本切片不改变任务查询规则、排序规则、任务行格式或空列表文案，只把投影封装到任务列表 item 模块。

### 调整

- 新增 `Views.Task.Items.ps1`，提供 `Get-TaskListItemsForView`。
- `Get-TaskListItemsForView` 根据视图模式读取今日/普通任务、生成显示编号、调用 `Format-TaskLine`，并在末尾补空占位行或空列表提示。
- `Views.Task.ps1` 只负责把返回的 item 加入 ListBox，不再直接调用 `Get-TodayTasks`、`Get-OpenTasks` 或 `Format-TaskLine`。
- 自动检查覆盖模块加载顺序、函数归属和 item 模块不得构造 WinForms 控件或调用任务突变/workflow。

### 验收

- 任务清单和今日待办显示顺序、编号、空列表提示和末尾空行保持不变。
- `Views.Task.ps1` 不直接调用 `Get-TodayTasks`、`Get-OpenTasks` 或 `Format-TaskLine`。
- `Views.Task.Items.ps1` 不创建 WinForms 控件，不调用任务命令、任务 workflow 或番茄 workflow。
- 自动检查和完整自测通过。

## 第十八轮切片：任务列表事件接线边界

### 问题

`Views.Task.ps1` 已经拆出了任务列表 item 投影和默认点击策略，但仍直接包含 MouseDown、SelectedIndexChanged、MouseMove、MouseUp、DragOver、DragDrop 和 MouseDoubleClick 等事件接线。这样 `Render-TaskView` 仍然同时承担控件装配、事件脚本块、拖动判定、双击判定、重命名触发和任务移动触发，后续维护时很难只阅读视图壳来确认布局没有副作用。

本切片不改变鼠标交互、拖动排序、复选框完成、双击默认动作、右键菜单或内联重命名行为。目标只是把列表事件注册集中到独立 UI 事件模块，让视图壳继续瘦身。

### 调整

- 新增 `Views.Task.Events.ps1`，提供 `Register-TaskListEventHandlers`。
- `Register-TaskListEventHandlers` 负责给任务 ListBox 注册 Mouse/Drag/DoubleClick/Selection 等事件脚本块。
- `Views.Task.ps1` 在创建并填充 ListBox 后只调用 `Register-TaskListEventHandlers $list`，不再直接包含这些事件脚本块。
- `Views.Task.Events.ps1` 可以调用已有 UI helper、workflow wrapper 和任务列表交互策略，但不得创建布局控件、投影任务 item 或定义渲染函数。
- 自动检查覆盖加载顺序、函数归属和事件模块禁止承担布局/数据投影/菜单构造职责。

### 验收

- 右键菜单、复选框完成、双击默认动作、Ctrl 打开链接、拖动排序、空白区域拖动窗口和内联重命名行为保持不变。
- `Views.Task.ps1` 不出现 `Add_MouseDown`、`Add_MouseMove`、`Add_MouseUp`、`Add_DragOver`、`Add_DragDrop` 或 `Add_MouseDoubleClick`。
- `Views.Task.Events.ps1` 不定义 `Render-TaskView`，不创建 `TableLayoutPanel`、`TextBox` 或 `ContextMenuStrip`，不调用 `Get-TodayTasks`、`Get-OpenTasks` 或 `Format-TaskLine`。
- 自动检查和完整自测通过。

## 第十九轮切片：任务列表事件处理策略边界

### 问题

`Views.Task.Events.ps1` 已经从 `Views.Task.ps1` 中接管事件注册，但它仍直接承载 MouseDown、MouseMove、MouseUp、DragOver、DragDrop 和 MouseDoubleClick 的具体行为。这样事件模块实际上既是接线层，又是交互策略层；如果后续要调整双击、重命名候选、拖动阈值或复选框命中，仍需要阅读事件注册文件本身。

本切片不改变任何鼠标交互结果，也不拆分双击算法或拖动算法。目标只是把事件脚本块瘦成“把 sender/eventArgs 转交给命名函数”，具体策略归入 `Views.Task.Interactions.ps1`。

### 调整

- `Views.Task.Events.ps1` 只保留 `Register-TaskListEventHandlers`，每个事件脚本块只调用一个明确的 `Invoke-TaskList*` 交互函数。
- `Views.Task.Interactions.ps1` 新增 MouseDown、SelectedIndexChanged、MouseMove、MouseUp、DragOver、DragDrop 和 MouseDoubleClick 的处理函数。
- 事件处理函数可以调用任务列表选择、hover、编辑、窗口拖动和 workflow wrapper，但不得创建布局、投影 item、构造菜单或直接调用任务命令/番茄状态机。
- 自动检查覆盖 `Views.Task.Events.ps1` 不再出现具体策略调用细节，例如 `Show-TaskMenu`、`Start-TaskTitleInlineEdit`、`Invoke-TaskMoveWorkflow` 和 `Invoke-TaskListDefaultClickAction`。

### 验收

- 右键菜单、复选框完成、双击默认动作、Ctrl 打开链接、拖动排序、空白区域拖动窗口和内联重命名行为保持不变。
- `Views.Task.Events.ps1` 只包含事件注册和对 `Invoke-TaskList*` handler 的委托，不包含具体交互策略调用。
- `Views.Task.Interactions.ps1` 不定义 `Render-TaskView`，不创建布局控件，不构造菜单，不投影任务 item，不直接调用任务命令或番茄状态机。
- 自动检查和完整自测通过。

## 第二十轮切片：任务列表点击手势判定边界

### 问题

`Invoke-TaskListMouseDown` 当前已经位于交互策略模块，但函数内部仍直接计算双击时间、双击区域、重命名候选和最后点击状态。这个判断依赖 WinForms 双击阈值和上一次点击坐标，细节较多，导致 MouseDown 主流程难以快速看清“右键菜单、窗口拖动、选择 item、双击默认动作、复选框完成、重命名、预览/拖动准备”的顺序。

本切片不改变任何阈值、点击顺序或用户可见行为。目标只是把点击手势判定和点击状态更新拆成命名 helper，让 MouseDown 主流程更接近业务顺序描述。

### 调整

- 在 `Views.Task.Interactions.ps1` 中新增点击 helper：读取当前选中 id、判断是否在双击区域内、生成点击手势对象、写回最后点击状态。
- `Invoke-TaskListMouseDown` 继续保留原有执行顺序，但不再内联计算 `$elapsed`、`$doubleSize`、`$withinDoubleTime` 和 `$withinDoubleArea`。
- 不新增模块，不改变加载顺序；本轮只整理交互策略模块内部结构。
- 自动检查覆盖新增 helper 标记，并继续禁止 `Views.Task.Interactions.ps1` 创建布局、构造菜单、投影 item 或直接调用任务命令/番茄状态机。

### 验收

- 双击默认动作、同一行延迟重命名、复选框完成、任务标题预览和拖动准备行为保持不变。
- `Invoke-TaskListMouseDown` 不再直接出现 `DoubleClickSize`、`DoubleClickTime` 或 `$withinDoubleArea` 计算细节。
- `Views.Task.Events.ps1` 仍只注册事件，具体策略仍在 `Views.Task.Interactions.ps1`。
- 自动检查和完整自测通过。

## 第二十一轮切片：任务列表拖动判定边界

### 问题

`Views.Task.Interactions.ps1` 已经承接任务列表交互策略，但拖动相关细节仍内联在 `Invoke-TaskListMouseMove` 和 `Invoke-TaskListDragDrop` 中：拖动阈值 `dx/dy >= 4`、拖拽数据类型检查、拖拽源 id 读取、屏幕坐标转列表坐标和目标索引计算都混在事件处理主流程里。这样后续如果要调整拖拽阈值或拖放目标规则，容易误碰窗口拖动、任务拖动和排序 workflow 的顺序。

本切片不改变拖动阈值、拖动排序、窗口拖动或拖放效果。目标只是把拖动判断和拖放数据转换拆成命名 helper，让 MouseMove/DragDrop 主流程只表达“是否开始拖动”和“将源任务移动到目标索引”。

### 调整

- 在 `Views.Task.Interactions.ps1` 中新增拖动 helper：判断任务拖动是否可开始、判断是否越过拖动阈值、读取拖拽源 id、计算拖放目标索引。
- `Invoke-TaskListMouseMove` 不再内联 `$dx/$dy` 计算和阈值判断。
- `Invoke-TaskListDragOver` 和 `Invoke-TaskListDragDrop` 不再内联 `GetDataPresent([string])`、`Data.GetData([string])` 和 `PointToClient/IndexFromPoint` 细节。
- 自动检查覆盖新增 helper 标记，并继续禁止交互模块创建布局、构造菜单、投影 item 或直接调用任务命令/番茄状态机。

### 验收

- 任务拖动排序、窗口拖动、拖放效果和空白区域拖动窗口行为保持不变。
- `Invoke-TaskListMouseMove` 不再直接出现 `$dx`、`$dy` 或 `DoDragDrop` 的阈值判断细节。
- `Invoke-TaskListDragDrop` 不再直接出现 `GetDataPresent([string])`、`GetData([string])`、`PointToClient` 或 `IndexFromPoint` 细节。
- 自动检查和完整自测通过。

## 第二十二轮切片：任务列表手势 mechanics 边界

### 问题

第 20、21 轮已经把点击和拖动算法拆成 helper，但这些 helper 仍然和高层交互策略同处 `Views.Task.Interactions.ps1`。这让 Interactions 同时承担“用户意图流程”和“WinForms 手势 mechanics”：双击时间/区域、最后点击坐标、拖动阈值、`DoDragDrop`、拖拽数据读取和目标索引计算。后续修改任务默认动作、右键菜单、复选框完成或内联重命名时，仍容易误碰底层手势细节。

本切片不改变任何点击、双击、重命名、拖动排序或窗口拖动行为。目标只是新增低层手势模块，让 `Views.Task.Interactions.ps1` 只描述高层交互顺序。

### 调整

- 新增 `Views.Task.Gestures.ps1`，承接任务列表点击/拖动 mechanics helper。
- `Views.Task.Gestures.ps1` 负责：当前选中 id、双击区域和时间判定、点击状态写回、任务拖动启动条件、拖动阈值、`DoDragDrop`、拖拽源 id 和目标索引计算。
- `Views.Task.Interactions.ps1` 保留默认点击动作、MouseDown/Move/Drop/DoubleClick 等高层流程，只调用 gesture helper，不再内联 WinForms 手势细节。
- `ModuleLoadOrder.ps1` 保证 `Views.Task.Gestures.ps1` 在 `Views.Task.Interactions.ps1` 前加载。
- 自动检查覆盖 gesture 模块加载顺序、helper 归属、Interactions 禁止出现低层手势实现细节，以及 Gestures 不得调用 workflow、菜单、编辑、渲染或任务命令。

### 验收

- 双击默认动作、同一行延迟重命名、复选框完成、任务标题预览、拖动排序和窗口拖动行为保持不变。
- `Views.Task.Interactions.ps1` 不定义 `Get-TaskListClickGesture`、`Set-TaskListLastClickState`、`Test-TaskListDragThresholdExceeded`、`Start-TaskListItemDrag`、`Get-TaskListDragSourceId` 或 `Get-TaskListDropTargetIndex`。
- `Views.Task.Interactions.ps1` 不直接出现 `DoubleClickSize`、`DoubleClickTime`、`DoDragDrop`、`GetDataPresent`、`PointToClient` 或 `IndexFromPoint` 等低层 gesture 细节。
- `Views.Task.Gestures.ps1` 不调用 `Show-TaskMenu`、`Invoke-TaskOperationResult`、`Invoke-TaskMoveWorkflow`、`Invoke-TaskToggleCompletionWorkflow`、`Start-TaskTitleInlineEdit`、`Open-TaskLink`、`Start-PomodoroFromUi` 或任务渲染/投影函数。
- 自动检查和完整自测通过。

## 第二十三轮切片：虚化切换按钮 chrome 边界

### 问题

`WatermarkMode.ps1` 当前同时包含两类职责：一类是虚化状态生命周期、点击穿透和虚化布局切换；另一类是 `~` 按钮的创建、显隐、位置刷新、右键菜单入口、拖动手势和退出点命中判断。后者属于 UI chrome 和手势 mechanics，不应继续混在虚化生命周期里。否则后续排查“进入翻译是否改变主窗口布局/字号”时，需要同时阅读按钮事件、菜单入口、点击穿透和布局恢复逻辑。

本切片不改变 `~` 按钮行为、右键菜单、虚化拖动、点击穿透或虚化进入/退出布局。目标只是把按钮 chrome 从虚化模式实现中拆出，让 `WatermarkMode.ps1` 更接近“虚化状态与布局生命周期”。

### 调整

- 新增 `WatermarkToggleButton.ps1`。
- `WatermarkToggleButton.ps1` 负责：创建 `~` 按钮、更新按钮显隐/样式/位置、处理按钮拖动手势、打开右键菜单、判断鼠标是否落在虚化退出按钮区域。
- `WatermarkMode.ps1` 保留：虚化进入/退出、透明度、点击穿透策略、默认虚化任务视图、布局保存和恢复。
- `WatermarkMode.ps1` 不再直接读写 `WatermarkToggleDragActive`；点击穿透策略通过 `Test-WatermarkToggleDragActive` 读取按钮拖动状态。
- `ModuleLoadOrder.ps1` 保证 `WatermarkToggleButton.ps1` 在 `WatermarkMode.ps1` 之前加载；`WatermarkRuntime.ps1` 仍在具体实现模块之后加载。
- 自动检查覆盖按钮模块加载顺序、函数归属、`WatermarkMode.ps1` 禁止创建按钮和注册按钮事件、`WatermarkToggleButton.ps1` 禁止修改虚化生命周期布局。

### 验收

- `~` 按钮左键切换、右键菜单、虚化状态下顶部拖动、按钮显隐和点击穿透保持不变。
- `WatermarkMode.ps1` 不定义 `Ensure-WatermarkToggleButton`、`Update-WatermarkToggleButton` 或 `Test-WatermarkTogglePoint`，不出现 `New-Button "~"`、`Add_MouseDown`、`Add_MouseMove` 或 `Add_MouseUp`。
- `WatermarkToggleButton.ps1` 不定义 `Enter-WatermarkMode`、`Exit-WatermarkMode`、`Restore-WatermarkPreviousLayout` 或 `Set-WatermarkDefaultTaskView`，不直接调用 `Resize-WindowForTaskRows`、`Set-BottomChromeVisible`、`Apply-WatermarkGhostSurface` 或 `Restore-WatermarkGhostSurface`。
- 自动检查和完整自测通过。

## 第二十四轮切片：虚化布局快照归属边界

### 问题

`WatermarkMode.ps1` 已经拆出了 `~` 按钮 chrome，但仍直接写入和清理 `WatermarkPreviousActiveView`、`WatermarkPreviousWindowWidth`、`WatermarkPreviousWindowHeight`、`WatermarkPreviousWindowLocation`、`WatermarkPreviousMinimumSize`、`WatermarkPreviousContentBounds`、`WatermarkPreviousOpacity` 和 `WatermarkPreviousTopMost`。这些字段本质上是“进入虚化前的主窗口状态快照”，属于目标架构中的 `WindowStateCoordinator`，不应继续散落在虚化生命周期实现里。

本切片不改变进入/退出虚化、保留布局虚化、翻译叠加、设置保存或点击穿透行为。目标是让 `WatermarkMode.ps1` 只请求“保存快照、按快照恢复、清理快照”，不直接拥有主窗口快照字段。

### 调整

- `WindowStateCoordinator.ps1` 新增虚化布局快照函数：保存当前窗口快照、读取快照、恢复快照、清理快照、更新快照透明度和读取内容区快照。
- `WatermarkMode.ps1` 在进入虚化时调用 `Save-WatermarkPreviousLayoutSnapshot`，在保留布局虚化和退出虚化时调用 `Restore-WatermarkPreviousLayout`，退出后调用 `Clear-WatermarkPreviousLayoutSnapshot`。
- `WatermarkRuntime.ps1` 设置运行中透明度时不再直接写 `WatermarkPreviousOpacity`，改为委托 `Set-WatermarkPreviousOpacity`。
- `WatermarkGhostSurface.ps1` 不直接读取 `WatermarkPreviousContentBounds`，改为调用 `Get-WatermarkPreviousContentBounds`。
- 自动检查覆盖：`WindowStateCoordinator.ps1` 拥有快照函数；`WatermarkMode.ps1`、`WatermarkRuntime.ps1` 和 `WatermarkGhostSurface.ps1` 不直接读写 `WatermarkPrevious*` 布局字段。

### 验收

- 普通虚化仍进入折叠虚化视图；保留布局虚化仍保持当前视图、位置、宽高和内容区边界。
- 退出虚化仍恢复进入前视图、位置、宽高、最小尺寸、透明度和置顶状态。
- 虚化中保存设置仍保存进入虚化前的实化窗口状态。
- `WatermarkMode.ps1` 不直接出现 `$script:WatermarkPreviousWindowWidth`、`$script:WatermarkPreviousWindowHeight`、`$script:WatermarkPreviousWindowLocation`、`$script:WatermarkPreviousOpacity` 或 `$script:WatermarkPreviousTopMost`。
- 自动检查和完整自测通过。

## 第二十五轮切片：翻译浮层实现归属边界

### 问题

`TranslationSurface.ps1` 当前仍只是历史 `WatermarkTranslation.Surface.ps1` 的薄 facade，真正的 WinForms 表单创建、字体读取、短释义定位、详细面板定位、详情格式化和隐藏 timer 都还落在 `WatermarkTranslation.Surface.ps1`。这会让“翻译浮层”继续被历史虚化命名牵引，也让后续排查翻译字号、浮层位置和主窗口布局副作用时需要跨越错误的概念边界。

本切片不改变浮层视觉、点击穿透、显示时机、隐藏时机或翻译 workflow。目标只是把翻译浮层实现所有权迁入中立 `TranslationSurface.ps1`，让历史文件只承担兼容函数名，避免新代码继续依赖 `WatermarkTranslation.Surface.ps1`。

### 调整

- `TranslationSurface.ps1` 接管短释义浮层、详细面板、字体读取、屏幕边缘避让、详情格式化、显示/隐藏和释放逻辑。
- `WatermarkTranslation.Surface.ps1` 保留旧函数名，但每个旧函数只委托给 `TranslationSurface.ps1` 的中立函数。
- `WatermarkTranslation.Settings.ps1` 等可迁移调用点改用中立 `Get-TranslationSurfaceFontSize`，避免新路径继续依赖旧函数名。
- 自动检查覆盖：`TranslationSurface.ps1` 拥有浮层实现函数；`WatermarkTranslation.Surface.ps1` 不再创建表单、不设置表单样式、不直接持有浮层渲染逻辑。

### 验收

- 翻译结果仍通过 `Show-TranslationSurfaceResult` 显示，短释义和详细面板行为保持不变。
- 停止翻译仍通过 `Dispose-TranslationSurfaces` 统一释放浮层和隐藏 timer。
- `WatermarkTranslation.Surface.ps1` 不出现 `TaskPomodoroNoActivateForm`、`TaskPomodoroTranslationDetailForm`、`FormBorderStyle`、`Opacity`、`Add_Tick` 或浮层 label 文本赋值。
- `TranslationSurface.ps1` 不调用 UIA、剪贴板、词典、在线 API、窗口行数、主窗口字号或视图切换逻辑。
- 自动检查和完整自测通过。

## 第二十六轮切片：翻译 workflow 状态边界

### 问题

`TranslationWorkflow.ps1` 已经负责文本过滤、防抖、缓存查询和发布翻译结果通知，但请求防抖和“最近已显示来源”的状态仍被 `TranslationRuntime.ps1` 和历史 `WatermarkTranslation.ps1` 直接读写：`WatermarkTranslationLastSignature`、`WatermarkTranslationLastShownSignature`、`WatermarkTranslationLastSource` 和 `WatermarkTranslationLastAt` 分散在启动、停止、UIA 选区为空和失败通知处理路径里。

这些字段本质上属于翻译请求工作流，不属于 runtime timer/listener，也不属于历史兼容入口。继续分散读写会让后续排查“选区变化后为什么隐藏/为什么不重复显示”时跨越 runtime、surface 和历史入口多个文件。

本切片不改变防抖时间、重复显示规则、失败提示、UIA 空选区隐藏策略或浮层显示行为。目标只是把请求状态读写收敛到 `TranslationWorkflow.ps1` 的命名函数。

### 调整

- `TranslationWorkflow.ps1` 新增 workflow 状态函数：重置状态、判断重复请求、记录最近请求、记录已显示结果、按来源清理已显示状态。
- `Start-TranslationRuntime` 和 `Stop-TranslationRuntime` 不再直接写 `WatermarkTranslationLast*` 字段，改为调用 workflow 状态重置函数。
- `WatermarkTranslation.ps1` 的失败通知和空选区处理不再直接读写 `WatermarkTranslationLastSource` / `WatermarkTranslationLastShownSignature`，改为调用 workflow 来源清理函数。`TranslationSurface.ps1` 的隐藏 timer 也只调用 workflow 状态清理函数。
- 自动检查覆盖：除 `TranslationWorkflow.ps1` 外，runtime、surface 和历史入口不得直接读写 `WatermarkTranslationLast*` 字段。

### 验收

- 相同文本短时间重复选择仍被防抖，已显示文本不会重复刷浮层。
- UIA 选区消失时，如果最近来源是 UIA，仍隐藏翻译浮层；剪贴板来源不被误清理。
- 启动/停止翻译仍清空请求状态和浮层状态。
- `TranslationRuntime.ps1`、`TranslationSurface.ps1` 和 `WatermarkTranslation.ps1` 不直接出现 `$script:WatermarkTranslationLastSignature`、`$script:WatermarkTranslationLastShownSignature`、`$script:WatermarkTranslationLastSource` 或 `$script:WatermarkTranslationLastAt`。
- 自动检查和完整自测通过。

## 第二十七轮切片：翻译 runtime 状态命名边界

### 问题

`TranslationRuntime.ps1` 已经是翻译启动、停止、暂停、恢复、UIA timer 和剪贴板 listener 的运行期边界，但内部活动状态和 timer 句柄仍使用历史 `WatermarkTranslationMode` / `WatermarkTranslationTimer` 命名。更重要的是，`SelfTest.Ui.ps1` 仍直接读取这些 `$script:` 私有变量来判断翻译是否启动、timer 是否存在或启用。

这让测试和实现共享了旧内部字段，削弱了 `TranslationRuntime` facade 的意义。后续如果继续迁移翻译 runtime 状态，测试会逼迫实现保留历史字段，也会让“虚化”和“翻译”命名继续混在一起。

本切片不改变翻译启动/停止、设置对话框暂停恢复、UIA 轮询间隔、剪贴板监听或浮层清理行为。目标只是把 runtime 活动状态和 timer 句柄改成中立私有字段，并让外部只通过只读 runtime facade 判断状态。

### 调整

- `TranslationRuntime.ps1` 使用 `TranslationRuntimeActive` 和 `TranslationRuntimeTimer` 作为内部活动标志与 timer 句柄。
- 新增只读 facade：判断翻译 runtime 是否活动、timer 是否已创建、timer 是否正在运行。
- `SelfTest.Ui.ps1` 改用只读 facade，不再直接读取 `WatermarkTranslationMode` 或 `WatermarkTranslationTimer`。
- 自动检查覆盖：除兼容 wrapper 外，模块和自测不得直接读取 `WatermarkTranslationMode` / `WatermarkTranslationTimer`；runtime 资源检查必须走 `TranslationRuntime` facade。

### 验收

- 翻译启动后 runtime active 为 true，UIA timer 已创建并启动。
- 打开和关闭翻译设置后，runtime active 保持，timer 恢复启用。
- 停止翻译后 runtime active 为 false，timer 被释放。
- 普通模式、普通虚化模式仍不创建翻译 timer。
- `SelfTest.Ui.ps1` 不直接出现 `$script:WatermarkTranslationMode` 或 `$script:WatermarkTranslationTimer`。
- 自动检查和完整自测通过。

## 第二十八轮切片：翻译启动零布局写入审计

问题：翻译启动属于 `TranslationRuntime`，但只要启动路径中仍能触达虚化进入流程、窗口尺寸计算、任务字号应用、视图切换或通用设置保存，就可能复现主窗口跳位、字号变小或闪烁。

调整：沿 `Start-TranslationRuntime`、设置暂停/恢复、UIA tick、翻译结果显示和停止清理路径做调用链审计；把会写主窗口布局的调用移回 `WindowStateCoordinator`、`WatermarkRuntime` 或对应 UI workflow；补边界检查，禁止翻译启动路径调用 `Enter-WatermarkMode`、`Resize-WindowForTaskRows`、任务字号应用、视图切换和 `Save-GeneralSettings`。

验收：在实化普通状态和虚化普通状态开启/停止翻译，主窗口位置、宽高、任务字号、当前视图和任务行数均保持不变；翻译浮层可以显示/隐藏，但不得触发主窗口重排或反复刷新。`AutomatedChecks.Boundaries.ps1` 已禁止翻译 runtime、历史翻译入口和取词 adapter 调用虚化进入/退出、窗口 resize、视图切换、通用设置保存或任务字号字段。

## 第二十九轮切片：翻译字号与浮层状态隔离

问题：翻译字号、短释义浮层位置、详细面板位置和主窗口字号/位置曾经被混淆。只要设置字段或保存路径共用，关闭翻译设置或显示浮层时就可能污染主界面。

调整：确认 `TranslationFontSize`、短释义避让位置、详细面板默认贴近主窗口下方等都由 `TranslationSurface` 或翻译设置拥有；主窗口只提供只读风格参考。没有稳定产品设计前，不持久化独立详细面板拖动位置；如后续加入拖动点，也必须是翻译面板自己的设置项。

验收：修改翻译字号不改变任务字号；修改任务字号不改变翻译字号；翻译面板位置不写入主窗口位置；设置保存走 `Save-TranslationSettings` 或保留窗口状态的保存 facade。

## 第三十轮切片：历史翻译兼容层瘦身

问题：`WatermarkTranslation*` 文件名会持续暗示翻译从属于虚化，容易把取词、词典、API、浮层和 runtime 状态重新写回历史模块。

调整：保持旧函数名用于兼容调用，但新逻辑只进入 `TranslationRuntime`、`TranslationWorkflow`、`TranslationSelection`、`TranslationDictionary`、`TranslationLookup`、`TranslationProviders`、`TranslationSurface` 和 `TranslationRules`；边界检查逐步要求历史文件只接线、转发或承载尚未迁出的底层实现细节。

验收：新增翻译产品策略不再落入 `WatermarkTranslation*`；虚化模块只依赖 `TranslationRuntime` facade；翻译模块不依赖虚化布局实现。`TranslationLookup`、自测和 runtime 清理路径应调用中立词典函数，旧词典文件不得再读取 TSV 或持有词典缓存。

## 第三十一轮切片：翻译私有状态中立命名

问题：`TranslationWorkflow.ps1` 和 `TranslationSurface.ps1` 已经承担翻译工作流与浮层实现，但内部 `$script:` 状态仍使用 `WatermarkTranslation*` 命名。这不会立即改变行为，却会继续暗示翻译状态从属于虚化，后续维护者容易把新策略写回历史兼容层。

调整：保留 `WatermarkTranslation*` 兼容函数名用于旧调用接线，但把 workflow 最近请求/已显示状态、surface 浮层 form/label/timer 句柄改为中立 `TranslationWorkflow*` 和 `TranslationSurface*` 私有状态；补边界检查，禁止中立实现模块重新引入历史私有状态名。

验收：旧 wrapper 函数继续可用；`TranslationWorkflow.ps1` 不再持有 `$script:WatermarkTranslationLast*`；`TranslationSurface.ps1` 不再持有 `$script:WatermarkTranslationMini*`、`$script:WatermarkTranslationDetail*` 或 `$script:WatermarkTranslationHideTimer`；自动检查覆盖命名边界。

## 第三十二轮切片：翻译桥接层中立化

问题：翻译结果通知注册、UIA 选区 tick 和文本请求入口仍集中在历史 `WatermarkTranslation.ps1`，而 runtime 启动路径没有显式注册翻译通知 handler。这样既保留了“翻译属于虚化”的结构暗示，也可能导致 workflow 已产生结果但 surface 没有收到展示通知。

调整：新增 `TranslationBridge.ps1` 作为中立接线层，负责 selection -> workflow、workflow notification -> surface 的进程内桥接；`TranslationRuntime.ps1` 在启动时注册通知 handler，在停止时清理；历史 `WatermarkTranslation.ps1` 只保留旧函数名 wrapper，不再直接读取 selection、注册通知或调用 surface。

验收：启动翻译会显式注册 `TranslationCompleted` / `TranslationFailed` handler；停止翻译会清理 handler；`WatermarkTranslation.ps1` 不再包含 `Register-AppNotificationHandler`、`Show-TranslationSurfaceResult`、`Get-TranslationSelection` 或 `Invoke-TranslationWorkflowRequest` 实现细节；自动检查覆盖 bridge 加载顺序和旧入口瘦身。

## 第三十三轮切片：翻译设置对话框中立化

问题：翻译设置对话框仍完整实现于历史 `WatermarkTranslation.Settings.ps1`，并持有 `$script:WatermarkTranslationSettingsDialog`。这让局部翻译设置继续挂在虚化命名下，也使 runtime/selftest 容易直接读写历史 UI 状态。

调整：新增 `TranslationSettings.ps1` 作为中立设置对话框实现，保留现有公开函数名用于菜单和全局设置页调用；把对话框私有句柄改为 `$script:TranslationSettingsDialog`，并提供 `Get-TranslationSettingsDialog` / `Test-TranslationSettingsDialogOpen` 作为只读 facade。历史 `WatermarkTranslation.Settings.ps1` 只保留旧函数 wrapper，不再创建控件、保存设置或持有 dialog 状态。

验收：右键翻译设置和全局设置页仍使用同一组翻译设置控件；翻译设置保存仍走 `Save-TranslationSettings` / `Save-TranslationDictionarySettings`，不写主窗口字段；`TranslationRuntime.ps1` 和自测不再直接访问 `$script:WatermarkTranslationSettingsDialog`；自动检查覆盖新模块加载顺序和旧设置文件瘦身。

## 第三十四轮切片：翻译平台适配器中立化

问题：切片开始前，`WatermarkTranslation.Platform.ps1` 承载 DPAPI、Win32 native type、无焦点浮层基类和剪贴板序号 native helper。虽然它不直接决定产品策略，但文件名继续把翻译平台能力挂在虚化命名下，后续维护者容易把平台 helper、取词逻辑、浮层实现和虚化状态混在一起。

调整：新增 `TranslationPlatform.ps1` 作为中立平台适配器，接管 `Ensure-TranslationPlatformTypes`、`Protect-TranslationSecret`、`Unprotect-TranslationSecret`、native type 定义和平台 helper；`WatermarkTranslation.Platform.ps1` 退化为 `Ensure-WatermarkTranslationTypes` 等旧函数名 wrapper。`TranslationRuntime`、`TranslationSelection`、`TranslationSurface`、`TranslationProviders`、`TranslationSettings` 和自测改用中立平台函数。

验收：中立翻译模块不再调用 `Ensure-WatermarkTranslationTypes`；旧平台文件不再包含 `Add-Type -Language CSharp`、`ProtectedData` 或 native helper 实现；DPAPI roundtrip、自定义 provider secret 解密、剪贴板序号读取和浮层 native type 仍通过自动检查与自测；`ModuleLoadOrder.ps1` 明确在 provider、selection、surface、settings 前加载 `TranslationPlatform.ps1`。

## 第三十五轮切片：虚化退出不拥有翻译生命周期

问题：目标架构已经规定实化、虚化、翻译是可组合状态，但 `Exit-WatermarkMode` 仍直接调用 `Stop-TranslationRuntime`。这让虚化 runtime 拥有了翻译 timer/listener/浮层生命周期，导致“退出虚化”隐式停止翻译，也让后续排查翻译资源释放时必须阅读虚化布局恢复流程。

调整：`WatermarkMode.ps1` 退出虚化只恢复主窗口布局、透明度、置顶、点击穿透和 ghost surface；不得调用 `Start-TranslationRuntime`、`Stop-TranslationRuntime` 或读取翻译 runtime 活动状态。翻译停止只由右键菜单的 `停止翻译`、应用关闭统一清理或 `TranslationRuntime` 自身入口触发。自测改为覆盖“虚化 + 翻译 -> 退出虚化后仍处于实化 + 翻译”。

验收：在虚化 + 翻译状态点击虚化退出后，主窗口恢复实化布局，`TranslationRuntime` 仍 active，UIA timer 仍存在；随后用户点击 `停止翻译` 才释放 timer、剪贴板监听和浮层。自动检查禁止 `WatermarkMode.ps1` / `WatermarkRuntime.ps1` 调用翻译 runtime 启停或读取翻译私有状态。

## 第三十六轮切片：番茄运行态字段写入 facade

问题：`PomodoroRuntime.ps1` 已接管运行中 tick，但启动工作阶段、启动休息、启动破冰、暂停、继续、停止后回到 idle work 和当前绑定任务字段仍由 `PomodoroEngine.ps1` / `PomodoroStarter.ps1` 直接散写。这样 Engine/Starter 同时承担状态机分支和运行态字段落盘，后续迁移 `$script:` 状态所有权时缺少稳定入口。

本切片不改变番茄业务规则、破冰流程、自动下一轮、UI 对话框或记录事件。目标只是新增 `PomodoroRuntime` facade 承接机械字段写入：当前任务、阶段、开始时间、计划分钟、剩余秒数、结束时间、运行/暂停/idle 状态。

调整：`PomodoroRuntime.ps1` 新增当前任务设置、阶段启动、暂停阶段、恢复阶段和回到 idle work 的命名函数；`PomodoroEngine.ps1` 与 `PomodoroStarter.ps1` 继续决定何时启动工作/休息/破冰、何时记录事件、何时自动下一轮，但通过 runtime facade 写入运行态字段。自动检查禁止 Engine/Starter 重新直接写 `TimerState`、`TimerPhase`、`SecondsRemaining`、`PomodoroEndAt`、`PomodoroStartedAt`、`PomodoroStartedAtDate` 和 `CurrentPhasePlannedMinutes`。

验收：番茄启动、暂停、继续、停止、完成进入休息、休息完成、破冰启动/完成/停止行为保持不变；`PomodoroRuntime.ps1` 不依赖 WinForms、不弹窗、不触发 UI action wrapper；完整自测通过。

## 第三十七轮切片：设置/会话时长变更写入 facade

问题：第 36 切片已经把番茄启动、暂停、继续、停止和任务绑定字段写入收敛到 `PomodoroRuntime.ps1`，但设置页保存、恢复默认设置和 `PomodoroSession.ps1` 的会话时长调整仍可能直接写 `SecondsRemaining`、`CurrentPhasePlannedMinutes` 或 `PomodoroEndAt`。这类写入虽然不直接来自 Engine/Starter，却同样属于番茄运行态字段；继续散落会让“修改工作分钟数后当前倒计时如何变化”这个规则分散在设置 UI、会话规则和 runtime 中。

本切片不改变用户可见行为：空闲状态修改工作分钟数仍刷新空闲倒计时；运行中修改当前工作/休息时长仍按已用时间重算剩余时间；暂停状态仍保持可恢复语义；背景音刷新和设置保存流程保持原样。目标只是把机械运行态字段写入统一委托给 `PomodoroRuntime`，让 `Views.Settings*.ps1` 只表达“设置已变更”，`PomodoroSession.ps1` 只表达“会话时长策略”。

调整：`PomodoroRuntime.ps1` 新增时长变更 facade，用于空闲状态刷新工作秒数、运行/暂停状态按旧计划分钟和已用时间重算剩余时间，并在运行状态下同步 `PomodoroEndAt`。`PomodoroSession.ps1` 的 `Update-CurrentPomodoroDuration` 保留选择工作/休息分钟数和会话覆盖策略，但调用 runtime facade 写入字段。`Views.Settings.Apply.ps1` 和 `Views.Settings.ps1` 不再直接写 `SecondsRemaining`，改为调用会话/运行态 facade。自动检查扩展为禁止设置模块直接写番茄运行态字段，并禁止 `PomodoroSession.ps1` 直接写 `SecondsRemaining`、`CurrentPhasePlannedMinutes` 和 `PomodoroEndAt`。

验收：保存设置、恢复默认设置、会话选项保存默认值、空闲状态修改工作分钟数、运行中修改当前阶段时长、暂停后修改设置再继续等行为保持不变；`Views.Settings*.ps1` 不直接出现 `$script:SecondsRemaining =`；`PomodoroSession.ps1` 不直接写 `SecondsRemaining`、`CurrentPhasePlannedMinutes` 或 `PomodoroEndAt`；`PomodoroRuntime.ps1` 仍不依赖 WinForms、不弹窗、不保存设置；自动检查和完整自测通过。

## 第三十八轮切片：任务行倒计时运行态查询 facade

问题：`PomodoroInlineCountdown.ps1` 是表现层只读投影，但当前仍直接读取 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId` 和 `$script:SecondsRemaining` 来判断任务行是否显示倒计时。这不写运行态字段，风险低于前面的散写问题，但仍让表现层理解了番茄 runtime 的内部字段结构。后续如果继续收敛番茄运行态私有字段，这类只读直连会迫使内部字段名继续外泄。

本切片不改变任务行倒计时行为：运行中或暂停的绑定任务仍显示 `starter`、`pomodoro` 或 `break` 的 `mm:ss` 文本；未绑定任务、独立番茄、idle 状态和不匹配任务仍不显示。目标只是让 `PomodoroRuntime.ps1` 提供只读快照，`PomodoroInlineCountdown.ps1` 负责把快照格式化为现有 UI 投影对象。

调整：`PomodoroRuntime.ps1` 新增任务行倒计时快照查询 facade，返回任务 id、阶段 kind 和剩余秒数；该函数只读运行态字段，不依赖 WinForms、不格式化 UI 文本、不写设置或记录。`PomodoroInlineCountdown.ps1` 改为调用该 facade，并只保留 `Format-Time` 文本格式化和投影对象构造。自动检查禁止 `PomodoroInlineCountdown.ps1` 直接读取番茄运行态私有字段。

验收：今日任务行倒计时、休息继承任务行倒计时和破冰倒计时表现保持不变；`PomodoroInlineCountdown.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId` 或 `$script:SecondsRemaining`；`PomodoroRuntime.ps1` 仍不依赖 WinForms、不刷新 UI、不弹窗；自动检查和完整自测通过。
## 第三十九轮切片：会话时长阶段查询 facade

问题：`PomodoroSession.ps1` 已经把当前阶段时长写入委托给 `PomodoroRuntime.ps1`，但仍直接读取 `$script:TimerPhase` 来判断当前是否为休息阶段。这个读取很小，却让会话规则层知道了 runtime 私有字段名；后续如果继续收敛番茄运行态私有字段，会话层会阻碍 `TimerPhase` 的封装。

本切片不改变会话时长规则：当前阶段是休息时使用休息分钟数，否则使用工作分钟数；运行、暂停和空闲状态的剩余时间刷新仍由 `Update-PomodoroRuntimeDuration` 负责。目标只是新增一个 runtime 查询 facade，让会话层只表达“按当前阶段刷新时长”。

调整：`PomodoroRuntime.ps1` 新增当前是否休息阶段的只读查询函数；`PomodoroSession.ps1` 的 `Update-CurrentPomodoroDuration` 改为调用该 facade，而不是读取 `$script:TimerPhase`。自动检查扩展为禁止 `PomodoroSession.ps1` 直接读取番茄运行态阶段字段，并要求保留 runtime 查询调用。

验收：保存会话选项、修改默认工作/休息分钟数、运行中或暂停中刷新当前阶段时长的行为保持不变；`PomodoroSession.ps1` 不直接出现 `$script:TimerPhase`；`PomodoroRuntime.ps1` 仍不依赖 WinForms、不刷新 UI、不弹窗；自动检查和完整自测通过。
## 第四十轮切片：背景音淡出阶段参数边界

问题：`PomodoroAudio.ps1` 是声音资源解析、试听、背景音控制和淡出策略的所有者，但 `Update-BackgroundAudioFade` 仍直接读取 `$script:TimerPhase` 来判断当前是否处于工作、休息或破冰阶段。这样会让音频策略层知道番茄 runtime 的私有字段名，也让后续迁移 `TimerPhase` 时被音频模块牵制。

本切片不改变音频行为：只有工作、休息和破冰阶段才做最后 8 秒淡出；没有背景播放器时仍直接返回；音量计算和循环播放策略保持不变。目标只是让 `PomodoroRuntime.ps1` 作为运行态所有者把当前阶段传给音频策略，`PomodoroAudio.ps1` 只处理收到的阶段参数。

调整：`Update-BackgroundAudioFade` 增加 `Phase` 参数并用参数判断是否需要淡出；`PomodoroRuntime.ps1` 在 tick 时把当前 `$script:TimerPhase` 作为参数传入。自动检查要求 runtime 调用包含阶段参数，并禁止 `PomodoroAudio.ps1` 直接读取 `$script:TimerPhase`。

验收：运行中倒计时最后 8 秒仍按设置音量线性淡出；非工作/休息/破冰阶段不做淡出；`PomodoroAudio.ps1` 不直接出现 `$script:TimerPhase`；`PomodoroRuntime.ps1` 仍是运行态字段所有者；自动检查和完整自测通过。
## 第四十一轮切片：番茄工作流运行态快照 facade

问题：`PomodoroWorkflow.ps1` 是应用工作流层，应该负责编排 UI 意图、状态机调用和少量通知发布，但它仍直接读取 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId`、`$script:CurrentPomodoroTaskTitle` 和 `$script:PomodoroStartedAt`。这些字段属于番茄运行态所有者；workflow 直接读取会让运行态内部结构继续外泄，也会阻碍后续把状态机和 runtime 私有字段进一步拆开。

本切片不改变番茄业务流程：开始、暂停/继续、完成、追加预计番茄、完成后发布 `PomodoroFinished` 通知都保持现有行为。目标只是让 `PomodoroRuntime.ps1` 提供只读 facade：暂停/运行状态、当前任务 id、当前阶段和完成通知所需快照；`PomodoroWorkflow.ps1` 只消费这些快照并继续做应用编排。

调整：`PomodoroRuntime.ps1` 新增 `Test-PomodoroRuntimePaused`、`Test-PomodoroRuntimeRunning`、`Get-PomodoroRuntimeCurrentTaskId` 和 `Get-PomodoroRuntimeCompletionNotificationSnapshot`。`PomodoroWorkflow.ps1` 的追加计划、暂停/继续和完成通知逻辑改用这些 facade。自动检查禁止 `PomodoroWorkflow.ps1` 直接读取番茄运行态私有字段，并要求保留 runtime facade 调用。

验收：暂停/继续按钮行为不变；工作阶段完成后仍发布 `PomodoroFinished`；休息阶段完成和追加番茄提示逻辑不变；`PomodoroWorkflow.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId`、`$script:CurrentPomodoroTaskTitle` 或 `$script:PomodoroStartedAt`；自动检查和完整自测通过。
## 第四十二轮切片：设置保存后的番茄运行态刷新 facade

问题：`Views.Settings.Apply.ps1`、`Views.Settings.ps1` 和 `Views.Settings.Starter.ps1` 在保存设置或恢复默认设置后直接读取 `$script:TimerState` / `$script:TimerPhase`，用来刷新背景音或空闲倒计时。设置 UI 因此知道了番茄运行态私有字段，也让“设置保存”路径继续承担运行期资源策略，容易复发设置保存带出窗口或运行态副作用的问题。

本切片不改变设置保存行为：运行中修改音频设置后仍按当前阶段重启背景音；非暂停且非运行状态仍停止背景音；空闲状态修改工作分钟数仍刷新空闲倒计时；破冰设置对话框保存时若正在破冰运行，仍刷新破冰背景音。目标只是把这些判断收敛到 `PomodoroRuntime.ps1`，设置层只表达“设置已变更，需要刷新番茄运行态”。

调整：`PomodoroRuntime.ps1` 新增 `Update-PomodoroRuntimeAudioAfterSettingsChange` 和 `Update-PomodoroRuntimeAfterGeneralSettingsChange`。通用设置保存与恢复默认值调用 general facade，局部破冰设置保存调用 audio facade。自动检查禁止设置模块直接读取 `TimerState` / `TimerPhase`，并要求保留 runtime 刷新 facade 调用。

验收：通用设置保存、恢复默认设置、破冰设置保存后音频刷新行为保持不变；空闲状态工作分钟数刷新仍生效；`Views.Settings.Apply.ps1`、`Views.Settings.ps1`、`Views.Settings.Starter.ps1` 不直接出现 `$script:TimerState` 或 `$script:TimerPhase`；自动检查和完整自测通过。
## 第四十三轮切片：番茄运行态查询子边界

问题：随着任务行倒计时、会话时长、工作流通知和设置刷新陆续通过 runtime facade 收敛，`PomodoroRuntime.ps1` 同时承载写入命令、tick 推进、资源刷新和只读查询，已经逼近文件体积上限。继续把查询函数塞进同一个文件，会让 runtime 核心变成新的小上帝模块，也会迫使后续切片反复压缩代码来满足 guardrail。

本切片不改变任何用户可见行为，也不改变 facade 名称。目标只是把只读查询类 facade 拆入 `PomodoroRuntime.Queries.ps1`：它仍属于番茄运行态边界，可以读取 runtime 私有字段，但不得写字段、启动 timer、播放音频、刷新 UI 或保存设置。`PomodoroRuntime.ps1` 保留写入、阶段启动/暂停/继续、设置刷新、tick 推进和完成防重入。

调整：新增 `PomodoroRuntime.Queries.ps1`，迁入 `Test-PomodoroRuntimePaused`、`Test-PomodoroRuntimeRunning`、`Get-PomodoroRuntimeCurrentTaskId`、`Get-PomodoroRuntimeCompletionNotificationSnapshot`、`Test-PomodoroRuntimeBreakPhase` 和 `Get-PomodoroRuntimeInlineCountdownSnapshot`。更新 `ModuleLoadOrder.ps1`，让查询模块在 runtime 后、UI/selftest 前加载。自动检查要求查询模块只读运行态字段，并禁止 `PomodoroRuntime.ps1` 重新承载这些外部查询 facade。

验收：调用方函数名保持不变；任务行倒计时、会话时长刷新、工作流暂停/继续和完成通知行为保持不变；`PomodoroRuntime.ps1` 低于文件体积上限；`PomodoroRuntime.Queries.ps1` 不写运行态字段、不依赖 WinForms、不播放音频、不保存设置；自动检查和完整自测通过。
## 第四十四轮切片：破冰状态机运行态查询 facade

问题：`PomodoroStarter.ps1` 已经把启动、停止和完成后的运行态字段写入委托给 `PomodoroRuntime.ps1`，但仍直接读取 `$script:TimerState`、`$script:TimerPhase` 和 `$script:CurrentPomodoroTaskId` 来判断是否 idle、是否处于破冰阶段、以及当前绑定任务。这样会让破冰状态机继续知道 runtime 私有字段，也削弱刚拆出的 `PomodoroRuntime.Queries.ps1` 查询边界。

本切片不改变破冰行为：已有计时器运行时仍拒绝启动破冰；任务行破冰倒计时判断保持不变；完成破冰仍返回原任务 id 并回到 idle work；停止破冰仍清理当前任务。目标只是让破冰状态机通过只读查询 facade 获取运行态，而不是直接读字段。

调整：`PomodoroRuntime.Queries.ps1` 新增 idle、starter 阶段和指定任务是否处于破冰的查询 facade。`PomodoroStarter.ps1` 的 `Test-TaskStarterRunningForTask`、`Start-TaskStarter` 和 `Complete-TaskStarter` 改用这些 facade。自动检查禁止 `PomodoroStarter.ps1` 直接读取 `TimerState`、`TimerPhase` 和 `CurrentPomodoroTaskId`，并要求保留查询 facade 调用。

验收：破冰启动、任务行破冰显示、破冰完成、破冰停止行为保持不变；`PomodoroStarter.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase` 或 `$script:CurrentPomodoroTaskId`；`PomodoroRuntime.Queries.ps1` 继续只读；自动检查和完整自测通过。
## 第四十五轮切片：计时器动作与任务菜单运行态查询 facade

问题：`Views.Timer.Actions.ps1` 和 `Views.Task.Menu.ps1` 是 UI action/menu 层，但仍直接读取 `$script:TimerState` / `$script:TimerPhase` 来判断是否可启动番茄、是否应完成破冰、以及右键菜单显示“暂停”还是“继续”。这些判断属于运行态只读查询，UI 层直接读取字段会继续暴露 runtime 内部结构。

本切片不改变 UI 行为：已有计时器运行时从 UI 启动番茄仍返回 `TimerAlreadyRunning`；破冰阶段点击完成仍走破冰完成 UI；今日任务右键菜单仍根据暂停状态显示“继续”或“暂停”。目标只是把这些 UI 判断改为调用 `PomodoroRuntime.Queries.ps1` 的只读 facade。

调整：`Views.Timer.Actions.ps1` 使用 `Test-PomodoroRuntimeIdle` 和 `Test-PomodoroRuntimeStarterPhase`；`Views.Task.Menu.ps1` 使用 `Test-PomodoroRuntimePaused`。自动检查禁止这两个 UI 文件直接读取 `TimerState` / `TimerPhase`，并要求保留对应查询 facade 调用。

验收：计时器 action wrapper 和今日任务右键菜单行为保持不变；`Views.Timer.Actions.ps1` 和 `Views.Task.Menu.ps1` 不直接出现 `$script:TimerState` 或 `$script:TimerPhase`；自动检查和完整自测通过。
## 第四十六轮切片：计时器视图运行态快照 facade

问题：`Views.Timer.ps1` 已经把跨视图番茄动作迁入 `Views.Timer.Actions.ps1`，但计时器标签刷新、按钮启停和设置入口仍直接读取 `$script:TimerState`、`$script:TimerPhase`、`$script:SecondsRemaining`、`$script:CurrentPomodoroTaskId` 和 `$script:CurrentPomodoroTaskTitle`。这让表现层继续知道番茄 runtime 私有字段，也会拖慢后续把运行态字段迁入更明确状态容器的工作。

本切片不改变任何用户可见行为：计时器剩余时间、阶段标题、任务标题、开始/暂停按钮状态和破冰设置入口保持原样。目标只是新增一个 timer view 只读快照，让 `Views.Timer.ps1` 负责 UI 渲染，`PomodoroRuntime.Queries.ps1` 负责运行态字段读取。

调整：`PomodoroRuntime.Queries.ps1` 新增 `Get-PomodoroRuntimeTimerViewSnapshot`，返回 state、phase、remaining seconds、当前任务 id/title 和常用布尔状态。`Views.Timer.ps1` 的 click handler 与 `Update-TimerLabels` 只读取该快照，不直接访问 runtime 私有字段。自动检查要求计时器视图使用快照，并禁止重新出现直接 runtime 字段读取。

验收：番茄页显示、开始、暂停/继续、设置入口和标题刷新保持不变；`Views.Timer.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase`、`$script:SecondsRemaining`、`$script:CurrentPomodoroTaskId` 或 `$script:CurrentPomodoroTaskTitle`；`PomodoroRuntime.Queries.ps1` 继续只读、不写设置、不刷新 UI、不播放音频；自动检查和完整自测通过。

## 第四十七轮切片：破冰完成 UI 当前任务查询 facade

问题：`Views.Timer.Starter.ps1` 是破冰完成后的 UI 对话框和后续选择流程，但 `Complete-TaskStarterFromUi` 仍直接读取 `$script:CurrentPomodoroTaskId` 来保留完成前绑定任务。这个读取很小，却让 UI 对话框知道番茄 runtime 私有字段，和第 46 切片刚建立的 timer view 查询边界不一致。

本切片不改变破冰完成后的用户选择行为：继续番茄、再做一次、完成任务或停止都保持原样。目标只是把当前绑定任务 id 的读取改为 `PomodoroRuntime.Queries.ps1` 的公开 facade。

调整：`Views.Timer.Starter.ps1` 使用 `Get-PomodoroRuntimeCurrentTaskId` 获取完成前任务 id；自动检查禁止该 UI 文件直接读取 `CurrentPomodoroTaskId`、`TimerState` 或 `TimerPhase`。

验收：破冰完成对话框行为保持不变；`Views.Timer.Starter.ps1` 不直接出现 `$script:CurrentPomodoroTaskId`、`$script:TimerState` 或 `$script:TimerPhase`；完整自动检查和自测通过。

## 第四十八轮切片：番茄 Engine 运行态读取快照 facade

问题：`PomodoroEngine.ps1` 已经把运行态字段写入委托给 `PomodoroRuntime.ps1`，但状态机分支仍直接读取 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId`、`$script:PomodoroStartedAt` 和 `$script:PomodoroStartedAtDate`。Engine 可以保留“何时启动、暂停、停止、完成和进入休息”的状态机职责，但不应知道 runtime 私有字段名。

本切片不改变番茄行为：开始、暂停、继续、停止、完成工作、完成休息、自动下一轮、手动下一轮和记录事件保持原样。目标只是给 Engine 一个只读快照，把运行态读取集中到 `PomodoroRuntime.Queries.ps1`。

调整：`PomodoroRuntime.Queries.ps1` 新增 `Get-PomodoroRuntimeEngineSnapshot`，返回 state、phase、current task id、started-at 和常用布尔状态。`PomodoroEngine.ps1` 通过该快照和已有 `Get-PomodoroRuntimeCurrentTaskId` 判断状态、构造记录事件和返回 result data。自动检查禁止 Engine 直接读取 runtime 私有字段。

验收：`PomodoroEngine.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase`、`$script:CurrentPomodoroTaskId`、`$script:PomodoroStartedAt` 或 `$script:PomodoroStartedAtDate`；番茄主流程自测通过；完整自动检查通过。

## 第四十九轮切片：自测番茄运行态断言查询 facade

问题：生产代码中的番茄运行态读取已经收敛到 `PomodoroRuntime.ps1` / `PomodoroRuntime.Queries.ps1`，但 `SelfTest.Pomodoro.ps1` 和 `SelfTest.Tasks.ps1` 仍直接读取 `$script:TimerState`、`$script:TimerPhase`、`$script:SecondsRemaining` 和 `$script:CurrentPomodoroTaskId`。自测属于质量闸门，也不应继续固化 runtime 私有字段名，否则后续迁移状态容器时测试会成为新的耦合点。

本切片不改变任何自测覆盖语义：仍验证启动、暂停、继续、停止、任务突变清理、破冰、休息、手动下一轮和默认任务动作。目标只是让断言通过现有 runtime 查询 facade 读取状态。

调整：`SelfTest.Pomodoro.ps1` 使用 `Get-PomodoroRuntimeTimerViewSnapshot` 或 `Get-PomodoroRuntimeCurrentTaskId` 断言状态、阶段、剩余秒数和任务绑定；`SelfTest.Tasks.ps1` 使用 `Test-PomodoroRuntimeIdle` 断言默认任务动作不启动计时器。自动检查禁止自测文件直接读取番茄 runtime 私有字段。

验收：`SelfTest.Pomodoro.ps1` 和 `SelfTest.Tasks.ps1` 不直接出现 `$script:TimerState`、`$script:TimerPhase`、`$script:SecondsRemaining` 或 `$script:CurrentPomodoroTaskId`；完整自动检查和主脚本自测通过。

## 第五十轮切片：番茄会话轮次 facade

问题：番茄运行态字段已经收敛到 runtime 边界，但会话轮次字段仍直接暴露：`PomodoroEngine.ps1` 直接读取/递增 `$script:PomodoroSessionStartedCount`，直接读取 `$script:PomodoroSessionMaxRounds` 判断是否还有下一轮；`Views.Timer.SettingsDialog.ps1` 直接读取最大轮次；`SelfTest.Pomodoro.ps1` 也直接断言 started count。连续轮次属于 `PomodoroSession.ps1` 的会话规则，不应由 Engine、UI 或自测读取私有字段。

本切片不改变用户可见行为：连续番茄轮次、手动下一轮、设置对话框默认轮次数和自测断言保持原样。目标只是新增 session facade，收回轮次读写所有权。

调整：`PomodoroSession.ps1` 新增“是否应因新任务重置会话”“递增已开始轮次”“是否还有下一轮”“读取已开始轮次/最大轮次”的 facade。Engine、设置对话框和自测改用这些 facade；自动检查禁止非 session 模块直接访问 `PomodoroSessionStartedCount` / `PomodoroSessionMaxRounds`。

验收：`PomodoroEngine.ps1`、`Views.Timer.SettingsDialog.ps1`、`SelfTest.Pomodoro.ps1` 不直接出现 `$script:PomodoroSessionStartedCount` 或 `$script:PomodoroSessionMaxRounds`；完整自动检查和主脚本自测通过。

## 每轮通用检查

- 更新相关文档。
- 运行 `git diff --check`。
- PowerShell 代码改动运行 `Invoke-AutomatedChecks.ps1`，如果正在运行应用且只需只读闸门，可先运行 `-SkipSelfTest`。
- 涉及窗口、虚化、翻译或点击穿透时，必须补手动冒烟记录。

## 第五十一轮切片：窗口拖动位置写入 facade

问题：`WindowDrag.ps1` 是低层拖动手势模块，但当前直接读取 `$script:Form.Location` 作为拖动起点，并在鼠标移动时直接写回 `$script:Form.Location`。这让手势层拥有了主窗口位置写入能力，和主架构文档中“主窗口位置由 `WindowStateCoordinator.ps1` 拥有”的边界不一致。后续如果窗口位置要考虑虚化快照、屏幕边界或持久化策略，直接写入会继续制造分叉。

本切片不改变拖动行为：按住可拖动区域仍按鼠标位移移动主窗口；拖动状态仍由 `WindowDrag.ps1` 持有；不改变保存窗口位置的时机，也不新增自动持久化。目标只是把运行中主窗口位置的读取/写入收敛到 `WindowStateCoordinator.ps1`，让拖动模块只表达“从起点移动到新点”。

调整：`WindowStateCoordinator.ps1` 新增运行期窗口位置 facade，用于读取当前主窗口位置和设置当前位置。`WindowDrag.ps1` 的拖动起点读取与移动写入改为调用这些 facade；自动检查要求 `WindowDrag.ps1` 保留 facade 调用，并禁止直接出现 `$script:Form.Location`。

验收：窗口拖动行为保持不变；`WindowDrag.ps1` 不直接出现 `$script:Form.Location`；`WindowStateCoordinator.ps1` 继续是窗口位置、尺寸和窗口字段持久化的所有者；完整自动检查和主脚本自测通过。
## 第五十二轮切片：窗口行数尺寸 facade

问题：第 51 切片已经把窗口拖动的 `Location` 写入收敛到 `WindowStateCoordinator.ps1`，但 `WindowSize.ps1` 仍直接读取 `$script:Form.Height`、`$script:Form.Padding` 和 `$script:Form.MinimumSize`，并直接写 `$script:Form.MinimumSize` / `$script:Form.Height`。`WindowSize.ps1` 可以保留“任务行数如何换算成窗口高度”和尺寸按钮状态，但运行中主窗口尺寸字段仍应由窗口状态边界拥有。

本切片不改变用户可见行为：折叠仍显示 2 行，展开仍显示 10 行；`Ensure-TaskRowsVisible` 仍只在当前高度不足时增高；`Resize-WindowForTaskRows` 仍设置目标高度并更新尺寸按钮；不改变窗口位置、保存时机或虚化布局快照。

调整：`WindowStateCoordinator.ps1` 新增运行期尺寸快照和高度写入 facade，集中读取当前高度、内容 padding 和最小宽度，并负责设置最小高度与当前高度。`WindowSize.ps1` 改为只调用这些 facade 做行数换算和高度请求；自动检查禁止 `WindowSize.ps1` 直接访问 `Form.Height`、`Form.MinimumSize` 或 `Form.Padding`。

验收：窗口折叠/展开、任务行数计算和虚化前后布局保持不变；`WindowSize.ps1` 不直接出现 `$script:Form.Height`、`$script:Form.MinimumSize` 或 `$script:Form.Padding`；`WindowStateCoordinator.ps1` 继续低于文件体积上限；完整自动检查和主脚本自测通过。
## 第五十三轮切片：窗口安全落点边界

问题：`WindowSize.ps1` 已经只通过窗口状态 facade 读写运行中高度和最小尺寸，但仍定义 `Get-SafeWindowLocation`，内部直接访问 `Screen.AllScreens`、`WorkingArea` 和 `PrimaryScreen`。这个函数处理的是主窗口启动/恢复时的屏幕安全落点，不是任务行数高度换算；继续放在 `WindowSize.ps1` 会让该模块同时承担“行数尺寸”和“屏幕放置策略”两个职责。

本切片不改变启动布局行为：已有窗口坐标仍会被校正到可见屏幕工作区；保存为空或无效坐标时仍返回 `$null` 或居中到主屏幕；自测中越界坐标应仍被修正。目标只是把屏幕工作区依赖从 `WindowSize.ps1` 拆出，放入窗口状态边界的轻量 `WindowPlacement.ps1`，避免继续扩大 `WindowStateCoordinator.ps1`。

调整：新增 `WindowPlacement.ps1`，承载 `Get-SafeWindowLocation` 和屏幕工作区计算；`WindowSize.ps1` 删除该函数，只保留任务行数高度、折叠/展开和顶部拖动带判断。模块加载顺序保证 `WindowPlacement.ps1` 在启动主脚本和自测调用前加载；自动检查禁止 `WindowSize.ps1` 再出现 `Screen.AllScreens`、`PrimaryScreen`、`WorkingArea` 或 `Get-SafeWindowLocation` 定义。

验收：启动窗口位置恢复和越界坐标校正行为保持不变；`WindowSize.ps1` 不直接出现屏幕工作区 API；`WindowPlacement.ps1` 不读写设置、不触碰虚化或翻译生命周期；完整自动检查和主脚本自测通过。
## 第五十四轮切片：窗口/虚化 chrome facade

问题：第 51-53 切片已经把主窗口位置、高度、最小尺寸和安全落点收敛到窗口状态边界，但 `WatermarkMode.ps1` / `WatermarkRuntime.ps1` 仍直接写 `Form.Opacity`、`Form.TopMost`、`Form.WatermarkMode`、`Form.WatermarkExitSize` 和点击穿透状态。这样虚化生命周期仍能绕过窗口边界直接改主窗体 chrome，后续翻译叠加时容易再次出现主界面状态被误改的问题。

本切片不改变虚化行为：进入虚化仍使用既有透明度、置顶和退出热区；设置窗口打开时仍可暂停点击穿透；退出虚化仍通过既有快照恢复主窗口 chrome。目标只是把运行中的主窗体 chrome 写入收口到一个轻量 facade。

调整：新增 `WindowChrome.ps1`，封装主窗体是否可用、虚化标志、透明度、置顶、虚化退出热区和点击穿透读写；`WatermarkMode.ps1` / `WatermarkRuntime.ps1` 改为调用该 facade。自动检查要求 `WindowChrome.ps1` 在虚化模块前加载，并禁止虚化 lifecycle/runtime 模块直接访问这些 `Form` chrome 字段。

验收：虚化切换、点击穿透、退出热区和运行中透明度设置行为保持不变；`WatermarkMode.ps1` / `WatermarkRuntime.ps1` 不再直接出现 `Form.Opacity`、`Form.TopMost`、`Form.WatermarkMode`、`Form.WatermarkExitSize`、`Form.SetClickThrough` 或 `Form.ClickThroughEnabled`；自动边界检查通过。
## 第五十五轮切片：历史翻译 wrapper 防回退

问题：第 30-34 切片已经把词典、平台、浮层、设置、桥接和 runtime 迁入中立 `Translation*` 模块，当前 `WatermarkTranslation*` 文件也基本只剩旧函数名转发。但原有检查分散在多个边界脚本里，且重点是禁止若干已迁出的函数，不能系统性阻止后续把 WinForms、UIA、网络/API、DPAPI、词典解析、通知接线或 runtime 私有状态重新写回历史文件。

本切片不改变翻译行为，也不删除旧函数名；这些旧函数仍用于兼容已有调用路径。目标是把“历史文件只能做 wrapper”变成独立、可维护的质量闸门。

调整：新增 `AutomatedChecks.LegacyTranslation.ps1`，集中检查五个 `WatermarkTranslation*` 文件的 wrapper 标记，并禁止真实实现依赖进入这些文件；主检查脚本新增 `Legacy translation wrapper boundaries` 检查，同时将历史 wrapper 文件的行数预算压到兼容层规模。

验收：`WatermarkTranslation.ps1`、`.Dictionary.ps1`、`.Platform.ps1`、`.Settings.ps1` 和 `.Surface.ps1` 继续提供旧函数名，但不得创建窗体、读 UIA、联网、做 DPAPI、解析词典、写剪贴板、注册通知 handler、持有 runtime 私有状态或保存设置；完整自动检查通过。
## 第五十六轮切片：自动检查窗口状态边界拆分

问题：`AutomatedChecks.Boundaries.ps1` 已经接近硬行数上限，并且同时承载任务菜单、设置视图、通知、音频、窗口状态和历史翻译等多个边界。窗口状态相关检查本身已经形成独立架构主线，如果继续放在通用边界脚本里，后续窗口/虚化调整会让检查脚本变成新的上帝文件。

本切片不改变应用行为和检查语义。目标只是把窗口状态质量闸门拆到同名 helper，让“窗口状态边界”在代码、文档和检查脚本中对齐。

调整：新增 `AutomatedChecks.WindowState.ps1`，迁入 `Invoke-WindowStateBoundaryCheck`；主检查入口 dot-source 该 helper，继续以 `Window state boundaries` 名称执行；`AutomatedChecks.Boundaries.ps1` 继续保留尚未拆出的通用边界检查。文件体积守卫同步加入新 helper，并下调通用边界脚本预算。

验收：自动检查输出中的 `Window state boundaries` 仍存在且通过；`AutomatedChecks.Boundaries.ps1` 行数明显下降；窗口状态检查仍覆盖 `WindowStateCoordinator.ps1`、`WindowPlacement.ps1`、`WindowSize.ps1`、`WindowDrag.ps1` 和虚化快照相关规则；`-SkipSelfTest` 自动检查通过。
## 第五十七轮切片：自动检查任务菜单边界拆分

问题：`AutomatedChecks.Boundaries.ps1` 中最大的剩余函数是 `Invoke-TaskMenuHelperBoundaryCheck`，它覆盖任务列表选择、交互、手势、item 投影、事件接线、菜单构造、链接菜单、完成页和更多页等多个 UI 子边界。该检查和任务列表/菜单架构高度相关，继续留在通用边界脚本里，会让通用脚本承担过多 UI 细节。

本切片不改变检查语义和产品行为。目标是让任务菜单/列表质量闸门按同名边界独立维护，同时把仅供该检查使用的 PowerShell AST 函数名 helper 一并迁出。

调整：新增 `AutomatedChecks.TaskMenu.ps1`，迁入 `Get-PowerShellFunctionNames` 和 `Invoke-TaskMenuHelperBoundaryCheck`；主检查入口 dot-source 该 helper，继续以 `Task menu helper boundaries` 名称执行。通用 `AutomatedChecks.Boundaries.ps1` 只保留尚未拆出的设置、音频、通知和历史翻译等检查。

验收：自动检查输出中的 `Task menu helper boundaries` 仍存在且通过；`AutomatedChecks.Boundaries.ps1` 行数继续下降；任务列表/菜单检查仍覆盖 `Views.Task.*`、`Views.Menu.Builders.ps1`、`Views.Done.ps1` 和 `Views.More.ps1` 的边界；`-SkipSelfTest` 自动检查通过。
## 第五十八轮切片：自动检查设置视图边界拆分

问题：设置视图边界已经在代码中拆成 `Views.Settings.*`、`SettingsWorkflow.ps1` 和设置保存策略，但对应检查仍留在通用 `AutomatedChecks.Boundaries.ps1`。这让通用脚本继续知道设置页行构造、设置保存 workflow 和 starter 设置控件的细节，和按目标边界维护质量闸门的方向不一致。

本切片不改变设置页行为，也不修改设置保存逻辑。目标只是把设置视图质量闸门拆到同名 helper，使设置 UI 分层的检查和实现边界对齐。

调整：新增 `AutomatedChecks.SettingsView.ps1`，迁入 `Invoke-SettingsViewBoundaryCheck`；主检查入口 dot-source 该 helper，继续以 `Settings view boundaries` 名称执行。通用 `AutomatedChecks.Boundaries.ps1` 只保留尚未拆出的音频、通知和历史翻译等检查。

验收：自动检查输出中的 `Settings view boundaries` 仍存在且通过；`AutomatedChecks.Boundaries.ps1` 行数继续下降；设置检查仍覆盖 `Views.Settings.General.ps1`、`Views.Settings.Pomodoro.ps1`、`Views.Settings.Apply.ps1`、`Views.Settings.Starter.ps1` 和 `SettingsWorkflow.ps1` 的边界；`-SkipSelfTest` 自动检查通过。
## 第五十九轮切片：自动检查翻译模块边界拆分

问题：翻译模块已经按中立 `Translation*` 边界迁移，并额外建立了 `AutomatedChecks.LegacyTranslation.ps1` 防止历史 wrapper 回流真实实现；但更宽的 `Invoke-WatermarkTranslationBoundaryCheck` 仍留在通用 `AutomatedChecks.Boundaries.ps1`。该检查覆盖平台、词典、surface、selection、bridge、runtime、菜单和自测等翻译边界，不应继续放在通用脚本中。

本切片不改变翻译行为，也不改变检查语义。目标是让“翻译模块边界”和“历史 wrapper 防回退”都由翻译相关 helper 维护，通用边界脚本继续减负。

调整：新增 `AutomatedChecks.WatermarkTranslation.ps1`，迁入 `Invoke-WatermarkTranslationBoundaryCheck`；主检查入口 dot-source 该 helper，继续以 `Watermark translation module boundaries` 名称执行。`AutomatedChecks.LegacyTranslation.ps1` 继续专注 compatibility-only 规则，不与本 helper 合并。

验收：自动检查输出中的 `Watermark translation module boundaries` 和 `Legacy translation wrapper boundaries` 均存在且通过；`AutomatedChecks.Boundaries.ps1` 行数继续下降；翻译模块检查仍覆盖 `TranslationPlatform`、`TranslationDictionary`、`TranslationSurface`、`TranslationSelection`、`TranslationBridge`、`TranslationRuntime`、`WatermarkMode.Menu` 和历史兼容文件边界；`-SkipSelfTest` 自动检查通过。
## 第六十轮切片：自动检查音频/通知边界拆分

问题：经过第 56-59 切片，通用 `AutomatedChecks.Boundaries.ps1` 只剩 `Invoke-AudioPlaybackBoundaryCheck` 和 `Invoke-NotificationHubBoundaryCheck`。这两个检查分别对应音频适配器边界和轻量通知 hub 边界，继续留在通用脚本里已经没有收益，反而让“通用边界脚本”成为残留聚合点。

本切片不改变音频播放、番茄音频策略或通知发布行为。目标是完成质量闸门拆分，让所有具体边界检查都有同名 helper。

调整：新增 `AutomatedChecks.AudioPlayback.ps1` 和 `AutomatedChecks.NotificationHub.ps1`，分别迁入音频播放和通知 hub 边界检查；主检查入口继续以 `Audio playback module boundaries` 与 `Notification hub boundaries` 名称执行。`AutomatedChecks.Boundaries.ps1` 保留为空壳过渡文件，只说明具体边界已拆出。

验收：自动检查输出中的 `Audio playback module boundaries` 和 `Notification hub boundaries` 仍存在且通过；`AutomatedChecks.Boundaries.ps1` 不再定义具体 `Invoke-*BoundaryCheck` 函数；音频检查仍覆盖 `AudioPlayback.ps1` / `PomodoroAudio.ps1` 分层，通知检查仍覆盖 `NotificationHub.ps1` / `SettingsWorkflow.ps1` 分层；`-SkipSelfTest` 自动检查通过。