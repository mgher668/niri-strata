# Wallpaper manager

## Goal

Add a centralized wallpaper management system to niri-strata Settings.
Users can add multiple wallpaper folders, browse thumbnails, select
wallpapers per-monitor, and apply them through swww or swaybg backends —
all from within the Settings window.

## Product decision

The wallpaper manager acts as a waypaper replacement: it detects available
backend tools (swww, swaybg), lets users pick a backend, browse folders of
images, and apply wallpapers with configurable fill mode and background
color. It does not render the wallpaper itself (no Quickshell PanelWindow
background layer); it delegates to the selected backend.

Selecting a wallpaper also feeds the path to ThemeEngine for matugen
dynamic palette generation, closing the loop between wallpaper and theme.

## Reference boundary

`temp/DankMaterialShell/` renders wallpapers via Quickshell PanelWindow +
WlrLayer.Background (1138 lines). niri-strata does NOT replicate this —
it delegates to external backends (swww/swaybg), which are simpler and
don't require a Quickshell Wayland layer.

Do NOT borrow:
- Quickshell PanelWindow wallpaper rendering (WlrLayer.Background)
- Wallpaper transition shaders (fade/wipe/disc/stripes/etc)
- Go daemon wallpaper cycling service
- Per-monitor wallpaper fill mode overrides (one fill mode for all)

## Settings keys

| key | type | default | notes |
|---|---|---|---|
| `wallpaperPath` | string | `""` | Current selected wallpaper (single file). Already exists. |
| `wallpaperDirs` | string | `"[]"` | JSON array of folder paths. |
| `wallpaperBackend` | string | `"swww"` | `"swww"` or `"swaybg"`. |
| `wallpaperFillMode` | string | `"fill"` | `fill`, `fit`, `center`, `tile`, `stretch`. |
| `wallpaperBgColor` | string | `"#000000"` | Hex color for uncovered areas. |
| `wallpaperPerMonitor` | bool | `false` | Independent wallpaper per monitor. |
| `wallpaperMonitorPaths` | string | `"{}"` | JSON map: `{"DP-1": "/path/a.jpg", ...}`. |
| `wallpaperSortBy` | string | `"name"` | `name` or `date`. |
| `wallpaperSortOrder` | string | `"ascending"` | `ascending` or `descending`. |
| `wallpaperRecursive` | bool | `false` | Scan subfolders recursively. |

Total: 1 existing + 9 new keys = 10 wallpaper-related keys.

## Backend detection

### Probe on startup

`ThemeEngine` (or a new `WallpaperService`) probes:

```sh
command -v swww && command -v swww-daemon
command -v swaybg
```

### Available backends

| backend | apply command | supports fill mode | supports bg color | needs daemon |
|---|---|---|---|---|
| swww | `swww img <path> --transition-type fade [-o <output>] [--fill-color <hex>]` | no (always scales) | yes (`--fill-color`) | yes (`swww-daemon`) |
| swaybg | `swaybg -i <path> -m <mode> -c <hex> [-o <output>]` | yes (`-m`) | yes (`-c`) | no |

### swww daemon auto-start

Before applying with swww, check `pgrep -x swww-daemon`. If not running,
start `swww-daemon &` and wait 1 second before sending `swww img`.

### Conflict detection

On startup, probe for running wallpaper daemons:

```sh
pgrep -x swww-daemon
pgrep -x swaybg
pgrep -x hyprpaper
pgrep -x wpaperd
```

Show a warning in Settings if any are detected. Do NOT auto-kill — only
inform the user.

## UI layout

All within `AppearanceTab.qml`, in the Dynamic mode section.

### Section: Wallpaper

