# Theme system

## Goal

Add a complete theme pipeline to niri-strata: auto light/dark switching via a
native Rust daemon, wallpaper-based dynamic color generation through matugen,
and optional system theme export for GTK/Qt applications.

The first version targets Arch Linux with niri, Quickshell, and matugen from
the AUR.

## Product decision

The theme system should be layered so each phase is independently useful:

- Phase A (daemon): auto light/dark switching works without matugen. The
  daemon is a single-file Rust binary that reads and writes the settings JSON
  directly.
- Phase B (matugen): wallpaper-based palette generation adds a "Dynamic"
  preset. Falls back to internal presets when matugen is not installed.
- Phase C (export): GTK/Qt export is opt-in and never blocks the shell.

## Reference boundary

`temp/DankMaterialShell/` inspires the overall architecture but niri-strata
simplifies by replacing the `dms` Go daemon + matugen orchestration with a
smaller Rust daemon and direct matugen calls from QML.

Do NOT borrow:
- The `dms` Go daemon (Rust rewrite, narrower scope)
- Time/location auto-switching via dms service (self-contained in daemon)
- Plugin browser, greeter, display layout, window rules
- Terminal/editor/browser theme templates (defer to a future phase)

## Phase A: Rust auto-theme daemon

### Architecture

```
Rust daemon                     Quickshell
    │                              │
    │  1. read settings.json       │
    │  2. calculate next switch    │
    │  3. sleep until then         │
    │  4. write themeMode to       │
    │     settings.json            │
    │  ──────────────────────────→ │
    │                              │  FileView watchChanges detects
    │                              │  SettingsData auto-reloads
    │                              │  Theme._isLight updates
    │                              │  UI colors update live
    │                              │
    │  5. goto 2                   │
```

The daemon NEVER talks IPC or Quickshell. It only reads and writes the
settings JSON file. Quickshell's existing `FileView` watcher handles the
rest.

### Modes

| mode | behavior |
|---|---|
| `manual` | daemon exits immediately; user controls `themeMode` |
| `time` | switch to dark at `autoTimeStart`, light at `autoTimeEnd` |
| `sun` | compute sunrise/sunset from `autoLat`/`autoLng`, switch at those times |

### Settings keys (add to spec)

| key | type | default | notes |
|---|---|---|---|
| `autoMode` | string | `"time"` | `"time"` or `"sun"` |
| `autoTimeStart` | string | `"18:00"` | HH:MM, dark mode on |
| `autoTimeEnd` | string | `"06:00"` | HH:MM, light mode on |
| `autoLat` | real | `0.0` | latitude for sunrise calc |
| `autoLng` | real | `0.0` | longitude for sunrise calc |

The daemon reads these keys on every loop iteration, so changing them in
Settings takes effect on the next cycle (no restart needed).

### Binary

- Located in `crates/auto-theme/`
- Single binary `niri-strata-auto-theme`
- Dependencies: `serde`, `serde_json`, `sunrise` (for sun mode)
- ~150 lines of Rust
- Installed via `cargo build --release`

### Startup

`shell.qml` launches the daemon once on shell start:

```qml
Component.onCompleted: {
    Quickshell.execDetached(["niri-strata-auto-theme"]);
}
```

If the binary is not on `$PATH`, the daemon silently fails — settings still
work manually.

### Files

| file | purpose |
|---|---|
| `Cargo.toml` | workspace root |
| `crates/auto-theme/Cargo.toml` | crate manifest |
| `crates/auto-theme/src/main.rs` | daemon |

### Acceptance criteria (Phase A)

- [ ] daemon starts with `niri-strata-auto-theme` and reads `settings.json`
- [ ] time mode switches `themeMode` between `"dark"` and `"light"` at set times
- [ ] sun mode switches at computed sunrise/sunset
- [ ] manual mode (`autoMode: "manual"`) daemon exits immediately
- [ ] changing settings in UI takes effect on next daemon cycle
- [ ] daemon not on `$PATH` does not crash the shell
- [ ] CI: `cargo build` passes in workspace root
- [ ] npm run harness passes (including new spec keys)

---

## Phase B: matugen dynamic palette

### Architecture

```
User picks wallpaper      →     matugen image "$path" --json
                                    │
                                    ▼
ThemeEngine service parses JSON →  30-color palette
                                    │
                                    ▼
Theme._palette updated live    →   UI recolors instantly
```

### New service: `modules/services/ThemeEngine.qml`

- `property bool matugenAvailable`: probe `command -v matugen`
- `property bool dynamicActive`: true when `themeId === "dynamic"`
- `property string wallpaperPath`: persisted
- `function generate()`: run `matugen image "$path" --json`, parse output
- `signal paletteReady(var palette)`: emitted with 30-color object
- Error states: matugen not found, wallpaper missing, parse failure

