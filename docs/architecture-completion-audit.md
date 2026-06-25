# 目标架构完成度审计

最后更新：2026-06-22

## 结论

当前目标架构调整按工程风险审计已达标。这里的“达标”表示高风险边界已经有明确所有者、代码落点和自动检查；它不表示所有历史文件都被重写成全新架构。

已达成的主线是：窗口状态、虚化、翻译、设置保存、任务 UI、番茄 UI、音频播放和通知 hub 都已经有目标边界、代码落点和自动检查。番茄状态机分支、历史兼容 wrapper、自测夹具和 runtime 内部 `$script:` 字段属于有意保留的实现细节，不再列为本轮架构调整阻塞项。

## 审计依据

- `docs/architecture.md` 中的 `Clean-lite + Event-lite` 分层、状态所有权地图和目标调用链。
- `docs/architecture-refactor-plan.md` 中 1-81 切片的落地状态。
- `task-pomodoro/modules/ModuleLoadOrder.ps1` 的当前模块加载顺序。
- `task-pomodoro/scripts/Invoke-AutomatedChecks.ps1` 与 `AutomatedChecks.*.ps1` 的质量闸门覆盖。
- 定向搜索结果：workflow/runtime/UI/window/translation/settings 的直接状态访问、直接 `Save-Settings` 调用、历史 `WatermarkTranslation*` 入口和窗口 chrome 写入。

## 完成度矩阵

| 目标边界 | 当前状态 | 证据 | 后续动作 |
| --- | --- | --- | --- |
| 窗口状态与主窗体 chrome | 达标 | `WindowStateCoordinator.ps1`、`WindowChrome.ps1`、`AutomatedChecks.WindowState.ps1`、`AutomatedChecks.WatermarkRuntime.ps1` | 本轮已收口残留的 `WatermarkToggleButton.ps1` 点击穿透写入和 `Views.Settings.Apply.ps1` 置顶写入。继续禁止翻译/局部设置绕过窗口边界。 |
| 虚化/翻译正交 | 达标 | `WatermarkRuntime.ps1`、`TranslationRuntime.ps1`、`TranslationBridge.ps1`、`AutomatedChecks.WatermarkRuntime.ps1`、`AutomatedChecks.WatermarkTranslation.ps1` | 保留组合运行能力，但不得恢复“启动翻译即进入虚化”或“退出虚化即释放翻译”的隐式生命周期。 |
| 翻译中立模块 | 达标 | `Translation*` 模块已接管 runtime、surface、selection、dictionary、lookup、providers、settings；`WatermarkTranslation*` wrapper 有实现禁用检查和专属行数预算 | 暂不删除 wrapper；兼容层只允许旧函数名转发。 |
| 设置保存策略 | 达标 | `SettingsWorkflow.ps1`、翻译设置保存走 `Save-TranslationSettings`、通用设置走 `Save-GeneralSettings`，应用生命周期和运行期字段保存也有命名 facade | `TaskPomodoro.ps1`、`AppMaintenance.ps1`、`TaskArchive.ps1`、`DesktopShortcut.ps1` 已完成归类；裸 `Save-Settings` 仅保留在底层 `SettingsStore` 与自测夹具。 |
| 任务 UI 子边界 | 达标 | `Views.Task.*` 已拆分 controls/items/events/gestures/interactions/menu；`TaskWorkflow.ps1` 和 `AutomatedChecks.TaskWorkflow.ps1` 已存在 | 后续新增任务突变必须走 `TaskWorkflow`，不要把持久化或跨领域副作用写回 Views。 |
| 番茄 UI/workflow/runtime | 达标 | `PomodoroResults.ps1`、`PomodoroEvents.ps1`、`PomodoroFormat.ps1`、`PomodoroPlanning.ps1`、`PomodoroWorkflow.ps1`、`PomodoroRuntime.ps1`、`PomodoroRuntime.Queries.ps1`、`PomodoroSession.ps1`、`Views.Timer.Actions.ps1`、相关自动检查 | tick 完成入口、操作结果对象、事件对象、事件语义 helper、记录事件语义、启动任务绑定、任务变更失效编排、计划补全规则、下一轮计划决策、破冰启动任务绑定、番茄/破冰状态机事件集合、时间格式化、破冰文案格式化、破冰完成默认动作和破冰时长读取边界已收口；状态机分支保留在 `PomodoroEngine.ps1` / `PomodoroStarter.ps1`，但外部读写必须继续经过 workflow、runtime/query 和 planning/session facade。 |
| 轻量事件通知 | 达标 | `NotificationHub.ps1`、`AppResultEvents.ps1`、通知 hub 边界检查 | 保持同步、进程内、少量通知；不升级成通用 Event Bus。 |
| 基础设施适配器 | 达标 | `AudioPlayback.ps1`、`TranslationPlatform.ps1`、`TranslationSelection.ps1`、`TranslationProviders.ps1`、`TranslationDictionary.ps1` | provider/API、UIA、只读剪贴板监听继续保持 adapter 属性，不决定产品流程。 |
| 质量闸门 | 达标 | `AutomatedChecks.Boundaries.ps1` 已瘦身；窗口、任务菜单、设置视图、翻译、音频、通知等检查独立 | 后续每个中等切片必须同时更新同名检查；完整自测仍较慢，日常架构切片可先跑 `-SkipSelfTest`。 |

