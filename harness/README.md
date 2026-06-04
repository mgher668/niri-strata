# niri-strata harness

This harness validates niri data rules before they are wired into QML.

It intentionally runs outside Quickshell so the risky parts can be tested quickly:

- normalize raw `niri msg --json` data into stable camelCase fields.
- sort workspaces by `output` and `idx`.
- calculate occupied workspace state from `activeWindowId` and window membership.
- generate CLI fallback actions without guessing unsupported niri flags.

Run:

```sh
npm run harness
```

or:

```sh
node --test harness/*.test.mjs
```

The `fixtures/live` files are sanitized niri-shaped samples. They include out-of-order workspace data so the sorting rule is covered by a realistic example without publishing local window titles or paths.
