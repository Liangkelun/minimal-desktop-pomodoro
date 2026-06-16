# Release Checklist

Last updated: 2026-06-14

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
- File-size guardrails
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
- `docs/`
- `task-pomodoro/TaskPomodoro.ps1`
- `task-pomodoro/StartTaskPomodoro.vbs`
- `task-pomodoro/VERSION`
- `task-pomodoro/modules/`
- Runtime audio and icon assets
- Operational scripts for checks, release packaging, and desktop shortcut maintenance

The release package must not include:

- `task-pomodoro/data/`
- `task-pomodoro/config/`
- `task-pomodoro/launch.log`
- `task-pomodoro/update.log`
- `dist/`
- Local temporary files

## Manual Smoke Test

Before a public release, still run a short manual UI pass:

1. Start the app from `TaskPomodoro.ps1`.
2. Add a task.
3. Schedule it to Today.
4. Start, pause, resume, and stop a pomodoro.
5. Enter and exit blur mode.
6. Change window row count.
7. Close and reopen the app to confirm persistence.
