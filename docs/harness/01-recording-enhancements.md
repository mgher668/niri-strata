# Harness phases: recording enhancements

## Target

Unify recording into one UI entry while supporting region/current-screen modes, optional audio, completion/degraded notifications, and saved-path feedback. Save-path configuration belongs to the later Settings work.

## Phase 0: compatibility map

Document and test tool probing for:

- `wf-recorder`
- `slurp`
- `niri`
- `notify-send`
- audio source backend: `pactl`; use `wpctl status` only for human-readable diagnostics

Acceptance:

- Harness parses a probe result into required and optional capability flags.
- Missing audio backend does not mark silent recording unavailable.
- Missing `wf-recorder` disables all recording.
- Missing `slurp` disables region mode only.
- Audio capture is available only when `pactl get-default-sink` succeeds and
  `pactl list sources short` contains `<default-sink>.monitor`.

## Phase 1: command builders

Add or extend `harness/lib/capture-core.mjs` with builders for:

- current-screen silent recording
- current-screen audio recording
- region silent recording
- region audio recording
- stop recording
- notification commands or notification availability decisions

Acceptance:

- Commands include timestamped output paths.
- Current-screen mode resolves focused output through niri.
- Region mode starts through a detached command so interactive `slurp`
  selection behaves like the previous standalone region button.
- Audio commands append `--audio=<monitor-source>` only when audio is enabled
  and the monitor source was discovered.
- If audio is enabled but no monitor source is available, start silent
  recording, set a degraded status, and emit an audio-unavailable notification
  when `notify-send` exists.
- Normal recording start does not emit a notification.
- Stop command remains idempotent.

## Phase 2: state reducer

Add harness coverage for recording state transitions:

- idle to selecting region
- selecting region to recording region
- idle to recording output
- recording to stopping
- stopping to idle
- error and cancellation paths

Acceptance:

- UI labels can be derived from state without special cases in widgets.
- Region selection cancellation returns to idle.
- Failed audio source discovery falls back to silent recording and records the
  degraded reason in state.

## Phase 3: QML service boundary

Extend `modules/services/Capture.qml` while keeping complex branching centralized.

Acceptance:

- `QuickToggleGrid.qml` does not build recording commands.
- Capture service exposes mode, audio, active, status, and error properties.
- A recording panel can call explicit settings actions such as
  `setRecordingMode` and `setRecordingAudioEnabled`.
- Explicit recording actions such as `startRecording` and `stopRecording`
  remain on the service boundary for the quick toggle to call.

## Phase 4: UI wiring

Replace multiple recording quick toggles with one `Record` entry and one compact panel.

Acceptance:

- Harness confirms only one recording quick toggle ID exists.
- Harness confirms the panel exposes `Region`, `Current screen`, and `Audio`
  controls without `Start`/`Stop`.
- Harness confirms left-click starts or stops recording.
- Harness confirms right-click opens the settings panel.
- Starting from the quick toggle closes the sidebar before region selection.
- Active recording state is visible from the quick toggle.

## Phase 5: manual smoke

Status: Not completed. Deferred until after the next feature pass.

Manual checks:

- Start and stop current-screen recording.
- Start and stop region recording.
- Try region cancellation.
- Try audio enabled and disabled; if the monitor source is unavailable, confirm
  that recording still starts silently with degraded feedback.
- Confirm normal start does not notify, and stop/cancel/failure/degraded
  notifications show useful text.
- Confirm saved files appear under `~/Videos/Screen Recordings`.
