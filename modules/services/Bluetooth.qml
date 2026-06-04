import QtQuick
import Quickshell.Bluetooth

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool discovering: available && adapter.discovering
    readonly property var devices: available ? Bluetooth.devices.values : []
    readonly property var sortedDevices: [...devices].sort((a, b) => {
        if (a.connected && !b.connected)
            return -1;
        if (!a.connected && b.connected)
            return 1;
        const aPaired = a.paired || a.bonded;
        const bPaired = b.paired || b.bonded;
        if (aPaired && !bPaired)
            return -1;
        if (!aPaired && bPaired)
            return 1;
        return deviceName(a).localeCompare(deviceName(b));
    })
    readonly property var connectedDevices: devices.filter(device => device.connected)
    readonly property var firstConnectedDevice: connectedDevices[0] ?? null
    readonly property string statusText: !available ? "Unavailable"
        : blocked ? "Blocked"
        : !enabled ? "Off"
        : firstConnectedDevice ? deviceName(firstConnectedDevice)
        : "On"
    readonly property string detailText: !available ? "BlueZ unavailable"
        : connectedDevices.length > 0 ? `${connectedDevices.length} connected`
        : enabled ? `${devices.length} devices`
        : "Bluetooth disabled"

    function deviceName(device) {
        return device?.name || device?.deviceName || device?.address || "Unknown device";
    }

    function deviceStatus(device) {
        if (!device)
            return "Unknown";
        if (device.connected)
            return device.batteryAvailable ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected";
        if (device.pairing)
            return "Pairing";
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting";
        if (device.paired || device.bonded)
            return "Paired";
        if (device.blocked)
            return "Blocked";
        return "Available";
    }

    function setEnabled(value) {
        if (!available)
            return;
        adapter.enabled = value;
        adapter.discovering = value;
    }

    function toggleEnabled() {
        setEnabled(!enabled);
    }

    function scan() {
        if (!enabled)
            return;
        adapter.discovering = true;
        scanTimer.restart();
    }

    function stopScan() {
        if (!available)
            return;
        adapter.discovering = false;
    }

    function toggleDevice(device) {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    Timer {
        id: scanTimer
        interval: 15000
        repeat: false
        onTriggered: root.stopScan()
    }
}
