# Harness phases: enhanced screenshot tooling

## Target

Expand screenshot actions while preserving the existing fast screenshot-to-clipboard behavior.

## Phase 0: compatibility map

Probe:

- `niri`
- `wl-copy`
- `slurp`
- `grim`
- `satty` or `swappy`
- `tesseract`
- optional upload/search tools

Acceptance:

- Existing screenshot-to-clipboard remains available with `niri` and `wl-copy`.
- Current-screen actions use `niri msg action screenshot-screen`.
- Region actions prefer `niri msg action screenshot --path <absolute-path>`.
- `grim` plus `slurp` is a fallback only when a niri-native region path is not
  available.
- OCR and annotation are optional capabilities.

## Phase 1: command builders

Extend `harness/lib/capture-core.mjs`.

Builders:

- current screen copy
- current screen save
- region copy
- region save
- region OCR
- region annotate

Acceptance:

- Save commands create target directories.
- Copy commands either use niri clipboard behavior directly or pipe saved image
  data to `wl-copy`.
- Region commands close the sidebar before selection at the QML wiring layer.
- OCR commands copy text to clipboard.

## Phase 2: action model

Add a harness action model:

- `copy`
- `save`
- `annotate`
- `ocr`
- `search`

Acceptance:

- Action availability is derived from probe results.
- Networked search actions are explicit and never run as a side effect of copy/save.
- Missing optional tools disable only their actions.

## Phase 3: QML service boundary

Extend `modules/services/Capture.qml`.

Acceptance:

- Capture service owns screenshot state, action dispatch, and error text.
- UI widgets do not build screenshot shell commands.
- Fast screenshot path is unchanged.

## Phase 4: UI wiring

Add either:

- a `ScreenshotPanel.qml`, or
- a compact menu from the existing screenshot tile.

Acceptance:

- Harness confirms there is still one top-level screenshot quick toggle.
- Harness confirms advanced actions are grouped inside the panel/menu.
- Harness confirms unavailable optional actions render disabled.

## Phase 5: manual smoke

Manual checks:

- Fast screenshot copies to clipboard.
- Region save writes a file.
- Region cancellation returns to idle.
- OCR copies text when `tesseract` exists.
- Annotation opens the configured editor when available.