### Theme.qml changes

- `themeId` enum adds `"dynamic"`
- When `themeId === "dynamic"`, `_palette` reads from `ThemeEngine` instead of
  `ThemePresets`
- Fallback: if matugen unavailable, use `"default"` preset

### AppearanceTab changes

- Preset segmented row adds `"Dynamic"` option
- Wallpaper picker: path text field (file picker deferred)
- When dynamic selected: show wallpaper path + "Generate" button + status

### Files

| file | purpose |
|---|---|
| `modules/services/ThemeEngine.qml` | matugen wrapper service |

### Acceptance criteria (Phase B)

- [ ] "Dynamic" appears in Preset selector
- [ ] Dynamic with valid wallpaper generates palette and updates UI
- [ ] Dynamic without matugen falls back to "default" preset
- [ ] Dynamic without wallpaper shows "No wallpaper set" state
- [ ] npm run harness passes

---

## Phase C: system theme export

### Architecture

```
ThemeEngine.exportGtk(dark)   →   scripts/gtk-colors.sh
    │
    ├── writes ~/.config/gtk-3.0/niri-strata-colors.css
    ├── symlinks ~/.config/gtk-3.0/gtk.css → niri-strata-colors.css
    ├── writes ~/.config/gtk-4.0/niri-strata-colors.css
    └── injects @import into ~/.config/gtk-4.0/gtk.css

ThemeEngine.exportQt()       →   scripts/qt-colors.sh
    │
    ├── writes ~/.config/qt5ct/qt5ct.conf (color_scheme_path)
    └── writes ~/.config/qt6ct/qt6ct.conf (color_scheme_path)
```

### Scripts

`scripts/gtk-colors.sh`: generates GTK CSS from the current Quickshell palette.
Reads a minimal set of Theme.colors values via environment or a temp file.

`scripts/qt-colors.sh`: generates `DankMatugen.colors` KDE-format scheme and
configures qt5ct/qt6ct to use it.

### ThemeEngine API additions

- `function exportGtk()`: run gtk script, show toast on success/error
- `function exportQt()`: run qt script, show toast
- `readonly property bool gtkExported`: check if symlink exists
- `readonly property bool qtExported`: check if qt5ct conf references our scheme

### AppearanceTab changes

- "System theme" section with:
  - GTK toggle + export button + status indicator
  - Qt toggle + export button + status indicator
  - Info text: "Requires matugen"

### Files

| file | purpose |
|---|---|
| `scripts/gtk-colors.sh` | GTK CSS generation |
| `scripts/qt-colors.sh` | Qt color scheme + qt5ct/qt6ct conf |

### Acceptance criteria (Phase C)

- [ ] GTK export creates valid CSS and symlinks
- [ ] GTK export is idempotent (running twice doesn't break)
- [ ] Qt export creates valid conf files
- [ ] Export buttons show success/error states
- [ ] Missing matugen shows "matugen required" state, not crash
- [ ] npm run harness passes

---

## Phase D: cleanup

- [ ] `harness/settings-structure.test.mjs`: full structural coverage
- [ ] qmllint zero warnings on all new files
- [ ] `npm run harness` all green
- [ ] ROADMAP updated
- [ ] `cargo build` in workspace root passes

---

## File inventory

### New files (14)

```
Cargo.toml
crates/auto-theme/Cargo.toml
crates/auto-theme/src/main.rs
modules/services/ThemeEngine.qml
scripts/gtk-colors.sh
scripts/qt-colors.sh
docs/features/08-theme-system.md
```

### Modified files (10)

```
modules/common/settings/SettingsSpec.js        # +5 auto keys
modules/common/SettingsData.qml                # +5 readonly properties
modules/common/Theme.qml                       # _isLight fix, dynamic palette
modules/settings/tabs/AppearanceTab.qml        # auto config UI, dynamic preset, export
shell.qml                                      # daemon startup
harness/lib/settings-core.mjs                  # +5 spec keys + tests
harness/settings-core.test.mjs                 # +5 key tests
harness/settings-structure.test.mjs            # phase A/B/C structure assertions
harness/niri-state-core.test.mjs               # auto-theme daemon wiring check
docs/ROADMAP.md                                # update theme system status
```

## Rollout order

1. Phase A: Rust daemon + 5 spec keys + UI + harness
2. Phase B: matugen dynamic palette + ThemeEngine service + UI
3. Phase C: GTK/Qt export + scripts + UI
4. Phase D: cleanup, qmllint, harness, docs
