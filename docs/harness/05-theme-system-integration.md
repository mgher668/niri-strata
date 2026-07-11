# Harness phases: theme system integration

## Target

Build a staged theme pipeline that lets niri-strata control its own shell
palette and, when explicitly enabled, export matching colors to most common
Linux desktop applications.

The design borrows the useful parts of DankMaterialShell:

- matugen as the Material color engine
- a queue/debounce boundary for expensive theme generation
- generated GTK/Qt/application theme files
- idempotent apply scripts with backups and clear ownership markers

The design does not borrow the DMS Go daemon or its all-in-one service model.
niri-strata should keep its smaller current architecture:

- `SettingsData` persists user choices in `settings.json`.
- `niri-strata-auto-theme` computes automatic light/dark state.
- `AutoThemeBridge` reads `auto-theme-state.json` and updates `Theme._autoLight`.
- `Theme.qml` exposes one runtime palette to the shell.
- new export services/scripts write external application theme files only when
  the user enables them.

## Current state

Implemented:

- `modules/common/Theme.qml` resolves `themeMode`, `_autoLight`, `themeId`, and
  `accentColor` into `Theme.colors`.
- `modules/common/ThemePresets.js` provides six built-in dark/light palettes:
  `default`, `blue`, `green`, `rose`, `amber`, `neutral`.
- `modules/common/SettingsData.qml` persists the settings schema and live
  properties.
- `modules/services/AutoThemeBridge.qml` watches `auto-theme-state.json` and
  writes `Theme._autoLight`.
- `crates/auto-theme/src/main.rs` reads `settings.json`, calculates time/sun
  mode, and writes the compact state file.
- `modules/settings/tabs/AppearanceTab.qml` exposes manual, light, dark, auto,
  preset, accent, and auto schedule controls.

Important correction:

- `docs/features/08-theme-system.md` describes an older plan where the daemon
  writes `themeMode` back to `settings.json`. The current implementation is
  better: the daemon writes only `auto-theme-state.json`, while `themeMode`
  remains the user's choice. Future docs and tests should describe this
  two-field model explicitly.

## Product scope

In scope:

- Dynamic palette generation from a wallpaper path or a hex source color.
- Optional external theme export for GTK, Qt, portal/gsettings, niri, terminals,
  editors, browsers, and selected Electron/CSS apps.
- Per-target availability, enabled state, last-applied state, and error state.
- Harness tests for settings schema, command construction, template rendering,
  idempotent file writes, and QML wiring.
- Safe defaults: no external application files are modified until a target is
  enabled.

Decisions:

- The master `systemThemeEnabled` switch only unlocks external theming. Each
  target, including GTK and Qt, still requires its own explicit toggle.
- External exports render from the resolved `Theme.colors` palette. Built-in
  presets are not regenerated through matugen just to theme external apps.
- Terminal, editor, browser, and Electron targets start as generated theme files
  plus include/import guidance. They do not auto-edit main user config files in
  the initial implementation.

Out of scope for the first implementation:

- Copying the DMS Go daemon, IPC layer, greeter, plugin browser, display layout,
  and distro installer.
- Full theme marketplace support.
- Automatic mutation of arbitrary user config files without a marker block,
  backup, or explicit target toggle.
- Live reload guarantees for every external app; many apps require restart or
  their own reload command.

## Architecture

Target shape:

```text
settings.json
  themeMode/themeId/accentColor/wallpaper/system target toggles
       |
       v
SettingsData.qml
       |
       v
Theme.qml ----------------------+
  resolved light/dark palette   |
       |                        |
       |                        v
       |                  ThemeEngine.qml
       |                   matugen probe/generate/cache
       |                        |
       v                        v
Shell UI live colors      scripts/theme-render.mjs
                            render target files in staging dir
                                  |
                                  v
                           ThemeExport.qml
                            explicit apply actions
                                  |
                                  v
                 GTK / Qt / portal / niri / terminals / apps
```

Keep three separate responsibilities:

- `Theme.qml`: palette resolution and readonly color properties for QML.
- `ThemeEngine.qml`: matugen availability, palette generation, cache reads, and
  generation queue state.
