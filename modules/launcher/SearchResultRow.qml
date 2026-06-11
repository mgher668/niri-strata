import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common/"

Rectangle {
    id: root

    signal activated()
    signal pinToggled()

    required property var result
    property bool selected: false
    property bool pinned: false
    property bool recent: false
    property bool immediateSelection: false
    property bool confirmationRequired: false
    property bool confirming: false
    readonly property bool rowHovered: rowHover.hovered || pinButton.hovered
    readonly property bool showPinButton: root.selected || root.rowHovered || root.pinned
    readonly property bool appResult: result.type === "app"
    readonly property string appIconSource: appResult && String(result.icon || "").length > 0
        ? Quickshell.iconPath(result.icon, "application-x-executable")
        : ""

    implicitHeight: 56
    radius: Theme.rounding.md
    color: selected ? Theme.colors.primaryContainer : rowHovered ? Theme.colors.surfaceContainerHigh : Theme.colors.transparent
    border.width: selected ? Theme.elevation.outlineWidth : 0
    border.color: Theme.colors.primary

    HoverHandler {
        id: rowHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Behavior on color {
        enabled: !root.immediateSelection
        ColorAnimation {
            duration: Theme.animation.fast
            easing.type: Theme.animation.easing
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacing.md
            rightMargin: Theme.spacing.md
        }
        spacing: Theme.spacing.md

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.rounding.full
            color: root.selected ? Theme.colors.primary : Theme.colors.surfaceContainerLow

            MaterialIcon {
                visible: !root.appResult || root.appIconSource.length === 0
                anchors.centerIn: parent
                name: root.appResult ? "apps" : root.result.icon
                size: 20
                filled: root.selected
                iconColor: root.selected ? Theme.colors.primaryText : Theme.colors.text
            }

            Image {
                visible: root.appResult && root.appIconSource.length > 0
                anchors.centerIn: parent
                width: 24
                height: 24
                source: root.appIconSource
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.result.title
                font.pixelSize: Theme.font.md
                color: root.selected ? Theme.colors.primaryContainerText : Theme.colors.text
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.result.subtitle || root.result.command || ""
                visible: text.length > 0
                font.pixelSize: Theme.font.xs
                color: root.selected ? Theme.colors.primaryContainerText : Theme.colors.subtleText
                elide: Text.ElideRight
            }
        }

        RowLayout {
            spacing: Theme.spacing.xs

            StatusPill {
                visible: root.confirmationRequired
                icon: root.confirming ? "priority_high" : "shield"
                text: root.confirming ? "Confirm again" : "Confirm"
                active: root.confirming
            }

            StatusPill {
                visible: root.pinned
                icon: "keep"
                text: "Pinned"
            }

            StatusPill {
                visible: root.recent && !root.pinned
                icon: "history"
                text: "Recent"
            }
        }

        IconButton {
            id: pinButton

            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            size: 28
            iconSize: 17
            icon: root.pinned ? "keep" : "keep_off"
            label: root.pinned ? "Unpin result" : "Pin result"
            active: root.pinned
            showBorder: true
            baseColor: Theme.colors.surfaceContainerLow
            opacity: root.showPinButton ? 1 : 0
            enabled: root.showPinButton
            onClicked: root.pinToggled()

            Behavior on opacity {
                enabled: !root.immediateSelection
                NumberAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }
        }

        MaterialIcon {
            visible: root.selected
            name: "keyboard_return"
            size: 18
            iconColor: Theme.colors.primaryContainerText
        }
    }

    component StatusPill: Rectangle {
        id: pillRoot

        property string icon: ""
        property string text: ""
        property bool active: false

        Layout.preferredHeight: 24
        Layout.preferredWidth: pillContent.implicitWidth + Theme.spacing.md
        radius: Theme.rounding.full
        color: active ? Theme.colors.warningContainer : Theme.colors.surfaceContainerLow
        border.width: Theme.elevation.outlineWidth
        border.color: active ? Theme.colors.warningColor : Theme.colors.outlineVariant

        RowLayout {
            id: pillContent
            anchors.centerIn: parent
            spacing: Theme.spacing.xs

            MaterialIcon {
                name: icon
                size: 14
                filled: active
                iconColor: active ? Theme.colors.warningColor : Theme.colors.subtleText
            }

            StyledText {
                text: pillRoot.text
                font.pixelSize: Theme.font.xs
                color: active ? Theme.colors.warningColor : Theme.colors.subtleText
            }
        }
    }
}
