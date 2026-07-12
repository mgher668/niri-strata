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

    signal imagesReady(var paths)
    signal wallpaperApplied(bool success)

    Component.onCompleted: {
        probeBackends();
        probeConflicts();
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
                    var nameA = a.split("/").pop().toLowerCase();
                    var nameB = b.split("/").pop().toLowerCase();
                    return nameA.localeCompare(nameB);
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
        if (!path || path.length === 0) return;

        var backend = SettingsData.wallpaperBackend;
        var fillColor = SettingsData.wallpaperBgColor;
        var fillMode = SettingsData.wallpaperFillMode;

        if (backend === "swww") {
            _applySwww(path, output, fillColor);
        } else if (backend === "swaybg") {
            _applySwaybg(path, output, fillMode, fillColor);
        }
    }

    function _applySwww(path, output, fillColor) {
        var args = ["swww", "img", path, "--transition-type", "fade"];
        if (output && output.length > 0)
            args.push("-o", output);
        if (fillColor && fillColor.length > 0)
            args.push("--fill-color", fillColor);

        // Check daemon, start if needed
        swwwDaemonCheck.command = ["sh", "-c", "pgrep -x swww-daemon || swww-daemon"];
        swwwDaemonCheck._pendingArgs = args;
        swwwDaemonCheck.running = true;
    }

    Process {
        id: swwwDaemonCheck
        property var _pendingArgs: []
        command: []
        onExited: (exitCode) => {
            // Small delay for daemon to be ready
            applyProcess.command = _pendingArgs;
            applyProcess.running = true;
        }
    }

    function _applySwaybg(path, output, fillMode, bgColor) {
        // Kill previous swaybg first
        swaybgKill.command = ["pkill", "-x", "swaybg"];
        swaybgKill._pendingArgs = ["swaybg", "-i", path, "-m", fillMode || "fill"];
        if (output && output.length > 0)
            swaybgKill._pendingArgs.push("-o", output);
        if (bgColor && bgColor.length > 0)
            swaybgKill._pendingArgs.push("-c", bgColor);
        swaybgKill.running = true;
    }

    Process {
        id: swaybgKill
        property var _pendingArgs: []
        command: []
        onExited: {
            applyProcess.command = _pendingArgs;
            applyProcess.running = true;
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
            wallpaperApplied(exitCode === 0);
        }
    }
}