```
[Backend: swww | swaybg]  (segmented row, only shows installed backends)

[Fill mode: fill | fit | center | tile | stretch]  (segmented row)
  ↑ swww selected: only "fill" available
  ↑ swaybg selected: all modes available

[Background color: ■ ■ ■ ■ ■ ■]  (swatch row, same pattern as accent)
  ↑ always visible (both backends support -c / --fill-color)

[Per-monitor: ☐]  (toggle)

  When per-monitor is ON:
  [Monitor: DP-1 | HDMI-1 | ...]  (segmented row from Quickshell.screens)

[Wallpaper folders]  (section header)
  [/home/user/Pictures/wallpapers     ✕]
  [/home/user/Pictures/landscapes     ✕]
  [+ Add folder]  (button → zenity --file-selection --directory)

[Sort: Name | Date] [Order: Asc | Desc] [⟳ Refresh] [☐ Include subfolders]

  GridView:
  ┌────┐ ┌────┐ ┌────┐ ┌────┐
  │ img│ │ img│ │ img│ │ img│   180×120 cells
  └────┘ └────┘ └────┘ └────┘    PreserveAspectCrop
  ┌────┐ ┌────┐ ┌────┐ ┌────┐   async load, sourceSize 180×120
  │ img│ │ img│ │ img│ │ img│   cache: true
  └────┘ └────┘ └────┘ └────┘    click → apply wallpaper + trigger matugen

  Empty state: "Add a wallpaper folder to browse images."
  Loading state: "Scanning..."
  No images state: "No images found in selected folders."
```

### Thumbnail grid

- `GridView` with fixed cell size 180×120 (3:2 ratio)
- `Image.fillMode: Image.PreserveAspectCrop` — center-crop to uniform cells
- `Image.asynchronous: true` — off-main-thread decode
- `Image.sourceSize: Qt.size(180, 120)` — limit decode resolution
- `Image.cache: true` — Qt caches decoded thumbnails
- `ListView`/`GridView` only creates visible delegates + `cacheBuffer: 2000`
  — 600 images won't lag; only ~20 decoded at any time

### Folder scanner

Non-recursive:
```sh
ls -1 <dir>/*.jpg <dir>/*.png <dir>/*.webp <dir>/*.jpeg <dir>/*.bmp <dir>/*.gif 2>/dev/null
```

Recursive:
```sh
find <dir> -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" -o -name "*.jpeg" -o -name "*.bmp" -o -name "*.gif" \) 2>/dev/null
```

Output is a newline-separated list of file paths. QML parses into an array.

### Sorting

Sorting is done in QML JS after scanning:

- `name`: `arr.sort((a, b) => a.localeCompare(b))`
- `date`: needs `stat --format=%Y <file>` — run as a second Process after
  listing, or use `ls -lt` / `find ... -printf "%T@ %p\n"` for combined output
- `ascending` / `descending`: reverse the sort result

Recommended: use `find <dir> -type f \( ... \) -printf "%T@ %p\n"` for date
sorting (timestamp + path on each line), and plain `ls` for name sorting.

### File picker

Folder selection uses zenity:
```sh
zenity --file-selection --directory --title="Select wallpaper folder"
```

## Apply wallpaper

### Flow

```
User clicks thumbnail
  ↓
1. Save wallpaperPath (or wallpaperMonitorPaths[output] if per-monitor)
  ↓
2. Apply via backend:
   swww:  pgrep swww-daemon || (swww-daemon &; sleep 1)
          swww img <path> --transition-type fade [-o <output>] [--fill-color <hex>]
   swaybg: swaybg -i <path> -m <mode> -c <hex> [-o <output>]
  ↓
3. Trigger ThemeEngine.generate(<path>) → matugen → palette → UI recolors
```

### swww fill mode limitation

swww does not support `-m` / fill mode selection. It always scales the
image to fill the screen. When swww is the selected backend:

- Fill mode segmented row shows only "fill" (disabled state for others)
- `--fill-color` is still supported for uncovered areas (letterboxing)

### swaybg kill before re-apply

`swaybg` blocks — each new invocation creates a new process. Before
applying, kill the previous `swaybg`:

```sh
pkill -x swaybg; swaybg -i <path> -m <mode> -c <hex> [-o <output>] &
```

### Per-monitor apply

When `wallpaperPerMonitor` is true:

