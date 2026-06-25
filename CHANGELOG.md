# Changelog

## 0.5.0 - 2026-06-24

### Added

- Added blur-mode translation with local dictionary lookup, optional API providers, and a read-only clipboard listener fallback.
- Added compact indexed dictionary lookup with bundled `watermark-translation-core.tsv.idx` so dictionary entries are read on demand instead of loaded into memory as a full PowerShell table.
- Added active Pomodoro runtime recovery through `timer-state.json`, including task binding, remaining time, session rounds, and pause-threshold state.
- Added desktop/VBS launch logging under `task-pomodoro/data/logs` to make launch failures diagnosable.
- Added bundled focus/break audio choices and source documentation.

### Changed

- Default translation mode is memory saver while keeping automatic selection enabled.
- Split timer runtime, workflows, settings, translation, audio, self-test, and view helpers into narrower modules with automated boundary checks.
- Release packaging now includes the core dictionary TSV plus its compact index and excludes runtime state, config, logs, and temporary files.
- Full dictionary acquisition is treated as an optional asset flow rather than a startup download.
- Task-link diagnostics now require explicit `TASK_POMODORO_LINK_DEBUG=1` opt-in instead of writing link/path debug logs by default.

### Fixed

- Fixed the large-dictionary memory regression by avoiding full dictionary object loading for indexed lookup.
- Fixed active Pomodoro progress loss after restart by restoring persisted runtime state.
- Fixed pause/resume accounting so work/break pauses can count threshold interruptions without duplicate counts, while starter pauses do not count.
- Fixed execution recovery stats for legacy pause-threshold windows that were missing explicit pause/resume events.
- Improved double-click/shortcut launch reliability through the packaged VBS launcher and per-launch logs.
- Clarified target-app-dependent UIA automatic selection and the clipboard listener fallback path for translation.

### Known Limitations

- Automatic translation selection depends on the target application's UI Automation selected-text support; use the clipboard listener fallback when selection is unavailable.
- Current Windows PowerShell/WinForms runtime footprint is lower than the 700MB dictionary regression but is not a hard under-100MB target in this release.
- The full dictionary should be published separately with its companion `.idx` file.

## 0.4.0 - 2026-06-14

### Changed

- Split window behavior into focused modules for timer ticks, bottom chrome, window sizing, dragging, help surface, and watermark mode.
- Added `AppState.ps1` and moved path access behind `$App.Paths` plus `Get-AppPath`.
- Split task domain logic into model, store, queries, ordering, and commands.
- Split pomodoro logic into records, audio, effects, and core state flow.
- Split task list owner-drawing out of task control helpers.
- Strengthened architecture checks to guard path access and business/UI boundaries.

### Fixed

- Preserved the one-row task view clipping fix through explicit self-test coverage.

## 0.3.0 - 2026-06-14

### Added

- Added project-level automated checks.
- Added module load-order validation.
- Added architecture boundary checks for business modules.
- Added file-size guardrails.
- Added invalid `tasks.json` recovery check in an isolated copy.
- Added release-oriented documentation.
- Added version file.
- Added reproducible release package script.
- Added release checklist.

### Changed

- Split the original large script into focused modules.
- Split view code into smaller view modules.
- Moved self-test code into `SelfTest.ps1`.
- Task operations now return result objects interpreted by the UI layer.
- Pomodoro main-path operations now return result objects instead of directly driving UI.
- UI timer uses a lower-frequency normal mode and a faster watermark mode.
- Automated checks now validate release metadata and release-script size guardrails.

### Known Limitations

- UI behavior still needs manual smoke testing before public release.
- Runtime data recovery is covered for invalid task JSON, but full backup restore UX is not implemented.

## 0.2.0 - 2026-06-14

### Added

- Local task list, Today view, completed task view.
- Pomodoro timer with task binding.
- Local JSON and JSONL persistence.
- Watermark mode.
- Audio and icon assets.
- Basic non-GUI self-test.

## 0.1.0 - 2026-06-13

### Added

- Initial architecture plan.
- Initial PowerShell WinForms prototype.
