import QtQuick
import Quickshell.Io

Item {
    id: root

    component OutputEntry: QtObject {
        required property string name
        readonly property string path: `/outputs/${name}`
        property int temperature: root.dayTemperature
        property bool ready: false
        property bool busy: false
        property string errorText: ""
        readonly property string label: name.replace(/_/g, "-")
    }

    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6500
    readonly property int dayTemperature: 6500
    readonly property int defaultNightTemperature: 3500
    readonly property bool available: outputs.length > 0 && errorText.length === 0
    readonly property bool busy: scanning || outputs.some(output => output.busy)
    readonly property int temperature: outputs.length > 0 ? outputs[0].temperature : dayTemperature
    readonly property bool enabled: available && temperature < dayTemperature
    readonly property string statusText: !available ? (errorText.length > 0 ? errorText : "Backend unavailable")
        : enabled ? `${temperature}K`
        : "Off"

    property list<OutputEntry> outputs: []
    property bool scanning: false
    property string errorText: ""
    property string scanErrorText: ""
    property var readQueue: []
    property var setQueue: []
    property string currentReadOutput: ""
    property string currentSetOutput: ""

    function refresh() {
        if (scanProcess.running)
            return;

        errorText = "";
        scanErrorText = "";
        scanning = true;
        scanProcess.running = true;
    }

    function clampTemperature(value) {
        return Math.round(Math.max(minTemperature, Math.min(maxTemperature, Number(value) || dayTemperature)));
    }

    function setTemperature(value) {
        const nextTemperature = clampTemperature(value);
        for (const output of outputs) {
            output.temperature = nextTemperature;
            output.busy = true;
            setQueue = [
                ...setQueue.filter(entry => entry.outputName !== output.name),
                { outputName: output.name, temperature: nextTemperature },
            ];
        }
        pumpSetQueue();
    }

    function toggle() {
        setTemperature(enabled ? dayTemperature : defaultNightTemperature);
    }

    function parseOutputs(text) {
        const names = [];
        const pattern = /<node name="([^"]+)"\/>/g;
        const value = String(text ?? "");
        let match = pattern.exec(value);

        while (match !== null) {
            if (match[1].length > 0)
                names.push(match[1]);
            match = pattern.exec(value);
        }

        return names;
    }

    function syncOutputs(text) {
        const parsed = parseOutputs(text);
        if (parsed.length === 0) {
            outputs = [];
            errorText = "No gamma outputs";
            return;
        }

        const existingNames = outputs.map(output => output.name);
        const same = existingNames.length === parsed.length
            && existingNames.every((name, index) => name === parsed[index]);

        if (!same) {
            for (const output of outputs)
                output.destroy();
            outputs = parsed.map(name => outputComponent.createObject(root, { name }));
        }

        readAllOutputs();
    }

    function readAllOutputs() {
        for (const output of outputs)
            readOutput(output);
    }

    function readOutput(output) {
        if (!output)
            return;

        output.busy = true;
        if (!readQueue.includes(output.name) && currentReadOutput !== output.name)
            readQueue = [...readQueue, output.name];
        pumpReadQueue();
    }

    function pumpReadQueue() {
        if (getProcess.running || readQueue.length === 0)
            return;

        currentReadOutput = readQueue[0];
        readQueue = readQueue.slice(1);
        getProcess.exec([
            "busctl",
            "--user",
            "get-property",
            "rs.wl-gammarelay",
            `/outputs/${currentReadOutput}`,
            "rs.wl.gammarelay",
            "Temperature",
        ]);
    }

    function pumpSetQueue() {
        if (setProcess.running || setQueue.length === 0)
            return;

        const next = setQueue[0];
        setQueue = setQueue.slice(1);
        currentSetOutput = next.outputName;
        setProcess.exec([
            "busctl",
            "--user",
            "set-property",
            "rs.wl-gammarelay",
            `/outputs/${next.outputName}`,
            "rs.wl.gammarelay",
            "Temperature",
            "q",
            String(next.temperature),
        ]);
    }

    function parseTemperature(text) {
        const match = String(text ?? "").trim().match(/^[qtnui]\s+(-?\d+)/);
        return match ? Number(match[1]) : null;
    }

    function outputByName(name) {
        return outputs.find(output => output.name === name) ?? null;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component {
        id: outputComponent
        OutputEntry {}
    }

    Process {
        id: scanProcess
        command: ["busctl", "--user", "introspect", "--xml-interface", "rs.wl-gammarelay", "/outputs"]
        stdout: StdioCollector {
            onStreamFinished: root.syncOutputs(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.scanErrorText = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.scanning = false;
            if (exitCode !== 0 && root.outputs.length === 0)
                root.errorText = root.scanErrorText.length > 0 ? root.scanErrorText : "wl-gammarelay-rs unavailable";
        }
    }

    Process {
        id: getProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const output = root.outputByName(root.currentReadOutput);
                if (!output)
                    return;

                const temperature = root.parseTemperature(text);
                if (temperature !== null) {
                    output.temperature = temperature;
                    output.ready = true;
                    output.errorText = "";
                } else {
                    output.errorText = "Could not read temperature";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const output = root.outputByName(root.currentReadOutput);
                if (output && text.trim().length > 0)
                    output.errorText = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            const output = root.outputByName(root.currentReadOutput);
            if (output) {
                output.busy = false;
                if (exitCode !== 0 && output.errorText.length === 0)
                    output.errorText = "Could not read temperature";
            }
            root.currentReadOutput = "";
            root.pumpReadQueue();
        }
    }

    Process {
        id: setProcess
        onExited: (exitCode, exitStatus) => {
            const output = root.outputByName(root.currentSetOutput);
            if (output) {
                output.busy = false;
                if (exitCode !== 0) {
                    output.errorText = "Could not set temperature";
                } else {
                    output.ready = true;
                    output.errorText = "";
                }
            }

            root.currentSetOutput = "";
            root.pumpSetQueue();
        }
    }
}
