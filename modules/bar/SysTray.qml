import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../common/"

Item {
    id: root

    property var trayState: null
    property string outputName: ""

    property bool itemsReady: false
    readonly property var items: itemsReady ? SystemTray.items.values : []
    readonly property int maxVisibleItems: trayConfig.maxVisibleItems
    property bool barIconsVisible: true
    property var sortedItems: []
    property var visibleItems: []
    property var hiddenItems: []
    property bool overflowOpen: false
    property bool tooltipEnabled: true
    property Item overflowTooltipSource
    property bool overflowTooltipMounted: false
    property bool overflowTooltipVisible: false
    property string overflowTooltipTitle: ""
    property string overflowTooltipDescription: ""
    property real overflowTooltipAnchorX: 0
    property real overflowTooltipAnchorY: 0

    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight
    visible: items.length > 0

    onOverflowOpenChanged: {
        if (!overflowOpen)
            clearOverflowTooltip();
    }

    onHiddenItemsChanged: {
        if (hiddenItems.length === 0) {
            overflowOpen = false;
            clearOverflowTooltip();
        }
    }

    TrayConfig {
        id: trayConfig
    }

    Connections {
        target: root.trayState || null
        ignoreUnknownSignals: true

        function onBarIconsVisibleChanged() {
            root.refreshItems();
        }
    }

    Component.onCompleted: trayStartupTimer.start()
    onItemsChanged: {
        if (itemsReady)
            refreshItems();
    }
    onMaxVisibleItemsChanged: {
        if (itemsReady)
            refreshItems();
    }
    onTrayStateChanged: {
        if (itemsReady)
            refreshItems();
    }
    onOutputNameChanged: {
        if (itemsReady)
            refreshItems();
    }

    function itemText(item) {
        return String(item?.tooltipTitle || item?.title || item?.id || "Tray item");
    }

    function itemDescription(item) {
        return String(item?.tooltipDescription || item?.id || "");
    }

    function itemSearchText(item) {
        return `${item?.id || ""} ${item?.title || ""} ${item?.tooltipTitle || ""} ${item?.tooltipDescription || ""}`.toLowerCase();
    }

    function isPinned(item) {
        const text = itemSearchText(item);
        return trayConfig.pinnedItemTokens.some(token => text.includes(String(token).toLowerCase()));
    }

    function sortItems(sourceItems) {
        return [...sourceItems].sort((left, right) => {
            const pinnedDelta = (isPinned(right) ? 1 : 0) - (isPinned(left) ? 1 : 0);
            if (pinnedDelta !== 0)
                return pinnedDelta;

            const leftKey = `${itemText(left)} ${left?.id || ""}`.toLowerCase();
            const rightKey = `${itemText(right)} ${right?.id || ""}`.toLowerCase();
            return leftKey.localeCompare(rightKey);
        });
    }

    function refreshItems() {
        const sorted = sortItems(items);
        const pinned = sorted.filter(item => isPinned(item));
        const unpinned = sorted.filter(item => !isPinned(item));
        const ordered = [...pinned, ...unpinned];
        const showBarIcons = trayState ? trayState.barIconsVisible : true;
        const visible = showBarIcons ? ordered.slice(0, maxVisibleItems) : [];

        barIconsVisible = showBarIcons;
        sortedItems = sorted;
        visibleItems = visible;
        hiddenItems = sorted.filter(item => !visible.includes(item));

        if (trayState)
            trayState.updateOutputStats(outputName, sortedItems.length, visibleItems.length, hiddenItems.length);
    }

    function needsAttention(item) {
        return String(item?.status ?? "").toLowerCase().includes("attention") || item?.status === 2;
    }

    function menuAnchor(button) {
        const anchor = button && button.QsWindow.window ? button : root;
        const window = anchor.QsWindow.window;
        if (!window)
            return null;

        const point = anchor.mapToItem(null, anchor.width / 2, anchor.height);

        return {
            window,
            x: Math.round(point.x),
            y: Math.round(point.y),
        };
    }

    function showMenu(item, button) {
        if (!item || !item.hasMenu)
            return false;

        const anchor = menuAnchor(button);
        if (!anchor) {
            console.warn("Cannot open tray menu without a parent window:", item.id);
            return false;
        }

        tooltipEnabled = false;

        Qt.callLater(() => {
            console.info("Opening tray menu:", item.id);
            try {
                item.display(anchor.window, anchor.x, anchor.y);
            } catch (error) {
                console.warn("Failed to open tray menu:", item.id, error);
            }
        });

        return true;
    }

    function overflowTooltipAnchor(button) {
        if (!button || !root.QsWindow.window)
            return null;

        const globalPoint = button.mapToGlobal(button.width / 2, button.height);
        const rootPoint = root.mapFromGlobal(globalPoint.x, globalPoint.y);
        const windowPoint = root.mapToItem(null, rootPoint.x, rootPoint.y);

        return {
            x: Math.round(windowPoint.x),
            y: Math.round(windowPoint.y),
        };
    }

    function showOverflowTooltip(button, title, description) {
        const anchor = overflowTooltipAnchor(button);
        if (!anchor || !title)
            return;

        overflowTooltipUnmountTimer.stop();
        overflowTooltipSource = button;
        overflowTooltipAnchorX = anchor.x;
        overflowTooltipAnchorY = anchor.y;
        overflowTooltipTitle = title;
        overflowTooltipDescription = description;
        overflowTooltipMounted = true;
        overflowTooltipVisible = true;
    }

    function hideOverflowTooltip(button) {
        if (button && overflowTooltipSource !== button)
            return;

        overflowTooltipVisible = false;
        overflowTooltipUnmountTimer.restart();
    }

    function clearOverflowTooltip() {
        overflowTooltipUnmountTimer.stop();
        overflowTooltipVisible = false;
        overflowTooltipMounted = false;
        overflowTooltipSource = null;
        overflowTooltipTitle = "";
        overflowTooltipDescription = "";
    }

    function activateItem(item) {
        if (!item)
            return;

        tooltipEnabled = false;
        console.info("Activating tray item:", item.id);
        item.activate();
    }

    function secondaryActivateItem(item) {
        if (!item)
            return;

        tooltipEnabled = false;
        console.info("Secondary activating tray item:", item.id);
        item.secondaryActivate();
    }

    Timer {
        id: trayStartupTimer

        interval: 900
        repeat: false
        onTriggered: {
            root.itemsReady = true;
            root.refreshItems();
        }
    }

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        Repeater {
            model: root.visibleItems

            TrayIconButton {
                id: visibleTrayButton

                required property var modelData

                item: modelData
                requestMenu: item => root.showMenu(item, visibleTrayButton)
                tooltipTitle: root.itemText(modelData)
                tooltipDescription: root.itemDescription(modelData)
                needsAttention: root.needsAttention(modelData)
                pinned: root.isPinned(modelData)
            }
        }

        MouseArea {
            id: overflowButton

            property bool hovered: containsMouse

            Layout.alignment: Qt.AlignVCenter
            visible: root.hiddenItems.length > 0
            implicitWidth: 28
            implicitHeight: 22
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            onClicked: root.overflowOpen = !root.overflowOpen

            Rectangle {
                anchors.fill: parent
                radius: Theme.rounding.full
                color: root.overflowOpen ? Theme.colors.primaryContainer
                    : overflowButton.hovered ? Theme.colors.layer1Hover : Theme.colors.transparent

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animation.fast
                        easing.type: Theme.animation.easing
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: "+" + root.hiddenItems.length
                color: root.overflowOpen ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                font.pixelSize: Theme.font.xs
                font.family: Theme.font.familyMono
                font.weight: Font.DemiBold
            }

            PanelPopup {
                open: root.overflowOpen
                target: overflowButton

                SysTrayOverflowPopup {
                    items: root.hiddenItems
                    requestMenu: (item, button) => root.showMenu(item, button)
                    itemText: item => root.itemText(item)
                    itemDescription: item => root.itemDescription(item)
                    needsAttention: item => root.needsAttention(item)
                    onTooltipRequested: (button, title, description) => root.showOverflowTooltip(button, title, description)
                    onTooltipDismissed: button => root.hideOverflowTooltip(button)
                }
            }
        }
    }

    Timer {
        id: overflowTooltipUnmountTimer

        interval: Theme.animation.fast
        repeat: false
        onTriggered: {
            if (!root.overflowTooltipVisible) {
                root.overflowTooltipMounted = false;
                root.overflowTooltipSource = null;
                root.overflowTooltipTitle = "";
                root.overflowTooltipDescription = "";
            }
        }
    }

    LazyLoader {
        active: root.overflowTooltipMounted
            && root.overflowTooltipTitle.length > 0
            && root.QsWindow.window !== null

        component: PopupWindow {
            id: overflowTooltipWindow

            visible: true
            color: Theme.colors.transparent
            implicitWidth: overflowTooltipCard.implicitWidth
            implicitHeight: overflowTooltipCard.implicitHeight

            anchor {
                window: root.QsWindow.window
                rect.x: Math.round(root.overflowTooltipAnchorX - overflowTooltipWindow.implicitWidth / 2)
                rect.y: Math.round(root.overflowTooltipAnchorY + Theme.spacing.sm)
                rect.width: 1
                rect.height: 1
                adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
                edges: Edges.Top | Edges.Left
                gravity: Edges.Bottom | Edges.Right
            }

            Rectangle {
                id: overflowTooltipCard

                implicitWidth: Math.min(240, Math.max(120, overflowTooltipContent.implicitWidth + Theme.spacing.lg * 2))
                implicitHeight: overflowTooltipContent.implicitHeight + Theme.spacing.md * 2
                radius: Theme.rounding.xs
                color: Theme.colors.layer0
                border.width: 1
                border.color: Theme.colors.outline
                opacity: root.overflowTooltipVisible ? 1 : 0
                scale: root.overflowTooltipVisible ? 1 : 0.96
                transformOrigin: Item.Top

                Behavior on opacity {
                    NumberAnimation {
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

                ColumnLayout {
                    id: overflowTooltipContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.spacing.md
                    }
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.overflowTooltipTitle
                        color: Theme.colors.text
                        font.pixelSize: Theme.font.sm
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.overflowTooltipDescription.length > 0
                        text: root.overflowTooltipDescription
                        color: Theme.colors.subtleText
                        font.pixelSize: Theme.font.xs
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component TrayIconButton: MouseArea {
        id: trayButton

        required property var item
        property bool hovered: containsMouse
        property bool needsAttention: false
        property bool pinned: false
        property string tooltipTitle: root.itemText(item)
        property string tooltipDescription: root.itemDescription(item)
        property var requestMenu: item => false

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 22
        implicitHeight: 22
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onContainsMouseChanged: {
            if (!containsMouse)
                root.tooltipEnabled = true;
        }

        onClicked: event => {
            root.tooltipEnabled = false;
            if (event.button === Qt.LeftButton) {
                if (trayButton.item.onlyMenu && trayButton.item.hasMenu)
                    trayButton.requestMenu(trayButton.item);
                else
                    root.activateItem(trayButton.item);
            } else if (event.button === Qt.RightButton) {
                trayButton.requestMenu(trayButton.item);
            } else if (event.button === Qt.MiddleButton) {
                root.secondaryActivateItem(trayButton.item);
            }
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.sm
            color: trayButton.needsAttention ? Theme.colors.warningContainer
                : trayButton.hovered ? Theme.colors.layer1Hover : Theme.colors.transparent
            border.width: trayButton.needsAttention || trayButton.pinned ? 1 : 0
            border.color: trayButton.needsAttention ? Theme.colors.warningColor : Theme.colors.outlineVariant

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }
        }

        Rectangle {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 1
            }
            visible: trayButton.needsAttention
            width: 6
            height: 6
            radius: Theme.rounding.full
            color: Theme.colors.warningColor
        }

        IconImage {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: trayButton.item.icon
        }

        PanelPopup {
            open: root.tooltipEnabled && trayButton.hovered && trayButton.tooltipTitle.length > 0
            target: trayButton
            contentPadding: Theme.spacing.md
            panelGap: Theme.spacing.sm
            panelRadius: Theme.rounding.xs

            ColumnLayout {
                implicitWidth: Math.max(titleText.implicitWidth, descriptionText.implicitWidth)
                spacing: 2

                StyledText {
                    id: titleText
                    text: trayButton.tooltipTitle
                    color: Theme.colors.text
                    font.pixelSize: Theme.font.sm
                    font.weight: Font.DemiBold
                }

                StyledText {
                    id: descriptionText
                    visible: trayButton.tooltipDescription.length > 0
                    text: trayButton.tooltipDescription
                    color: Theme.colors.subtleText
                    font.pixelSize: Theme.font.xs
                }
            }
        }
    }
}
