# Enhanced screenshot tooling

## Goal

Expand screenshots from a single clipboard action into a small capture toolkit: copy, save, annotate, OCR, and image search. The feature should reuse the same capture service principles as recording.

## Product decision

Keep quick access simple:

- `Screenshot` quick toggle keeps its current fast behavior.
- A secondary panel or menu exposes advanced actions.

Initial advanced actions:

- Region copy
- Region save
- Current screen copy
- Current screen save

Future advanced actions:

- Annotate
- OCR to clipboard
- Image search

## User flows

### Fast screenshot

1. User clicks `Screenshot`.
2. Current behavior copies screenshot to clipboard.
3. Notification confirms success or failure.

### Region save

1. User opens screenshot actions.
2. User chooses `Region save`.
3. Sidebar closes.
4. Region selection starts.
5. File is saved to the configured screenshot directory.
6. Notification shows saved path.

### OCR

1. User chooses `OCR`.
2. Region selection starts.
3. Screenshot is cropped.
4. OCR backend extracts text.
5. Text is copied to clipboard.
6. Notification shows result status.

## State model

Recommended additions to `Capture.qml`:

- `screenshotMode`
- `screenshotAction`
- `screenshotSavePath`
- `screenshotBusy`
- `screenshotLastError`

Recommended action enum:

- `copy`
- `save`
- `annotate`
- `ocr`
- `search`

## Backend requirements

Required:

- `niri`
- `wl-copy`

Optional:

- `slurp` for fallback region selection
- `grim` for generic Wayland screenshots when niri screenshot actions are insufficient
- `satty` or `swappy` for annotation
- `tesseract` for OCR
- `curl` or browser open command for image search/upload workflows

Avoid introducing network upload behavior for image search without a clear confirmation step.

Backend policy:

- Region copy/save uses `niri msg action screenshot --path <absolute-path>` by
  default. This opens niri's screenshot UI and avoids adding a separate region
  selector dependency for the primary path.
- Current screen copy/save uses
  `niri msg action screenshot-screen --path <absolute-path>`.
- For copy actions, save to a temporary absolute path and copy PNG data through
  `wl-copy --type image/png`; remove the temporary file after copy succeeds.
- `grim + slurp` is only a fallback if a future niri version or environment
  cannot provide the required screenshot action.
- Until Settings exists, default saved screenshots to
  `~/Pictures/Screenshots` and keep that path in `Config.qml` or the capture
  helper, not inline inside UI widgets.

## UI placement

Keep one quick `Screenshot` tile. Add advanced actions through either:

- a small screenshot panel inside the sidebar, or
- a compact menu opened from the tile.

Possible components:

- `modules/sidebar/ScreenshotPanel.qml`
- `modules/services/Capture.qml`
- `harness/lib/capture-core.mjs`

## Acceptance criteria

- Existing screenshot-to-clipboard behavior remains intact.
- Advanced actions do not add several top-level quick toggle buttons.
- Region actions close the sidebar before selection.
- OCR and annotation are disabled when their tools are missing.
- Image search is treated as an explicit action with clear network implications.
- `npm run harness` passes.

## Harness plan

Detailed harness phases live in [../harness/04-screenshot-tooling.md](../harness/04-screenshot-tooling.md).
