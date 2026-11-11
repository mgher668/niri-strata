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
| 1 | Recording enhancements | Silent recording smoke passed | [01-recording-enhancements.md](features/01-recording-enhancements.md) |
| 2 | App launcher / command palette | Keyboard smoke passed | [03-app-launcher-command-palette.md](features/03-app-launcher-command-palette.md) |
| 3 | Clipboard history panel | Planned | [02-clipboard-history.md](features/02-clipboard-history.md) |
| 4 | Enhanced screenshot tooling | Planned | [04-screenshot-tooling.md](features/04-screenshot-tooling.md) |
| 5 | Notification center redesign | Implemented | [05-notification-center-redesign.md](features/05-notification-center-redesign.md) |
| 6 | Notification action buttons | Implemented | [06-notification-action-buttons.md](features/06-notification-action-buttons.md) |
| 7 | Wallpaper + Material color pipeline | Implemented | [08-theme-system.md](features/08-theme-system.md) |
| 8 | Color picker | Backlog | Future detail doc |
| 9 | Idle inhibitor | Backlog | Future detail doc |
| 10 | More complete media overlay | Backlog | Future detail doc |
| 11 | Workspace / window overview | Backlog | Future detail doc |
| 12 | Settings UI | Done | [07-settings-module.md](features/07-settings-module.md) |
| 13 | Theme system (auto + matugen + export) | Core done | [08-theme-system.md](features/08-theme-system.md) |
| 14 | Wallpaper manager | Dual-output `swww` smoke passed | [09-wallpaper-manager.md](features/09-wallpaper-manager.md) |

## Runtime verification

- In nested niri, focused-output and region recording both produced readable H.264 video using the shared-memory recording path. Audio and the physical desktop's recording controls still need a smoke pass.
- In nested niri, launcher search, Up and Down, Enter to launch an application, and Escape to close all passed. The niri keybinding and focused-output placement across multiple monitors remain open.
- In nested niri, manual mode changes and a scheduled switch updated both the system color preference and the configured GTK themes.
- With `swww` 0.11.2 and two virtual Wayland outputs, rapid selection applied the latest wallpaper to both outputs. Restarting Quickshell restored it on both outputs.

## Recommended order

1. Finish the desktop recording smoke and verify launcher placement on the focused monitor.
2. Add clipboard history using the launcher search model.
3. Expand screenshot tooling with OCR and capture actions in the command palette.

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
- [Wallpaper manager](features/09-wallpaper-manager.md)
