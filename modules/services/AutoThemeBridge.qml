import QtQuick
import Quickshell
import Quickshell.Io
import "../common/"

// AutoThemeBridge — watches daemon state file via FileView.
// File is touched before shell start so FileView can register its watch.

Item {
    id: root

    property string _lastApplied: ""

    function _refresh() {
        stateFile.reload();
        _apply();
    }

    FileView {
        id: stateFile
        path: {
            var xdg = Quickshell.env("XDG_CONFIG_HOME");
            var home = Quickshell.env("HOME");
            var base = (xdg && xdg.length > 0) ? xdg : (home + "/.config");
            return base + "/quickshell/niri-strata/auto-theme-state.json";
        }
        blockLoading: true
        watchChanges: true

        onLoaded: root._apply()
        onFileChanged: refreshDebounce.restart()
    }

    Timer {
        id: refreshDebounce
        interval: 50
        repeat: false
        onTriggered: root._refresh()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._refresh()
    }

    function _apply() {
        if (typeof Theme === "undefined") return;

        var raw = stateFile.text();
        if (!raw) return;
        var desired = raw.trim();
        if (desired !== "dark" && desired !== "light") return;
        if (desired === _lastApplied) return;

        _lastApplied = desired;
        Theme._autoLight = (desired === "light");
    }
}
