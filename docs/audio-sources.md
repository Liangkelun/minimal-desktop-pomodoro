# Audio Sources

This project only bundles audio that is already project-owned/bundled, generated for this project, or suitable for redistribution under a permissive license.

## Bundled In This Pass

The following files were generated for this project and are distributed with the project under the repository license:

- `task-pomodoro/assets/audio/start-soft.wav`
- `task-pomodoro/assets/audio/start-clear.wav`
- `task-pomodoro/assets/audio/end-soft.wav`
- `task-pomodoro/assets/audio/end-clear.wav`
- `task-pomodoro/assets/audio/white-noise-loop.wav`
- `task-pomodoro/assets/audio/pink-noise-loop.wav`
- `task-pomodoro/assets/audio/brown-noise-loop.wav`

The noise loops are deterministic generated PCM WAV files. The short cues are generated sine-tone prompts with simple envelopes. They do not embed third-party recordings.

## Existing Project Audio

The following audio files existed in the project before this pass and remain in the package:

- `focus-start.wav`
- `break-start.wav`
- `focus-loop.mp3`
- `focus-loop.wav`
- `break-loop.mp3`
- `break-loop.wav`
- `Degrees_of_Clarity.mp3`
- `A_Measured_Turn.mp3`
- `Clearwater_Path.mp3`

The audio catalog uses the primary MP3 entries where both MP3 and WAV variants exist, keeping the dropdown concise. Existing saved settings that point to a bundled WAV path are still preserved and shown as custom selections.

## Reviewed But Not Bundled

- Kenney Interface Sounds: https://kenney.nl/assets/interface-sounds
  - License: Creative Commons Zero (CC0)
  - Package license text says attribution is appreciated but not mandatory.
  - Not bundled in this pass because the downloaded package audio is OGG, and the current Windows playback path is kept to WAV/MP3/WMA/M4A/AAC for reliability.

- Pixabay sound effects: https://pixabay.com/sound-effects/
  - Not bundled in this pass. Pixabay has many suitable ambience references, but its Pixabay Content License is not CC0 and has standalone redistribution constraints.

## Policy

- New bundled audio should be generated for this project, existing project-owned audio, or explicitly CC0/permissive files with source documentation.
- Do not add Pixabay, Freesound CC-BY/NC, or other attribution/redistribution-constrained files to the package without updating this document and reviewing release implications.
