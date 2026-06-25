# Release Checklist

Last updated: 2026-06-25

## Purpose

This project ships as a local Windows PowerShell desktop app. A release must be reproducible, exclude personal runtime state, and pass the same automated checks as the working tree.

## Pre-release Checks

Run the full automated gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\Invoke-AutomatedChecks.ps1
```

Confirm these checks pass:

- PowerShell syntax for the main script, modules, and support scripts
- Release metadata and semantic version file
- Module load order
- Architecture boundary rules
- File-size hard guardrails pass and soft warnings are reviewed
- Required launch, audio, and icon assets
- Runtime data schema
- Invalid data recovery in an isolated copy
- Main script self-test in an isolated copy

## Build Package

Generate the release archive:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\task-pomodoro\scripts\New-ReleasePackage.ps1
```

The package script validates the staged package before compression and checks the resulting zip contents.

## Package Contents

The release package should include:

- `README.md`
- `CHANGELOG.md`
- `LICENSE`
- `Start Minimal Desktop Pomodoro.vbs`
- `docs/`
- `task-pomodoro/TaskPomodoro.ps1`
- `task-pomodoro/StartTaskPomodoro.vbs`
- `task-pomodoro/VERSION`
- `task-pomodoro/modules/`
- Runtime audio and icon assets
- Core translation dictionary assets: `watermark-translation-core.tsv` and `watermark-translation-core.tsv.idx`
- Operational scripts for checks, release packaging, and desktop shortcut maintenance

The release package must not include:

- `task-pomodoro/data/`
- `task-pomodoro/config/`
- `task-pomodoro/reports/`
- `task-pomodoro/launch.log`
- `task-pomodoro/update.log`
- `dist/`
- Full dictionary runtime assets such as `task-pomodoro-full-dictionary.tsv` or its `.idx`
- Local temporary files

## Manual Smoke Test

Before a public release, still run a short manual UI pass:

1. Start the app from the top-level `Start Minimal Desktop Pomodoro.vbs` in an extracted package.
2. Confirm a launch log appears under `task-pomodoro/data/logs/`.
3. Add a task.
4. Schedule it to Today.
5. Start, pause, resume, and stop a pomodoro.
6. Enter and exit blur mode.
7. Change window row count.
8. Close and reopen the app to confirm persistence.
9. Start translation from the `~` context menu and confirm a UIA-readable target selection can show a local dictionary result without changing the main window layout.
10. Confirm the selection compatibility fallback: when a target app does not expose UIA selected text, enable the clipboard listener, manually copy an English word, and verify translation appears without the app writing to the clipboard or simulating `Ctrl+C`.
11. Confirm task-link opening does not create `open-link-debug.log` unless `TASK_POMODORO_LINK_DEBUG=1` is explicitly set for diagnostics.

## Version Control Gate

Before committing a release candidate:

- Confirm real Git staged count is 0 before intentional staging.
- Confirm the numbered 01-07 pathspec groups cover the current visible changes with 0 missing, extra, or duplicate paths.
- Run temporary-index checks for each group and combined 01-07 so `git diff --cached --check` is clean without touching the real index.
- Run `git add --dry-run --pathspec-from-file=...` for the recommended pathspec commands and confirm the combined count matches the expected visible change count.
- Do not commit `dist/`, `task-pomodoro/reports/`, runtime `data/`, runtime `config/`, or full dictionary runtime files unless the project explicitly changes that release policy.

## Dual Remote Publication Gate

The project publishes source history to GitHub and Gitee from the same local commit and tag. Do not create separate release commits per platform.

Expected remotes:

- `origin`: `https://github.com/Liangkelun/minimal-desktop-pomodoro.git`
- `gitee`: `https://gitee.com/liang-kelun/minimalist-desktop-tomato.git`

One-time setup after explicit user authorization:

```powershell
git remote add gitee https://gitee.com/liang-kelun/minimalist-desktop-tomato.git
```

For each release:

1. Build one local package and record its SHA256.
2. Create one release commit from the verified working tree.
3. Create one annotated release tag, for example `v0.5.0`.
4. Push the same branch and tags to both remotes:

```powershell
git push origin main --tags
git push gitee main --tags
```

A release is not complete until both remotes contain the same release commit and tag. If either remote rejects authentication or diverges, stop the publication and resolve the mismatch before announcing the release.
