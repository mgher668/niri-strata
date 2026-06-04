import QtQuick
import Quickshell.Networking

Item {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var connectedDevices: devices.filter(device => device.connected)
    readonly property var wiredDevice: connectedDevices.find(device => device.type === DeviceType.Wired) ?? null
    readonly property var wifiDevice: connectedDevices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var activeDevice: wiredDevice ?? wifiDevice ?? devices.find(device => device.connected) ?? null
    readonly property var activeNetwork: networkForDevice(activeDevice)
    readonly property bool available: activeDevice !== null
    readonly property bool connected: activeDevice?.connected ?? false
    readonly property bool wired: activeDevice?.type === DeviceType.Wired
    readonly property bool wifi: activeDevice?.type === DeviceType.Wifi
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal
    readonly property string label: wired ? "LAN" : wifi ? "WIFI" : "NET"
    readonly property string nameText: activeNetwork?.name || activeDevice?.name || "Offline"
    readonly property int strength: wifi ? normalizeStrength(activeNetwork?.signalStrength ?? 0) : 100
    readonly property string detailText: wired ? linkSpeedText(activeDevice?.linkSpeed ?? 0)
        : wifi ? `${strength}%` : connected ? "Connected" : "Offline"
    readonly property string stateText: !connected ? "Offline" : limited ? "Limited" : "Connected"

    function networkForDevice(device) {
        if (!device)
            return null;
        if (device.type === DeviceType.Wired)
            return device.network ?? null;

        const networks = device.networks?.values ?? [];
        return networks.find(network => network.connected) ?? null;
    }

    function linkSpeedText(speed) {
        if (!speed || speed <= 0)
            return "wired";
        if (speed >= 1000)
            return `${Math.round(speed / 1000)}G`;
        return `${speed}M`;
    }

    function normalizeStrength(value) {
        const numeric = Number(value ?? 0);
        if (numeric <= 1)
            return Math.round(numeric * 100);
        return Math.round(Math.min(100, numeric));
    }
}
