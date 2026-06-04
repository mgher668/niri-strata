import QtQuick
import QtQuick.Layouts
import "../common/"

GridLayout {
    id: root

    required property var actions

    columns: 2
    columnSpacing: Theme.spacing.md
    rowSpacing: Theme.spacing.md

    property var toggleIds: [
        "wifi",
        "bluetooth",
        "dnd",
        "audio",
        "microphone",
        "night",
        "screenshot",
        "recording",
        "lock",
    ]

    function labelFor(id) {
        if (id === "wifi")
            return "Wi-Fi";
        if (id === "bluetooth")
            return "Bluetooth";
        if (id === "dnd")
            return "Do not disturb";
        if (id === "audio")
            return "Output mute";
        if (id === "microphone")
            return "Microphone";
        if (id === "night")
            return "Night mode";
        if (id === "screenshot")
            return "Screenshot";
        if (id === "recording")
            return "Record";
        if (id === "lock")
            return "Lock";
        return id;
    }

    function iconFor(id) {
        if (id === "wifi")
            return "wifi";
        if (id === "bluetooth")
            return "bluetooth";
        if (id === "dnd")
            return "notifications_off";
        if (id === "audio")
            return "volume_off";
        if (id === "microphone")
            return "mic_off";
        if (id === "night")
            return "nightlight";
        if (id === "screenshot")
            return "screenshot_region";
        if (id === "recording")
            return "radio_button_checked";
        if (id === "lock")
            return "lock";
        return "toggle_on";
    }

    function statusFor(id) {
        if (id === "wifi")
            return actions.wifiStatus;
        if (id === "bluetooth")
            return actions.bluetoothStatus;
        if (id === "dnd")
            return actions.notificationService.doNotDisturb ? "On" : "Off";
        if (id === "audio")
            return actions.audioStatus;
        if (id === "microphone")
            return actions.microphoneStatus;
        if (id === "night")
            return actions.nightModeStatus;
        if (id === "screenshot")
            return actions.screenshotStatus;
        if (id === "recording")
            return actions.recordingStatus;
        if (id === "lock")
            return "Screenshot clock";
        return "";
    }

    function availableFor(id) {
        if (id === "wifi")
            return actions.wifiAvailable;
        if (id === "bluetooth")
            return actions.bluetoothAvailable;
        if (id === "dnd")
            return true;
        if (id === "audio")
            return actions.audioAvailable;
        if (id === "microphone")
            return actions.microphoneAvailable;
        if (id === "night")
            return actions.nightModeAvailable;
        if (id === "screenshot")
            return actions.screenshotAvailable;
        if (id === "recording")
            return actions.recordingAvailable;
        if (id === "lock")
            return actions.lockAvailable;
        return false;
    }

    function activeFor(id) {
        if (id === "wifi")
            return actions.wifiEnabled;
        if (id === "bluetooth")
            return actions.bluetoothEnabled;
        if (id === "dnd")
            return actions.notificationService.doNotDisturb;
        if (id === "audio")
            return actions.audioMuted;
        if (id === "microphone")
            return actions.microphoneMuted;
        if (id === "night")
            return actions.nightModeEnabled;
        if (id === "screenshot")
            return false;
        if (id === "recording")
            return actions.recordingActive;
        return false;
    }

    function trigger(id) {
        if (id === "wifi")
            actions.toggleWifi();
        else if (id === "bluetooth")
            actions.toggleBluetooth();
        else if (id === "dnd")
            actions.notificationService.toggleDoNotDisturb();
        else if (id === "audio")
            actions.toggleAudioMute();
        else if (id === "microphone")
            actions.toggleMicrophoneMute();
        else if (id === "night")
            actions.toggleNightMode();
        else if (id === "screenshot")
            actions.takeScreenshot();
        else if (id === "recording")
            actions.toggleRecording();
        else if (id === "lock")
            actions.lockScreen();
    }

    Repeater {
        model: root.toggleIds

        Rectangle {
            required property string modelData

            readonly property bool toggleAvailable: root.availableFor(modelData)
            readonly property bool toggleActive: root.activeFor(modelData)

            Layout.fillWidth: true
            Layout.preferredHeight: Config.sidebar.toggleHeight
            radius: Theme.rounding.lg
            color: toggleActive
                ? Theme.colors.primaryContainer
                : toggleArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainer
            border.width: Theme.elevation.outlineWidth
            border.color: toggleActive ? Theme.colors.primary : Theme.colors.outlineVariant
            opacity: toggleAvailable ? 1 : 0.45
            scale: toggleArea.pressed ? Theme.elevation.pressedScale : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    margins: Theme.spacing.lg
                }
                spacing: Theme.spacing.md

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: Theme.rounding.full
                    color: toggleActive ? Theme.colors.primary : Theme.colors.surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: root.iconFor(modelData)
                        size: 22
                        filled: toggleActive
                        iconColor: toggleActive ? Theme.colors.primaryText : Theme.colors.text
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.labelFor(modelData)
                        font.pixelSize: Theme.font.sm
                        font.weight: Font.DemiBold
                        color: toggleActive ? Theme.colors.primaryContainerText : Theme.colors.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: toggleAvailable ? root.statusFor(modelData) : "Unavailable"
                        font.pixelSize: Theme.font.xs
                        color: toggleActive ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                enabled: toggleAvailable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.trigger(modelData)
            }
        }
    }
}