- `ThemeExport.qml`: external target detection and apply/revert actions.

This separation prevents UI components from owning shell commands and prevents
external application theming from blocking shell recoloring.

## Data model

Add settings conservatively. Names below are proposed; final names should be
kept in sync between `SettingsSpec.js`, `harness/lib/settings-core.mjs`, and
`SettingsData.qml`.

Core source settings:

| key | type | default | notes |
|---|---:|---|---|
| `themeSource` | string | `"preset"` | enum: `"preset"`, `"wallpaper"`, `"hex"` |
| `themeId` | string | `"default"` | add `"dynamic"` only if keeping preset selector semantics |
| `themeWallpaperPath` | string | `""` | source for `themeSource: "wallpaper"` |
| `themeSourceColor` | string | `"#42a5f5"` | source for `themeSource: "hex"` |
| `matugenScheme` | string | `"scheme-tonal-spot"` | enum from matugen scheme list |
| `matugenContrast` | real | `0.0` | optional; pass only when non-zero |
| `dynamicPaletteCachePath` | string | `""` | optional diagnostic path, not user-facing |

System export settings:

| key | type | default | notes |
|---|---:|---|---|
| `systemThemeEnabled` | bool | `false` | master switch for external writes |
| `systemThemeApplyOnModeChange` | bool | `true` | rerun export when dark/light changes |
| `systemThemeApplyOnPaletteChange` | bool | `true` | rerun export when source/preset/accent changes |
| `systemThemePortalEnabled` | bool | `true` | set color-scheme through portal/gsettings if available |
| `systemThemeGtkEnabled` | bool | `false` | write GTK3/GTK4 CSS |
| `systemThemeQtEnabled` | bool | `false` | write qt5ct/qt6ct/KDE color scheme |
| `systemThemeNiriEnabled` | bool | `false` | write a niri color include fragment |
| `systemThemeTerminalEnabled` | bool | `false` | generate terminal theme files |
| `systemThemeEditorEnabled` | bool | `false` | generate editor theme files |
| `systemThemeBrowserEnabled` | bool | `false` | generate browser CSS/theme files |
| `systemThemeElectronEnabled` | bool | `false` | generate Vesktop/Vencord-style CSS files |
| `systemThemeUserTemplatesEnabled` | bool | `false` | future extension point |

Runtime-only service state:

- `matugenAvailable`
- `matugenVersion`
- `generationRunning`
- `generationPending`
- `lastGenerationStatus`
- `lastGenerationError`
- `lastAppliedMode`
- `lastAppliedPaletteHash`
- per-target: `available`, `enabled`, `managed`, `lastApplied`, `lastError`

Do not persist `Theme._autoLight` or the generated palette as the user's
preference. Persist source choices and cache generated output separately.

## Palette contract

The shell should keep its existing `Theme.colors` API stable. Dynamic color
generation should map matugen output into the same keys used by
`ThemePresets.js`:

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

Recommended matugen mapping:

| niri-strata key | matugen role |
|---|---|
| `background` | `background` |
| `surface` | `surface` |
| `layer0` | `surface_container_lowest` |
| `layer1` | `surface_container_low` |
| `layer1Hover` | derived blend of `surface_container` and `primary` |
| `layer1Active` | derived blend of `surface_container_high` and `primary` |
| `surfaceContainerLowest` | `surface_container_lowest` |
| `surfaceContainerLow` | `surface_container_low` |
| `surfaceContainer` | `surface_container` |
| `surfaceContainerHigh` | `surface_container_high` |
| `surfaceContainerHighest` | `surface_container_highest` |
| `text` | `on_surface` |
| `mutedText` | `on_surface_variant` |
| `subtleText` | derived alpha/blend from `on_surface_variant` |
| `primary` | `primary` |
| `primaryText` | `on_primary` |
| `primaryContainer` | `primary_container` |
| `primaryContainerText` | `on_primary_container` |
| `secondary` | `secondary` |
| `secondaryContainer` | `secondary_container` |
| `secondaryContainerText` | `on_secondary_container` |
| `tertiary` | `tertiary` |
| `tertiaryContainer` | `tertiary_container` |
| `tertiaryContainerText` | `on_tertiary_container` |
| `errorColor` | `error` |
| `errorContainer` | `error_container` |
| `outline` | `outline` |
| `outlineVariant` | `outline_variant` |

