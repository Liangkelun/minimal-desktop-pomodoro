# 完整版词典获取计划

最后更新：2026-06-22

英文版：[full-dictionary-acquisition-plan.md](full-dictionary-acquisition-plan.md)

## 目标

默认程序继续只内置小词典，保持体积小、启动快、离线可用；同时提供一个明确、可测试的路径，让用户或开发者绑定高质量完整版词典。

完整版词典不能成为启动依赖。只有用户在翻译设置里主动点击“获取完整版”时，程序才允许尝试联网。

## 用户可见流程

翻译设置中保留两个相关操作：

- `导入词典` / `解绑词典`
- `获取完整版`

导入按钮是状态化按钮：

- 没有绑定有效用户词典时，按钮显示“导入词典”，点击后选择 TSV 文件。
- 已绑定有效用户词典时，按钮显示“解绑词典”。
- 解绑只清空设置，不删除已经缓存的词典文件，方便反复测试。

“获取完整版”是显式操作：

1. 尝试配置好的远程 URL。
2. 如果远程下载失败或远程资产暂不可用，检查本地缓存路径。
3. 如果缓存不存在，检查开发工作区路径。
4. 找到有效 TSV 后，绑定该词典并清空翻译缓存。
5. 如果没有找到有效 TSV，只提示“暂时无法加载词典”，不破坏原设置。

## 查词运行时

普通翻译查词逻辑保持不变：

- 先加载内置小词典。
- 如果设置里绑定了有效用户词典，再把用户词典作为覆盖层加载。
- 查词过程中不下载词典。
- 不为完整版词典增加启动探测、后台任务、额外 timer。

这样可以保持运行时资源消耗稳定；完整版词典的成本只在用户主动获取时发生。

## 路径

主要本地缓存路径：

`task-pomodoro/data/dictionaries/task-pomodoro-full-dictionary.tsv`

开发工作区回退路径：

`local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`

大词典文件不进入 Git。仓库只跟踪构建脚本、来源说明、校验信息和文档，不跟踪大 TSV 本体。

## 获取顺序

默认设置：

`TranslationDictionaryFetchOrder = remote-first`

手动导入或获取完整版成功后：

`TranslationDictionaryFetchOrder = local-first`

原因：

- 首次用户体验可以在 GitHub/Gitee 资产稳定后优先走发布资产。
- 一旦本地绑定成功，后续开发和离线测试会更直接。
- 需要测试“没有本地大词典”时，可以解绑并移走或改名本地缓存文件。

## 发布策略

当前阶段：

- 完整版词典先在本地维护。
- 先确认质量、格式、体积、来源和许可证。
- 默认程序包继续保持精简。

后续发布阶段：

- 将 `task-pomodoro-full-dictionary.tsv` 作为 release asset 发布。
- 可以额外发布 `task-pomodoro-full-dictionary.tsv.zip`，方便手动下载。
- GitHub 作为当前主发布源。
- Gitee 作为非致命镜像候选；探测失败必须回退本地路径。

## TSV 格式契约

完整版词典必须能被程序直接导入，并使用以下表头：

`word	phonetic	pos	translation	tags	frequency	exchange`

文件应为 UTF-8 TSV。每条非空数据至少应包含 `word`、`phonetic`、`pos`、`translation` 四列。

## 实现边界

- `TranslationDictionary.ps1` 负责查词加载。
- `TranslationDictionaryInstall.ps1` 负责显式获取、本地回退、校验、绑定和解绑。
- `TranslationSettings.ps1` 只负责按钮和用户反馈。
- `SettingsSchema.ps1` 负责 `TranslationDictionaryFetchOrder` 的默认值和归一化。
- 翻译运行时路径不得调用 `Invoke-WebRequest`。