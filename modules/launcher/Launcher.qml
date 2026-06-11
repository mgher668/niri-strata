import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common/"

Scope {
    id: root

    required property var palette
    required property var niriState

    readonly property string targetOutputName: niriState.focusedOutputName

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: launcherWindow
            required property ShellScreen modelData

            readonly property bool targetScreen: root.targetOutputName.length === 0 || modelData.name === root.targetOutputName
            readonly property bool shown: root.palette.open && targetScreen

            screen: modelData
            visible: shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            onShownChanged: {
                if (shown)
                    focusTimer.restart();
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.38)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.palette.close()
                }

                Rectangle {
                    id: panel
                    width: Math.min(720, launcherWindow.width - Theme.spacing.xxl * 2)
                    height: Math.min(520, launcherWindow.height - Theme.spacing.xxl * 3)
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Math.max(72, launcherWindow.height * 0.16)
                    }
                    radius: Theme.rounding.xl
                    color: Theme.colors.surfaceContainerLow
                    border.width: Theme.elevation.outlineWidth
                    border.color: Theme.colors.outlineVariant
                    opacity: launcherWindow.shown ? 1 : 0
                    scale: launcherWindow.shown ? 1 : 0.96

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.emphasized
                        }
                    }

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: Theme.spacing.xl
                        }
                        spacing: Theme.spacing.md

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: Theme.rounding.lg
                            color: Theme.colors.surfaceContainer
                            border.width: Theme.elevation.outlineWidth
                            border.color: searchField.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.spacing.lg
                                    rightMargin: Theme.spacing.lg
                                }
                                spacing: Theme.spacing.md

                                MaterialIcon {
                                    name: "search"
                                    size: 22
                                    iconColor: Theme.colors.mutedText
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    StyledText {
                                        anchors.fill: parent
                                        text: "Search"
                                        visible: searchField.text.length === 0
                                        color: Theme.colors.subtleText
                                        font.pixelSize: Theme.font.lg
                                    }

                                    TextInput {
                                        id: searchField
                                        anchors.fill: parent
                                        text: root.palette.inputQuery
                                        color: Theme.colors.text
                                        selectionColor: Theme.colors.primaryContainer
                                        selectedTextColor: Theme.colors.primaryContainerText
                                        font.family: Theme.font.familyText
                                        font.pixelSize: Theme.font.lg
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true

                                        onTextEdited: root.palette.setInputQuery(text)

                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_Escape) {
                                                root.palette.close();
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Down) {
                                                root.palette.moveSelection(1);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Up) {
                                                root.palette.moveSelection(-1);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                root.palette.executeSelected();
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: resultsView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Theme.spacing.sm
                            visible: root.palette.results.length > 0
                            model: root.palette.results
                            currentIndex: root.palette.selectedIndex
                            boundsBehavior: Flickable.StopAtBounds
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, ListView.Contain);
                            }

                            function scrollBy(delta) {
                                const maxY = Math.max(0, contentHeight - height);
                                contentY = Math.max(0, Math.min(maxY, contentY + delta));
                            }

                            WheelHandler {
                                target: null
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    resultsView.scrollBy(-event.angleDelta.y * Config.sidebar.wheelScrollFactor);
                                    event.accepted = true;
                                }
                            }

                            delegate: SearchResultRow {
                                required property var modelData
                                required property int index

                                width: resultsView.width
                                result: modelData
                                selected: index === root.palette.selectedIndex
                                pinned: root.palette.isPinned(modelData.id)
                                recent: root.palette.isRecent(modelData.id)
                                immediateSelection: root.palette.keyboardNavigationActive
                                confirmationRequired: root.palette.requiresResultConfirmation(modelData)
                                confirming: root.palette.confirmingActionId === (modelData.actionId || "")
                                onActivated: {
                                    root.palette.selectedIndex = index;
                                    root.palette.executeSelected();
                                }
                                onPinToggled: root.palette.togglePinned(modelData.id)
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.palette.results.length === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacing.sm

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    name: "search_off"
                                    size: 28
                                    iconColor: Theme.colors.subtleText
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No results"
                                    color: Theme.colors.subtleText
                                    font.pixelSize: Theme.font.md
                                }
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: launcherWindow.visible
                onActivated: root.palette.close()
            }

            Timer {
                id: focusTimer
                interval: 1
                repeat: false
                onTriggered: searchField.forceActiveFocus()
            }
        }
    }
}
