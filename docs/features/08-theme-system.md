# Theme system

## Goal

Build a complete theme pipeline for niri-strata:

- automatic light/dark switching through a small Rust daemon
- live shell palette resolution through QML
- optional dynamic palettes through matugen
- optional external theme export for GTK, Qt, niri, terminals, editors, browsers,
  and CSS-based apps

The system is intentionally layered so each phase is independently useful and
safe to ship.

## Product decisions

- User preference and current effective mode are separate.
- `SettingsData.themeMode` is the user's choice: `"dark"`, `"light"`, or
  `"auto"`.
- `Theme._autoLight` is runtime state used only when `themeMode === "auto"`.
- The daemon never writes `settings.json`.
- The daemon writes only `auto-theme-state.json`, containing exactly `dark` or
  `light`.
- `AutoThemeBridge.qml` is the QML bridge from daemon state to `Theme._autoLight`.
- External app theming is opt-in per target.
- External exports render from the resolved `Theme.colors` palette, not from a
  separate DMS or matugen-specific preset model.

## Reference boundary

`temp/DankMaterialShell/` inspires the system, especially:

- matugen as a color engine
- queued/debounced theme generation
- generated GTK/Qt/application theme files
- idempotent apply scripts with backups and ownership markers

Do not borrow:

- the `dms` Go daemon
- DMS IPC for time/location automation
- the greeter, plugin browser, display layout, or window-rule system
- automatic mutation of terminal/editor/browser main config files

## Phase A: Rust auto-theme daemon

### Architecture

```text
Rust daemon                         Quickshell
    |                                  |
    | 1. read settings.json            |
    |    - autoMode                    |
    |    - autoTimeStart/End           |
    |    - autoLat/autoLng             |
    |                                  |
    | 2. calculate effective mode      |
    |    dark or light                 |
    |                                  |
    | 3. write auto-theme-state.json   |
    |    only when value changed       |
    |  -------------------------------->
    |                                  | AutoThemeBridge FileView watches
    |                                  | auto-theme-state.json
    |                                  |
    |                                  | AutoThemeBridge sets
    |                                  | Theme._autoLight
    |                                  |
    |                                  | Theme._isLight resolves:
    |                                  | - dark/light directly from themeMode
    |                                  | - auto from _autoLight
    |                                  |
    |                                  | Theme.colors updates live
    |
    | 4. sleep until next check
    |    min(next transition, 120s)
    |    max(..., 5s)
    |
    | 5. repeat
```

The daemon never talks IPC and never calls Quickshell. It reads `settings.json`
and writes the compact state file:

```text
~/.config/quickshell/niri-strata/auto-theme-state.json
```

That file contains a plain string:

```text
dark
```

or:

```text
light
```

`AutoThemeBridge.qml` is responsible for watching the file, explicitly
reloading it, and copying its value into `Theme._autoLight`.

### Runtime state model

| value | owner | persisted | purpose |
|---|---|---:|---|
| `SettingsData.themeMode` | user/settings UI | yes, in `settings.json` | user preference: dark/light/auto |
| `SettingsData.autoMode` | user/settings UI | yes, in `settings.json` | auto schedule mode: time/sun |
| `auto-theme-state.json` | Rust daemon | runtime file | current calculated effective mode |
| `Theme._autoLight` | `AutoThemeBridge.qml` | no | runtime light/dark state for auto mode |
| `Theme._isLight` | `Theme.qml` | no | resolved effective mode used by palette |

This mirrors the DMS lesson that "what the user chose" and "what is currently
effective" must not be the same field.

### Modes

| mode | behavior |
|---|---|
| `time` | write `dark` at `autoTimeStart`, write `light` at `autoTimeEnd` |
| `sun` | compute sunrise/sunset from `autoLat`/`autoLng`; write `light` between sunrise and sunset, `dark` otherwise |
| empty / `manual` | daemon exits immediately; user controls `themeMode` manually |

`autoMode: "manual"` is accepted by the daemon even though the current settings
enum exposes only `"time"` and `"sun"`. If manual daemon control becomes a UI
feature, update the settings enum and harness tests together.

### Settings keys

