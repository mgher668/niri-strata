import QtQuick
import Quickshell

Item {
    id: root

    required property var niri

    property var eventWorkspaces: []
    property var eventWindows: []
    property var eventFocusedOutput: null

    readonly property var outputOrder: Quickshell.screens.map(screen => screen.name)
    readonly property var rawWindows: eventWindows.length > 0 ? eventWindows : toArray(readField(niri, "windows", "windows", []))
    readonly property var rawFocusedWindow: readField(niri, "focused_window", "focusedWindow", null)
        ?? rawWindows.find(window => !!readField(window, "is_focused", "isFocused", false))
        ?? null
    readonly property var rawFocusedOutput: eventFocusedOutput
    readonly property var rawWorkspaces: eventWorkspaces.length > 0 ? eventWorkspaces : toArray(readField(niri, "workspaces", "workspaces", []))
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
        if (typeof value.count === "number" && typeof value.get === "function") {
            const result = [];
            for (let i = 0; i < value.count; ++i)
                result.push(value.get(i));
            return result;
        }

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
        if (hasOwn(object, camelName) || object[camelName] !== undefined) return object[camelName];
        if (hasOwn(object, snakeName) || object[snakeName] !== undefined) return object[snakeName];
        return fallback;
    }

    function copyObject(object) {
        if (!object || typeof object !== "object")
            return {};
        return Object.assign({}, object);
    }

    function setField(object, snakeName, camelName, value) {
        object[snakeName] = value;
        object[camelName] = value;
    }

    function itemId(item) {
        return readField(item, "id", "id", null);
    }

    function updateWorkspace(id, updater) {
        let changed = false;
        const nextWorkspaces = eventWorkspaces.map(workspace => {
            if (itemId(workspace) !== id)
                return workspace;

            const next = copyObject(workspace);
            updater(next);
            changed = true;
            return next;
        });

        if (changed)
            eventWorkspaces = nextWorkspaces;
    }

    function handleWorkspacesChanged(payload) {
        eventWorkspaces = toArray(readField(payload, "workspaces", "workspaces", [])).map(workspace => copyObject(workspace));
    }

    function handleWorkspaceActivated(payload) {
        const id = readField(payload, "id", "id", null);
        const focused = !!readField(payload, "focused", "focused", false);
        const activated = eventWorkspaces.find(workspace => itemId(workspace) === id);
        if (!activated)
            return;

        const output = readField(activated, "output", "output", "");
        eventWorkspaces = eventWorkspaces.map(workspace => {
            const next = copyObject(workspace);
            const isTarget = itemId(workspace) === id;
            if (readField(workspace, "output", "output", "") === output)
                setField(next, "is_active", "isActive", isTarget);
            if (focused)
                setField(next, "is_focused", "isFocused", isTarget);
            return next;
        });
    }

    function handleWorkspaceActiveWindowChanged(payload) {
        const workspaceId = readField(payload, "workspace_id", "workspaceId", null);
        const activeWindowId = readField(payload, "active_window_id", "activeWindowId", null);
        updateWorkspace(workspaceId, workspace => setField(workspace, "active_window_id", "activeWindowId", activeWindowId));
    }

    function handleWorkspaceUrgencyChanged(payload) {
        const id = readField(payload, "id", "id", null);
        const urgent = !!readField(payload, "urgent", "urgent", false);
        updateWorkspace(id, workspace => setField(workspace, "is_urgent", "isUrgent", urgent));
    }

    function handleWindowsChanged(payload) {
        eventWindows = toArray(readField(payload, "windows", "windows", [])).map(window => copyObject(window));
    }

    function handleWindowOpenedOrChanged(payload) {
        const window = copyObject(readField(payload, "window", "window", null));
        const id = itemId(window);
        if (id === null || id === undefined)
            return;

        const focused = !!readField(window, "is_focused", "isFocused", false);
        const nextWindows = eventWindows.map(existing => {
            const next = copyObject(existing);
            if (itemId(existing) === id)
                return window;
            if (focused)
                setField(next, "is_focused", "isFocused", false);
            return next;
        });

        if (!nextWindows.some(existing => itemId(existing) === id))
            nextWindows.push(window);

        eventWindows = nextWindows;
    }

    function handleWindowClosed(payload) {
        const id = readField(payload, "id", "id", null);
        eventWindows = eventWindows.filter(window => itemId(window) !== id);
    }

    function handleWindowFocusChanged(payload) {
        const id = readField(payload, "id", "id", null);
        eventWindows = eventWindows.map(window => {
            const next = copyObject(window);
            setField(next, "is_focused", "isFocused", id !== null && id !== undefined && itemId(window) === id);
            return next;
        });
    }

    function handleOutputFocusChanged(payload) {
        const output = readField(payload, "output", "output", null) ?? payload;
        eventFocusedOutput = typeof output === "string" ? { name: output } : output;
    }

    function handleRawEvent(event) {
        if (!event)
            return;

        if (event.WorkspacesChanged)
            handleWorkspacesChanged(event.WorkspacesChanged);
        else if (event.WorkspaceActivated)
            handleWorkspaceActivated(event.WorkspaceActivated);
        else if (event.WorkspaceActiveWindowChanged)
            handleWorkspaceActiveWindowChanged(event.WorkspaceActiveWindowChanged);
        else if (event.WorkspaceUrgencyChanged)
            handleWorkspaceUrgencyChanged(event.WorkspaceUrgencyChanged);
        else if (event.WindowsChanged)
            handleWindowsChanged(event.WindowsChanged);
        else if (event.WindowOpenedOrChanged)
            handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
        else if (event.WindowClosed)
            handleWindowClosed(event.WindowClosed);
        else if (event.WindowFocusChanged)
            handleWindowFocusChanged(event.WindowFocusChanged);
        else if (event.OutputFocusChanged)
            handleOutputFocusChanged(event.OutputFocusChanged);
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

    function focusWorkspaceByStep(step) {
        const current = focusedWorkspace ?? activeWorkspace;
        if (!current)
            return;

        const candidates = workspaces.filter(workspace => workspace.output === current.output);
        const currentIndex = candidates.findIndex(workspace => workspace.id === current.id);
        const nextIndex = currentIndex + step;
        if (currentIndex < 0 || nextIndex < 0 || nextIndex >= candidates.length)
            return;

        focusWorkspace(candidates[nextIndex]);
    }

    function focusWorkspaceUp() {
        focusWorkspaceByStep(-1);
    }

    function focusWorkspaceDown() {
        focusWorkspaceByStep(1);
    }

    function focusWindow(window) {
        if (!window || window.id === null || window.id === undefined)
            return;
        if (niri && typeof niri.focusWindow === "function") {
            niri.focusWindow(window.id);
            return;
        }
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(window.id)]);
    }

    Connections {
        target: root.niri
        function onRawEventReceived(event) {
            root.handleRawEvent(event);
        }
    }
}
