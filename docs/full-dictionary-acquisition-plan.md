# Full Dictionary Acquisition Plan

Last updated: 2026-06-22

## Goal

Keep the default app lightweight with the small built-in dictionary, while adding a clear, explicit path for a user or developer to bind a high-quality full dictionary.

The full dictionary must not become a startup dependency. Network access must only happen after a user clicks the full-dictionary action in Translation settings.

## User-Facing Flow

Translation settings expose two related actions:

- `Import dictionary` / `Unbind dictionary`
- `Get full dictionary`

The import action is stateful:

- If no valid user dictionary is bound, it opens a TSV picker.
- If a valid user dictionary is bound, it becomes an unbind action.
- Unbinding clears the setting only. It does not delete cached dictionary files.

The full-dictionary action is explicit:

1. Try the configured remote URLs.
2. If remote download fails or is not available yet, check the local cache path.
3. If cache is missing, check the development workspace path.
4. If a valid TSV is found, bind it and clear translation caches.
5. If no valid TSV is found, show a short unavailable message and keep existing settings unchanged.

## Lookup Runtime

Normal translation lookup remains unchanged:

- Load the built-in small dictionary.
- If a user dictionary path is bound and valid, load it as an overlay.
- Do not download during lookup.
- Do not add timers, background workers, or startup probes for the full dictionary.

This keeps resource use stable. The full-dictionary cost is paid only when the user explicitly requests it.

## Paths

Primary local cache:

`task-pomodoro/data/dictionaries/task-pomodoro-full-dictionary.tsv`

Development workspace fallback:

`local-assets/dictionaries/task-pomodoro-full-dictionary.tsv`

Large local dictionary files are ignored by Git. The repository should track scripts, notices, checksums, and documentation, not the large TSV itself.

## Fetch Order

Default setting:

`TranslationDictionaryFetchOrder = remote-first`

After any successful manual import or full-dictionary acquisition:

`TranslationDictionaryFetchOrder = local-first`

Rationale:

- First-run user experience can prefer release assets once GitHub/Gitee URLs are stable.
- Developer and offline testing become simple after a local dictionary has been bound once.
- The user can test “no local dictionary” by unbinding and removing or renaming the local cache.

## Release Strategy

Current phase:

- Keep the full dictionary local.
- Validate quality, format, size, source, and license.
- Keep the app package small.

Later release phase:

- Publish `task-pomodoro-full-dictionary.tsv` as a release asset.
- Optionally publish `task-pomodoro-full-dictionary.tsv.zip` for manual download.
- Use GitHub as the current canonical remote.
- Probe Gitee as a non-fatal mirror candidate when configured; failed probes must fall back to local paths.

## TSV Contract

The full dictionary must be directly importable and use this header:

`word	phonetic	pos	translation	tags	frequency	exchange`

The file should be UTF-8 TSV. Each non-empty data line should contain at least `word`, `phonetic`, `pos`, and `translation`.

## Implementation Boundaries

- `TranslationDictionary.ps1` owns lookup loading.
- `TranslationDictionaryInstall.ps1` owns explicit acquisition, local fallback, validation, bind, and unbind.
- `TranslationSettings.ps1` owns buttons and user feedback only.
- `SettingsSchema.ps1` owns default and normalization for `TranslationDictionaryFetchOrder`.
- Runtime translation paths must not call `Invoke-WebRequest`.
