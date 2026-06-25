# Watermark Translation Dictionary Notice

`watermark-translation-core.tsv` is generated from ECDICT by skywind3000.

- Source: https://github.com/skywind3000/ECDICT
- License: MIT
- Generation script: `task-pomodoro/scripts/Build-TranslationDictionary.ps1`
- Runtime index: `watermark-translation-core.tsv.idx` uses compact binary offset lookup and is generated from the TSV.
- Current package: high-frequency/core subset generated from ECDICT CSV, not the full 760k-entry CSV.

The full ECDICT CSV is used only as a local build source and is not required at runtime.

Full dictionary packages should be released separately from the default app package, for example as `task-pomodoro-full-dictionary.tsv.zip`. The extracted TSV must keep the same header as `watermark-translation-core.tsv` so users can import it directly from Translation settings. Publish a matching `.tsv.idx` beside the full TSV when possible; the app falls back to streaming lookup if the index is missing or stale.
Full local build command:

`powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Build-TranslationDictionary.ps1 -EcDictCsv .\task-pomodoro\.cache\dict\ecdict.csv -OutputPath .\local-assets\dictionaries\task-pomodoro-full-dictionary.tsv -Full`
