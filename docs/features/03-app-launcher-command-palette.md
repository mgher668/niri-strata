# App launcher and command palette

## Goal

Add a fast overlay for launching applications and running shell-provided commands. It should be keyboard-first, niri-native, and reusable for future utilities like clipboard search, emoji, screenshot actions, and settings navigation.

## Product decision

Start as a command palette rather than a decorative start menu. Keep it compact, searchable, and action-oriented.

Current implementation status:

- Core search, ranking, command registry, overlay wiring, and automated harness
  coverage are implemented.
- Real compositor smoke is still pending.
- The launcher currently opens through the `launcher` IPC target. A niri keybind
  should be added before considering the feature fully finished.
- Application rows use `DesktopEntry.icon` through Quickshell icon resolution,
  with a fallback icon when the active theme cannot resolve an app icon.
- Empty-query results include session-local pinned and recent items. Pinned
  state is editable from the row pin control and currently lasts until the shell
  restarts.
- Search supports exact, prefix, contains, initials, and subsequence fuzzy
  matching.
- Confirmation-required commands show a row affordance and require a second
  activation before execution.
- Result lists are not capped by the search model. All matches are returned in
  ranked order and the overlay scroll view handles overflow.
- Application search prewarms and caches normalized desktop entries on service
  startup, then refreshes when the `DesktopEntries` model changes.
- Keyboard navigation is optimized for high repeat rates: selection changes are
  immediate during rapid up/down navigation, while normal hover/transition
  animation remains available outside that path.

Planned performance direction:

- Keep the Quickshell launcher UI and command palette behavior, but move
  application indexing and heavy search work out of the QML hot path.
- Build an external launcher index/search helper that scans `.desktop` files,
  writes a persistent JSON cache, watches XDG application directories with
  debounce, and serves the last good cache while a rescan is in progress.
- Preserve uncapped result semantics: application search should compute and
  return every matching result in ranked order, while the QML `ListView` handles
  overflow and only instantiates visible rows.
- Treat `DesktopEntries.applications` as a compatibility fallback rather than
  the preferred daily-use backend once the external cache is available.

Initial groups:

- Applications
- Shell commands
- Session actions
- Capture actions
- Settings entries, after Settings UI exists

Future groups:

- Clipboard history
- Emoji
- Calculator
- Web/search shortcuts

## User flows

### Launch app

1. User triggers launcher.
2. Search field receives focus.
3. User types app name.
4. Results rank desktop apps first.
5. Enter launches the selected app.
6. Overlay closes.

### Run command

1. User triggers launcher.
2. User types command alias, such as `record`, `lock`, or `settings`.
3. Palette shows matching shell actions.
4. Enter runs the selected action.

## State model

Recommended service split:

- `modules/services/AppSearch.qml`
- `modules/services/CommandPalette.qml`

Recommended item fields:

- `id`
- `type`
- `title`
- `subtitle`
- `icon`
- `keywords`
- `score`
- `command`
- `actionId`

## Backend requirements

The initial implementation can use Quickshell's `DesktopEntries.applications`
model. The installed Quickshell exposes `DesktopEntry` fields for `id`, `name`,
`genericName`, `comment`, `icon`, `command`, `workingDirectory`,
`runInTerminal`, `categories`, `keywords`, `actions`, and `noDisplay`, which are
enough for the first launcher model.

For the performance-oriented implementation, prefer a parser-backed external
helper that reads `.desktop` files directly, precomputes normalized search
fields, and returns complete ranked result sets to QML. Quickshell's
`DesktopEntries` model should remain available as a fallback if the helper is
missing or returns no cache.

Command palette actions should call service actions instead of embedding raw shell strings in UI rows.

## UI placement

Use a centered overlay or top command bar. It should not live inside the right sidebar because launchers need direct keyboard focus and quick dismissal.

Possible components:

- `modules/launcher/Launcher.qml`
- `modules/launcher/SearchResultRow.qml`
- `modules/services/CommandPalette.qml`
- `harness/lib/launcher-core.mjs`

## Acceptance criteria

- Overlay opens and focuses search input.
- Application results are searchable and ranked.
- Application results show real desktop entry icons when available.
- Shell actions are searchable and executable.
- Empty query shows a useful default list.
- Escape closes the overlay.
- A niri keybind can open the launcher without typing an IPC command.
- Destructive/session-ending commands show confirmation affordances before execution.
- Missing app backend degrades to shell actions rather than crashing.
- `npm run harness` passes.

## Follow-up optimizations

### Completion blockers

- Add a first-class niri keybinding, likely `Mod+Space` or `Mod+D`, that runs
  `quickshell ipc call launcher toggle`.
- Complete manual smoke for open/close, keyboard navigation, application launch,
  command execution, and focused-output placement.

### Search and result quality

- Add better fallback icons by app category, such as terminal, browser,
  settings, files, and media, before falling back to the generic app icon.
- Show `.desktop` actions as secondary results where useful, such as browser
  new-window or private-window actions.

### Future integrations

- Persist recent and pinned applications once the settings storage path exists.
- Add explicit handling for desktop entries that require `runInTerminal`, since
  Quickshell's `DesktopEntry.execute()` does not cover every terminal wrapping
  case.
- Reuse the palette model for clipboard history, screenshot actions, settings
  navigation, emoji, calculator, and web/search shortcuts.

## Harness plan

Detailed harness phases live in [../harness/03-app-launcher-command-palette.md](../harness/03-app-launcher-command-palette.md).
