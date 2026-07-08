import QtQuick
import QtQuick.Layouts
import "../common/"

Rectangle {
    id: root

    required property var service
    required property var notificationGroup
    property bool expanded: false

    readonly property var notifications: notificationGroup?.notifications ?? []
    readonly property int notificationCount: notificationGroup?.count ?? notifications.length
    readonly property bool critical: notificationGroup?.critical ?? false
    readonly property int collapsedCount: Math.max(1, service.previewCount ?? 2)
    readonly property int expandedCount: Math.max(collapsedCount, service.expandedPreviewCount ?? 8)
    readonly property int visibleCount: expanded ? Math.min(notificationCount, expandedCount) : Math.min(notificationCount, collapsedCount)
    readonly property var visibleNotifications: notifications.slice(0, visibleCount)
    readonly property bool canExpand: notificationCount > collapsedCount
    readonly property string appName: notificationGroup?.appName ?? "Application"
    readonly property string appIcon: notificationGroup?.appIcon ?? ""
    readonly property var latestNotification: notifications[0] ?? null
    readonly property string summaryText: latestNotification?.summary || appName
    readonly property string countText: notificationCount === 1 ? "1 notification" : `${notificationCount} notifications`

    implicitWidth: 360
    implicitHeight: cardContent.implicitHeight + Theme.spacing.lg * 2
    radius: Theme.rounding.md
    color: critical ? Theme.colors.errorContainer : Theme.colors.surfaceContainerLow
    border.width: Theme.elevation.outlineWidth
    border.color: critical ? Theme.colors.errorColor : Theme.colors.outlineVariant

    ColumnLayout {
        id: cardContent

        anchors {
            fill: parent
            margins: Theme.spacing.lg
        }
        spacing: Theme.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            NotificationAppIcon {
                Layout.alignment: Qt.AlignVCenter
                size: 36
                appIcon: root.appIcon
                image: root.latestNotification?.image ?? ""
                summary: root.summaryText
                urgency: root.critical ? "critical" : "normal"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.appName
                    font.pixelSize: Theme.font.md
                    font.weight: Font.DemiBold
                    color: root.critical ? Theme.colors.errorColor : Theme.colors.text
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.countText
                    font.pixelSize: Theme.font.xs
                    color: root.critical ? Theme.colors.errorColor : Theme.colors.mutedText
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.canExpand
                size: 30
                icon: root.expanded ? "expand_less" : "expand_more"
                label: root.expanded ? "Show fewer" : "Show more"
                iconSize: 18
                baseColor: Theme.colors.surfaceContainer
                hoverColor: Theme.colors.surfaceContainerHigh
                onClicked: root.expanded = !root.expanded
            }

            IconButton {
                size: 30
                icon: "clear_all"
                label: "Dismiss group"
                iconSize: 17
                baseColor: Theme.colors.surfaceContainer
                hoverColor: Theme.colors.surfaceContainerHigh
                onClicked: root.service.dismissAppNotifications(root.appName)
            }
        }

        Repeater {
            model: root.visibleNotifications

            Rectangle {
                id: previewCard

                required property var modelData
                readonly property var notificationActions: modelData.actions ?? []
                readonly property bool notificationHasActions: modelData.hasActions ?? notificationActions.length > 0

                Layout.fillWidth: true
                implicitHeight: previewContent.implicitHeight + Theme.spacing.md * 2
                radius: Theme.rounding.sm
                color: previewArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainer
                border.width: Theme.elevation.outlineWidth
                border.color: Theme.colors.outlineVariant

                MouseArea {
                    id: previewArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.dismissNotification(modelData.notificationId)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animation.fast
                        easing.type: Theme.animation.easing
                    }
                }

                ColumnLayout {
                    id: previewContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.spacing.md
                    }
                    spacing: Theme.spacing.md

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.md

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.summary
                                font.pixelSize: Theme.font.sm
                                font.weight: Font.DemiBold
                                color: Theme.colors.text
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: modelData.body.length > 0
                                text: modelData.body
                                wrapMode: Text.WordWrap
                                maximumLineCount: root.expanded || previewCard.notificationHasActions ? 2 : 1
                                elide: Text.ElideRight
                                font.pixelSize: Theme.font.xs
                                color: Theme.colors.mutedText
                            }
                        }

                        IconButton {
                            size: 28
                            icon: "close"
                            label: "Dismiss"
                            iconSize: 15
                            baseColor: Theme.colors.transparent
                            hoverColor: Theme.colors.surfaceContainerHighest
                            onClicked: root.service.dismissNotification(modelData.notificationId)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: previewCard.notificationHasActions
                        spacing: Theme.spacing.sm

                        Repeater {
                            model: previewCard.notificationActions

                            ActionChip {
                                required property var modelData

                                text: modelData.text
                                minWidth: 84
                                icon: "touch_app"
                                active: true
                                onTriggered: root.service.invokeNotificationAction(previewCard.modelData.notificationId, modelData.identifier)
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.expanded && root.notificationCount > root.visibleCount
            text: `Showing newest ${root.visibleCount} of ${root.notificationCount}`
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.font.xs
            color: root.critical ? Theme.colors.errorColor : Theme.colors.subtleText
        }
    }
}
