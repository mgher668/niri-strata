# Settings module

## Goal

Add a standalone Settings window for niri-strata. It should make common shell
configuration discoverable, apply safe changes live, and manage a small
niri-owned config fragment without taking over the user's full compositor
configuration.

## Product decision

Settings should be an independent window, not a page inside the right control
center. The control center is for frequent actions; Settings is for slower
configuration, validation, and recovery from invalid input.

The first version should support live updates where the blast radius is clear:

- Shell-only settings update immediately through QML bindings.
- Capture, notification, bar, sidebar, workspace, and theme settings update
  without restarting Quickshell.
- niri layout changes are written to a niri-strata-owned fragment, validated as
  much as practical, then applied through an explicit compositor reload/apply
  action.
- Destructive or broad compositor edits require a backup and a visible failure
  state.

## Reference boundary

`temp/DankMaterialShell/` is useful for structure, not for a direct port. Borrow:

- `SettingsData` as the central persisted settings singleton.
- A small settings spec/store layer for defaults, coercion, migration, and JSON
  export.
- A modal/window split with sidebar navigation and lazy-loaded tab content.
- Reusable setting rows for toggles, sliders, segmented choices, and text/path
  fields.
- A compositor fragment workflow that writes only generated files and inserts a
  single include into the user's main compositor config.

Do not borrow the full DMS feature surface in the first pass: plugin browser,
greeter, display layout editor, window rules, app defaults, package management,
and system-wide GTK/Qt/terminal theming should stay out of scope.

## User flows

### Open Settings

1. User triggers an IPC binding, command palette action, or bar/control entry.
2. A standalone Settings window opens on the focused output.
3. The left side shows compact categories; the right side loads the selected
   tab on demand.
4. Escape or the close button hides the window without stopping the shell.

### Change shell setting

1. User changes a toggle, slider, segmented choice, or path field.
2. `SettingsData.set(key, value)` coerces and stores the value.
3. Bound UI and services update immediately.
4. The JSON file is written atomically.
5. Parse or write errors are shown without overwriting the user's file.

### Manage niri layout fragment

1. User opens the niri layout tab.
2. Settings checks whether `~/.config/niri/config.kdl` includes the
   niri-strata fragment.
3. If missing, Settings offers a setup action that backs up `config.kdl`,
   creates the fragment, and inserts one include line.
4. User changes supported layout options.
5. Settings writes only the generated fragment and requests niri to reload.
6. Failure leaves the previous file intact when possible and shows the command
   output/error.

### Switch theme

1. User selects an internal theme or accent.
2. Theme values update live in `Theme.qml`.
3. The selected theme id and custom accent are persisted.
4. Later wallpaper/material-color support can generate the same palette shape
   without changing the Settings UI contract.

## Architecture

Recommended new modules:

- `modules/common/settings/SettingsSpec.js`
- `modules/common/settings/SettingsStore.js`
- `modules/common/SettingsData.qml`
- `modules/settings/SettingsController.qml`
- `modules/settings/SettingsWindow.qml`
- `modules/settings/SettingsSidebar.qml`
- `modules/settings/SettingsContent.qml`
- `modules/settings/widgets/*`

Use `.js` for QML-side helper libraries because they are imported by QML.
Use `.mjs` only for Node harness code, such as `harness/lib/settings-core.mjs`.

Recommended shell wiring:

- Instantiate `SettingsData` early enough for `Config.qml`, `Theme.qml`, and
  services to bind to it.
- Instantiate `SettingsController` in `shell.qml`.
- Lazy-load `SettingsWindow` only after the user opens it.
- Add `IpcHandler target: "settings"` with `toggle`, `open`, `close`, and
  `showTab(tabName)`.
- Add an `Open settings` command palette item after the controller exists.

## Persistence model

Use one user-editable JSON file:

```text
~/.config/quickshell/niri-strata/settings.json
```

The file should contain only settings, not runtime state. Runtime state such as
focused output, currently selected tab, capture progress, and service
availability should remain in services/controllers.

The settings JSON can use flat keys for migration simplicity, but each key
should have an explicit mapping to the current QML API. The first model should
cover these values:

