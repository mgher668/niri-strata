import QtQuick

// SettingsController — manages Settings window open/close state and tab selection.
// Instantiated in shell.qml. The window itself is lazy-loaded via LazyLoader.

Item {
    id: root

    property bool open: false
    property string activeTab: "appearance"
    property string focusedOutputName: ""

    // Tab definitions — drives sidebar navigation
    readonly property var tabs: [
        { id: "appearance", title: "Appearance", icon: "palette" },
        { id: "bar", title: "Bar", icon: "space_bar" },
        { id: "workspaces", title: "Workspaces", icon: "view_carousel" },
        { id: "capture", title: "Capture", icon: "screenshot_monitor" },
        { id: "notifications", title: "Notifications", icon: "notifications" },
        { id: "niri", title: "Niri", icon: "settings_input_component" },
        { id: "services", title: "Services", icon: "build" },
        { id: "about", title: "About", icon: "info" }
    ]

    function toggle(outputName) {
        if (open)
            close();
        else
            openSettings(outputName);
    }

    function openSettings(outputName) {
        focusedOutputName = outputName || "";
        open = true;
    }

    function close() {
        open = false;
    }

    function showTab(tabId) {
        activeTab = tabId;
        if (!open)
            open = true;
    }
}