| key | type | default | notes |
|---|---|---|---|
| `themeMode` | string | `"dark"` | `"dark"`, `"light"`, or `"auto"` |
| `autoMode` | string | `"time"` | `"time"` or `"sun"` |
| `autoTimeStart` | string | `"18:00"` | HH:MM, dark mode on |
| `autoTimeEnd` | string | `"06:00"` | HH:MM, light mode on |
| `autoLat` | real | `0.0` | latitude for sunrise calculation |
| `autoLng` | real | `0.0` | longitude for sunrise calculation |

The daemon reads `settings.json` on every loop iteration, so changing these
settings takes effect on the next daemon cycle.

### Binary

- Located in `crates/auto-theme/`
- Single binary: `niri-strata-auto-theme`
- Dependencies: `serde`, `serde_json`, `sunrise = "3"` (v3 API uses year/month/day, not Unix timestamp)
- Built with `cargo build --release`

### Startup

`shell.qml` starts the daemon after shell startup. The current implementation
uses a full path under the user's niri-strata config directory:

```qml
var bin = home + "/.config/quickshell/niri-strata/target/release/niri-strata-auto-theme";
Quickshell.execDetached([bin]);
```

It also ensures the state file exists before starting the daemon:

```qml
Quickshell.execDetached(["sh", "-c", "mkdir -p " + dir + " && touch " + dir + "/auto-theme-state.json"]);
```

Future cleanup should avoid shell string construction here and replace the
`mkdir -p && touch` command with a small helper or safer array-shaped command
boundary.

### Debug mode

The daemon supports a read-only check mode:

```sh
target/release/niri-strata-auto-theme --check
```

Optional overrides:

```sh
target/release/niri-strata-auto-theme --check --time 19:30
target/release/niri-strata-auto-theme --check --lat 23.1089 --lng 113.2647
```

`--time` values are interpreted as UTC. Convert from local time before testing.

Expected output includes:

- calculated mode: `dark` or `light`
- time until next transition
- next transition clock time
- coordinates when `autoMode` is `sun`

### Files

| file | purpose |
|---|---|
| `Cargo.toml` | Rust workspace root |
| `crates/auto-theme/Cargo.toml` | daemon crate manifest |
| `crates/auto-theme/src/main.rs` | daemon implementation and `--check` mode |
| `modules/services/AutoThemeBridge.qml` | watches `auto-theme-state.json`, writes `Theme._autoLight` |
| `modules/common/Theme.qml` | resolves `themeMode` + `_autoLight` into `Theme._isLight` |
| `shell.qml` | mounts `AutoThemeBridge` and starts the daemon |
| `auto-theme-state.json` | runtime state file; should not be committed |

- [x] daemon reads `settings.json`
- [x] daemon writes `auto-theme-state.json`, not `settings.json`
- [x] state file contains only `dark` or `light`
- [x] time mode writes expected state for configured start/end times
- [x] sun mode writes expected state for configured coordinates
- [x] empty/manual auto mode exits immediately
- [x] changing auto settings in UI takes effect on the next daemon cycle
- [x] `AutoThemeBridge.qml` updates `Theme._autoLight` from file changes
- [x] `themeMode: "auto"` uses `_autoLight`
- [x] `themeMode: "dark"` and `"light"` ignore `_autoLight`
- [x] `--check`, `--time`, `--lat`, and `--lng` work for diagnostics
- [x] missing daemon binary does not crash the shell
- [x] `cargo build --release` passes
- [x] `npm run harness` passes

## Phase B: matugen dynamic palette

### Architecture

```text
User selects source
  - built-in preset
  - wallpaper path
  - hex source color
        |
        v
ThemeEngine.qml
  probes matugen
  debounces requests
  runs one generation at a time
  keeps one pending newest request
        |
        v
matugen JSON output
        |
        v
harness/lib/theme-core.mjs-compatible mapping
        |
        v
niri-strata palette contract
        |
        v
Theme._palette / Theme.colors
```

### Invocation

niri-strata should call `matugen` directly from a QML service boundary, not
through `dms matugen queue`.

The exact command should be verified against the supported matugen version and
then implemented as an array-shaped command builder in
`harness/lib/theme-core.mjs` first. The implementation must support two source
classes:

```text
wallpaper path -> matugen JSON
hex source     -> matugen JSON
```

Candidate CLI examples, to be validated before coding:

```text
matugen image <wallpaper-path> --json
matugen image <hex-color> --json
```

