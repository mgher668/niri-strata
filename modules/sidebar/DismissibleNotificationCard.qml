import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var notification
    property var service: null
    property int bodyLineCount: 3
    property int cardRadius: Theme.rounding.md
    property int minimumCardHeight: 76
    property bool dismissing: false
    property bool dragMoved: false
    readonly property int dismissThreshold: Math.min(124, Math.max(72, width * 0.34))
    readonly property string bodyText: notification.body || ""
    readonly property int clickDragTolerance: 6
    readonly property var notificationActions: notification.actions ?? []
    readonly property bool hasActions: notification.hasActions ?? notificationActions.length > 0

    signal dismissed()

    implicitWidth: 360
    implicitHeight: Math.max(minimumCardHeight, cardContent.implicitHeight + Theme.spacing.lg * 2)

    function requestDismiss(animated) {
        if (dismissing)
            return;

        dismissing = true;
        if (animated) {
            card.x = width;
            dismissTimer.start();
        } else {
            dismissed();
        }
    }

    function settleSwipe() {
        if (card.x >= dismissThreshold) {
            requestDismiss(true);
        } else {
            card.x = 0;
        }
    }

    Timer {
        id: dismissTimer

        interval: Theme.animation.normal
        repeat: false
        onTriggered: root.dismissed()
    }

    Rectangle {
        id: card

        width: parent.width
        height: parent.height
        radius: root.cardRadius
        color: root.notification.urgency === "critical" ? Theme.colors.errorContainer : Theme.colors.surfaceContainerLow
        border.width: Theme.elevation.outlineWidth
        border.color: root.notification.urgency === "critical" ? Theme.colors.errorColor : Theme.colors.outlineVariant
        layer.enabled: dragArea.pressed || x > 0

        Behavior on x {
            enabled: !dragArea.drag.active

            NumberAnimation {
                duration: Theme.animation.normal
                easing.type: Theme.animation.emphasized
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            hoverEnabled: true
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: root.width * 0.58
            onPressed: root.dragMoved = false
            onPositionChanged: {
                if (Math.abs(card.x) > root.clickDragTolerance)
                    root.dragMoved = true;
            }
            onReleased: {
                if (root.dragMoved)
                    root.settleSwipe();
            }
            onClicked: {
                if (!root.dragMoved)
                    root.requestDismiss(false);
            }
            onCanceled: card.x = 0
        }

        ColumnLayout {
            id: cardContent

            anchors {
                fill: parent
                margins: Theme.spacing.lg
            }
            spacing: Theme.spacing.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.md

                NotificationAppIcon {
                    Layout.alignment: Qt.AlignVCenter
                    size: 34
                    appIcon: root.notification.appIcon
                    image: root.notification.image
                    summary: root.notification.summary
                    urgency: root.notification.urgency
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notification.appName
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.mutedText
                    elide: Text.ElideRight
                }

                IconButton {
                    size: 28
                    icon: "close"
                    label: "Dismiss"
                    iconSize: 16
                    onClicked: root.requestDismiss(false)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification.summary
                font.pixelSize: Theme.font.md
                font.weight: Font.DemiBold
                color: Theme.colors.text
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.bodyText.length > 0
                text: root.bodyText
                wrapMode: Text.WordWrap
                maximumLineCount: root.bodyLineCount
                elide: Text.ElideRight
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.hasActions
                spacing: Theme.spacing.sm

                Repeater {
                    model: root.notificationActions

                    ActionChip {
                        required property var modelData

                        text: modelData.text
                        minWidth: 84
                        icon: "touch_app"
                        active: true
                        enabled: root.service !== null
                        onTriggered: root.service.invokeNotificationAction(root.notification.notificationId, modelData.identifier)
                    }
                }
            }
        }
    }
}
