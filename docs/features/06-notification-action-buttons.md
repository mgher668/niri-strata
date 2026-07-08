# Notification action buttons

## Goal

Add first-class support for interactive notifications, especially authorization
and confirmation notifications that expose actions such as Allow, Deny, Accept,
Reject, Confirm, or Cancel.

The implementation should follow the action handling pattern from
`dots-hyprland`: store lightweight action metadata in the notification
wrapper, render action buttons in the UI, and route clicks back through the
notification service so the live Quickshell notification action can be invoked.

## Product requirements

- Notifications with actions must visibly show their action buttons.
- Authorization-style notifications follow the same body-click dismissal rule as
  regular notifications.
- For notifications with actions, action button clicks must take precedence over
  body-click dismissal.
- Clicking an action button should invoke the underlying notification action and
  then dismiss the notification, unless a future notification-specific rule says
  otherwise.
- Regular notifications without actions may keep the existing single-click
  dismiss behavior.
- Drag-to-dismiss must not conflict with action buttons or the explicit close
  button.

## Reference behavior

The useful part of `dots-hyprland` is the action routing, not the visual
component framework.

Reference files:

- `dots-hyprland/dots/.config/quickshell/ii/services/Notifications.qml`
- `dots-hyprland/dots/.config/quickshell/ii/modules/common/widgets/NotificationItem.qml`
- `dots-hyprland/dots/.config/quickshell/ii/modules/common/widgets/NotificationActionButton.qml`

The service stores actions as plain metadata:

```qml
property list<var> actions: notification?.actions.map((action) => ({
    "identifier": action.identifier,
    "text": action.text,
})) ?? []
```

The UI renders those actions with a repeater. When a button is clicked, the UI
passes `notificationId` and `identifier` back to the service:

```qml
Notifications.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
```

The service then finds the live tracked notification, finds the matching action,
calls `action.invoke()`, and dismisses the notification.

## Target design

### Service

Update `modules/services/Notifications.qml`:

- Normalize `NotificationEntry.actions` into `{ identifier, text }` objects.
- Add `hasActions` to each entry.
- Add `invokeNotificationAction(notificationId, actionIdentifier)`.
- In `invokeNotificationAction`, find the live server notification from
  `notificationServer.trackedNotifications.values`.
- Find the matching action by `identifier`.
- Call `action.invoke()`.
- Dismiss the notification after successful invocation.
- Log a warning and keep the notification visible if the action cannot be found
  or invocation fails.

### UI

Update `modules/sidebar/NotificationGroupCard.qml`:

- Render an action row under any visible notification preview that has actions.
- Use compact `ActionChip`-style buttons or a dedicated
  `NotificationActionButton.qml` if the row needs more control.
- Keep action buttons above the row background click target so action clicks are
  not swallowed by click-to-dismiss.
- Keep whole-row click-to-dismiss enabled for notifications with actions.
- Ensure action buttons receive their own click events before the row background
  click target can dismiss the notification.
- Keep the explicit close icon available on action notifications.

Update `modules/sidebar/DismissibleNotificationCard.qml`:

- Render action buttons for popup notifications with actions.
- Keep body click-to-dismiss enabled when `notification.actions.length > 0`.
- Ensure action buttons receive their own click events before the card background
  click target can dismiss the notification.
- Keep drag-to-dismiss available, but only for intentional drag gestures.
- Keep the close icon as the explicit non-drag dismissal path.

### Interaction rules

For notifications without actions:

- Single-click card body dismisses.
- Close icon dismisses.
- Drag-to-dismiss works.

For notifications with actions:

- Card body click dismisses the notification.
- Action button click invokes that action.
- Close icon dismisses.
- Drag-to-dismiss works only after the drag movement threshold.
- Action buttons and close icon must not start a drag gesture.

## Action items

[ ] Add action metadata normalization to `NotificationEntry`.

[ ] Add `invokeNotificationAction(notificationId, actionIdentifier)` to
`modules/services/Notifications.qml`.

[ ] Add harness coverage that actions are normalized and invoked through the
service rather than directly from UI delegates.

[ ] Update `NotificationGroupCard.qml` to render action buttons for previewed
notifications with actions.

[ ] Update `DismissibleNotificationCard.qml` to render action buttons for popup
notifications with actions.

[ ] Keep click-to-dismiss behavior consistent for notifications with and without
actions.

[ ] Add harness coverage that action buttons invoke actions while body clicks
still dismiss action notifications.

[ ] Add a local debug seed case with a fake authorization notification carrying
two actions, such as Allow and Deny.

[ ] Validate with `npm run harness`, `git diff --check`, and a runtime smoke:
open Control Center, confirm action buttons render, click an action, click the
close icon, and verify ordinary no-action notifications still dismiss on body
click.

## Risks and mitigations

- Stored or restored notifications may not have live actions. Keep action
  invocation service-owned and only enable buttons when live action metadata is
  present.
- Body click-to-dismiss can accidentally close authorization prompts. This is an
  accepted consistency tradeoff; action buttons must still take click precedence
  over the background dismiss target.
- Action buttons can conflict with drag areas. Keep buttons visually and
  event-wise above background MouseAreas, and keep drag thresholds explicit.
- Some notification actions may be destructive. Do not invent labels or reorder
  actions beyond the order provided by the notification server.

## Open questions

- Should action notifications stay expanded automatically in grouped collapsed
  previews?
- Should invoked actions always dismiss the notification, or should dismissal be
  configurable later?
- Should debug seed include one authorization notification by default when
  `debugSeedNotifications` is enabled?
