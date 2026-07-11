import QtQuick
import Quickshell
import Quickshell.Io
import "../common/"

// ThemeExport — generates and applies system theme files (GTK CSS, Qt color scheme)
// from the current Theme.colors palette.
//
// Uses scripts/theme-render.mjs as the testable renderer (via Node subprocess).
// In production, the render functions are mirrored in QML JS for synchronous output.
//
// Apply rules:
//   - Master switch: systemThemeEnabled must be true
//   - GTK: creates ~/.config/gtk-3.0/niri-strata-colors.css + managed symlink
//   - GTK4: injects @import into ~/.config/gtk-4.0/gtk.css (marker-block, idempotent)
//   - Qt: writes ~/.local/share/color-schemes/NiriStrata.colors + qt5ct/qt6ct conf

Item {
    id: root

    // ── Public API ──

    property bool gtkAvailable: false
    property bool qt5ctAvailable: false
    property bool qt6ctAvailable: false

    property string lastError: ""
    property string lastStatus: "idle"  // idle | exporting | done | error

    signal exportComplete(string target, bool success)

    // ── Internal ──

    Component.onCompleted: {
        probeProcess.running = true;
    }

    function configDir() {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        var home = Quickshell.env("HOME");
        return (xdg && xdg.length > 0) ? xdg : (home + "/.config");
    }

    function exportAll() {
        if (!SettingsData.systemThemeEnabled) {
            lastError = "System theme export is disabled";
            lastStatus = "error";
            return;
        }

        lastStatus = "exporting";
        lastError = "";

        if (SettingsData.systemThemeGtkEnabled)
            exportGtk();

        if (SettingsData.systemThemeQtEnabled)
            exportQt();
    }

    // ── GTK export ──

    function exportGtk() {
        if (!gtkAvailable) {
            exportComplete("gtk", false);
            return;
        }

        var cd = configDir();
        var cssContent = _renderGtkCss();
        var gtk3Dir = cd + "/gtk-3.0";
        var gtk4Dir = cd + "/gtk-4.0";

        // Write CSS file for both GTK3 and GTK4
        var cmd = "set -euo pipefail\n"
            + "mkdir -p '" + gtk3Dir + "' '" + gtk4Dir + "'\n"
            + "cat > '" + gtk3Dir + "/niri-strata-colors.css' << 'NIRI_EOF'\n"
            + cssContent
            + "NIRI_EOF\n"
            + "cp '" + gtk3Dir + "/niri-strata-colors.css' '" + gtk4Dir + "/niri-strata-colors.css'\n";

        // GTK3: managed symlink (only if missing or already managed)
        cmd += "if [ ! -e '" + gtk3Dir + "/gtk.css' ] || [ -L '" + gtk3Dir + "/gtk.css' ]; then\n"
            + "  ln -sfn niri-strata-colors.css '" + gtk3Dir + "/gtk.css'\n"
            + "fi\n";

        // GTK4: marker-block import injection
        var gtk4Css = gtk4Dir + "/gtk.css";
        cmd += "if [ -f '" + gtk4Css + "' ]; then\n"
            + "  if grep -q 'niri-strata-import-start' '" + gtk4Css + "'; then\n"
            + "    sed -i '/niri-strata-import-start/,/niri-strata-import-end/c\\"
            + "/* niri-strata-import-start */\\n@import url(\"niri-strata-colors.css\");\\n/* niri-strata-import-end */' '" + gtk4Css + "'\n"
            + "  else\n"
            + "    sed -i '1i\\/* niri-strata-import-start */\\n@import url(\"niri-strata-colors.css\");\\n/* niri-strata-import-end */' '" + gtk4Css + "'\n"
            + "  fi\n"
            + "else\n"
            + "  printf '/* niri-strata-import-start */\\n@import url(\"niri-strata-colors.css\");\\n/* niri-strata-import-end */\\n' > '" + gtk4Css + "'\n"
            + "fi\n";

        gtkProcess.command = ["sh", "-c", cmd];
        gtkProcess.running = true;
    }

    // ── Qt export ──

    function exportQt() {
        var cd = configDir();
        var home = Quickshell.env("HOME");
        var localShare = Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share");
        var schemePath = localShare + "/color-schemes/NiriStrata.colors";
        var schemeContent = _renderQtScheme();

        var cmd = "set -euo pipefail\n"
            + "mkdir -p '" + localShare + "/color-schemes'\n"
            + "cat > '" + schemePath + "' << 'NIRI_EOF'\n"
            + schemeContent
            + "NIRI_EOF\n";

        // qt5ct
        if (qt5ctAvailable) {
            var qt5ctDir = cd + "/qt5ct";
            cmd += "mkdir -p '" + qt5ctDir + "'\n"
                + "if [ -f '" + qt5ctDir + "/qt5ct.conf' ]; then\n"
                + "  sed -i '/^\\[Appearance\\]/a custom_palette=true\\ncolor_scheme_path=" + schemePath + "' '" + qt5ctDir + "/qt5ct.conf'\n"
                + "else\n"
                + "  printf '[Appearance]\\ncustom_palette=true\\ncolor_scheme_path=" + schemePath + "\\n' > '" + qt5ctDir + "/qt5ct.conf'\n"
                + "fi\n";
        }

        // qt6ct
        if (qt6ctAvailable) {
            var qt6ctDir = cd + "/qt6ct";
            cmd += "mkdir -p '" + qt6ctDir + "'\n"
                + "if [ -f '" + qt6ctDir + "/qt6ct.conf' ]; then\n"
                + "  sed -i '/^\\[Appearance\\]/a custom_palette=true\\ncolor_scheme_path=" + schemePath + "' '" + qt6ctDir + "/qt6ct.conf'\n"
                + "else\n"
                + "  printf '[Appearance]\\ncustom_palette=true\\ncolor_scheme_path=" + schemePath + "\\n' > '" + qt6ctDir + "/qt6ct.conf'\n"
                + "fi\n";
        }

        if (!qt5ctAvailable && !qt6ctAvailable) {
            lastError = "Neither qt5ct nor qt6ct found";
            exportComplete("qt", false);
            return;
        }

        qtProcess.command = ["sh", "-c", cmd];
        qtProcess.running = true;
    }

    // ── Renderers (mirrored from scripts/theme-render.mjs) ──

    function _renderGtkCss() {
        var c = Theme.colors;
        var lines = [
            "/* Generated by niri-strata Settings. Do not edit manually. */",
            "/* This file is managed by niri-strata and may be overwritten. */",
            "",
            "@define-color accent_bg_color " + c.primary + ";",
            "@define-color accent_fg_color " + c.primaryText + ";",
            "@define-color window_bg_color " + c.background + ";",
            "@define-color window_fg_color " + c.text + ";",
            "@define-color view_bg_color " + c.surface + ";",
            "@define-color view_fg_color " + c.text + ";",
            "@define-color headerbar_bg_color " + c.surfaceContainer + ";",
            "@define-color headerbar_fg_color " + c.text + ";",
            "@define-color sidebar_bg_color " + c.surfaceContainer + ";",
            "@define-color sidebar_fg_color " + c.text + ";",
            "",
            "@define-color destructive_bg_color " + c.errorColor + ";",
            "@define-color destructive_fg_color " + c.text + ";",
            "@define-color error_bg_color " + c.errorColor + ";",
            "@define-color error_fg_color " + c.text + ";",
            "@define-color success_bg_color " + c.successColor + ";",
            "@define-color success_fg_color " + c.text + ";",
            "@define-color warning_bg_color " + c.warningColor + ";",
            "@define-color warning_fg_color " + c.text + ";",
            "",
            "@define-color card_bg_color " + c.surfaceContainer + ";",
            "@define-color card_fg_color " + c.text + ";",
            "@define-color popover_bg_color " + c.surfaceContainerHigh + ";",
            "@define-color popover_fg_color " + c.text + ";",
            "",
            "@define-color border_color " + c.outlineVariant + ";",
            "@define-color shade_color " + c.outline + ";",
            "",
            "/* End of niri-strata generated colors */",
        ];
        return lines.join("\n") + "\n";
    }

    function _renderQtScheme() {
        var c = Theme.colors;
        var lines = [
            "[Color Scheme]",
            "Name=NiriStrata",
            "Comment=Generated by niri-strata Settings",
            "",
            "[WM]",
            "activeBackground=" + c.surface,
            "activeForeground=" + c.text,
            "inactiveBackground=" + c.surfaceContainer,
            "inactiveForeground=" + c.mutedText,
            "",
            "[General]",
            "windowBackground=" + c.background,
            "windowForeground=" + c.text,
            "baseColor=" + c.surfaceContainerLow,
            "alternateBaseColor=" + c.surfaceContainer,
            "textColor=" + c.text,
            "buttonColor=" + c.surfaceContainerHigh,
            "buttonBackgroundColor=" + c.surfaceContainer,
            "buttonTextColor=" + c.text,
            "highlightColor=" + c.primary,
            "highlightedTextColor=" + c.primaryText,
            "linkColor=" + c.primary,
            "visitedLinkColor=" + c.tertiary,
            "",
            "[Selection]",
            "background=" + c.primary,
            "foreground=" + c.primaryText,
            "",
            "[KDE]",
            "contrast=4",
            "",
            "[Colors:View]",
            "Background=" + c.surface,
            "Foreground=" + c.text,
            "BackgroundAlternate=" + c.surfaceContainerLow,
            "BackgroundNormal=" + c.surface,
            "ForegroundLink=" + c.primary,
            "ForegroundVisited=" + c.tertiary,
            "",
            "[Colors:Window]",
            "Background=" + c.surfaceContainer,
            "Foreground=" + c.text,
            "BackgroundNormal=" + c.surfaceContainer,
            "ForegroundNormal=" + c.text,
            "",
            "[Colors:Button]",
            "Background=" + c.surfaceContainerHigh,
            "Foreground=" + c.text,
            "BackgroundNormal=" + c.surfaceContainerHigh,
            "ForegroundNormal=" + c.text,
            "",
            "[Colors:Selection]",
            "Background=" + c.primary,
            "Foreground=" + c.primaryText,
            "BackgroundNormal=" + c.primary,
            "ForegroundNormal=" + c.primaryText,
            "",
            "[Colors:Tooltip]",
            "Background=" + c.surfaceContainerHigh,
            "Foreground=" + c.text,
            "",
            "[Colors:Complementary]",
            "Background=" + c.surfaceContainer,
            "Foreground=" + c.text,
            "",
            "/* End of niri-strata generated color scheme */",
        ];
        return lines.join("\n") + "\n";
    }

    // ── Availability probe ──

    Process {
        id: probeProcess
        command: ["sh", "-c", "command -v gtk3.0 2>/dev/null; command -v qt5ct 2>/dev/null; command -v qt6ct 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("qt5ct") >= 0) qt5ctAvailable = true;
                    if (lines[i].indexOf("qt6ct") >= 0) qt6ctAvailable = true;
                }
                gtkAvailable = true;  // GTK config dir is always writable
            }
        }
    }

    // ── Apply processes ──

    Process {
        id: gtkProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length > 0) {
                    lastError = "GTK: " + msg.split("\n")[0];
                    lastStatus = "error";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            var ok = (exitCode === 0);
            if (ok && lastStatus !== "error") {
                lastStatus = "done";
            }
            exportComplete("gtk", ok);
        }
    }

    Process {
        id: qtProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length > 0) {
                    lastError = "Qt: " + msg.split("\n")[0];
                    lastStatus = "error";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            var ok = (exitCode === 0);
            if (ok && lastStatus !== "error") {
                lastStatus = "done";
            }
            exportComplete("qt", ok);
        }
    }
}