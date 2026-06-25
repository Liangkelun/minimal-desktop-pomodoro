# 翻译 API 与词典发布说明

最后更新：2026-06-24

英文版：[translation-api-and-dictionary.md](translation-api-and-dictionary.md)

## 本地 API 教程

面向用户的 API 教程位于 `task-pomodoro/assets/help/translation-api-setup.html`，在翻译设置中通过系统默认浏览器打开。它是静态本地 HTML，因此基础说明不依赖 WebView2，也不要求联网。

该页面应覆盖：

- 自定义接口的请求和响应格式。
- DeepL Free / Pro 配置方式和官方文档链接。
- 百度翻译 App ID / Secret 配置方式和官方文档链接。
- 隐私边界：默认只查本地词典；只有用户启用并配置 API 后，选中文本才会发往对应服务。
- 选区兼容性：自动取词依赖目标软件暴露 UIA 选中文本；对不暴露选区的软件，剪贴板监听是兜底路径。
- 测试连接的行为。

## 完整版词典包

默认发布包只保留精简核心词典：

`task-pomodoro/assets/dict/watermark-translation-core.tsv`

完整版词典应作为独立 release asset 发布，避免普通程序包变大。

推荐给程序直接获取的资产名：

`task-pomodoro-full-dictionary.tsv`

可选的手动下载包名：

`task-pomodoro-full-dictionary.tsv.zip`

解压后的 TSV 必须能被程序直接导入，并使用以下表头：

`word	phonetic	pos	translation	tags	frequency	exchange`

GitHub 是当前主远程仓库：`https://github.com/Liangkelun/minimal-desktop-pomodoro`。程序可以把 GitHub 和 Gitee 都作为非致命远程候选进行探测；探测失败时必须回退到本地词典路径，并且不能破坏已有设置。

## 来源与许可

当前词典由 skywind3000 的 ECDICT 生成，许可证为 MIT。任何生成后的词典包，包括完整版词典包，都应保留 `task-pomodoro/assets/dict/NOTICE.md` 或等效来源说明。

## 完整版词典获取流程

程序启动时不下载大词典。完整版词典流程只在用户点击翻译设置里的获取动作后运行。

默认顺序是 `remote-first`：

- 尝试 GitHub release asset URL。
- 尝试 Gitee release asset URL。
- 回退到本地缓存路径：`task-pomodoro/data/dictionaries/task-pomodoro-full-dictionary.tsv`。
- 回退到开发工作区路径：`local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`。

手动导入或获取完整版成功后，设置切换为 `local-first`。之后再次点击获取时，先检查本地缓存和开发路径，再尝试两个远程 URL。这样更方便离线测试和本地大词典维护。

翻译设置中的导入按钮是状态化按钮：绑定了有效词典时显示“解绑词典”。解绑只清空设置，不删除缓存文件。
## 本地完整版词典构建记录

当前本地文件：

`local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`

构建命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Build-TranslationDictionary.ps1 -EcDictCsv .\task-pomodoro\.cache\dict\ecdict.csv -OutputPath .\local-assets\dictionaries\task-pomodoro-full-dictionary.tsv -Full
```

2026-06-22 构建结果：

- 扫描 ECDICT 行数：770611
- 选出有效 TSV 词条：400847
- 文件大小：25775456 字节
- SHA256：B67A807484A7D66CD86782CBD463F6327A3D849F200A2A40A2DDA85B48E0C921

该本地文件被 Git 忽略，用于本地测试和后续 release asset 制作。