## 本轮发现并处理的问题

1. `WatermarkToggleButton.ps1` 在拖动虚化按钮时直接调用 `$script:Form.SetClickThrough($false)`，绕过 `WindowChrome.ps1`。
2. `Views.Settings.Apply.ps1` 在应用通用设置时直接写 `$script:Form.TopMost`，绕过 `WindowChrome.ps1`。
3. 执行计划的第 60 切片后阶段存在重复的“完成度审计”条目，容易让下一步优先级失真。

本轮代码切片已把 1、2 改为通过 `WindowChrome.ps1` facade，并补边界检查防回退。第 3 项在执行计划中同步清理。

追加切片已把 `UiTimer.ps1` 的 tick 完成入口改为调用 `Complete-PomodoroTickFromUi`，completion guard 的释放归入 `Views.Timer.Actions.ps1`，并在番茄 runtime/workflow 自动检查中防回退。

结果对象边界切片已完成：`New-PomodoroOperationResult` 迁入 `PomodoroResults.ps1`，`PomodoroEngine.ps1` 不再拥有被 `PomodoroStarter`、`PomodoroWorkflow` 和 `Views.Timer.Actions` 复用的结果对象 schema。

时间格式化边界切片已完成：`Format-Time` 迁入 `PomodoroFormat.ps1`，`PomodoroEngine.ps1` 不再拥有被计时器视图和任务行内倒计时复用的文本格式化 helper。

设置保存调用点切片已完成：应用重启/更新前保存使用 `Save-AppLifecycleSettings`，每日归档时间戳和首次快捷方式提示使用 `Save-AppRuntimeSettings`，底层 `SettingsStore` 和自测夹具保留直接 `Save-Settings`。

番茄事件对象边界切片已完成：`New-PomodoroEvent` 与 `Add-PomodoroResultEvents` 迁入 `PomodoroEvents.ps1`，`PomodoroCoordinator.ps1` 只保留 result event 副作用执行入口。

番茄事件语义 helper 切片已完成：背景音、开始音、提醒、记录追加和任务番茄数递增的事件 shape 由 `PomodoroEvents.ps1` 统一构造，状态机不再手写 result event 类型字符串。

番茄下一轮计划决策切片已完成：`PomodoroPlanning.ps1` 接管休息结束后的轮次和任务剩余番茄判断，`PomodoroEngine.ps1` 只消费决策对象。

番茄记录事件语义切片已完成：工作完成、休息完成、中断和跳过休息的记录事件字段由 `PomodoroEvents.ps1` 统一构造，`PomodoroEngine.ps1` 不再计算 elapsed/planned/result 细节。

番茄启动任务绑定切片已完成：`PomodoroPlanning.ps1` 接管启动时任务查找和绑定对象构造，`PomodoroEngine.ps1` 不再直接调用 `Get-TaskById` 绑定当前任务。

