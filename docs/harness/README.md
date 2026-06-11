# Harness planning

## Purpose

This directory describes how feature work should be validated before it is wired deeply into QML. The current project harness is a Node-based test suite that validates data normalization, command construction, and QML architecture invariants.

Run:

```sh
npm run harness
```

The package script is the source of truth for local validation. It must run
every `harness/*.test.mjs` file so new feature-specific tests cannot be missed.
When a feature adds `harness/lib/<feature>-core.mjs`, add either a matching
`harness/<feature>-core.test.mjs` file or extend an existing test file before
QML wiring.

## Best practices

- Write parser and command-builder tests before adding service UI.
- Prefer array-shaped commands in helpers where possible.
- Keep complex shell construction in one service/helper boundary.
- Add fixtures only when they are sanitized and stable.
- Never store secrets, clipboard contents, window titles, or local paths in fixtures unless sanitized.
- Test unavailable, available, and degraded states.
- Add QML text-structure assertions for critical wiring that Node cannot execute.
- Do not import `Quickshell.Hyprland` in niri-specific modules.
- Keep UI widgets bound to services; do not build raw commands inside repeated item delegates.

## Phase pattern

Most features should follow this order:

1. **Compatibility map**: identify required commands, optional commands, and fallback behavior.
2. **Core harness helpers**: add parsers, command builders, reducers, and fixtures.
3. **Service boundary**: add or extend a QML service with normalized state and explicit actions.
4. **UI wiring**: add components that bind to services, including disabled states.
5. **Behavior checks**: add QML structure tests for entry points, unavailable states, and command ownership.
6. **Manual smoke**: run the real action and document the observed behavior when needed.

## Feature phase docs

- [Recording enhancements](01-recording-enhancements.md)
- [Clipboard history](02-clipboard-history.md)
- [App launcher / command palette](03-app-launcher-command-palette.md)
- [Enhanced screenshot tooling](04-screenshot-tooling.md)
