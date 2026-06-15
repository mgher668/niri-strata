import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property bool available: profiles.length > 0 && errorText.length === 0
    readonly property string statusText: available ? activeProfile || "Unknown" : "Unavailable"

    property var profiles: []
    property string activeProfile: ""
    property string errorText: ""

    function refresh() {
        errorText = "";
        getProcess.running = true;
        listProcess.running = true;
    }

    function parseProfiles(text) {
        profiles = String(text ?? "").split("\n")
            .map(line => line.trim())
            .filter(line => line.endsWith(":"))
            .map(line => ({
                name: line.replace(/^\*\s*/, "").replace(/:$/, ""),
                active: line.startsWith("*"),
            }));

        const active = profiles.find(profile => profile.active);
        if (active)
            activeProfile = active.name;
    }

    function setProfile(profile) {
        if (!profile)
            return;
        setProcess.exec(["powerprofilesctl", "set", profile]);
    }

    Component.onCompleted: startupRefreshTimer.start()

    Timer {
        id: startupRefreshTimer
        interval: 2600
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: getProcess
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                if (value.length > 0)
                    root.activeProfile = value;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorText = "power-profiles-daemon unavailable";
            }
        }
    }

    Process {
        id: listProcess
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseProfiles(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorText = "power-profiles-daemon unavailable";
            }
        }
    }

    Process {
        id: setProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.errorText = "Could not change power profile";
            root.refresh();
        }
    }
}
