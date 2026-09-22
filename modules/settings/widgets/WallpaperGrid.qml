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
    property var _readyImages: ({})
    property int _renderCursor: 0
    property real _retentionBuffer: 512
    signal sortRequested(string value)
    signal sortOrderRequested(string value)
    signal recursiveRequested(bool value)
    signal imageClicked(string path)

    onImageListChanged: {
        root._readyImages = {};
        root._renderCursor = 0;
        root._retentionBuffer = 512;
        revealTimer.stop();
        Qt.callLater(() => {
            grid.positionViewAtBeginning();
            grid.contentY = grid.originY;
        });
    }

    function _markImageReady(imageIndex) {
        if (imageIndex < 0 || imageIndex >= root.imageList.length)
            return;

        var ready = Object.assign({}, root._readyImages);
        ready[imageIndex] = true;
        root._readyImages = ready;

        // Reveal only the first image immediately. Every later image must go
        // through the timer, even if several decode callbacks arrive together.
        if (imageIndex === 0 && root._renderCursor === 0)
            root._revealNextReady();
        if (root._renderCursor < root.imageList.length
                && root._readyImages[root._renderCursor] === true)
            revealTimer.start();
    }

    function _revealNextReady() {
        if (root._renderCursor >= root.imageList.length) {
            revealTimer.stop();
            return false;
        }
        if (root._readyImages[root._renderCursor] !== true)
            return false;

        root._renderCursor += 1;
        if (root._renderCursor >= root.imageList.length)
            revealTimer.stop();
        return true;
    }

    function _imageIsRevealed(imageIndex) {
        return imageIndex < root._renderCursor;
    }

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
                selectedCallback: (val) => { root.sortRequested(val); root.rescan(); }
            }

            SettingsSegmentedRow {
                label: ""
                value: root.sortOrder === "descending" ? "Descending" : "Ascending"
                options: [
                    { label: "Asc", value: "ascending" },
                    { label: "Desc", value: "descending" }
                ]
                selectedCallback: (val) => { root.sortOrderRequested(val); root.rescan(); }
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
                toggleCallback: (val) => { root.recursiveRequested(val); root._rescan(); }
                Layout.preferredHeight: 28
            }
        }

        // ── Grid ──
        // GridView is itself a Flickable — no need to wrap it.
        // Keep its scrollbar as a sibling so it stays fixed to the viewport.

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: grid
                anchors.fill: parent
                anchors.rightMargin: 12
                model: root.imageList
                cellWidth: 188
                cellHeight: 128
                flow: GridView.FlowLeftToRight
                layoutDirection: Qt.LeftToRight
                verticalLayoutDirection: GridView.TopToBottom
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Start small for fast first paint. As the user scrolls,
                // _retentionBuffer grows so visited delegates stay alive.
                cacheBuffer: root._retentionBuffer
                onContentYChanged: {
                    var visitedDistance = Math.max(0, contentY - originY);
                    root._retentionBuffer = Math.max(root._retentionBuffer, visitedDistance);
                }

                delegate: Rectangle {
                    id: delegateRoot
                    property int imageIndex: index
                    width: 180
                    height: 120
                    radius: Theme.rounding.xs
                    color: root.selectedPath === modelData ? Theme.colors.activeTabBg : "transparent"
                    border.width: root.selectedPath === modelData ? 2 : 1
                    border.color: root.selectedPath === modelData ? Theme.colors.primary : Theme.colors.outlineVariant
                    clip: true

                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        anchors.margins: 2
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 180
                        sourceSize.height: 120
                        // Async decoding is kept for responsiveness. The
                        // reveal timer controls when each decoded image appears.
                        opacity: root._imageIsRevealed(delegateRoot.imageIndex) ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutQuad
                            }
                        }
                        onStatusChanged: {
                            if (status === Image.Ready || status === Image.Error)
                                root._markImageReady(delegateRoot.imageIndex);
                        }
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

            StyledScrollbar {
                targetFlickable: grid
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }
        }
    }

    Timer {
        id: revealTimer
        interval: 36
        repeat: true
        onTriggered: {
            if (!root._revealNextReady())
                revealTimer.stop();
        }
    }

    signal rescan()
    function _rescan() { root.rescan(); }
}
