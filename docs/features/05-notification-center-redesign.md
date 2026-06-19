# Notification center redesign

## Goal

Redesign the notification center so it can handle long-running sessions and
notification floods without making Control Center animation or scrolling feel
heavy. The target behavior should match the useful parts of
`dots-hyprland`: grouped notifications, virtualized lists, collapsed group
previews, and smooth interaction, while keeping the implementation niri-strata
native.

## Product decision

Use a staged vendor-and-port approach instead of copying selected QML files into
the current sidebar directly.

The `dots-hyprland` notification implementation is GPL-3.0 and depends on
its own UI framework (`Appearance`, `Config.options`, `Translation`,
`GlobalStates`, `StyledListView`, `DragManager`, and common widgets). Directly
mixing those files into the current MIT codebase would create licensing and
maintenance concerns. If copied code is used, keep it isolated under a clearly
marked vendor directory with license notices. Prefer porting the behavior into
the current `Theme`, `Config`, `SurfaceCard`, and `SectionHeader` system once
the interaction model is proven.

## Scope

- In: notification grouping by app, grouped list rendering, collapsed group
  previews, bounded notification history, smooth ListView scrolling, local test
  seeding, and harness coverage.
- Out: full dots-hyprland UI framework migration, notification persistence in
  the first native pass, Hyprland-specific globals, and wholesale theme
  replacement.

## Reference behavior

The dots-hyprland implementation does not render one card per notification in
the sidebar. It groups notifications first:

- `services/Notifications.qml` builds `groupsByAppName` and `appNameList`.
- `NotificationListView.qml` uses a ListView whose model is the app-name list.
- `NotificationGroup.qml` renders one app group.
- Collapsed groups show only the newest one or two notifications.
- Expanded groups reveal more notifications inside that group.

For a flood of Telegram notifications, this turns hundreds of messages into one
Telegram group instead of hundreds of visible cards.

## Target architecture

### Service state

Extend `modules/services/Notifications.qml` with derived grouped state:

- `groupsByAppName`
- `appNameList`
- `groupForApp(appName)`
- `maxHistoryCount`
- optional `maxHistoryPerApp`

Each group should expose:

- `appName`
- `appIcon`
- `latestTime`
- `count`
- `critical`
- `notifications`
- `previewNotifications`

### UI components

Add niri-strata-native components:

- `modules/sidebar/NotificationGroupCard.qml`
- optional `modules/sidebar/NotificationGroupList.qml`

Update:

- `modules/sidebar/NotificationCenter.qml`
- `modules/sidebar/DismissibleNotificationCard.qml` only if group rows need a
  smaller embedded preview variant.

The notification center should use a ListView with app groups as delegates. It
should not use `Repeater` for an unbounded notification history.

## Action items

[ ] Audit the current temporary ListView and debug notification seed in
`modules/sidebar/NotificationCenter.qml` and `modules/services/Notifications.qml`;
keep only the parts needed for testing.

[ ] Add grouping helpers to `modules/services/Notifications.qml`: compute
`groupsByAppName`, sorted `appNameList`, and preview slices from the existing
`notifications` list.

[ ] Add bounded history controls to `modules/services/Notifications.qml`, with
a default global cap and an optional per-app cap so long-running sessions cannot
grow without limit.

[ ] Create `modules/sidebar/NotificationGroupCard.qml` using current
niri-strata components and theme tokens. The collapsed state should show app
name, count, latest summary/body preview, urgency, and dismiss actions.

[ ] Replace `NotificationCenter.qml`'s direct notification model with a
`ListView` over `service.appNameList`, rendering `NotificationGroupCard`
delegates.

[ ] Implement group expansion without rendering every historical notification
by default. The first pass can show the newest two notifications collapsed and a
bounded expanded slice.

[ ] Keep the dots-hyprland source as a reference, not an inline dependency. If
any GPL code is copied, place it under a clearly marked vendor path and document
the license boundary before committing.

[ ] Add harness assertions that the notification center uses ListView, does not
use Repeater for the long history, exposes grouping state, and enforces history
caps.

[ ] Refresh generated QML graph output with `npm run graphify:qml` after QML
structure changes.

[ ] Validate with `npm run harness`, `git diff --check`, and a manual smoke with
300 seeded Telegram notifications: open/close Control Center, scroll the group
list, expand/collapse Telegram, dismiss one notification, and clear all.

## Risks and mitigations

- Nested scrolling can feel inconsistent. Prefer a single group ListView with a
bounded viewport and explicit wheel handling.
- Group expansion can accidentally reintroduce full rendering. Keep expanded
content bounded or use a second virtualized list if a group can be very large.
- GPL code reuse can affect distribution terms. Keep copied code isolated and
documented, or port behavior instead of copying implementation.
- Notification object lifetimes can grow across long sessions. Enforce caps in
the service, not only in the UI.

## Open questions

- Should the default global notification cap be 100, 200, or user-configurable?
- Should expanded groups show all notifications, a bounded slice, or open a
separate detail page?
- Should notification persistence be added after grouping, or remain out of
scope for now?
