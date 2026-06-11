# Harness phases: clipboard history

## Target

Add a clipboard history panel backed by `cliphist` and `wl-clipboard`.

## Phase 0: compatibility map

Probe:

- `cliphist`
- `wl-copy`
- `wl-paste`

Acceptance:

- Harness maps probe output to `available`, `watchAvailable`, and `restoreAvailable`.
- Missing `cliphist` disables the panel.
- Missing `wl-paste` disables shell-managed collection but still allows listing
  existing history when `cliphist` exists.
- Missing `wl-copy` disables restore actions.

Lifecycle decision:

- `modules/services/Clipboard.qml` owns a long-lived watcher process:
  `wl-paste --watch cliphist store`.
- Start the watcher when the service is available and the shell starts.
- Restart the watcher after an unexpected exit with a short backoff.
- Do not start more than one watcher from this shell instance.
- Manual user/systemd-managed watchers are not required for the first version.
- The panel remains usable for existing `cliphist list` data if watcher startup
  fails, but it shows collection as unavailable or degraded.

## Phase 1: list parsing

Add `harness/lib/clipboard-core.mjs`.

Test parsing of representative `cliphist list` lines:

- plain text
- multiline text preview
- image marker
- binary/unknown marker
- duplicate-looking entries with distinct IDs

Acceptance:

- Parser returns stable IDs and display previews.
- Parser does not decode secrets in tests.
- Empty history produces an empty model, not an error.

## Phase 2: command builders

Add builders for:

- list history
- decode item to clipboard
- clear history
- watcher command and restart/degraded-state decisions

Acceptance:

- Restore command uses `cliphist decode | wl-copy`.
- Clear command is separate and can be confirmation-gated.
- Commands are not built in item delegates.
- Watcher command construction is covered without storing clipboard contents in
  fixtures.

## Phase 3: QML service boundary

Add `modules/services/Clipboard.qml`.

Acceptance:

- Service exposes `available`, `items`, `query`, `busy`, `lastError`.
- Service exposes watcher state such as `watchAvailable`, `watching`, and
  `watchLastError`.
- Service has explicit `refresh`, `restore`, `clear`, `startWatcher`, and
  `stopWatcher` actions.
- UI can show unavailable and empty states.

## Phase 4: UI wiring

Add `modules/sidebar/ClipboardPanel.qml`.

Acceptance:

- Harness confirms sidebar imports/wires the panel.
- Harness confirms rows call service actions instead of raw shell commands.
- Search query filters or highlights items.
- Clear action requires confirmation.

## Phase 5: manual smoke

Manual checks:

- Copy text, refresh panel, restore it.
- Copy image, verify image entry appears.
- Clear history after confirmation.
- Stop the watcher process and confirm the service restarts it or shows degraded
  collection state.
- Remove or hide `wl-paste` and confirm existing history can still be listed
  while collection is disabled.