For built-in presets, keep the current palette table as the source of truth.
If system export is enabled for a built-in preset, generate export templates
from the resolved `Theme.colors` palette, not from a separate preset format.
This avoids the DMS problem where shell colors and exported colors can drift.

## Target coverage matrix

Phase the targets by risk and blast radius.

| target | phase | write path | apply style | notes |
|---|---:|---|---|---|
| Shell UI | 1 | none | live QML binding | must remain fastest path |
| Portal/gsettings | 2 | DBus/gsettings | command action | color-scheme only; no palette |
| GTK3 | 3 | `~/.config/gtk-3.0/niri-strata-colors.css` | managed `gtk.css` symlink or import | backup existing `gtk.css` |
| GTK4/libadwaita | 3 | `~/.config/gtk-4.0/niri-strata-colors.css` | marker import block | do not replace whole user file |
| Qt5/Qt6 ct | 3 | `~/.config/qt5ct/colors/niri-strata.conf`, `~/.config/qt6ct/colors/niri-strata.conf` | update `[Appearance]` keys | only when qt5ct/qt6ct exists |
| KDE color scheme | 3 | `~/.local/share/color-schemes/NiriStrata.colors` | referenced by qtct configs | useful even without KDE session |
| niri | 4 | `~/.config/niri/strata/colors.kdl` | include fragment | separate from existing layout fragment |
| Kitty | 5 | `~/.config/kitty/niri-strata-theme.conf` | include hint | do not edit `kitty.conf` by default |
| Foot | 5 | `~/.config/foot/niri-strata.ini` | include hint | direct include varies by user |
| Alacritty | 5 | `~/.config/alacritty/niri-strata.toml` | import hint | do not mutate main config by default |
| Ghostty | 5 | `~/.config/ghostty/themes/niri-strata` | theme file | user selects/imports |
| WezTerm | 5 | `~/.config/wezterm/niri-strata-theme.lua` | require hint | do not rewrite user Lua |
| Neovim | 6 | `~/.config/nvim/lua/niri_strata_theme.lua` | opt-in require | safe generated module |
| VS Code / VSCodium | 6 | extension/theme JSON under user dir | manual select | avoid extension packaging initially |
| Zed | 6 | `~/.config/zed/themes/niri-strata.json` | user selects | plain JSON |
| Firefox / Zen | 7 | generated `userChrome.css` include or CSS file | marker block only | high user-file risk |
| Vesktop/Vencord | 7 | generated CSS file | app-specific import | low priority |
| Flatpak variants | 8 | corresponding `~/.var/app/.../config` paths | target-specific | opt-in and separately tested |

Default toggles should enable only shell UI and the already-existing auto
light/dark state. External writes are opt-in.

## Phase 0: documentation and compatibility map

Tasks:

- Update `docs/features/08-theme-system.md` to reflect the current
  `auto-theme-state.json` architecture.
- Add a compatibility map in `docs/harness` listing required commands,
  optional commands, and expected degraded behavior.
- Identify available binaries using array-shaped probes:
  `matugen`, `gsettings`, `busctl` or `gdbus`, `qt5ct`, `qt6ct`, `niri`,
  terminal/editor/browser commands.
- Decide exact naming for generated files: use `niri-strata-*`, not `dank-*`.

Acceptance:

- Harness docs describe daemon, bridge, theme engine, and export service as
  separate layers.
- No implementation phase depends on a DMS binary or Go service.
- Missing optional tools degrade to disabled target state, not shell failure.

## Phase 1: palette engine for shell-only dynamic themes

Goal:

Add dynamic color generation without touching external applications.

Tasks:

- Add `harness/lib/theme-core.mjs` with pure helpers:
  - build matugen command arrays
  - parse matugen JSON
  - map Material roles into niri-strata palette keys
  - validate palette completeness
  - calculate a stable palette hash
