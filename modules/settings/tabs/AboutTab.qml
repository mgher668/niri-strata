import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common/"
import "../widgets/"

// AboutTab — project info and credits.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    SettingsSectionHeader {
        title: "About"
    }

    // --- Logo area ---
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                MaterialIcon {
                    name: "layers"
                    size: 32
                    iconColor: Theme.colors.primary
                }

                StyledText {
                    text: "niri-strata"
                    font.pixelSize: Theme.font.xxl
                    font.weight: Font.Bold
                    color: Theme.colors.text
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "A Quickshell bar and Material You control center for niri"
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
            }
        }
    }

    // --- Info section ---
    SettingsSectionHeader {
        title: "Info"
    }

    InfoRow {
        label: "Compositor"
        value: "niri"
    }

    InfoRow {
        label: "License"
        value: "MIT"
    }

    InfoRow {
        label: "Quickshell"
        value: "Qt " + Qt.application.version
    }

    // --- Links section ---
    SettingsSectionHeader {
        title: "Links"
    }

    LinkRow {
        label: "GitHub"
        value: "github.com/mgher668/niri-strata"
        iconName: "open_in_new"
    }

    LinkRow {
        label: "niri"
        value: "github.com/niri-wm/niri"
        iconName: "open_in_new"
    }

    LinkRow {
        label: "Quickshell"
        value: "git.outfoxxed.me/outfoxxed/quickshell"
        iconName: "open_in_new"
    }

    Item { Layout.fillHeight: true }

    // --- Info row component ---
    component InfoRow: RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        property string label
        property string value

        StyledText {
            text: label
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            Layout.preferredWidth: 120
        }

        StyledText {
            text: value
            font.pixelSize: Theme.font.sm
            color: Theme.colors.text
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    // --- Link row component (clickable) ---
    component LinkRow: RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        property string label
        property string value
        property string iconName

        StyledText {
            text: label
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            Layout.preferredWidth: 120
        }

        StyledText {
            text: value
            font.pixelSize: Theme.font.sm
            color: Theme.colors.primary
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        MaterialIcon {
            name: iconName
            size: 14
            iconColor: Theme.colors.primary
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.xs
            color: linkMouse.containsMouse
                ? Theme.colors.surfaceHover
                : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }
        }

        MouseArea {
            id: linkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const urls = {
                    "github.com/mgher668/niri-strata": "https://github.com/mgher668/niri-strata",
                    "github.com/niri-wm/niri": "https://github.com/niri-wm/niri",
                    "git.outfoxxed.me/outfoxxed/quickshell": "https://git.outfoxxed.me/outfoxxed/quickshell",
                };
                const url = urls[value] || ("https://" + value);
                Quickshell.execDetached(["xdg-open", url]);
            }
        }
    }
}