| Setting key | Current or target QML surface | Notes |
|---|---|---|
| `configVersion` | `SettingsData.settingsConfigVersion` | Stored migration version. |
| `themeMode` | `Theme` target behavior | New: dark, light, and future auto mode. |
| `themeId` | `Theme.colors` palette resolver | New: internal palette id. |
| `accentColor` | `Theme.colors` palette resolver | New: custom accent fallback. |
| `barPosition` | `Config.bar.position` | Existing values: `top`, `bottom`. |
| `barStyle` | `Config.bar.style` | Existing config key; should control `floating` vs `flush` if restored. |
| `barShowBackground` | `Config.bar.showBackground` | Existing boolean. |
| `barHeight` | `Config.bar.height` | Existing integer. |
| `barIconButtonSize` | `Config.bar.iconButtonSize` | Existing integer. |
| `barSideMargin` | `Config.bar.sideMargin` | Existing integer. |
| `barGroupSpacing` | `Config.bar.groupSpacing` | Existing integer. |
| `barWingRadius` | `BarCanvas.wingRadius` | Existing hardcoded value in `Bar.qml`; move behind config. |
| `barBottomRadius` | `BarCanvas.bottomRadius` | Existing value currently tied to `Theme.rounding.sm`. |
| `barFlattenOnMaximized` | `BarCanvas.hasMaximizedWindow` policy | New user-facing policy; `hasMaximizedWindow` itself remains runtime state. |
| `sidebarWidth` | `Config.sidebar.width` | Existing integer. |
| `sidebarWheelScrollFactor` | `Config.sidebar.wheelScrollFactor` | Existing real. |
| `workspaceDragReorder` | `Workspaces.qml` drag gate | Drag reorder is already implemented; Settings exposes an enable switch. |
| `workspacePillHeight` | `Workspaces.pillHeight` | Existing readonly constant; convert to config-backed value. |
| `workspaceActiveWidth` | `Workspaces.activeWidth` | Existing readonly constant; convert to config-backed value. |
| `workspacePillSpacing` | `Workspaces.pillSpacing` | Existing readonly constant; convert to config-backed value. |
| `workspaceAnimationDuration` | `Workspaces.workspaceMotionDuration` | Existing readonly constant; convert to config-backed value. |
| `workspaceQuickAnimationDuration` | `Workspaces.workspaceQuickMotionDuration` | Existing readonly constant; convert to config-backed value. |
| `workspaceDragPreviewDuration` | `Workspaces.workspaceDragPreviewDuration` | Existing readonly constant; convert to config-backed value. |
| `notificationMaxHistoryCount` | `Config.notifications.maxHistoryCount` | Existing integer. |
| `notificationMaxHistoryPerApp` | `Config.notifications.maxHistoryPerApp` | Existing integer. |
| `notificationPreviewCount` | `Config.notifications.previewCount` | Existing integer. |
| `notificationExpandedPreviewCount` | `Config.notifications.expandedPreviewCount` | Existing integer. |
| `recordingSaveDir` | `Capture.recordingStartCommand()` | New default directory; do not confuse with runtime `recordingSavePath`. |
| `recordingDefaultMode` | `Capture.recordingMode` when idle | Existing runtime property; setting should only apply when not recording. |
| `recordingAudioEnabled` | `Capture.recordingAudioEnabled` | Existing property. |
| `screenshotDefaultAction` | `Capture` screenshot action model | New: copy or save. |
| `niriLayoutManaged` | niri fragment setup state | New persisted opt-in. |
| `niriLayoutGaps` | generated `strata/layout.kdl` | New generated fragment field. |
| `niriLayoutPreset` | generated `strata/layout.kdl` | New generated fragment preset. |

Implementation rules:

- `SettingsSpec.js` owns defaults, type coercion, min/max ranges, and optional
  migration hooks.
- `SettingsStore.js` parses JSON into the singleton and exports JSON from it.
- `SettingsData.qml` owns file I/O, `set(key, value)`, migration, parse error
  state, read-only state, and external reload handling.
- Do not write the settings file while loading or after a parse error.
- Use atomic writes and a self-write guard so file watching does not create
  reload loops.
- Keep runtime fields out of JSON. Examples: `Capture.recordingSavePath`,
  `Workspaces.dragActive`, `Bar.hasMaximizedWindow`, and service availability.

## Live update strategy

Use direct bindings for shell-only settings:

- `Config.bar.*` can read from `SettingsData` with static defaults as fallback.
- `Config.sidebar.*` can expose live width, padding, and scroll factor.
- `Theme.colors` can resolve an active palette from `SettingsData.themeId` and
  `SettingsData.accentColor`.
- `Theme.animation` can expose live durations for workspace/sidebar/modal
  movement.
- `Notifications.qml` can bind history limits and preview counts to settings.
- `Capture.qml` can bind default save paths and default recording preferences.

For values that affect a running action, update only when idle. Example:
recording mode and audio preferences should not mutate an active recording.

For niri settings, keep the live boundary explicit: write the fragment, run a
reload/apply command, and report the result. Avoid silently rewriting compositor
files from unrelated tabs.

## Initial tabs

### Appearance

- Theme mode: dark, light, system/auto placeholder.
- Theme preset: small internal palettes.
- Accent color: preset swatches and custom hex.
- Motion speed: normal, slower, faster.
- Workspace animation duration/easing.

### Bar

- Position: top or bottom.
- Style: flush or floating. `Config.bar.style` already exists, but `Bar.qml`
  currently behaves as flush; restoring floating should be a deliberate change.