The harness should use fixtures captured from the supported matugen version so
parser tests do not depend on live commands.

### Output and parsing

Do not describe this as just a "30-color palette".

There are three layers:

1. raw matugen output: many Material roles for dark/light/default modes
2. niri-strata palette contract: the keys required by `Theme.colors`
3. derived shell colors: hover/active/transparent values calculated in QML

The mapper must produce every key expected by `ThemePresets.js`:

- `background`
- `surface`
- `layer0`, `layer1`, `layer1Hover`, `layer1Active`
- `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`,
  `surfaceContainerHigh`, `surfaceContainerHighest`
- `text`, `mutedText`, `subtleText`
- `primary`, `primaryText`, `primaryContainer`, `primaryContainerText`
- `secondary`, `secondaryContainer`, `secondaryContainerText`
- `tertiary`, `tertiaryContainer`, `tertiaryContainerText`
- `successColor`, `successContainer`
- `warningColor`, `warningContainer`
- `errorColor`, `errorContainer`
- `outline`, `outlineVariant`

If any required key is missing, the dynamic palette is invalid and `Theme.qml`
must keep the last valid palette or fall back to the selected built-in preset.

### New service: `modules/services/ThemeEngine.qml`

Responsibilities:

- `property bool matugenAvailable`
- `property string matugenVersion`
- `property bool generationRunning`
- `property bool generationPending`
- `property string lastGenerationStatus`
- `property string lastGenerationError`
- `property var generatedPalette`
- probe `matugen`
- build commands through a tested helper contract
- parse JSON output
- debounce repeated requests
- prevent stale generation results from overwriting newer requests

### Theme changes

- Keep the existing `Theme.colors` API stable.
- Built-in presets continue to come from `ThemePresets.js`.
- Dynamic mode uses `ThemeEngine.generatedPalette` only when complete.
- `accentColor` is applied as a final override through the existing `applyAccent`, even in dynamic mode. This preserves user customization on top of generated palettes.

### Appearance tab changes

- Add source controls:
  - preset
  - wallpaper
  - hex
- Add wallpaper path input.
- Add source hex input.
- Add matugen scheme selector.
- Add contrast control if supported by the chosen matugen version.
- Show generation status and last error.

### Acceptance criteria

- [ ] matugen availability is visible in service/settings status
- [ ] dynamic palette generation from wallpaper updates shell colors
- [ ] dynamic palette generation from hex updates shell colors
- [ ] invalid JSON does not blank `Theme.colors`
- [ ] missing matugen falls back to a built-in preset
- [ ] repeated setting changes coalesce into one generation
- [ ] stale generation results cannot overwrite newer requests
- [ ] parser and mapper are covered by harness fixtures
- [ ] `npm run harness` passes

## Phase C: system theme export

### Architecture

```text
Theme.colors
    |
    v
palette JSON snapshot
    |
    v
scripts/theme-render.mjs
    |
    +--> GTK CSS
    +--> Qt color scheme
    +--> niri color KDL
    +--> terminal/editor/browser theme files in later phases
    |
    v
ThemeExport.qml
    |
    v
target-specific apply scripts
```

External export renders from the resolved `Theme.colors` palette. Built-in
presets are not regenerated through matugen just to theme external apps.

### Render boundary

Use a testable renderer:

```text
scripts/theme-render.mjs
```

Input:

- palette JSON snapshot generated from `Theme.colors`
- target id
- mode: `dark` or `light`
- output directory

Output examples:

- `niri-strata-colors.css`
- `NiriStrata.colors`
- `niri-strata.conf`
- `colors.kdl`

This makes GTK/Qt rendering testable without launching Quickshell.

### GTK export

Generated files:

- `~/.config/gtk-3.0/niri-strata-colors.css`
- `~/.config/gtk-4.0/niri-strata-colors.css`

Apply rules:

- GTK export is disabled until both `systemThemeEnabled` and
  `systemThemeGtkEnabled` are true.
- Existing user files are modified only through a marker block, managed symlink,
  or explicit backup-and-replace flow.
- GTK4 should prefer marker import insertion over replacing `gtk.css`.
- GTK3 may use a managed symlink only if the file is missing or already managed.

### Qt export

Generated files:

