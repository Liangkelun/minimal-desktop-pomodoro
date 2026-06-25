# Translation API and Dictionary Distribution

Last updated: 2026-06-24

## Local API Guide

The product-facing API guide lives at `task-pomodoro/assets/help/translation-api-setup.html` and is opened from Translation settings with the system default browser. It stays as a static local HTML file so the app does not need WebView2 or network access for basic instructions.

The page must cover:
- Custom endpoint request and response shape.
- DeepL Free / Pro setup and official docs link.
- Baidu Translate App ID / Secret setup and official docs link.
- Privacy boundary: default local lookup only, API text is sent only after the user enables a provider.
- Selection compatibility: automatic selection depends on the target application's UIA selected-text support; the clipboard listener is the fallback for apps that do not expose selection.
- Test connection behavior.

## Full Dictionary Package

The default release keeps only the compact core dictionary at `task-pomodoro/assets/dict/watermark-translation-core.tsv`. A full dictionary should be published separately as a release asset so the normal app package stays small.

Recommended direct app asset name:

`task-pomodoro-full-dictionary.tsv`

Optional manually downloadable package name:

`task-pomodoro-full-dictionary.tsv.zip`

The extracted TSV must be directly importable by the app and use this header:

`word	phonetic	pos	translation	tags	frequency	exchange`

GitHub is the current canonical remote: `https://github.com/Liangkelun/minimal-desktop-pomodoro`. The app may probe both GitHub and Gitee as non-fatal remote candidates; failed probes must fall back to local dictionary paths without changing existing settings.

## Source and License

The current dictionary is generated from ECDICT by skywind3000 under the MIT license. Keep `task-pomodoro/assets/dict/NOTICE.md` with any generated dictionary package, including full dictionary packages.
## Full Dictionary Acquisition Flow

The app does not download a large dictionary during startup. The full dictionary flow only runs after the user clicks the Translation settings action.

Default order is `remote-first`:
- Try the GitHub release asset URL.
- Try the Gitee release asset URL.
- Fall back to the local cache path: `task-pomodoro/data/dictionaries/task-pomodoro-full-dictionary.tsv`.
- Fall back to the development workspace path: `local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`.

After any manual import or successful full-dictionary acquisition, settings switch to `local-first`. Future clicks first check the local cache/development path, then try the two remote URLs. This makes offline testing and local dictionary maintenance easier.

The Translation settings import button is stateful: when a valid dictionary is bound it shows an unbind action. Unbinding only clears the setting; it does not delete cached dictionary files.
## Local Full Dictionary Build

Current local artifact:

`local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`

Build command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Build-TranslationDictionary.ps1 -EcDictCsv .\task-pomodoro\.cache\dict\ecdict.csv -OutputPath .\local-assets\dictionaries\task-pomodoro-full-dictionary.tsv -Full
```

Build result on 2026-06-22:

- ECDICT rows scanned: 770611
- Valid TSV entries selected: 400847
- File size: 25775456 bytes
- SHA256: B67A807484A7D66CD86782CBD463F6327A3D849F200A2A40A2DDA85B48E0C921

This local artifact is ignored by Git and is intended for local testing and later release packaging.

## Runtime Dictionary Index

Generated TSV dictionaries should have a matching compact runtime index beside them. The default package includes:

- `task-pomodoro/assets/dict/watermark-translation-core.tsv`
- `task-pomodoro/assets/dict/watermark-translation-core.tsv.idx`

Full dictionary releases should publish the same companion naming pattern:

- `task-pomodoro-full-dictionary.tsv`
- `task-pomodoro-full-dictionary.tsv.idx`

The `.idx` file stores sorted words, TSV byte offsets, and line lengths in a compact binary format. Runtime lookup uses on-demand indexed lookup: it keeps the TSV on disk, loads only the compact index, and seeks to the matching line when translation is requested. The default memory-saver mode keeps automatic selection enabled; it changes the dictionary loading strategy rather than disabling translation. If the index is missing, stale, or invalid, the app falls back to streaming TSV lookup.