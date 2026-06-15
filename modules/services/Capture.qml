import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property bool screenshotAvailable: tools.niri && tools.wlCopy
    readonly property bool currentOutputRecordingAvailable: tools.niri && tools.wfRecorder
    readonly property bool regionRecordingAvailable: tools.slurp && tools.wfRecorder
    readonly property bool recordingAvailable: currentOutputRecordingAvailable || regionRecordingAvailable
    readonly property bool recordingAudioAvailable: audioMonitorSource.length > 0
    readonly property bool recordingActive: recordingState === "selectingRegion" || recordingState === "recordingRegion" || recordingState === "recordingOutput" || recordingState === "stopping"
    readonly property bool regionRecordingActive: recordingState === "selectingRegion" || recordingState === "recordingRegion"
    readonly property bool regionRecordingStarting: recordingState === "selectingRegion"
    readonly property string screenshotStatus: screenshotAvailable ? "Clipboard" : "Unavailable"
    readonly property string recordingStatus: recordingStatusText()
    readonly property string regionRecordingStatus: regionRecordingAvailable ? "Region ready" : "Region unavailable"

    property string recordingState: "idle"
    property string recordingMode: "output"
    property bool recordingAudioEnabled: false
    property string recordingDegradedReason: ""
    property string recordingSavePath: ""
    property string recordingLastError: ""
    property string recordingStopSourceState: ""
    property string audioMonitorSource: ""
    property string audioMonitorLastError: ""
    property int regionRecordingStartGraceTicks: 0
    property string regionRecordingMonitorState: ""
    property int recordingStopReconcileAttempts: 0
    property bool screenshotBusy: false
    property var tools: ({
        grim: false,
        niri: false,
        notifySend: false,
        pactl: false,
        slurp: false,
        wlCopy: false,
        wfRecorder: false,
        wpctl: false,
    })
    property string errorText: ""

    function refresh() {
        if (!probeProcess.running)
            probeProcess.running = true;
    }

    function parseTools(text) {
        const next = {
            grim: false,
            niri: false,
            notifySend: false,
            pactl: false,
            slurp: false,
            wlCopy: false,
            wfRecorder: false,
            wpctl: false,
        };

        for (const rawLine of String(text ?? "").split("\n")) {
            const parts = rawLine.trim().split("=");
            const available = parts[1] === "1";

            if (parts[0] === "grim")
                next.grim = available;
            else if (parts[0] === "niri")
                next.niri = available;
            else if (parts[0] === "notify-send")
                next.notifySend = available;
            else if (parts[0] === "pactl")
                next.pactl = available;
            else if (parts[0] === "slurp")
                next.slurp = available;
            else if (parts[0] === "wl-copy")
                next.wlCopy = available;
            else if (parts[0] === "wf-recorder")
                next.wfRecorder = available;
            else if (parts[0] === "wpctl")
                next.wpctl = available;
        }

        tools = next;
        refreshAudioMonitorSource();
        ensureRecordingModeAvailable();
    }

    function refreshAudioMonitorSource() {
        audioMonitorSource = "";
        audioMonitorLastError = "";

        if (tools.pactl && !audioMonitorProcess.running)
            audioMonitorProcess.running = true;
        else if (!tools.pactl)
            audioMonitorLastError = "pactl unavailable";
    }

    function ensureRecordingModeAvailable() {
        if (recordingModeAvailable(recordingMode))
            return;
        if (currentOutputRecordingAvailable)
            recordingMode = "output";
        else if (regionRecordingAvailable)
            recordingMode = "region";
    }

    function recordingModeAvailable(mode) {
        if (mode === "region")
            return regionRecordingAvailable;
        if (mode === "output")
            return currentOutputRecordingAvailable;
        return false;
    }

    function setRecordingMode(mode) {
        if (recordingActive || mode !== "region" && mode !== "output")
            return;

        recordingMode = mode;
    }

    function setRecordingAudioEnabled(enabled) {
        if (recordingActive)
            return;

        recordingAudioEnabled = enabled;
    }

    function recordingStatusText() {
        if (recordingState === "selectingRegion")
            return "Selecting area";
        if (recordingState === "recordingRegion")
            return recordingDegradedReason.length > 0 ? "Recording region silently" : "Recording region";
        if (recordingState === "recordingOutput")
            return recordingDegradedReason.length > 0 ? "Recording screen silently" : "Recording screen";
        if (recordingState === "stopping")
            return "Stopping";
        if (!recordingAvailable)
            return "Unavailable";

        const modeText = recordingMode === "region" ? "Region" : "Current screen";
        if (recordingAudioEnabled)
            return recordingAudioAvailable ? `${modeText} + audio` : `${modeText} + silent fallback`;
        return `${modeText} silent`;
    }

    function quoteShell(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function recordingAudioArgument() {
        if (!recordingAudioEnabled || audioMonitorSource.length === 0)
            return "";
        return " --audio=" + quoteShell(audioMonitorSource);
    }

    function recordingStartCommand() {
        const audioArg = recordingAudioArgument();
        const filePrefix = recordingMode === "region" ? "recording-region" : "recording";
        let target = "";

        if (recordingMode === "region") {
            target = `geometry="$(slurp)"
[ -n "$geometry" ]
printf 'file=%s\\n' "$file"
exec wf-recorder -g "$geometry"${audioArg} -f "$file"`;
        } else {
            target = `output="$(niri msg --json focused-output | sed -n 's/.*"name":"\\([^"]*\\)".*/\\1/p')"
[ -n "$output" ]
printf 'file=%s\\n' "$file"
exec wf-recorder -o "$output"${audioArg} -f "$file"`;
        }

        return [
            "bash",
            "-lc",
            `set -euo pipefail
dir="$HOME/Videos/Screen Recordings"
mkdir -p "$dir"
file="$dir/${filePrefix}-$(date +%Y%m%d-%H%M%S).mp4"
${target}`,
        ];
    }

    function notify(summary, body) {
        if (!tools.notifySend)
            return;

        const command = ["notify-send", summary];
        if (body && body.length > 0)
            command.push(body);
        Quickshell.execDetached(command);
    }

    function completeStoppedRecording() {
        const stoppedSelection = recordingStopSourceState === "selectingRegion";

        regionRecordingMonitorTimer.stop();
        recordingStopReconcileTimer.stop();
        recordingStopReconcileAttempts = 0;
        regionRecordingStartGraceTicks = 0;

        if (stoppedSelection) {
            recordingLastError = "Region selection cancelled";
            notify("Recording cancelled", "Region selection cancelled");
        } else {
            notify("Recording stopped", recordingSavePath.length > 0 ? recordingSavePath : "Saved under ~/Videos/Screen Recordings");
        }

        recordingState = "idle";
        recordingStopSourceState = "";
    }

    function takeScreenshot() {
        if (!screenshotAvailable || screenshotProcess.running)
            return;

        errorText = "";
        screenshotBusy = true;
        screenshotProcess.running = true;
    }

    function toggleRecording() {
        if (recordingActive)
            stopRecording();
        else
            startRecording();
    }

    function startRecording() {
        if (recordingActive || !recordingAvailable)
            return;

        ensureRecordingModeAvailable();
        if (!recordingModeAvailable(recordingMode))
            return;

        errorText = "";
        recordingLastError = "";
        recordingSavePath = "";
        recordingStopSourceState = "";
        recordingDegradedReason = "";

        if (recordingAudioEnabled && !recordingAudioAvailable) {
            recordingDegradedReason = "Audio monitor unavailable";
            notify("Recording audio unavailable", "Starting without audio");
        }

        const command = recordingStartCommand();

        if (recordingMode === "region") {
            recordingState = "selectingRegion";
            regionRecordingStartGraceTicks = 8;
            if (!regionRecordingMonitorTimer.running)
                regionRecordingMonitorTimer.start();
            refreshRegionRecordingState();
            Quickshell.execDetached(command);
        } else {
            recordingState = "recordingOutput";
            startRecordingProcess.command = command;
            startRecordingProcess.running = true;
        }
    }

    function stopRecording() {
        if (!recordingActive)
            return;

        recordingStopSourceState = recordingState;
        recordingState = "stopping";
        recordingStopReconcileAttempts = 0;
        regionRecordingStartGraceTicks = 0;
        if (!stopRecordingProcess.running)
            stopRecordingProcess.running = true;
        if (!recordingStopReconcileTimer.running)
            recordingStopReconcileTimer.start();
    }

    function toggleRegionRecording() {
        if (regionRecordingActive)
            stopRecording();
        else {
            setRecordingMode("region");
            startRecording();
        }
    }

    function refreshRegionRecordingState() {
        if ((recordingState === "selectingRegion" || recordingState === "recordingRegion") && !regionRecordingMonitorProcess.running)
            regionRecordingMonitorProcess.running = true;
    }

    function refreshRecordingStopState() {
        if (recordingState !== "stopping") {
            recordingStopReconcileTimer.stop();
            return;
        }

        if (!recordingStopMonitorProcess.running)
            recordingStopMonitorProcess.running = true;
    }

    Component.onCompleted: startupRefreshTimer.start()

    Timer {
        id: startupRefreshTimer
        interval: 2200
        repeat: false
        onTriggered: root.refresh()
    }

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

    Timer {
        id: recordingStopReconcileTimer
        interval: 500
        repeat: true
        onTriggered: root.refreshRecordingStopState()
    }

    Process {
        id: probeProcess
        command: [
            "sh",
            "-c",
            "for tool in grim niri notify-send pactl slurp wl-copy wf-recorder wpctl; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool=1\" || echo \"$tool=0\"; done",
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseTools(text)
        }
    }

    Process {
        id: audioMonitorProcess
        command: [
            "bash",
            "-lc",
            "set -euo pipefail\nsink=\"$(pactl get-default-sink 2>/dev/null)\"\n[ -n \"$sink\" ]\nmonitor=\"$sink.monitor\"\npactl list sources short | cut -f2 | grep -Fx \"$monitor\"",
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const source = text.trim().split("\n").find(line => line.length > 0) || "";
                root.audioMonitorSource = source;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.audioMonitorLastError = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.audioMonitorLastError.length === 0)
                root.audioMonitorLastError = "No default output monitor";
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
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                for (const rawLine of text.split("\n")) {
                    if (rawLine.startsWith("file="))
                        root.recordingSavePath = rawLine.slice(5);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.recordingLastError = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.recordingState === "idle" && root.recordingStopSourceState.length === 0)
                return;

            const wasStopping = root.recordingState === "stopping";
            const wasSelecting = root.recordingState === "selectingRegion";
            const stoppedSelection = wasStopping && root.recordingStopSourceState === "selectingRegion";

            root.regionRecordingMonitorTimer.stop();
            root.recordingStopReconcileTimer.stop();
            root.recordingStopReconcileAttempts = 0;
            root.regionRecordingStartGraceTicks = 0;

            if (stoppedSelection || wasStopping || exitCode === 0) {
                root.completeStoppedRecording();
            } else if (wasSelecting) {
                root.recordingLastError = "Region selection cancelled";
                root.notify("Recording cancelled", "Region selection cancelled");
            } else {
                const message = root.recordingLastError.length > 0 ? root.recordingLastError : "Recording failed";
                root.recordingLastError = message;
                root.notify("Recording failed", message);
            }

            root.recordingState = "idle";
            root.recordingStopSourceState = "";
        }
    }

    Process {
        id: regionRecordingMonitorProcess
        command: ["bash", "-lc", "if pgrep -x wf-recorder >/dev/null 2>&1; then echo recording; elif pgrep -x slurp >/dev/null 2>&1; then echo selecting; else exit 1; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.regionRecordingMonitorState = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            const monitorState = root.regionRecordingMonitorState;
            root.regionRecordingMonitorState = "";

            if (exitCode === 0 && monitorState === "recording" && root.recordingState === "selectingRegion") {
                root.recordingState = "recordingRegion";
                root.regionRecordingStartGraceTicks = 0;
                return;
            }

            if (exitCode === 0)
                return;

            if (root.recordingState === "selectingRegion" && root.regionRecordingStartGraceTicks > 0) {
                root.regionRecordingStartGraceTicks -= 1;
                return;
            }

            if (root.recordingState === "selectingRegion") {
                root.recordingState = "idle";
                root.regionRecordingMonitorTimer.stop();
                root.notify("Recording cancelled", "Region selection cancelled");
                return;
            }

            if (root.recordingState === "recordingRegion") {
                root.completeStoppedRecording();
            }
        }
    }

    Process {
        id: recordingStopMonitorProcess
        command: ["bash", "-lc", "pgrep -x wf-recorder >/dev/null 2>&1 || pgrep -x slurp >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            if (root.recordingState !== "stopping") {
                root.recordingStopReconcileTimer.stop();
                return;
            }

            root.recordingStopReconcileAttempts += 1;

            if (exitCode === 0 || root.recordingStopReconcileAttempts < 2)
                return;

            root.completeStoppedRecording();
        }
    }

    Process {
        id: stopRecordingProcess
        command: [
            "bash",
            "-lc",
            "pkill -INT wf-recorder >/dev/null 2>&1 || true\npkill -TERM slurp >/dev/null 2>&1 || true",
        ]
        onExited: {
            if (root.recordingState === "stopping" && !recordingStopReconcileTimer.running)
                recordingStopReconcileTimer.start();
        }
    }
}
