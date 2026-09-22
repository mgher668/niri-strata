import QtQuick
import Quickshell
import Quickshell.Io
import "../common/"

// WallpaperService — backend detection, folder scanning, wallpaper application.
// Delegates to swww or swaybg. Does not render wallpaper itself.

Item {
    id: root

    property bool swwwAvailable: false
    property bool swaybgAvailable: false
    property string activeBackend: "swww"
    property var detectedConflicts: []
    property var imageList: []
    property string scanStatus: "idle"
    property string scanError: ""
    property bool _initialRestoreDone: false
    property var _pendingSwwwEntries: []
    property int _swwwEntryIndex: 0
    property bool _swwwBatchSuccess: true
    property string _swwwFillColor: ""
    property var _pendingSwaybgEntries: []
    property string _swaybgFillMode: "fill"
    property string _swaybgBgColor: ""

    signal imagesReady(var paths)
    signal wallpaperApplied(bool success)

    Component.onCompleted: {
        probeBackends();
        probeConflicts();
        restoreTimer.start();
    }

    Connections {
        target: SettingsData
        function onLoadedChanged() {
            root.restoreWallpaper();
        }
    }

    Timer {
        id: restoreTimer
        interval: 100
        repeat: false
        onTriggered: root.restoreWallpaper()
    }

    function _persistedWallpaperEntries() {
        var globalPath = SettingsData.wallpaperPath;
        var entries = [];

        if (SettingsData.wallpaperPerMonitor) {
            var monitorPaths = {};
            try {
                var parsed = JSON.parse(SettingsData.wallpaperMonitorPaths);
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                    monitorPaths = parsed;
            } catch (e) {}

            var screens = Quickshell.screens;
            var monitorNames = [];
            for (var i = 0; i < screens.length; i++)
                monitorNames.push(screens[i].name);

            // If outputs are not exposed yet, still use persisted names. This
            // lets the backend receive the restore request during early login.
            if (monitorNames.length === 0)
                monitorNames = Object.keys(monitorPaths);

            for (var j = 0; j < monitorNames.length; j++) {
                var name = monitorNames[j];
                var path = monitorPaths[name];
                if ((typeof path !== "string" || path.length === 0)
                        && globalPath && globalPath.length > 0)
                    path = globalPath;
                if (typeof path === "string" && path.length > 0)
                    entries.push({ path: path, output: name });
            }
        }

        // Older settings and an empty monitor map fall back to the global
        // selection, preserving the single-wallpaper behavior.
        if (entries.length === 0 && globalPath && globalPath.length > 0)
            entries.push({ path: globalPath, output: "" });

        return entries;
    }

    function restoreWallpaper() {
        if (_initialRestoreDone || !SettingsData.loaded)
            return;

        var entries = _persistedWallpaperEntries();
        _initialRestoreDone = true;
        if (entries.length > 0)
            _applyEntries(entries);
    }

    function applyConfiguredWallpapers() {
        var entries = _persistedWallpaperEntries();
        if (entries.length > 0)
            _applyEntries(entries);
    }

    function configDir() {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        var home = Quickshell.env("HOME");
        return (xdg && xdg.length > 0) ? xdg : (home + "/.config");
    }

    // ── Backend probe ──

    function probeBackends() {
        swwwProbe.running = true;
        swaybgProbe.running = true;
    }

    Process {
        id: swwwProbe
        command: ["sh", "-c", "command -v swww && command -v swww-daemon"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                swwwAvailable = lines.length >= 2 && lines[0].length > 0 && lines[1].length > 0;
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) swwwAvailable = false;
        }
    }

    Process {
        id: swaybgProbe
        command: ["sh", "-c", "command -v swaybg"]
        stdout: StdioCollector {
            onStreamFinished: {
                swaybgAvailable = text.trim().length > 0;
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) swaybgAvailable = false;
        }
    }

    // ── Conflict probe ──

    function probeConflicts() {
        conflictProbe.running = true;
    }

    Process {
        id: conflictProbe
        command: ["sh", "-c",
            "pgrep -x swww-daemon 2>/dev/null && echo swww-daemon; "
            + "pgrep -x swaybg 2>/dev/null && echo swaybg; "
            + "pgrep -x hyprpaper 2>/dev/null && echo hyprpaper; "
            + "pgrep -x wpaperd 2>/dev/null && echo wpaperd"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(s => s.length > 0);
                detectedConflicts = lines;
            }
        }
    }

    // ── Folder scanning ──

    function scanFolders(dirs, recursive, sortBy, sortOrder) {
        if (!dirs || dirs.length === 0) {
            imageList = [];
            scanStatus = "ready";
            imagesReady([]);
            return;
        }

        scanStatus = "scanning";
        scanError = "";

        // Build combined scan command for all dirs
        var parts = [];
        for (var i = 0; i < dirs.length; i++) {
            var d = dirs[i];
            if (recursive) {
                parts.push('find "' + d + '" -type f \\( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.bmp" -o -name "*.gif" \\)');
            } else {
                parts.push('ls -1 "' + d + '"/*.jpg "' + d + '"/*.jpeg "' + d + '"/*.png "' + d + '"/*.webp "' + d + '"/*.bmp "' + d + '"/*.gif 2>/dev/null');
            }
        }
        var cmd = parts.join(" 2>/dev/null; ");

        _currentSortBy = sortBy;
        _currentSortOrder = sortOrder;
        scanProcess.command = ["sh", "-c", cmd];
        scanProcess.running = true;
    }

    property string _currentSortBy: "name"
    property string _currentSortOrder: "ascending"

    Process {
        id: scanProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(s => s.length > 0);

                // Sort
                if (_currentSortBy === "date") {
                    // If using find without -printf, we don't have dates.
                    // Fall back to name sort.
                }
                lines.sort((a, b) => {
                    // Sort the complete path so the grid has a deterministic
                    // top-to-bottom order, including duplicate filenames in
                    // different folders.
                    var pathA = a.toLowerCase();
                    var pathB = b.toLowerCase();
                    var result = pathA.localeCompare(pathB);
                    return result !== 0 ? result : a.localeCompare(b);
                });
                if (_currentSortOrder === "descending")
                    lines.reverse();

                imageList = lines;
                scanStatus = "ready";
                imagesReady(lines);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length > 0)
                    scanError = msg.split("\n")[0];
            }
        }
        onExited: (exitCode) => {
            if (scanStatus === "scanning" && imageList.length === 0) {
                scanStatus = "ready";
                imageList = [];
                imagesReady([]);
            }
        }
    }

    // ── Apply wallpaper ──

    function applyWallpaper(path, output) {
        if (!path || path.length === 0)
            return;

        _applyEntries([{ path: path, output: output || "" }]);
    }

    function _applyEntries(entries) {
        if (!entries || entries.length === 0)
            return;

        var backend = SettingsData.wallpaperBackend;
        var fillColor = SettingsData.wallpaperBgColor;
        var fillMode = SettingsData.wallpaperFillMode;

        if (backend === "swww") {
            _applySwwwEntries(entries, fillColor);
        } else if (backend === "swaybg") {
            _applySwaybgEntries(entries, fillMode, fillColor);
        }
    }

    function _applySwww(path, output, fillColor) {
        _applySwwwEntries([{ path: path, output: output || "" }], fillColor);
    }

    function _applySwwwEntries(entries, fillColor) {
        _pendingSwwwEntries = entries;
        _swwwEntryIndex = 0;
        _swwwBatchSuccess = true;
        _swwwFillColor = fillColor || "";

        // Check daemon, start if needed. The daemon must be backgrounded so
        // this process can exit and the image command can run.
        swwwDaemonCheck.command = ["sh", "-c",
            "if pgrep -x swww-daemon >/dev/null 2>&1; then exit 0; fi; "
            + "swww-daemon >/dev/null 2>&1 &"];
        swwwDaemonCheck.running = true;
    }

    Process {
        id: swwwDaemonCheck
        command: []
        onExited: {
            // Small delay for a newly spawned daemon to be ready.
            swwwReadyDelay.restart();
        }
    }

    Timer {
        id: swwwReadyDelay
        interval: 500
        repeat: false
        onTriggered: root._runNextSwww()
    }

    function _runNextSwww() {
        if (_swwwEntryIndex >= _pendingSwwwEntries.length) {
            wallpaperApplied(_swwwBatchSuccess);
            return;
        }

        var entry = _pendingSwwwEntries[_swwwEntryIndex];
        var args = ["swww", "img", entry.path, "--transition-type", "fade"];
        if (entry.output && entry.output.length > 0)
            args.push("-o", entry.output);
        if (_swwwFillColor.length > 0)
            args.push("--fill-color", _swwwFillColor);

        applyProcess.command = args;
        applyProcess.running = true;
    }

    function _applySwaybg(path, output, fillMode, bgColor) {
        _applySwaybgEntries(
            [{ path: path, output: output || "" }],
            fillMode,
            bgColor
        );
    }

    function _applySwaybgEntries(entries, fillMode, bgColor) {
        _pendingSwaybgEntries = entries;
        _swaybgFillMode = fillMode || "fill";
        _swaybgBgColor = bgColor || "";

        // Kill previous swaybg instances once, then launch one detached
        // process per output. This keeps per-monitor restore independent.
        swaybgKill.command = ["pkill", "-x", "swaybg"];
        swaybgKill.running = true;
    }

    Process {
        id: swaybgKill
        command: []
        onExited: {
            for (var i = 0; i < _pendingSwaybgEntries.length; i++) {
                var entry = _pendingSwaybgEntries[i];
                var args = ["swaybg", "-i", entry.path, "-m", _swaybgFillMode];
                if (entry.output && entry.output.length > 0)
                    args.push("-o", entry.output);
                if (_swaybgBgColor.length > 0)
                    args.push("-c", _swaybgBgColor);
                Quickshell.execDetached(args);
            }
            wallpaperApplied(true);
        }
    }

    Process {
        id: applyProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length > 0)
                    console.warn("Wallpaper apply error:", msg.split("\n")[0]);
            }
        }
        onExited: (exitCode) => {
            _swwwEntryIndex++;
            if (exitCode !== 0) {
                _swwwBatchSuccess = false;
                console.warn("Wallpaper apply error: swww exited with code " + exitCode);
            }
            if (_swwwEntryIndex < _pendingSwwwEntries.length)
                root._runNextSwww();
            else
                wallpaperApplied(_swwwBatchSuccess);
        }
    }
}
