import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../common/"
import "../widgets/"

// WallpaperGrid — thumbnail grid for browsing wallpaper images.
// Uses GridView with virtualization for performance (only visible delegates decoded).

Item {
    id: root

    property var imageList: []
    property string sortBy: "name"
    property string sortOrder: "ascending"
    property bool recursive: false
    property string selectedPath: ""
    signal imageClicked(string path)

    // ── Sort/filter toolbar ──

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: "Sort:"
                font.pixelSize: Theme.font.xs
                color: Theme.colors.mutedText
            }

            SettingsSegmentedRow {
                label: ""
                value: root.sortBy === "date" ? "Date" : "Name"
                options: [
                    { label: "Name", value: "name" },
                    { label: "Date", value: "date" }
                ]
                selectedCallback: (val) => { root.sortBy = val; root.rescan(); }
            }

            SettingsSegmentedRow {
                label: ""
                value: root.sortOrder === "descending" ? "Descending" : "Ascending"
                options: [
                    { label: "Asc", value: "ascending" },
                    { label: "Desc", value: "descending" }
                ]
                selectedCallback: (val) => { root.sortOrder = val; root.rescan(); }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "refresh"
                size: 28
                iconSize: 16
                onClicked: root._rescan()
            }

            SettingsToggleRow {
                label: "Subfolders"
                checked: root.recursive
                toggleCallback: (val) => { root.recursive = val; root._rescan(); }
                Layout.preferredHeight: 28
            }
        }

        // ── Grid ──

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: grid.contentHeight
            boundsBehavior: Flickable.StopAtBounds

            GridView {
                id: grid
                anchors.fill: parent
                model: root.imageList
                cellWidth: 188
                cellHeight: 128
                clip: true
                cacheBuffer: 2000

                delegate: Rectangle {
                    width: 180
                    height: 120
                    radius: Theme.rounding.xs
                    color: root.selectedPath === modelData ? Theme.colors.activeTabBg : "transparent"
                    border.width: root.selectedPath === modelData ? 2 : 1
                    border.color: root.selectedPath === modelData ? Theme.colors.primary : Theme.colors.outlineVariant
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 180
                        sourceSize.height: 120
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedPath = modelData;
                            root.imageClicked(modelData);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.imageList.length === 0
                    text: "No images found. Add a wallpaper folder to browse."
                    color: Theme.colors.subtleText
                    font.pixelSize: Theme.font.sm
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    signal rescan()
    function _rescan() { root.rescan(); }
}