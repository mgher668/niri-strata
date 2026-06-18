import QtQuick
import Quickshell.Io

Item {
    id: root

    component DisplayEntry: QtObject {
        required property int id
        required property int bus
        property string connector: ""
        property string manufacturer: ""
        property string model: ""
        property string serial: ""
        property string label: model.length > 0 ? model : `Display ${id}`
        property bool controllable: true
        property int current: 0
        property int max: 100
        property bool ready: false
        property bool busy: false
        property string errorText: ""
        readonly property int percent: max > 0 ? Math.round(Math.max(0, Math.min(1, current / max)) * 100) : 0
    }

    readonly property bool available: displays.some(display => display.controllable) && errorText.length === 0
    readonly property bool busy: detecting || displays.some(display => display.busy)
    readonly property string statusText: !available ? (errorText.length > 0 ? errorText : "No DDC display")
        : displays.length === 1 ? `${displays[0].percent}%`
        : `${displays.length} displays`
    readonly property string primaryLabel: displays.length > 0 ? displays[0].label : "Brightness"

    property list<DisplayEntry> displays: []
    property string detectText: ""
    property string errorText: ""
    property string detectErrorText: ""
    property bool detecting: false
    property var readQueue: []
    property var setQueue: []
    property var staleReadBuses: []
    property int currentReadBus: -1
    property int currentSetBus: -1

    function refresh() {
        if (detectProcess.running)
            return;

        errorText = "";
        detectErrorText = "";
        detecting = true;
        detectProcess.running = true;
    }

    function readDisplay(display) {
        if (!display || !display.controllable)
            return;

        display.busy = true;
        if (!readQueue.includes(display.bus) && currentReadBus !== display.bus)
            readQueue = [...readQueue, display.bus];
        pumpReadQueue();
    }

    function readAllDisplays() {
        for (const display of displays)
            readDisplay(display);
    }

    function setBrightness(display, percent) {
        if (!display || !display.controllable)
            return;

        const value = Math.round(Math.max(0, Math.min(100, Number(percent) || 0)));
        display.current = Math.round(display.max * value / 100);
        display.busy = true;
        setQueue = [
            ...setQueue.filter(entry => entry.bus !== display.bus),
            { bus: display.bus, value },
        ];
        if (currentReadBus === display.bus && !staleReadBuses.includes(display.bus))
            staleReadBuses = [...staleReadBuses, display.bus];
        pumpSetQueue();
    }

    function pumpReadQueue() {
        if (getProcess.running || readQueue.length === 0)
            return;

        currentReadBus = readQueue[0];
        readQueue = readQueue.slice(1);
        getProcess.exec(["ddcutil", "--bus", String(currentReadBus), "getvcp", "10"]);
    }

    function pumpSetQueue() {
        if (setProcess.running || setQueue.length === 0)
            return;

        const next = setQueue[0];
        setQueue = setQueue.slice(1);
        currentSetBus = next.bus;
        setProcess.exec(["ddcutil", "--bus", String(next.bus), "setvcp", "10", String(next.value)]);
    }

    function hasSetPendingForBus(bus) {
        return currentSetBus === bus || setQueue.some(entry => entry.bus === bus);
    }

    function hasStaleReadForBus(bus) {
        return staleReadBuses.includes(bus);
    }

    function clearStaleReadForBus(bus) {
        staleReadBuses = staleReadBuses.filter(staleBus => staleBus !== bus);
    }

    function parseDisplays(text) {
        const next = [];
        let current = null;

        for (const rawLine of String(text ?? "").split("\n")) {
            const line = rawLine.trim();
            if (line.length === 0)
                continue;

            const displayMatch = line.match(/^Display\s+(\d+)/);
            if (displayMatch) {
                current = {
                    id: Number(displayMatch[1]),
                    bus: null,
                    connector: "",
                    manufacturer: "",
                    model: "",
                    serial: "",
                    controllable: true,
                    errorText: "",
                };
                next.push(current);
                continue;
            }

            if (line === "Invalid display") {
                current = {
                    id: next.length + 1,
                    bus: null,
                    connector: "",
                    manufacturer: "",
                    model: "",
                    serial: "",
                    controllable: false,
                    errorText: "DDC communication failed",
                };
                next.push(current);
                continue;
            }

            if (!current)
                continue;

            const busMatch = line.match(/^I2C bus:\s+\/dev\/i2c-(\d+)/);
            if (busMatch) {
                current.bus = Number(busMatch[1]);
                continue;
            }

            const connectorMatch = line.match(/^DRM_connector:\s+(.+)$/);
            if (connectorMatch) {
                current.connector = connectorMatch[1].trim();
                continue;
            }

            const briefConnectorMatch = line.match(/^DRM connector:\s+(.+)$/);
            if (briefConnectorMatch) {
                current.connector = briefConnectorMatch[1].trim();
                continue;
            }

            const manufacturerMatch = line.match(/^Mfg id:\s+(.+)$/);
            if (manufacturerMatch) {
                current.manufacturer = manufacturerMatch[1].trim();
                continue;
            }

            const modelMatch = line.match(/^Model:\s+(.+)$/);
            if (modelMatch) {
                current.model = modelMatch[1].trim();
                continue;
            }

            const serialMatch = line.match(/^Serial number:\s+(.+)$/);
            if (serialMatch) {
                current.serial = serialMatch[1].trim();
                continue;
            }

            if (/DDC communication failed/i.test(line))
                current.errorText = "DDC communication failed";
        }

        return next.filter(display => Number.isInteger(display.bus));
    }

    function displaysEqual(left, right) {
        if (left.length !== right.length)
            return false;

        for (let i = 0; i < left.length; i++) {
            if (left[i].bus !== right[i].bus
                    || left[i].model !== right[i].model
                    || left[i].connector !== right[i].connector
                    || left[i].serial !== right[i].serial
                    || left[i].controllable !== right[i].controllable
                    || left[i].errorText !== right[i].errorText) {
                return false;
            }
        }

        return true;
    }

    function syncDisplays(text) {
        const parsed = parseDisplays(text);
        if (parsed.length === 0) {
            displays = [];
            errorText = "No DDC display";
            return;
        }

        const existing = displays;
        if (!displaysEqual(existing, parsed)) {
            for (const display of existing)
                display.destroy();

            displays = parsed.map(display => displayComponent.createObject(root, {
                id: display.id,
                bus: display.bus,
                connector: display.connector,
                manufacturer: display.manufacturer,
                model: display.model,
                serial: display.serial,
                controllable: display.controllable,
                errorText: display.errorText,
            }));
        }

        readAllDisplays();
    }

    function parseBrightness(text) {
        const match = String(text ?? "").match(/current value\s*=\s*(\d+),\s*max value\s*=\s*(\d+)/i);
        if (!match)
            return null;

        return {
            current: Number(match[1]),
            max: Number(match[2]),
        };
    }

    function displayForBus(bus) {
        return displays.find(display => display.bus === bus) ?? null;
    }

    Component.onCompleted: startupRefreshTimer.start()

    Timer {
        id: startupRefreshTimer
        interval: 3000
        repeat: false
        onTriggered: root.refresh()
    }

    Component {
        id: displayComponent
        DisplayEntry {}
    }

    Process {
        id: detectProcess
        command: ["ddcutil", "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detectText = text;
                root.syncDisplays(text);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.detectErrorText = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.detecting = false;
            if (exitCode !== 0 && root.displays.length === 0)
                root.errorText = root.detectErrorText.length > 0 ? root.detectErrorText : "ddcutil unavailable";
        }
    }

    Process {
        id: getProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const display = root.displayForBus(root.currentReadBus);
                if (!display)
                    return;

                const brightness = root.parseBrightness(text);
                const stale = root.hasSetPendingForBus(root.currentReadBus)
                    || root.hasStaleReadForBus(root.currentReadBus);
                if (brightness && !stale) {
                    display.current = brightness.current;
                    display.max = brightness.max;
                    display.ready = true;
                    display.errorText = "";
                } else if (brightness) {
                    display.ready = true;
                    display.errorText = "";
                } else {
                    display.errorText = "Could not read brightness";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const display = root.displayForBus(root.currentReadBus);
                if (display && text.trim().length > 0)
                    display.errorText = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            const bus = root.currentReadBus;
            const display = root.displayForBus(root.currentReadBus);
            if (display) {
                display.busy = root.hasSetPendingForBus(bus) || root.hasStaleReadForBus(bus);
                if (exitCode !== 0 && display.errorText.length === 0)
                    display.errorText = "Could not read brightness";
            }
            root.currentReadBus = -1;
            if (root.hasStaleReadForBus(bus)) {
                root.clearStaleReadForBus(bus);
                if (display && !root.hasSetPendingForBus(bus)) {
                    root.readDisplay(display);
                    return;
                }
            }
            root.pumpReadQueue();
        }
    }

    Process {
        id: setProcess
        onExited: (exitCode, exitStatus) => {
            const display = root.displayForBus(root.currentSetBus);
            if (!display)
                return;

            if (exitCode !== 0) {
                display.busy = false;
                display.errorText = "Could not set brightness";
                root.readDisplay(display);
                root.currentSetBus = -1;
                root.pumpSetQueue();
                return;
            }

            display.ready = true;
            display.errorText = "";
            root.currentSetBus = -1;
            display.busy = root.setQueue.some(entry => entry.bus === display.bus);
            if (!display.busy)
                root.readDisplay(display);
            root.pumpSetQueue();
        }
    }
}
