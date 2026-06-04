import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../common/"

SurfaceCard {
    id: root

    required property var service

    ColumnLayout {
        id: audioContent
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "tune"
            title: "Audio"
            subtitle: service.available ? root.service.nodeLabel(service.sink) : "PipeWire unavailable"
            active: service.available
        }

        AudioSlider {
            title: "Output"
            node: service.sink
            unavailableText: "No output device"
        }

        DeviceChoices {
            title: "Output device"
            devices: service.outputDevices
            currentNode: service.sink
            selectDevice: function(node) { service.setDefaultSink(node); }
        }

        AudioSlider {
            title: "Input"
            node: service.source
            unavailableText: "No input device"
        }

        DeviceChoices {
            title: "Input device"
            devices: service.inputDevices
            currentNode: service.source
            selectDevice: function(node) { service.setDefaultSource(node); }
        }

        StreamList {
            title: "Output streams"
            streams: service.outputStreams
        }

        StreamList {
            title: "Input streams"
            streams: service.inputStreams
        }
    }

    component AudioSlider: ColumnLayout {
        id: audioSlider

        required property string title
        required property var node
        property string unavailableText: "Unavailable"
        property bool compact: false
        property real maxVolume: compact ? 1 : 1.5

        readonly property bool ready: node !== null && node !== undefined && node.audio !== null && node.audio !== undefined

        Layout.fillWidth: true
        spacing: compact ? Theme.spacing.xs : Theme.spacing.sm

        PwObjectTracker {
            objects: audioSlider.node ? [audioSlider.node] : []
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: compact ? Theme.spacing.sm : Theme.spacing.md

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: title
                    font.pixelSize: compact ? Theme.font.sm : Theme.font.md
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !compact
                    text: ready ? root.service.nodeLabel(node) : unavailableText
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.mutedText
                    elide: Text.ElideRight
                }
            }

            StyledText {
                text: ready ? root.service.volumeText(node) : "--"
                font.pixelSize: compact ? Theme.font.xs : Theme.font.sm
                font.family: Theme.font.familyMono
                color: ready && node.audio.muted ? Theme.colors.subtleText : Theme.colors.text
            }

            ActionChip {
                text: compact ? "" : ready && node.audio.muted ? "Unmute" : "Mute"
                icon: ready && node.audio.muted ? "volume_off" : "volume_up"
                active: ready && node.audio.muted
                enabled: ready
                minWidth: compact ? 34 : 72
                chipHeight: compact ? 28 : 32
                onTriggered: node.audio.muted = !node.audio.muted
            }
        }

        MaterialSlider {
            Layout.fillWidth: true
            enabled: ready
            from: 0
            to: maxVolume
            stepSize: 0.01
            size: compact ? "compact" : "regular"
            value: ready ? node.audio.volume : 0
            onSetValue: value => node.audio.volume = value
        }
    }

    component DeviceChoices: ColumnLayout {
        required property string title
        required property var devices
        required property var currentNode
        required property var selectDevice

        Layout.fillWidth: true
        spacing: Theme.spacing.sm
        visible: devices.length > 0

        StyledText {
            Layout.fillWidth: true
            text: title
            font.pixelSize: Theme.font.xs
            color: Theme.colors.subtleText
        }

        Repeater {
            model: devices

            Rectangle {
                required property var modelData

                readonly property bool selected: currentNode && modelData.id === currentNode.id

                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.rounding.sm
                color: selected ? Theme.colors.primaryContainer : choiceArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainerLow
                border.width: Theme.elevation.outlineWidth
                border.color: selected ? Theme.colors.primary : Theme.colors.outlineVariant

                StyledText {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacing.md
                        rightMargin: Theme.spacing.xxl
                    }
                    text: root.service.nodeLabel(modelData)
                    font.pixelSize: Theme.font.sm
                    color: selected ? Theme.colors.primaryContainerText : Theme.colors.text
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.spacing.md
                        verticalCenter: parent.verticalCenter
                    }
                    name: selected ? "check_circle" : "radio_button_unchecked"
                    size: 18
                    filled: selected
                    iconColor: selected ? Theme.colors.primaryContainerText : Theme.colors.subtleText
                }

                MouseArea {
                    id: choiceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: selectDevice(modelData)
                }
            }
        }
    }

    component StreamList: ColumnLayout {
        required property string title
        required property var streams

        Layout.fillWidth: true
        spacing: Theme.spacing.xs
        visible: streams.length > 0

        StyledText {
            Layout.fillWidth: true
            text: title
            font.pixelSize: Theme.font.xs
            color: Theme.colors.subtleText
        }

        Repeater {
            model: streams.slice(0, 5)

            AudioSlider {
                required property var modelData

                title: root.service.nodeLabel(modelData)
                node: modelData
                compact: true
                maxVolume: 1
            }
        }
    }

}