- Iterate `Quickshell.screens`
- For each screen, read `wallpaperMonitorPaths[screen.name]`
- Apply with `-o <screen.name>`

When false:

- Apply to all outputs (swww default; swaybg `-o "*"` or no `-o`)

## Conflict detection detail

On Settings open, run:

```sh
pgrep -x swww-daemon && echo "swww-daemon"
pgrep -x swaybg && echo "swaybg"
pgrep -x hyprpaper && echo "hyprpaper"
pgrep -x wpaperd && echo "wpaperd"
```

If any are detected, show a warning banner:

```
⚠ Detected: swww-daemon is running. Stop it before applying wallpapers
from niri-strata to avoid conflicts.
```

Do NOT auto-kill. Only warn.

## Harness test plan

Pure functions are tested without launching Quickshell.

### `harness/lib/wallpaper-commands.mjs`

Backend command construction — no side effects, pure argv builders.

```js
buildSwwwCommand(path, output, fillColor)
  → ["swww", "img", path, "--transition-type", "fade", ...]
  → omit "-o" when output is empty
  → omit "--fill-color" when fillColor is empty

buildSwaybgCommand(path, output, fillMode, bgColor)
  → ["swaybg", "-i", path, "-m", fillMode, "-c", bgColor, ...]
  → omit "-o" when output is empty
  → omit "-c" when bgColor is empty

buildSwwwDaemonStart()
  → ["swww-daemon"]

buildSwaybgKill()
  → ["pkill", "-x", "swaybg"]

validFillModesForBackend(backend)
  → swww: ["fill"]
  → swaybg: ["fill", "fit", "center", "tile", "stretch"]
  → unknown: []

parseConflictProbe(rawText)
  → "" → []
  → "swaybg\n" → ["swaybg"]
  → "swww-daemon\nhyprpaper\n" → ["swww-daemon", "hyprpaper"]
```

### `harness/lib/wallpaper-scan.mjs`

Folder scanning and sorting — pure parse/sort functions.

```js
parseFileList(rawText, sortBy, sortOrder)
  → raw text from ls/find → sorted array of paths
  → name sort: localeCompare
  → date sort: parse "timestamp path" lines from find -printf
  → ascending/descending: reverse
  → empty input → []

buildScanCommand(dirs, recursive, sortBy)
  → recursive=false, sortBy=name: ["ls", "-1", dir + "/*.jpg", ...]
  → recursive=true, sortBy=date: ["find", dir, "-type", "f", "(", ...,
     "-printf", "%T@ %p\\n"]
  → multiple dirs: one command per dir, results merged
```

### `harness/wallpaper-commands.test.mjs`

| test | validates |
|---|---|
| swww command has correct argv | path, transition-type, no -o when output empty |
| swww command includes -o when output specified | per-monitor apply |
| swww command includes --fill-color when provided | bg color support |
| swaybg command has correct argv | -i, -m, -c, -o |
| swaybg command omits -o when output empty | all-outputs apply |
| swaybg command omits -c when bgColor empty | default black |
| validFillModesForBackend swww returns only fill | swww limitation |
| validFillModesForBackend swaybg returns all 5 | full support |
| validFillModesForBackend unknown returns empty | graceful fallback |
| parseConflictProbe empty returns empty array | no conflicts |
| parseConflictProbe detects swww-daemon | single conflict |
| parseConflictProbe detects multiple | multi conflict |
| parseFileList name ascending | alphabetical order |
| parseFileList name descending | reverse alphabetical |
| parseFileList date ascending | oldest first |
| parseFileList date descending | newest first |
| parseFileList empty input returns empty | no crash on empty |
| buildScanCommand non-recursive uses ls | correct command shape |
| buildScanCommand recursive uses find | find with -type f |
| buildScanCommand date sort uses -printf | timestamp prefix |

### `harness/settings-structure.test.mjs` (additions)

| test | validates |
|---|---|
| SettingsSpec has all 9 new wallpaper keys | spec completeness |
| SettingsData has wallpaper properties | QML wiring |
| WallpaperService has scanFolders and applyWallpaper | service API |
| WallpaperGrid has GridView with Image delegates | thumbnail rendering |
| AppearanceTab has backend segmented row | UI wiring |
| AppearanceTab has wallpaper folders list | folder management |