- Add `harness/theme-core.test.mjs` with fixtures for dark/light matugen JSON.
- Add `modules/services/ThemeEngine.qml`:
  - probes `matugen`
  - owns generation state
  - debounces generation requests
  - keeps one current process and one pending request
  - exposes `generatedPalette`
- Extend `Theme.qml`:
  - use generated palette only when dynamic source is active and complete
  - fall back to current preset palette on missing matugen, bad JSON, or empty
    wallpaper/source color
- Extend settings schema:
  - source type
  - wallpaper path
  - hex source color
  - matugen scheme
  - contrast
- Extend `AppearanceTab.qml` with dynamic source controls.

Acceptance:

- Shell colors update live from a valid generated palette.
- Invalid dynamic input never blanks `Theme.colors`.
- Built-in presets still work without `matugen`.
- `npm run harness` covers parser, mapping, fallback, and QML wiring.

## Phase 2: mode-change orchestration

Goal:

Make manual light/dark changes and auto mode changes trigger palette
regeneration and optional system export consistently.

Tasks:

- Define a single `Theme.requestRefresh(reason)` entry point or equivalent.
- Trigger refresh on:
  - `themeMode` changes
  - `Theme._autoLight` changes
  - `themeId` changes
  - `accentColor` changes
  - dynamic source path/color/scheme/contrast changes
- Keep a short debounce, around 100-250 ms, before generation/export.
- Keep generation and export separate:
  - generation updates shell palette/cache
  - export writes external target files
- Add a status object that distinguishes:
  - `idle`
  - `generating`
  - `generated`
  - `exporting`
  - `partial`
  - `failed`

Acceptance:

- `echo -n dark > auto-theme-state.json` changes shell mode first, then queues
  dynamic generation if needed.
- Repeated setting changes coalesce into one generation.
- A slow generation does not block shell UI.
- A newer pending request replaces an older pending request.

## Phase 3: GTK and Qt export

Goal:

Cover the largest share of desktop apps with safe, idempotent file writes.

Implementation boundary:

- Prefer a Node renderer for testability: `scripts/theme-render.mjs`.
- Keep apply scripts small:
  - `scripts/theme-apply-gtk.sh`
  - `scripts/theme-apply-qt.sh`
- Use temporary directories and atomic rename for generated CSS/conf files.
- Use marker comments for edits inside existing files.

GTK output:

- `~/.config/gtk-3.0/niri-strata-colors.css`
- `~/.config/gtk-4.0/niri-strata-colors.css`
- GTK3 apply mode:
  - if `gtk.css` is missing, create a symlink or file import
  - if `gtk.css` is already a niri-strata-managed symlink, update it
  - if `gtk.css` exists and is user-managed, create timestamp backup before
    replacing only when user confirms/enables destructive apply
  - otherwise insert a marker import block
- GTK4 apply mode:
  - insert marker import at the top
  - do not replace the full file

Qt output:

- `~/.config/qt5ct/colors/niri-strata.conf`
- `~/.config/qt6ct/colors/niri-strata.conf`
- `~/.local/share/color-schemes/NiriStrata.colors`
- update `qt5ct.conf` and `qt6ct.conf` `[Appearance]` with:
  - `custom_palette=true`
  - `color_scheme_path=<generated scheme>`

Acceptance:

- Running apply twice is a no-op except for updated generated content.
- Existing user `gtk.css` is never silently destroyed.
- Scripts can run against a temp `HOME`/`XDG_CONFIG_HOME` in tests.
- Missing `qt5ct` disables Qt5 apply but does not block Qt6 apply.
- Missing both `qt5ct` and `qt6ct` reports a target-level error, not a global
  failure.

## Phase 4: portal, gsettings, and niri colors

Goal:

Synchronize platform-level light/dark preference and niri accent colors.

Portal/gsettings:

- Probe `gsettings`.
- Set `org.gnome.desktop.interface color-scheme` to:
  - `prefer-dark` when dark
  - `default` when light
- Optionally set `gtk-theme` only if the user enables it and a known theme is
  installed. Do not assume `adw-gtk3` exists.
