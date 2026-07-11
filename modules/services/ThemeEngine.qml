import QtQuick
import Quickshell
import Quickshell.Io
import "../common/"

// ThemeEngine — wraps matugen for wallpaper-based dynamic palette generation.
// Runs `matugen image <path> --json hex --dry-run` and parses the JSON output.
// Emits paletteReady with a { dark: {...}, light: {...} } palette object
// matching the ThemePresets.js shape.

Item {
    id: root

    // ── Public API ──

    property bool matugenAvailable: false
    property string wallpaperPath: ""
    property string status: "idle"  // idle | generating | ready | error
    property string errorMessage: ""

    signal paletteReady(var palette)

    // ── Internal ──

    Component.onCompleted: {
        probeProcess.running = true;
    }

    function generate(path) {
        if (!matugenAvailable) {
            status = "error";
            errorMessage = "matugen not installed";
            return;
        }

        if (!path || path.length === 0) {
            status = "error";
            errorMessage = "No wallpaper path";
            return;
        }

        wallpaperPath = path;
        status = "generating";
        errorMessage = "";

        matugenProcess.command = [
            "matugen", "image", path,
            "--json", "hex",
            "--dry-run",
            "-q",
        ];
        matugenProcess.running = true;
    }

    function generateFromHex(hex) {
        if (!matugenAvailable) {
            status = "error";
            errorMessage = "matugen not installed";
            return;
        }

        status = "generating";
        errorMessage = "";

        matugenProcess.command = [
            "matugen", "color", "hex", hex,
            "--json", "hex",
            "--dry-run",
            "-q",
        ];
        matugenProcess.running = true;
    }

    function _parseOutput(text) {
        try {
            var json = JSON.parse(text);
            if (!json || !json.colors) {
                status = "error";
                errorMessage = "matugen output missing 'colors' key";
                return;
            }

            var palette = _mapToPalette(json.colors);
            status = "ready";
            errorMessage = "";
            paletteReady(palette);
        } catch (e) {
            status = "error";
            errorMessage = "Failed to parse matugen output: " + e.message;
        }
    }

    // ── matugen → ThemePresets palette mapping ──
    // Mirrors harness/lib/matugen-mapper.mjs (kept in sync manually).

    function _mapToPalette(colors) {
        var dark = {};
        var light = {};

        var directMap = {
            "background": "background",
            "surface": "surface",
            "primary": "primary",
            "on_primary": "primaryText",
            "primary_container": "primaryContainer",
            "on_primary_container": "primaryContainerText",
            "secondary": "secondary",
            "secondary_container": "secondaryContainer",
            "on_secondary_container": "secondaryContainerText",
            "tertiary": "tertiary",
            "tertiary_container": "tertiaryContainer",
            "on_tertiary_container": "tertiaryContainerText",
            "error": "errorColor",
            "error_container": "errorContainer",
            "on_surface": "text",
            "on_surface_variant": "mutedText",
            "outline": "outline",
            "outline_variant": "outlineVariant",
            "surface_container_lowest": "surfaceContainerLowest",
            "surface_container_low": "surfaceContainerLow",
            "surface_container": "surfaceContainer",
            "surface_container_high": "surfaceContainerHigh",
            "surface_container_highest": "surfaceContainerHighest",
            "scrim": "scrim",
        };

        for (var matugenName in directMap) {
            if (!directMap.hasOwnProperty(matugenName)) continue;
            var paletteName = directMap[matugenName];
            var entry = colors[matugenName];
            if (!entry) continue;

            if (entry.dark && entry.dark.color)
                dark[paletteName] = entry.dark.color;
            if (entry.light && entry.light.color)
                light[paletteName] = entry.light.color;
        }

        // Derived fields
        var derived = {
            "layer0": "surfaceContainerLowest",
            "layer1": "surfaceContainerLow",
            "layer1Hover": "surfaceContainer",
            "layer1Active": "surfaceContainerHigh",
            "subtleText": "mutedText",
        };

        for (var dName in derived) {
            if (!derived.hasOwnProperty(dName)) continue;
            var src = derived[dName];
            if (dark[src]) dark[dName] = dark[src];
            if (light[src]) light[dName] = light[src];
        }

        // Hardcoded fallbacks for success/warning
        dark.successColor = "#9ed9b3";
        dark.successContainer = "#1f5234";
        dark.warningColor = "#f3cf7a";
        dark.warningContainer = "#5a471b";
        light.successColor = "#1a7a3a";
        light.successContainer = "#c4f0d4";
        light.warningColor = "#8a7a1a";
        light.warningContainer = "#fef8d8";

        return { dark: dark, light: light };
    }

    // ── matugen availability probe ──

    Process {
        id: probeProcess
        command: ["sh", "-c", "command -v matugen"]
        stdout: StdioCollector {
            onStreamFinished: {
                matugenAvailable = (text.trim().length > 0);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                matugenAvailable = false;
        }
    }

    // ── matugen execution ──

    Process {
        id: matugenProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._parseOutput(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length > 0 && root.status === "generating") {
                    root.status = "error";
                    root.errorMessage = msg.split("\n")[0];
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.status === "generating") {
                root.status = "error";
                if (errorMessage.length === 0)
                    errorMessage = "matugen exited with code " + exitCode;
            }
        }
    }
}