任务变更计时器失效 workflow 切片已完成：`PomodoroWorkflow.ps1` 接管 `TaskTimerInvalidated` 后是否停止当前计时器的编排，`PomodoroEngine.ps1` 不再承载任务变更清理入口。

番茄计划补全规则切片已完成：预计番茄的启动前判断、启动时补写、休息后追加判断和追加写入进入 `PomodoroPlanning.ps1`，`PomodoroWorkflow.ps1` 不再直接读写任务估算字段。

破冰启动任务绑定切片已完成：破冰启动时的任务查找和绑定对象构造进入 `PomodoroPlanning.ps1`，`PomodoroStarter.ps1` 不再直接调用 `Get-TaskById`。

番茄状态机事件集合切片已完成：工作开始、暂停、继续、中断、工作完成、休息开始和休息完成对应的事件集合进入 `PomodoroEventSets.ps1`，`PomodoroEngine.ps1` 不再拼接底层事件数组或读取开始音设置。

主脚本保存语义入口切片已完成：数据检查保存走 `Save-SettingsPreservingWindowState`，窗体关闭保存走 `Save-AppLifecycleSettings`，`TaskPomodoro.ps1` 不再直接调用底层 `Save-Settings`。

破冰状态机事件集合切片已完成：破冰开始、停止和完成对应的事件集合进入 `PomodoroEventSets.ps1`，`PomodoroStarter.ps1` 不再直接构造底层背景音事件。

历史翻译 wrapper 显式瘦身审计已完成：`WatermarkTranslation*` 兼容文件保持 2-37 行规模，`AutomatedChecks.LegacyTranslation.ps1` 已增加专属行数预算和实现禁用检查，防止真实实现回流历史命名文件。

破冰文案格式化边界切片已完成：破冰菜单和完成对话框文案 helper 进入 `PomodoroFormat.ps1`，`PomodoroStarter.ps1` 不再拼接中英文标签或持有编码文案片段。

破冰完成默认动作边界切片已完成：破冰完成对话框默认动作读取与兜底进入 `PomodoroWorkflow.ps1`，`PomodoroStarter.ps1` 不再读取 `StarterDefaultAction` 设置。

破冰时长读取边界切片已完成：破冰分钟数读取与秒数派生进入 `PomodoroSession.ps1`，和工作/休息分钟数同属时长规则边界；`PomodoroStarter.ps1` 不再读取 `StarterMinutes` 设置。
最终达标审计已完成：定向搜索确认翻译模块没有主窗口布局/保存穿透，非番茄 runtime/query 模块没有番茄运行态私有字段访问，非设置存储/workflow/自测模块没有裸 `Save-Settings`；完整自动检查和主脚本自测作为最终质量门。

## 有意保留的非阻塞实现细节

- `PomodoroRuntime.ps1` 与 `PomodoroRuntime.Queries.ps1` 仍直接读写番茄运行态 `$script:` 字段，这是当前 runtime 所有权内部实现，不应误判为跨边界泄漏；真正需要审计的是外部模块是否绕过 facade。
- `SelfTest.Ui.ps1` 仍直接构造和检查窗体字段，这是自测夹具行为；不要把它当成生产架构边界问题。
- `TranslationRuntime.ps1` 创建 WinForms timer 并读取 `$script:Form`，属于运行期能力层职责；边界检查继续确保它不写主窗口布局、字号或视图。
- 历史 `WatermarkTranslation*` 文件仍存在，但已由专属 wrapper 行数预算和实现禁用检查约束；删除它们不是优先目标。

## 后续维护建议

1. 新增功能继续先更新 `docs/architecture.md` 或对应分文档，再改代码和自动检查。
2. 任何窗口、虚化、翻译、设置保存、番茄运行态或任务 workflow 改动，都必须同步检查对应 `AutomatedChecks.*.ps1`。
3. 后续瘦身只在发现真实高风险耦合、用户可见异常、资源泄漏或检查难以维护时进行；不要为了追求形式上的 Clean Architecture 重写稳定模块。