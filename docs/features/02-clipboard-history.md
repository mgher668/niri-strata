# Clipboard history panel

## Goal

Add a sidebar panel for clipboard history using compositor-neutral Wayland tools. The feature should make recently copied text and images browsable, searchable, and restorable to the clipboard.

## Product decision

Use `cliphist` as the first backend because it is already proven in Wayland desktop setups and does not depend on Hyprland. The shell should own the UI, while `wl-paste --watch cliphist store` owns collection.

Watcher lifecycle:

- `modules/services/Clipboard.qml` starts `wl-paste --watch cliphist store`
  when `cliphist` and `wl-paste` are available.
- The service tracks collection separately from restore: `cliphist` controls
  history availability, `wl-paste` controls collection, and `wl-copy` controls
  restore.
- If the watcher exits unexpectedly, the service restarts it with a short
  backoff and records `watchLastError`.
- If `wl-paste` is unavailable, the panel can still list existing `cliphist`
  history, but it must show that new collection is unavailable.
- Do not require a systemd user service or external autostart entry in the first
  version.

## User flows

### Restore text

1. User opens sidebar.
2. User opens Clipboard panel.
3. User searches or scrolls recent items.
4. User clicks an item.
5. The item is decoded through `cliphist decode`.
6. The decoded content is copied through `wl-copy`.

### Restore image

1. User opens Clipboard panel.
2. Image entries show a compact preview or image marker.
3. User clicks an image item.
4. The image is decoded and copied back to the clipboard.

### Clear history

1. User clicks clear action.
2. The panel asks for confirmation.
3. History is cleared.
4. Empty state appears.

## State model

Recommended service:

- `modules/services/Clipboard.qml`

Recommended state:

- `available`
- `watchAvailable`
- `watching`
- `watchLastError`
- `items`
- `query`
- `busy`
- `lastError`

Recommended item fields:

- `id`
- `rawLine`
- `previewText`
- `type`
- `timestamp` when available
- `isImage`
- `isPinned` for future use

## Backend requirements

Required:

- `cliphist`

Required for restore:

- `wl-copy`

Required for shell-managed collection:

- `wl-paste`

Optional:

- thumbnail generation for image previews

Collection is started by the Clipboard service, not by a top-level UI component. The feature should detect separate unavailable states for history storage, collection, and restore instead of assuming the watcher is running.

## UI placement

Add a Clipboard section to the sidebar, likely near notifications or as a tabbed utility panel.

Possible components:

- `modules/sidebar/ClipboardPanel.qml`
- `modules/services/Clipboard.qml`
- `harness/lib/clipboard-core.mjs`

## Acceptance criteria

- Clipboard panel shows decoded, human-friendly history rows.
- Text restore copies the selected item to clipboard.
- Image restore supports at least a non-preview placeholder in the first version.
- Clear history requires confirmation.
- Missing `cliphist` or `wl-clipboard` shows an unavailable state.
- No clipboard content is stored in harness fixtures if it may contain secrets.
- `npm run harness` passes.

## Harness plan

Detailed harness phases live in [../harness/02-clipboard-history.md](../harness/02-clipboard-history.md).
