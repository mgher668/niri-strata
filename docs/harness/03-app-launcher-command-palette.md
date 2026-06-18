# Harness phases: app launcher and command palette

## Target

Add a keyboard-first launcher overlay that searches apps and shell commands.

## Phase 0: compatibility map

Identify the first application source:

- Primary: Quickshell `DesktopEntries.applications`.
- Fallback: `.desktop` file parser command.

Acceptance:

- Harness documents Quickshell `DesktopEntry` fields used by the launcher.
- Missing app source still allows shell command results.

## Phase 1: app parser and ranking

Add `harness/lib/launcher-core.mjs`.

Test:

- normalization from Quickshell `DesktopEntry` objects
- fallback desktop entry parsing
- hidden/no-display filtering
- name/comment/keyword matching
- deterministic ranking
- duplicate app IDs

Acceptance:

- Empty query returns a useful default list.
- Exact name match outranks fuzzy keyword match.
- Hidden apps are excluded unless explicitly allowed by policy.

## Phase 2: command registry

Add a command palette registry in harness.

Initial commands:

- open control center
- lock
- screenshot
- record
- power actions with confirmation metadata

Acceptance:

- Commands have stable IDs, labels, icons, keywords, and action IDs.
- Destructive or session-ending commands carry confirmation metadata.
- Search can mix app and command results deterministically.

## Phase 3: QML service boundary

Add:

- `modules/services/AppSearch.qml`
- `modules/services/CommandPalette.qml`

Acceptance:

- Services expose query, results, selected index, and execute action.
- UI does not directly parse `.desktop` files.
- Commands route through existing services where possible.

## Phase 4: overlay UI

Add a launcher overlay.

Acceptance:

- Harness confirms overlay is wired from shell.
- Harness confirms search input receives focus.
- Harness confirms Escape closes the overlay.
- Harness confirms Enter executes selected result.
- Missing app backend still renders command results.

## Phase 5: manual smoke

Status: Not completed. Automated harness coverage is in place; real overlay launch and app execution still need a compositor smoke pass.

Manual checks:

- Open and close launcher.
- Launch a desktop app.
- Run shell command action.
- Navigate with keyboard.
- Confirm unavailable app backend fallback if possible.

## Phase 6: completion polish

Status: Partially implemented. Confirmation UI, session-local recent/pinned
results, initials/subsequence fuzzy matching, uncapped result lists, app search
cache prewarming, and fast keyboard-navigation selection are covered by harness
or QML structure tests. Keybinding, persistence, and compositor smoke remain.

Target:

- Turn the implemented launcher into a finished daily-use command surface.

Test:

- niri config or documented shell binding opens the launcher through
  `quickshell ipc call launcher toggle`.
- Application rows render `DesktopEntry.icon` through Quickshell icon
  resolution, with a tested fallback.
- Confirmation metadata is visible in rows for logout, suspend, reboot, and
  shutdown.
- Confirmation-gated commands require an explicit second action before running.
- Abbreviation matching ranks common short queries deterministically.
- Search returns every matching result by default, sorted by score, rather than
  truncating to a fixed count.
- App search caches normalized desktop entries and refreshes when the
  Quickshell desktop entry model changes.
- Fast keyboard navigation moves selection and scroll position immediately,
  while preserving row animations outside the keyboard repeat path.
- Empty query can include recent or pinned apps once persistence exists.

Acceptance:

- A user can open the launcher from a normal keybinding without knowing the IPC
  command.
- Destructive/session-ending commands cannot be triggered accidentally from one
  Enter press.
- App rows use real icons when the theme resolves them and degrade cleanly when
  it does not.
- Future integrations can add clipboard, screenshot, settings, emoji,
  calculator, or web/search items without bypassing the command registry.

## Phase 7: external app index and full-result search

Status: Planned. This phase moves application indexing and heavy search work
out of the Quickshell/QML hot path while preserving the current launcher UI and
uncapped result behavior.

Target:

- Add a launcher helper that scans XDG `.desktop` application directories,
  builds a persistent JSON cache, and can return every matching application in
  ranked order.
- Keep QML responsible for rendering and command-palette state only; QML should
  not synchronously scan desktop entries, normalize every app, or sort every
  app result during pointer/keyboard interaction.
- Keep `DesktopEntries.applications` as a compatibility fallback until the
  helper path is stable.

Test:

- Desktop entry parser covers `Name`, `GenericName`, `Comment`, `Icon`, `Exec`,
  `Path`, `Terminal`, `Categories`, `Keywords`, `NoDisplay`, and duplicate IDs.
- Cache generation writes a stable schema with precomputed lowercase, compact,
  initials, and combined search fields.
- Search returns all matching applications in deterministic ranked order, not a
  fixed top-N subset.
- Empty-query search returns all visible applications in deterministic default
  order, with pinned/recent command-palette adjustments applied afterward.
- Directory watch/rescan logic debounces changes and continues serving the last
  good cache while a rescan is running.
- QML service tests confirm `AppSearch` consumes helper/cache data and no longer
  depends on `DesktopEntries` for the primary search path.

Acceptance:

- The launcher opens immediately with the last good cache, even if an app
  directory rescan is pending.
- Search can display every matching result in the overlay scroll view without
  freezing quickshell input, pointer movement, or niri workspace updates.
- A failed or missing helper degrades to command results and, when available,
  the legacy `DesktopEntries` fallback instead of crashing the shell.
- Manual smoke confirms open, close, type-to-search, full result scrolling,
  app launch, helper restart, and app directory rescan behavior.
