# Changelog

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
