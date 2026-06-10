# Recording enhancements

## Goal

Make recording powerful without multiplying buttons. The control center should expose one obvious `Record` entry while supporting region recording, current-screen recording, audio capture, notifications, saved-path feedback, and future save-path configuration.

## Product decision

Use **one recording entry** instead of separate buttons for each recording variant.

Recommended behavior:

- Left-clicking the `Record` quick toggle starts recording with the current
  settings.
- Left-clicking the same entry while recording is active stops recording.
- Right-clicking the `Record` quick toggle opens a compact recording settings
  panel.
- The panel contains mode selection: `Region` and `Current screen`.
- The panel contains an `Audio` toggle.
- The panel does not contain `Start` or `Stop`; starting and stopping stay on
  the quick toggle.
- Default mode is `Current screen`; switching to `Region` is remembered for the
  current Quickshell session.
- When recording is active, the quick toggle keeps the `Record` label and shows
  active state.
- Notifications are on for stop, cancel, failure, and degraded events. Normal
  start does not notify.
- Save path is configured in Settings later, not in the main recording panel.

This avoids duplicate buttons while keeping the workflow explicit enough to prevent accidental recording.

## User flows

### Region recording

1. User opens the sidebar.
2. User right-clicks `Record`.
3. A compact recording settings panel opens.
4. User selects `Region`.
5. User optionally enables `Audio`.
6. User left-clicks `Record`.
7. Sidebar closes, then region selection starts.
8. Recording starts after the selected geometry is available.
9. User left-clicks the active `Record` entry to end recording.
10. A notification shows the saved file path.

### Current screen recording

1. User left-clicks `Record`.
2. The focused niri output is resolved.
3. `wf-recorder` records that output.
4. User left-clicks the active `Record` entry to end recording.

Optional configuration:

1. User right-clicks `Record`.
2. User selects `Current screen`.
3. User optionally enables `Audio`.
4. User closes the panel or left-clicks `Record` directly.

## State model

Recording state should be normalized in `modules/services/Capture.qml` and mirrored in harness helpers.

Recommended states:

- `idle`
- `selectingRegion`
- `recordingRegion`
- `recordingOutput`
- `stopping`
- `unavailable`
- `error`

Recommended derived properties:

- `recordingAvailable`
- `recordingAudioAvailable`
- `recordingActive`
- `recordingMode`
- `recordingAudioEnabled`
- `recordingDegradedReason`
- `recordingStatus`
- `recordingSavePath`
- `recordingLastError`

## Command backends

Required:

- `wf-recorder`
- `niri`
- `slurp` for region mode

Optional:

- `pactl` for audio monitor source discovery
- `wpctl` for diagnostics when audio source discovery fails
- `notify-send` for feedback

Command construction should live in a harness-friendly helper shape. QML can still execute commands through `Process`, but it should not build complex shell strings inline when the logic becomes branchy.

Audio policy:

- Silent recording is always allowed when `wf-recorder` and the relevant video
  target tools are available.
- Audio recording uses the default sink monitor source from `pactl`: get the
  default sink with `pactl get-default-sink`, then look for
  `<default-sink>.monitor` in `pactl list sources short`.
- When audio is enabled but the monitor source cannot be found, start silent
  recording, show degraded status in the recording state, and notify the user if
  `notify-send` exists.
- Do not use microphone input as the default audio source for screen recording.
  A future settings surface can add explicit microphone/system/mixed choices.

## Notifications

Notifications are not a user-facing setting in the first version. They are part of safety and completion feedback:

- Recording stopped
- Saved path
- Region selection cancelled
- Audio source unavailable
- Backend unavailable

## UI placement

Keep one `Record` entry in `QuickToggleGrid.qml`. Remove the separate `Record area` entry after the unified panel is implemented.

Primary and secondary actions are split intentionally:

- Left-click `Record`: start with current settings.
- Left-click active `Record`: stop the active recording.
- Right-click `Record`: open recording settings.

Possible components:

- `modules/sidebar/RecordingPanel.qml`
- `modules/services/Capture.qml`
- `harness/lib/capture-core.mjs`

## Acceptance criteria

- There is one visible recording entry in quick toggles.
- The entry can start region recording and current-screen recording.
- Right-click opens the recording settings panel.
- The settings panel has mode and audio controls, but no start or stop action.
- Audio can be toggled before starting.
- Stop behavior works for both modes.
- Notifications are emitted for stop, cancel, failure, and degraded recording
  when `notify-send` exists.
- Missing optional audio backend does not block silent recording.
- Missing required tools show disabled or degraded UI states.
- `npm run harness` passes.

## Harness plan

Detailed harness phases live in [../harness/01-recording-enhancements.md](../harness/01-recording-enhancements.md).
