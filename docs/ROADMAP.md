# niri-strata roadmap

## Positioning

`niri-strata` is a niri-native Quickshell configuration. Its job is not to clone a Hyprland desktop shell, but to provide a focused Material You bar, control center, and command surface that speak niri's data model directly.

The roadmap borrows useful ideas from `dots-hyprland` only when they can be made compositor-neutral or niri-native. Hyprland-only services, dispatch semantics, and layer rules are out of scope unless they are replaced with niri, Wayland, or common desktop backends.

## Route

The project should grow in three bands:

1. **Capture and daily utilities**: recording, screenshots, clipboard history, launcher, color picker, idle inhibitor.
2. **Desktop personalization**: wallpaper selection, Material color generation, settings.
3. **Navigation and richer surfaces**: media overlay, workspace/window overview, command palette extensions.

Each feature should be implemented harness-first:

- Add command builders, parsers, and state reducers to `harness/lib/` before QML wiring.
- Add text-structure tests for QML service boundaries and critical UI wiring.
- Keep command construction outside UI widgets.
- Model unavailable and degraded states explicitly.
- Run `npm run harness` before commits.

## Roadmap

| # | Feature | Status | Detail |
|---|---|---|---|
| 1 | Recording enhancements | Smoke pending | [01-recording-enhancements.md](features/01-recording-enhancements.md) |
| 2 | App launcher / command palette | Smoke pending | [03-app-launcher-command-palette.md](features/03-app-launcher-command-palette.md) |
| 3 | Clipboard history panel | Planned | [02-clipboard-history.md](features/02-clipboard-history.md) |
| 4 | Enhanced screenshot tooling | Planned | [04-screenshot-tooling.md](features/04-screenshot-tooling.md) |
| 5 | Notification center redesign | Planned | [05-notification-center-redesign.md](features/05-notification-center-redesign.md) |
| 6 | Notification action buttons | Planned | [06-notification-action-buttons.md](features/06-notification-action-buttons.md) |
| 7 | Wallpaper + Material color pipeline | Backlog | [08-theme-system.md](features/08-theme-system.md) |
| 8 | Color picker | Backlog | Future detail doc |
| 9 | Idle inhibitor | Backlog | Future detail doc |
| 10 | More complete media overlay | Backlog | Future detail doc |
| 11 | Workspace / window overview | Backlog | Future detail doc |
| 12 | Settings UI | Done | [07-settings-module.md](features/07-settings-module.md) |
| 13 | Theme system (auto + matugen + export) | Planned | [08-theme-system.md](features/08-theme-system.md) |

## Recommended order

1. Finish recording enhancements manual smoke because the implementation is already in place.
2. Build the launcher / command palette because search, ranking, keyboard navigation, and compact overlay behavior become shared foundations for later utilities.
3. Add clipboard history after the launcher foundation, so clipboard search can reuse the command palette model.
4. Expand screenshot tooling after the launcher foundation, so OCR/search/save actions can share command palette affordances where useful.
5. Build the theme system (auto light/dark + matugen dynamic palette + GTK/Qt export). See [08-theme-system.md](features/08-theme-system.md).
6. Add wallpaper and Material color once settings/persistence requirements are clearer.

### Color picker

### Idle inhibitor

Add a toggle that prevents idle sleep/lock during presentations, calls, or long-running work. Prefer `systemd-inhibit` or a Wayland idle-inhibit path over compositor-specific commands.

### More complete media overlay

Keep the existing sidebar media panel, then add a compact media overlay with album art, player switching, playback controls, and progress. It should reuse `modules/services/Media.qml`.

### Workspace / window overview

Build a niri-native overview from `niri msg --json windows` and `workspaces`. Start with list/grid navigation and window focus actions. Avoid promising live thumbnails until niri/Quickshell support is proven.

### Settings UI

Add a standalone settings window for user-facing configuration: recording save path, screenshot behavior, theme mode, sidebar width, bar layout, niri layout fragment management, and feature availability. Settings should not be required for basic operation. See [07-settings-module.md](features/07-settings-module.md).

## Documentation index

- [Harness planning](harness/README.md)
- [Recording harness phases](harness/01-recording-enhancements.md)
- [Clipboard harness phases](harness/02-clipboard-history.md)
- [Launcher harness phases](harness/03-app-launcher-command-palette.md)
- [Screenshot harness phases](harness/04-screenshot-tooling.md)
- [Theme system planning](features/08-theme-system.md)