## Architecture

| file | purpose |
|---|---|
| `modules/services/WallpaperService.qml` | Backend detection, folder scanning, apply commands, conflict probe |
| `modules/settings/widgets/WallpaperGrid.qml` | GridView with thumbnails, sort controls, refresh button |
| `harness/lib/wallpaper-commands.mjs` | Pure command builders + fill mode validator + conflict parser |
| `harness/lib/wallpaper-scan.mjs` | Pure scan command builder + file list parser/sorter |
| `harness/wallpaper-commands.test.mjs` | 20 test cases for command construction, fill modes, conflicts, scanning |
### Modified files

| file | changes |
|---|---|
| `modules/common/settings/SettingsSpec.js` | +9 wallpaper keys |
| `modules/common/SettingsData.qml` | +9 readonly properties |
| `harness/lib/settings-core.mjs` | +9 spec keys |
| `harness/settings-core.test.mjs` | update key count + defaults |
| `modules/settings/tabs/AppearanceTab.qml` | Wallpaper section UI |
| `shell.qml` | Instantiate WallpaperService |

### WallpaperService API

```qml
property bool swwwAvailable: false
property bool swaybgAvailable: false
property string activeBackend: "swww"
property var detectedConflicts: []  // ["swww-daemon", "swaybg", ...]
property var imageList: []  // scanned image paths
property string scanStatus: "idle"  // idle | scanning | ready | error

function scanFolders(dirs, recursive, sortBy, sortOrder)
function applyWallpaper(path, output)
function probeBackends()
function probeConflicts()
```

## Acceptance criteria

- [ ] Backend segmented row only shows installed backends
- [ ] swww not installed hides swww option
- [ ] swaybg not installed hides swaybg option
- [ ] Neither installed shows "Install swww or swaybg" message
- [ ] Adding a wallpaper folder via zenity works
- [ ] Multiple folders can be added and removed
- [ ] Thumbnail grid loads images asynchronously without blocking UI
- [ ] Clicking a thumbnail applies the wallpaper via selected backend
- [ ] swww auto-starts daemon if not running
- [ ] swaybg kills previous instance before re-apply
- [ ] Fill mode segmented row adapts to backend (swww: only fill)
- [ ] Background color picker works for both backends
- [ ] Per-monitor toggle enables monitor selector
- [ ] Per-monitor apply sends `-o <output>` per screen
- [ ] Sorting by name and date works
- [ ] Sorting ascending and descending works
- [ ] Recursive toggle scans subfolders
- [ ] Refresh button re-scans folders
- [ ] Conflict detection shows warning when swww-daemon/swaybg running
- [ ] Selecting a wallpaper triggers matugen palette generation
- [ ] 600+ images don't lag the thumbnail grid
- [ ] Empty folder shows "No images found" state
- [ ] No wallpaper folders shows "Add a folder" state
- [ ] harness: command builders produce correct argv for swww and swaybg
- [ ] harness: fill mode validator returns correct modes per backend
- [ ] harness: conflict parser correctly detects running daemons
- [ ] harness: file list parser sorts by name and date, ascending and descending
- [ ] harness: scan command builder uses ls for non-recursive, find for recursive
- [ ] `npm run harness` passes

1. SettingsSpec + SettingsData: add 9 wallpaper keys + harness sync
2. harness/lib/wallpaper-commands.mjs + wallpaper-scan.mjs: pure functions
3. harness/wallpaper-commands.test.mjs: 20 test cases
4. WallpaperService.qml: backend probe, conflict probe, folder scan, apply
5. WallpaperGrid.qml: GridView + thumbnails + sort/refresh/recursive controls
6. AppearanceTab.qml: wallpaper section UI (backend, fill, bg color, per-monitor, folders, grid)
7. shell.qml: instantiate WallpaperService
8. harness: structural assertions + full verification