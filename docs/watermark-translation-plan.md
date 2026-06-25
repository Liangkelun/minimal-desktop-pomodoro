# 翻译增强功能计划

最后更新：2026-06-22

## 目标

翻译增强是独立于虚化模式的按需运行能力，用于阅读英文资料时快速理解英文单词、短语或句子。它的入口放在 `~` 右键菜单，但不属于虚化布局流程；实化状态和虚化状态都可以开启翻译。

它只在用户显式开启后运行；普通模式和普通虚化模式不加载词典、不启动监听、不创建在线翻译客户端。

核心边界：

- 默认不碰剪贴板，不自动复制，不模拟 `Ctrl+C`，不做临时复制与恢复。
- 可选剪贴板监听只读取用户手动复制到系统剪贴板的英文文本，仍然不写入剪贴板。
- 默认只查本地词典，不联网。
- 只有用户主动配置并启用 API 后，才发送选中文本到翻译服务。
- 不保存翻译历史；只保留运行期内存缓存、API 字符计数和最近错误状态。
- UIA 读不到选区时轻提示或静默，不弹窗打断。

## 入口与交互

- 左键 `~`：继续做虚化/实化转换。
- 右键 `~` 或虚化退出点：菜单项为 `转换`、`翻译/停止翻译`、`翻译设置`。
- `翻译` 启动时保留当前窗口布局、字号、任务行数和视图，只启动翻译监听、查询和浮层，不进入虚化布局、不折叠窗口、不重算任务行数；翻译运行期不得拥有主窗口布局。
- `翻译设置` 打开局部翻译设置对话框；全局设置页仍保留完整设置。
- 单词附近浮层只显示 1-3 个最高可能中文释义，视觉读取当前窗口风格，默认低透明、无边框、不抢焦点。
- 详细面板默认贴近主窗口下方，显示音标、词性、更多释义、词频/标签、词形变化；句子翻译完整内容也放这里。
- 详细面板位置属于翻译浮层状态，不是主窗口位置；没有稳定设计前不持久化独立拖动点，也不得复用主窗口定位设置。

## 取词路径

取词路径按优先级和风险分层：

1. 默认 UI Automation：读取当前焦点控件的 `TextPattern.GetSelection()`，失败时向父级控件有限上溯查找 `TextPattern`。
2. 可选只读剪贴板监听：仅在翻译增强开启且用户主动启用时，监听真实用户复制造成的剪贴板变化并读取英文文本。
3. OCR 另做独立 spike：图片 PDF、canvas、不可访问 Electron 等场景不混入本轮默认流程。

## 词典

默认包位于 `task-pomodoro/assets/dict/watermark-translation-core.tsv`。当前仓库内置包已从完整 ECDICT `ecdict.csv` 生成：扫描约 77 万行，筛出 37,334 个高频/核心词条，文件约 3.6 MB；它应离线命中 `public`、`private`、`class`、`method`、`example`、`translation`、`document`、`true`、`false`、`return`、`value` 等基础和技术词。

完整 ECDICT CSV 约 63 MB，不作为运行时依赖内置。重新生成默认包时，先把完整 CSV 放入被 `.gitignore` 忽略的 `task-pomodoro/.cache/dict/ecdict.csv`，再运行 `task-pomodoro/scripts/Build-TranslationDictionary.ps1`。ECDICT 使用 MIT license，词典资源目录保留 `NOTICE.md` 说明来源和许可。

查询顺序固定为：内存缓存 -> 用户导入词典 -> 内置核心词典 -> 已启用在线 API。

## API 配置

首批支持：

- 自定义接口：`POST` JSON `{ "text": "...", "source": "auto", "target": "zh" }`，返回 `{ "translation": "..." }`。
- DeepL：支持 Free / Pro endpoint。
- 百度翻译：使用 App ID + Secret。

API key 和 secret 使用 Windows DPAPI CurrentUser 本地加密。用户需要自行保存原始 key；本地加密后的设置不能保证跨设备或重装系统恢复。在线 API 默认关闭，默认月度上限为 100000 字符。

## 模块边界

翻译增强按中立 `Translation*` 边界继续演进，历史 `WatermarkTranslation*` 文件只作为兼容实现落点，不再承载新的产品策略。

| 模块 | 所属层 | 职责 |
| --- | --- | --- |
| `TranslationRuntime.ps1` | runtime | 翻译启动、停止、timer、设置暂停/恢复、listener 接线和资源释放所有者。 |
| `TranslationWorkflow.ps1` | workflow | 文本请求编排、防抖、失败策略和翻译完成/失败通知。 |
| `TranslationBridge.ps1` | runtime/application bridge | UIA/剪贴板文本请求进入 workflow，并把翻译完成/失败通知接到 surface；不拥有 timer 或查询策略。 |
| `TranslationRules.ps1` | domain rules | 文本过滤、选择分类和翻译结果对象模型。 |
| `TranslationLookup.ps1` | application/domain boundary | 内存缓存、本地词典、在线 provider 查询顺序和未命中提示选择。 |
| `TranslationSelection.ps1` | adapter | UIA 选区读取、可选只读剪贴板监听和文本回调接线；不得写剪贴板。 |
| `TranslationDictionary.ps1` | domain/adapter boundary | 本地词典路径、加载、词形候选和离线查词；不得调用在线 API，不负责查询顺序。 |
| `WatermarkTranslation.Dictionary.ps1` | compatibility | 只保留历史词典函数名 wrapper，新词典实现不得继续写回该文件。 |
| `TranslationProviders.ps1` | adapter | 自定义接口、DeepL、百度、字符额度和最近错误更新；secret 解密只调用平台 facade，不直接承载 DPAPI 实现。 |
| `TranslationPlatform.ps1` | adapter | 承载 DPAPI、Win32 native type、无焦点浮层基类和点击穿透等平台 helper；不承载取词、查询或产品策略。 |
| `WatermarkTranslation.Platform.ps1` | compatibility | 只保留历史平台函数名 wrapper，新平台实现不得继续写回该文件。 |
| `TranslationSurface.ps1` | surface UI | 创建、定位、显示/隐藏和释放短释义浮层与详细面板；只读翻译字号和受控视觉风格，不写主窗口字段。 |
| `TranslationSettings.ps1` | dialog UI | 显示和保存翻译设置、测试连接、导入词典，经 runtime facade 暂停/恢复监听；不写主窗口字段。 |
| `WatermarkTranslation.Settings.ps1` | compatibility | 只保留历史设置函数名 wrapper，新设置 UI 实现不得继续写回该文件。 |

## 验收

- 普通模式和普通虚化模式不启动 UIA timer、剪贴板监听或 API 客户端。
- 停止翻译时释放 timer、可选剪贴板监听、浮层、词典和内存缓存；停止翻译不得改变虚化/实化状态。
- 自测覆盖设置默认值、DPAPI roundtrip、本地词典查词、布局保持和翻译生命周期。
- 自动检查禁止翻译模块写剪贴板、模拟复制或复制恢复。
- 手动冒烟确认 Word 常见单词命中、Electron/UIA 失败不弹窗、可选剪贴板监听只读用户复制内容。