- Height.
- Icon button size.
- Side margin and group spacing.
- Background on/off.
- Canvas shape: wing radius, bottom radius, and whether maximized windows
  flatten the bar shape.
- Tray visible item limit and pinned tokens can be deferred unless the current
  tray behavior becomes hard to configure manually.

### Workspaces

- Drag to reorder. The drag behavior already exists; Settings should expose a
  switch that gates it.
- Pill sizing: height, active width, spacing, and radius. Keep inactive diameter
  tied to height unless a real need appears for separate control.
- Focused capsule animation duration, quick-switch duration, and drag preview
  duration.
- Follow current output behavior if added later.
- Occupied-only display can be deferred until the workspace data model supports
  it cleanly.

### Capture

- Recording save directory.
- Default recording mode: focused output or region.
- Record audio by default.
- Screenshot default action: copy or save.
- `recordingSavePath` should remain runtime state for the last completed
  recording file. The persisted setting should be a directory, such as
  `recordingSaveDir`.
- Tool availability summary for `niri`, `wl-copy`, `wf-recorder`, `slurp`, and
  audio monitor detection.

### Notifications

- History maximum.
- Preview count.
- Expanded preview count.
- Debug seed notifications should remain hidden or clearly marked as a
  development setting.

### Niri

- Setup/check managed fragment include.
- Window gaps.
- Corner radius or border-related values only if niri supports the exact
  generated syntax being written.
- Center/focus behavior only if the generated KDL can be validated against the
  installed niri version.
- A preview of the generated fragment before apply.

### Services

- Backend availability summary.
- Paths/commands used by capture and optional services.
- No package installation or privileged repair actions in the first version.

## Niri fragment management

Use a generated fragment path owned by this project:

```text
~/.config/niri/strata/layout.kdl
```

The setup action should:

- Read `~/.config/niri/config.kdl`.
- Check whether an include for `strata/layout.kdl` already exists.
- Create `~/.config/niri/strata/` if needed.
- Write the generated fragment.
- Back up `config.kdl` before editing it.
- Insert exactly one include line if missing.

The generated file should contain a clear header:

```text
// Generated by niri-strata Settings.
// Edit Settings, not this file. Manual changes may be overwritten.
```

Keep generated KDL narrow. The first pass should manage only layout keys that
the Settings UI owns. If the installed niri version cannot be validated, show
the generated preview and require manual apply instead of guessing.

## Theme switching

Theme switching is reasonable if it starts small.

Recommended first version:

- Internal palette presets, such as default, blue, green, rose, amber, and
  neutral.
- One accent color field.
- Live update of Quickshell colors only.
- Stored fields that leave room for wallpaper-generated palettes later.

Do not implement full DMS-style theming in the first version. DMS-style theming
includes wallpaper pipelines, Matugen, GTK/Qt/icon/cursor changes, terminal
templates, external commands, and drift detection. That is a separate feature
because it writes outside the Quickshell config and needs rollback behavior.

Suggested phases:

1. Internal Quickshell palettes.
2. Wallpaper picker plus optional palette generation.
3. Optional external theme export for GTK/Qt/terminal templates.

## Acceptance criteria

- Settings opens as a standalone window through IPC.
- Settings is reachable from the command palette.
- Shell-only settings apply live and persist after restart.
- Invalid settings JSON does not get overwritten.
- External settings file edits reload without a save loop.
- niri fragment setup creates a backup before touching `config.kdl`.
- niri fragment generation writes only the niri-strata-owned file.
- niri apply/reload failures are visible and recoverable.
- Theme preset changes update visible UI colors without restarting Quickshell.
- Missing optional tools show unavailable states rather than crashing.
- `npm run harness` passes.

## Harness plan

Add a small settings core harness before QML wiring:

- `harness/lib/settings-core.mjs`
- `harness/settings-core.test.mjs`

Test:

- default settings export
- type coercion
- range clamping
- migration from old versions
- parse failure behavior
- generated niri include detection
- generated niri fragment content
- command boundaries for niri reload/apply

Add QML structure assertions to verify:

- `shell.qml` instantiates the settings controller.
- `shell.qml` exposes the `settings` IPC target.
- `SettingsData.qml` uses atomic writes and does not save while loading.
- capture, notifications, theme, and config bind to `SettingsData` instead of
  duplicating hardcoded values in UI widgets.

## Rollout order

1. Add settings spec/store/harness.
2. Add `SettingsData.qml` with read/write/error handling.
3. Bind a small set of existing `Config.qml` and `Theme.qml` values.
4. Add the standalone Settings window and IPC controller.
5. Add Appearance, Bar, Workspaces, Capture, and Notifications tabs.
6. Add niri fragment check/setup/generate/apply.
7. Add command palette integration.
8. Run harness, qmllint, and manual smoke on a disposable niri config backup.
