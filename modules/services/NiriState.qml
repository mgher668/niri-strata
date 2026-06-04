import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var niri
    readonly property int cliPollInterval: 1500

    property var cliWorkspaces: []
    property var cliWindows: []
    property var cliFocusedWindow: null
    property var cliFocusedOutput: null
    property bool cliReady: cliWorkspaces.length > 0

    readonly property var outputOrder: Quickshell.screens.map(screen => screen.name)
    readonly property var rawWindows: cliReady ? cliWindows : readField(niri, "windows", "windows", [])
    readonly property var rawFocusedWindow: cliFocusedWindow ?? readField(niri, "focused_window", "focusedWindow", null)
    readonly property var rawFocusedOutput: cliFocusedOutput ?? readField(niri, "focused_output", "focusedOutput", null)
    readonly property var rawWorkspaces: cliReady ? cliWorkspaces : readField(niri, "workspaces", "workspaces", [])
    readonly property var windows: normalizeWindows(rawWindows)
    readonly property var focusedWindow: normalizeFocusedWindow(rawFocusedWindow)
    readonly property var focusedOutput: normalizeFocusedOutput(rawFocusedOutput)
    readonly property var workspaces: buildWorkspaces(rawWorkspaces, windows)
    readonly property var workspaceGroups: groupWorkspacesByOutput(workspaces)
    readonly property var activeWorkspace: workspaces.find(workspace => workspace.isActive) ?? null
    readonly property var focusedWorkspace: workspaces.find(workspace => workspace.isFocused) ?? null
    readonly property string focusedOutputName: focusedOutput?.name
        ?? focusedWorkspace?.output
        ?? focusedWindowWorkspace()?.output
        ?? ""

    function toArray(value) {
        if (!value) return [];
        if (Array.isArray(value)) return value;
        if (value.values && Array.isArray(value.values)) return value.values;

        const result = [];
        if (typeof value.length === "number") {
            for (let i = 0; i < value.length; ++i)
                result.push(value[i]);
        }
        return result;
    }

    function hasOwn(object, key) {
        return object && Object.prototype.hasOwnProperty.call(object, key);
    }

    function readField(object, snakeName, camelName, fallback) {
        if (!object) return fallback;
        if (hasOwn(object, camelName)) return object[camelName];
        if (hasOwn(object, snakeName)) return object[snakeName];
        return fallback;
    }

    function parseJson(text, fallback, label) {
        const trimmed = String(text ?? "").trim();
        if (trimmed.length === 0)
            return fallback;

        try {
            return JSON.parse(trimmed);
        } catch (error) {
            console.warn(`Failed to parse niri ${label} JSON:`, error);
            return fallback;
        }
    }

    function refreshCliState() {
        if (!workspacesProcess.running)
            workspacesProcess.exec(["niri", "msg", "--json", "workspaces"]);
        if (!windowsProcess.running)
            windowsProcess.exec(["niri", "msg", "--json", "windows"]);
        if (!focusedWindowProcess.running)
            focusedWindowProcess.exec(["niri", "msg", "--json", "focused-window"]);
        if (!focusedOutputProcess.running)
            focusedOutputProcess.exec(["niri", "msg", "--json", "focused-output"]);
    }

    function normalizeWorkspace(raw) {
        return {
            id: readField(raw, "id", "id", null),
            idx: readField(raw, "idx", "idx", null),
            name: readField(raw, "name", "name", null),
            output: readField(raw, "output", "output", null),
            isActive: !!readField(raw, "is_active", "isActive", false),
            isFocused: !!readField(raw, "is_focused", "isFocused", false),
            isUrgent: !!readField(raw, "is_urgent", "isUrgent", false),
            activeWindowId: readField(raw, "active_window_id", "activeWindowId", null),
        };
    }

    function normalizeWindow(raw) {
        return {
            id: readField(raw, "id", "id", null),
            title: readField(raw, "title", "title", ""),
            appId: readField(raw, "app_id", "appId", ""),
            workspaceId: readField(raw, "workspace_id", "workspaceId", null),
            isFocused: !!readField(raw, "is_focused", "isFocused", false),
            isFloating: !!readField(raw, "is_floating", "isFloating", false),
            isUrgent: !!readField(raw, "is_urgent", "isUrgent", false),
        };
    }

    function normalizeWindows(rawWindows) {
        return toArray(rawWindows).map(window => normalizeWindow(window));
    }

    function normalizeFocusedWindow(rawFocusedWindow) {
        if (!rawFocusedWindow)
            return windows.find(window => window.isFocused) ?? null;
        return normalizeWindow(rawFocusedWindow);
    }

    function normalizeFocusedOutput(rawFocusedOutput) {
        if (!rawFocusedOutput)
            return null;
        return {
            name: readField(rawFocusedOutput, "name", "name", null),
            make: readField(rawFocusedOutput, "make", "make", ""),
            model: readField(rawFocusedOutput, "model", "model", ""),
            serial: readField(rawFocusedOutput, "serial", "serial", ""),
            logical: readField(rawFocusedOutput, "logical", "logical", null),
        };
    }

    function focusedWindowWorkspace() {
        if (!focusedWindow)
            return null;
        return workspaces.find(workspace => workspace.id === focusedWindow.workspaceId) ?? null;
    }

    function workspaceLabel(workspace) {
        if (workspace.name && String(workspace.name).trim().length > 0)
            return workspace.name;
        if (workspace.idx !== null && workspace.idx !== undefined)
            return String(workspace.idx);
        return "";
    }

    function compareWorkspaces(left, right) {
        const leftOutput = left.output ?? "";
        const rightOutput = right.output ?? "";
        const leftOutputIndex = outputOrder.includes(leftOutput) ? outputOrder.indexOf(leftOutput) : Number.MAX_SAFE_INTEGER;
        const rightOutputIndex = outputOrder.includes(rightOutput) ? outputOrder.indexOf(rightOutput) : Number.MAX_SAFE_INTEGER;

        if (leftOutputIndex !== rightOutputIndex)
            return leftOutputIndex - rightOutputIndex;
        if (leftOutput !== rightOutput)
            return leftOutput.localeCompare(rightOutput);
        if (left.idx !== right.idx)
            return (left.idx ?? Number.MAX_SAFE_INTEGER) - (right.idx ?? Number.MAX_SAFE_INTEGER);
        return (left.id ?? Number.MAX_SAFE_INTEGER) - (right.id ?? Number.MAX_SAFE_INTEGER);
    }

    function windowsForWorkspace(workspace, normalizedWindows) {
        return normalizedWindows.filter(window => window.workspaceId === workspace.id);
    }

    function isWorkspaceOccupied(workspace, normalizedWindows) {
        if (workspace.activeWindowId !== null && workspace.activeWindowId !== undefined)
            return true;
        return windowsForWorkspace(workspace, normalizedWindows).length > 0;
    }

    function buildWorkspaces(rawWorkspaces, normalizedWindows) {
        return toArray(rawWorkspaces)
            .map(workspace => normalizeWorkspace(workspace))
            .sort((left, right) => compareWorkspaces(left, right))
            .map(workspace => {
                const workspaceWindows = windowsForWorkspace(workspace, normalizedWindows);
                return {
                    id: workspace.id,
                    idx: workspace.idx,
                    name: workspace.name,
                    output: workspace.output,
                    isActive: workspace.isActive,
                    isFocused: workspace.isFocused,
                    isUrgent: workspace.isUrgent,
                    activeWindowId: workspace.activeWindowId,
                    label: workspaceLabel(workspace),
                    occupied: isWorkspaceOccupied(workspace, normalizedWindows),
                    windows: workspaceWindows,
                };
            });
    }

    function groupWorkspacesByOutput(normalizedWorkspaces) {
        const groups = [];
        for (const workspace of normalizedWorkspaces) {
            const output = workspace.output ?? "";
            const current = groups[groups.length - 1];
            if (!current || current.output !== output) {
                groups.push({
                    output,
                    workspaces: [workspace],
                });
            } else {
                current.workspaces.push(workspace);
            }
        }
        return groups;
    }

    function workspaceReference(workspace) {
        if (workspace.name && String(workspace.name).trim().length > 0)
            return workspace.name;
        return String(workspace.idx);
    }

    function focusWorkspace(workspace) {
        if (!workspace)
            return;

        if (niri && typeof niri.focusWorkspaceById === "function" && workspace.id !== null && workspace.id !== undefined) {
            niri.focusWorkspaceById(workspace.id);
            return;
        }

        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", workspaceReference(workspace)]);
    }

    function focusWorkspaceUp() {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-up"]);
    }

    function focusWorkspaceDown() {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
    }

    function focusWindow(window) {
        if (!window || window.id === null || window.id === undefined)
            return;
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(window.id)]);
    }

    Component.onCompleted: refreshCliState()

    Timer {
        interval: root.cliPollInterval
        running: true
        repeat: true
        onTriggered: root.refreshCliState()
    }

    Connections {
        target: root.niri
        function onRawEventReceived(event) {
            root.refreshCliState();
        }
    }

    Process {
        id: workspacesProcess
        stdout: StdioCollector {
            id: workspacesStdout
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.cliWorkspaces = root.parseJson(workspacesStdout.text, root.cliWorkspaces, "workspaces");
        }
    }

    Process {
        id: windowsProcess
        stdout: StdioCollector {
            id: windowsStdout
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.cliWindows = root.parseJson(windowsStdout.text, root.cliWindows, "windows");
        }
    }

    Process {
        id: focusedWindowProcess
        stdout: StdioCollector {
            id: focusedWindowStdout
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.cliFocusedWindow = root.parseJson(focusedWindowStdout.text, root.cliFocusedWindow, "focused-window");
        }
    }

    Process {
        id: focusedOutputProcess
        stdout: StdioCollector {
            id: focusedOutputStdout
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.cliFocusedOutput = root.parseJson(focusedOutputStdout.text, root.cliFocusedOutput, "focused-output");
        }
    }
}