- `~/.config/qt5ct/colors/niri-strata.conf`
- `~/.config/qt6ct/colors/niri-strata.conf`
- `~/.local/share/color-schemes/NiriStrata.colors`

Apply rules:

- Qt export is disabled until both `systemThemeEnabled` and
  `systemThemeQtEnabled` are true.
- If `qt5ct` exists, update `~/.config/qt5ct/qt5ct.conf`.
- If `qt6ct` exists, update `~/.config/qt6ct/qt6ct.conf`.
- Set `[Appearance]` keys:
  - `custom_palette=true`
  - `color_scheme_path=<generated color scheme path>`
- Missing `qt5ct` disables only Qt5 apply.
- Missing `qt6ct` disables only Qt6 apply.
- Missing both reports a Qt target error, not a global failure.

Use niri-strata naming. Do not write `DankMatugen.colors`.

### ThemeExport service

Add `modules/services/ThemeExport.qml` later in this phase.

Responsibilities:

- target availability probes
- target enabled state
- target managed state
- last applied mode/palette hash
- last error per target
- `applyTarget(targetId)`
- `applyEnabledTargets(reason)`
- `revertTarget(targetId)` where safe

### Appearance tab changes

System theme section:

- master toggle: `systemThemeEnabled`
- apply-on-mode-change toggle
- target toggles:
  - Portal
  - GTK
  - Qt
  - niri
  - Terminals
  - Editors
  - Browsers
  - Electron/CSS apps
- target status rows:
  - unavailable
  - disabled
  - generated
  - applied
  - error

The master switch only unlocks the section. Each target requires its own toggle.

### Acceptance criteria

- [ ] GTK CSS renders from a palette JSON fixture
- [ ] Qt color scheme renders from a palette JSON fixture
- [ ] generated names use `niri-strata` / `NiriStrata`
- [ ] GTK apply is idempotent
- [ ] GTK apply does not silently destroy user `gtk.css`
- [ ] Qt apply updates qt5ct and qt6ct independently
- [ ] missing optional tools produce target-level disabled/error state
- [ ] export does not block live shell recoloring
- [ ] `npm run harness` passes

## Phase D: broader external targets

After GTK/Qt are stable, add targets in this order:

1. Portal/gsettings color-scheme
2. niri color include fragment
3. terminal generated theme files
4. editor generated theme files
5. browser generated CSS files
6. Electron/CSS app generated files
7. user templates

Terminal/editor/browser/Electron targets should start as generated files plus
include/import guidance. They must not auto-edit main user config files in the
initial implementation.

## Runtime files and ignore rules

Runtime files should not be committed:

- `settings.json`
- `auto-theme-state.json`
- Rust `target/` build outputs
- generated external theme output under user config/data/cache roots

Current `.gitignore` already ignores `settings.json`; it should also ignore
`auto-theme-state.json` and `target/`.

## File inventory

### Existing Phase A files

```text
Cargo.toml
crates/auto-theme/Cargo.toml
crates/auto-theme/src/main.rs
modules/services/AutoThemeBridge.qml
modules/common/Theme.qml
modules/common/SettingsData.qml
modules/common/settings/SettingsSpec.js
modules/settings/tabs/AppearanceTab.qml
shell.qml
harness/lib/settings-core.mjs
harness/settings-core.test.mjs
harness/settings-structure.test.mjs
```

### Planned Phase B/C files

```text
harness/lib/theme-core.mjs
harness/theme-core.test.mjs
harness/fixtures/theme/
modules/services/ThemeEngine.qml
modules/services/ThemeExport.qml
scripts/theme-render.mjs
scripts/theme-apply-gtk.sh
scripts/theme-apply-qt.sh
```

## Rollout order

1. Keep Phase A aligned with the `auto-theme-state.json` architecture.
2. Add `.gitignore` entries for runtime/build files.
3. Add theme-core harness helpers and matugen JSON fixtures.
4. Add `ThemeEngine.qml` for shell-only dynamic palettes.
5. Wire dynamic source settings into `Theme.qml` and `AppearanceTab.qml`.
6. Add `ThemeExport.qml` target model with probes and disabled states.
7. Implement GTK/Qt renderers and apply scripts.
8. Add portal/gsettings and niri colors.
9. Add terminal/editor/browser/Electron generated files.
10. Add user templates only after built-in targets are stable.
