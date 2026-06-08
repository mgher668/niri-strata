import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property bool screenshotAvailable: tools.niri && tools.wlCopy
    readonly property bool recordingAvailable: tools.niri && tools.wfRecorder
    readonly property bool regionRecordingAvailable: tools.slurp && tools.wfRecorder
    readonly property string screenshotStatus: screenshotAvailable ? "Clipboard" : "Unavailable"
    readonly property string recordingStatus: recordingActive ? "Recording" : recordingAvailable ? "Focused output" : "Unavailable"
    readonly property string regionRecordingStatus: regionRecordingStarting ? "Selecting area" : regionRecordingActive ? "Recording region" : regionRecordingAvailable ? "Select region" : "Unavailable"
    readonly property var regionRecordingCommand: [
        "bash",
        "-lc",
        "set -euo pipefail\ndir=\"$HOME/Videos/Screen Recordings\"\nmkdir -p \"$dir\"\nfile=\"$dir/recording-region-$(date +%Y%m%d-%H%M%S).mp4\"\ngeometry=\"$(slurp)\"\n[ -n \"$geometry\" ]\nexec wf-recorder -g \"$geometry\" -f \"$file\"",
    ]

    property bool recordingActive: false
    property bool regionRecordingActive: false
    property bool regionRecordingStarting: false
    property int regionRecordingStartGraceTicks: 0
    property bool screenshotBusy: false
    property var tools: ({
        grim: false,
        niri: false,
        slurp: false,
        wlCopy: false,
        wfRecorder: false,
    })
    property string errorText: ""

    function refresh() {
        probeProcess.running = true;
    }

    function parseTools(text) {
        const next = {
            grim: false,
            niri: false,
            slurp: false,
            wlCopy: false,
            wfRecorder: false,
        };

        for (const rawLine of String(text ?? "").split("\n")) {
            const parts = rawLine.trim().split("=");
            const available = parts[1] === "1";

            if (parts[0] === "grim")
                next.grim = available;
            else if (parts[0] === "niri")
                next.niri = available;
            else if (parts[0] === "slurp")
                next.slurp = available;
            else if (parts[0] === "wl-copy")
                next.wlCopy = available;
            else if (parts[0] === "wf-recorder")
                next.wfRecorder = available;
        }

        tools = next;
    }

    function takeScreenshot() {
        if (!screenshotAvailable || screenshotProcess.running)
            return;

        errorText = "";
        screenshotBusy = true;
        screenshotProcess.running = true;
    }

    function toggleRecording() {
        if (!recordingAvailable)
            return;

        if (recordingActive) {
            recordingActive = false;
            if (!stopRecordingProcess.running)
                stopRecordingProcess.running = true;
        } else if (!regionRecordingActive && !startRecordingProcess.running) {
            recordingActive = true;
            startRecordingProcess.running = true;
        }
    }

    function toggleRegionRecording() {
        if (!regionRecordingAvailable)
            return;

        if (regionRecordingActive || regionRecordingStarting) {
            regionRecordingActive = false;
            regionRecordingStarting = false;
            regionRecordingStartGraceTicks = 0;
            if (!stopRecordingProcess.running)
                stopRecordingProcess.running = true;
        } else if (!recordingActive) {
            regionRecordingActive = true;
            regionRecordingStarting = true;
            regionRecordingStartGraceTicks = 8;
            Quickshell.execDetached(regionRecordingCommand);
            if (!regionRecordingMonitorTimer.running)
                regionRecordingMonitorTimer.start();
            refreshRegionRecordingState();
        }
    }

    function refreshRegionRecordingState() {
        if ((regionRecordingActive || regionRecordingStarting) && !regionRecordingMonitorProcess.running)
            regionRecordingMonitorProcess.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: regionRecordingMonitorTimer
        interval: 500
        repeat: true
        onTriggered: root.refreshRegionRecordingState()
    }

    Process {
        id: probeProcess
        command: [
            "sh",
            "-c",
            "for tool in grim niri slurp wl-copy wf-recorder; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool=1\" || echo \"$tool=0\"; done",
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseTools(text)
        }
    }

    Process {
        id: screenshotProcess
        command: [
            "bash",
            "-lc",
            "set -euo pipefail\n(\n    file=\"$(mktemp \"${XDG_RUNTIME_DIR:-/tmp}/niri-screenshot-XXXXXX.png\")\"\n    rm -f \"$file\"\n    niri msg action screenshot --path \"$file\"\n    for _ in $(seq 1 900); do\n        if [ -s \"$file\" ]; then\n            wl-copy --type image/png < \"$file\"\n            rm -f \"$file\"\n            exit 0\n        fi\n        sleep 0.1\n    done\n    rm -f \"$file\"\n) >/dev/null 2>&1 </dev/null &",
        ]
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.errorText = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.screenshotBusy = false;
            if (exitCode !== 0 && root.errorText.length === 0)
                root.errorText = "Screenshot cancelled";
        }
    }

    Process {
        id: startRecordingProcess
        command: [
            "bash",
            "-lc",
            "set -euo pipefail\ndir=\"$HOME/Videos/Screen Recordings\"\nmkdir -p \"$dir\"\nfile=\"$dir/recording-$(date +%Y%m%d-%H%M%S).mp4\"\noutput=\"$(niri msg --json focused-output | sed -n 's/.*\"name\":\"\\([^\"]*\\)\".*/\\1/p')\"\n[ -n \"$output\" ]\nwf-recorder -o \"$output\" -f \"$file\"",
        ]
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.errorText = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => root.recordingActive = false
    }

    Process {
        id: regionRecordingMonitorProcess
        command: ["bash", "-lc", "pgrep -x slurp >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.regionRecordingStarting = false;
                root.regionRecordingActive = true;
                root.regionRecordingStartGraceTicks = 0;
                return;
            }

            if (root.regionRecordingStartGraceTicks > 0) {
                root.regionRecordingStartGraceTicks -= 1;
                return;
            }

            root.regionRecordingStarting = false;
            root.regionRecordingActive = false;
            root.regionRecordingMonitorTimer.stop();
        }
    }

    Process {
        id: stopRecordingProcess
        command: [
            "bash",
            "-lc",
            "pkill -INT wf-recorder >/dev/null 2>&1 || true\npkill -TERM slurp >/dev/null 2>&1 || true",
        ]
    }
}
