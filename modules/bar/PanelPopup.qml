import QtQuick
import Quickshell
import "../common/"

LazyLoader {
    id: root

    property bool open: false
    property Item target
    property int contentPadding: Theme.spacing.xl
    property int panelGap: Theme.spacing.lg
    property int edgeGap: Config.bar.sideMargin
    property int panelRadius: Theme.rounding.lg
    readonly property bool targetReady: root.target !== null
        && root.target.QsWindow.window !== null
    default property Item contentItem

    active: root.open && root.targetReady

    component: PopupWindow {
        id: popupWindow

        visible: true
        color: Theme.colors.transparent
        implicitWidth: popupBackground.implicitWidth + root.edgeGap * 2
        implicitHeight: popupBackground.implicitHeight + root.panelGap

        anchor {
            window: root.target.QsWindow.window
            item: root.target
            adjustment: PopupAdjustment.SlideX | PopupAdjustment.ResizeY
            edges: Config.bar.position === "bottom" ? Edges.Top : Edges.Bottom
            gravity: Config.bar.position === "bottom" ? Edges.Top : Edges.Bottom
        }

        Rectangle {
            id: popupBackground

            x: root.edgeGap
            y: Config.bar.position === "bottom" ? 0 : root.panelGap
            implicitWidth: contentHost.implicitWidth + root.contentPadding * 2
            implicitHeight: contentHost.implicitHeight + root.contentPadding * 2
            radius: root.panelRadius
            color: Theme.colors.layer0
            border.width: 1
            border.color: Theme.colors.outline

            Item {
                id: contentHost

                anchors {
                    fill: parent
                    margins: root.contentPadding
                }
                implicitWidth: root.contentItem ? root.contentItem.implicitWidth : 0
                implicitHeight: root.contentItem ? root.contentItem.implicitHeight : 0
                children: [root.contentItem]

                Binding {
                    target: root.contentItem
                    property: "width"
                    value: contentHost.width
                    when: root.contentItem !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: root.contentItem
                    property: "height"
                    value: contentHost.height
                    when: root.contentItem !== null
                    restoreMode: Binding.RestoreNone
                }
            }
        }
    }
}