- Treat DBus portal integration as a later improvement unless a reliable local
  API is already available.

niri:

- Generate `~/.config/niri/strata/colors.kdl`.
- Keep it separate from `strata/layout.kdl`.
- Add a settings UI status if `config.kdl` does not include the colors file.
- Do not change user `config.kdl` automatically unless the existing NiriTab
  include workflow is extended with explicit confirmation.

Acceptance:

- Light/dark preference is set without writing unrelated settings.
- niri colors file contains focus ring, border, shadow, tab indicator, and
  insert hint colors.
- Missing niri include is reported as "generated but inactive".

## Phase 5: terminal themes

Goal:

Generate terminal theme files while leaving user main config files alone.

Targets:

- Kitty
- Foot
- Alacritty
- Ghostty
- WezTerm

Tasks:

- Add terminal renderers in `theme-core.mjs`.
- Add per-target generated paths.
- Add Appearance/Services status showing the exact include/import line users
  need for terminals that cannot be safely auto-edited.
- Optionally add an "install include" action later, guarded per terminal.

Acceptance:

- Theme files render from the same palette contract.
- Generated files contain both ANSI 16 colors and UI foreground/background.
- Main terminal configs are not modified in Phase 5.
- Tests cover every renderer with a fixture palette.

## Phase 6: editor themes

Goal:

Support common editor surfaces through generated theme files.

Targets:

- Neovim Lua module
- VS Code/VSCodium JSON theme
- Zed JSON theme
- Emacs theme file if worth the maintenance cost

Tasks:

- Start with generated files only.
- Avoid packaging a VS Code extension in the first pass; write a valid JSON
  theme file and document manual installation/selection.
- Keep editor toggles disabled by default.

Acceptance:

- Generated files are syntactically valid.
- No editor process is restarted by niri-strata.
- The UI reports "generated" vs "active unknown" honestly.

## Phase 7: browser and Electron CSS targets

Goal:

Support high-demand CSS-based apps without taking ownership of large user CSS
files.

Targets:

- Firefox `userChrome.css`
- Zen Browser `userChrome.css`
- Pywalfox-compatible JSON if useful
- Vesktop/Vencord CSS

Rules:

- Use generated CSS files plus a marker import block.
- Never overwrite a non-managed `userChrome.css`.
- Show a warning that browser CSS may require profile-specific paths and app
  restart.
- Treat Flatpak profile paths as separate target variants.

Acceptance:

- CSS renderers are tested as pure string output.
- Apply scripts modify only marker blocks.
- Missing profiles are a disabled/unconfigured state, not an error.

## Phase 8: user templates and advanced app coverage

Goal:

Allow advanced users to add custom templates after core targets are stable.

Tasks:

- Define a minimal template manifest:
  - id
  - enabled
  - input template
  - output path
  - required command
  - optional post-apply command
- Render with the same palette JSON used by built-in targets.
- Validate paths to avoid accidental writes outside allowed config/data roots
  unless explicitly marked as advanced.

Acceptance:

- User templates are opt-in.
- Bad custom templates cannot crash the shell.
- Errors are per-template.

## Harness plan

Add `harness/lib/theme-core.mjs` for pure logic:

- `normalizePalette(input)`
- `mapMatugenColors(matugenJson, mode)`
- `validatePalette(palette)`
- `paletteHash(palette)`
- `buildMatugenCommand(options)`
- `buildTargetModel(tools, settings)`
- `renderGtkCss(palette, mode)`
- `renderQtColorScheme(palette, mode)`
- `renderNiriKdl(palette)`
- terminal/editor/browser render helpers as phases land

Add `harness/theme-core.test.mjs`:

- maps Material roles to all required `Theme.colors` keys
- rejects incomplete generated palettes
- preserves built-in preset fallback behavior
- builds array-shaped commands without shell interpolation
- derives target availability from tool probes
- renders GTK CSS with expected `@define-color` variables
- renders Qt color scheme with expected sections
- renders niri KDL with focus-ring/border colors
- verifies marker block insertion/removal helpers

Extend `harness/settings-core.test.mjs`:

