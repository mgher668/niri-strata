import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var service
    opacity: service.available ? 1 : 0.7

    ColumnLayout {
        id: mediaContent
        width: parent.width
        spacing: Theme.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: Theme.rounding.md
                color: Theme.colors.surfaceContainerLow
                border.width: Theme.elevation.outlineWidth
                border.color: Theme.colors.outlineVariant
                clip: true

                Image {
                    anchors.fill: parent
                    source: service.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: service.artUrl.length > 0
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: service.artUrl.length === 0
                    name: "music_note"
                    size: 26
                    iconColor: Theme.colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: service.playerName
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.subtleText
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: service.title
                    font.pixelSize: Theme.font.md
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: service.available ? (service.artist || "Unknown artist") : "No active player"
                    font.pixelSize: Theme.font.sm
                    color: Theme.colors.mutedText
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacing.md

            IconButton {
                size: 38
                icon: "skip_previous"
                label: "Previous"
                enabled: service.canPrevious
                onClicked: service.previous()
            }

            IconButton {
                size: 46
                icon: service.playing ? "pause" : "play_arrow"
                label: service.playing ? "Pause" : "Play"
                active: service.playing
                enabled: service.canToggle
                filled: true
                onClicked: service.toggle()
            }

            IconButton {
                size: 38
                icon: "skip_next"
                label: "Next"
                enabled: service.canNext
                onClicked: service.next()
            }
        }
    }
}