- new settings defaults exist
- enums reject unsupported target/source values
- booleans coerce correctly
- paths remain strings and are not executed by core helpers

Extend `harness/settings-structure.test.mjs`:

- `shell.qml` instantiates `ThemeEngine` and `ThemeExport`
- `Theme.qml` keeps the existing `Theme.colors` contract
- `AppearanceTab.qml` owns controls only, not shell commands
- export service owns scripts/process calls
- target status is visible in settings

Script tests:

- Run apply scripts against temporary `HOME`, `XDG_CONFIG_HOME`, and
  `XDG_DATA_HOME`.
- Verify no writes escape the temp roots.
- Verify repeat apply is idempotent.
- Verify user-managed files are backed up or marker-edited, never silently
  replaced.

Manual smoke:

- Start shell with `themeMode: "dark"` and `themeMode: "light"`.
- Start shell with `themeMode: "auto"` and modify `auto-theme-state.json`.
- Generate dynamic palette from wallpaper.
- Export GTK/Qt in a temp profile first.
- Export GTK/Qt to real config after confirming backup behavior.
- Restart one GTK3, one GTK4, one Qt5/6 app and inspect colors.

## UI plan

Appearance tab should stay compact but complete:

- Source section:
  - preset / wallpaper / hex segmented control
  - preset selector
  - wallpaper path input
  - source hex input
  - matugen scheme selector
  - contrast control
  - generate button and status
- Mode section:
  - dark / light / auto
  - time/sun controls when auto is selected
  - current resolved mode indicator
- System theme section:
  - master toggle
  - apply-on-mode-change toggle
  - target rows for Portal, GTK, Qt, niri, Terminals, Editors, Browsers,
    Electron
  - each row shows available/enabled/managed/error state
  - "Apply now" and "Revert managed files" actions where safe

Services tab can show dependency availability:

- matugen
- gsettings
- qt5ct
- qt6ct
- niri
- target app commands discovered by probes

Avoid visible instructional copy inside the main UI where possible. Use compact
status labels and target rows; keep detailed include snippets in docs or an
expandable diagnostic panel.

## Safety rules

- External writes are opt-in.
- Generated files use `niri-strata` names.
- Existing user files are changed only through:
  - a managed symlink already owned by niri-strata
  - a marker block
  - an explicit backup-and-replace action
- Every apply action has a target-level revert plan.
- No script should use unquoted paths.
- QML should pass command arrays where Quickshell supports them.
- Any shell script should accept explicit root paths for tests:
  - `--config-dir`
  - `--data-dir`
  - `--cache-dir`
  - `--shell-dir`
- Theme generation failures never blank the live shell palette.

## Rollout order

1. Correct docs for the current daemon/bridge model.
2. Add pure theme harness helpers and fixtures.
3. Add `ThemeEngine.qml` for shell-only dynamic palettes.
4. Wire dynamic source settings into `Theme.qml` and `AppearanceTab.qml`.
5. Add `ThemeExport.qml` target model with probes and disabled states.
6. Implement GTK/Qt renderers and apply scripts with temp-root tests.
7. Add portal/gsettings and niri color fragment support.
8. Add terminal generated files.
9. Add editor generated files.
10. Add browser/Electron CSS targets.
11. Add user templates.
12. Update `docs/features/08-theme-system.md` and `docs/ROADMAP.md` after each
    completed milestone.

## Risks

- matugen CLI output can differ by version. Mitigate with version probe,
  fixtures, and fallback to presets.
- GTK theming can break user CSS. Mitigate with marker blocks, backups, and
  opt-in target toggles.
- Qt theme behavior depends on `QT_QPA_PLATFORMTHEME`, `qt5ct`, and `qt6ct`.
  Mitigate by reporting "generated" separately from "active".
- Browser profile paths are messy. Mitigate by making browser targets later and
  profile-specific.
- Auto mode can trigger too many exports. Mitigate with palette hash checks and
  debounce.
- Full app coverage can become maintenance-heavy. Mitigate with target phases
  and user-template support.

## Open questions

- None for the initial plan. The three policy choices above are now fixed as
  design decisions.
