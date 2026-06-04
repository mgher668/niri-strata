import QtQuick
import Quickshell.Networking
import Quickshell.Io

Item {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property bool available: wifiDevice !== null && Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool enabled: available && Networking.wifiEnabled
    readonly property var networks: available ? (wifiDevice.networks?.values ?? []) : []
    readonly property var sortedNetworks: [...networks].sort((a, b) => {
        if (a.connected && !b.connected)
            return -1;
        if (!a.connected && b.connected)
            return 1;
        if (a.known && !b.known)
            return -1;
        if (!a.known && b.known)
            return 1;
        return signalPercent(b) - signalPercent(a);
    })
    readonly property var activeNetwork: networks.find(network => network.connected) ?? null
    readonly property string activeSsid: activeNetwork?.name ?? ""
    readonly property bool scanning: scanBusy || (available && (wifiDevice.scannerEnabled ?? false))
    readonly property string statusText: !available ? "Unavailable"
        : !hardwareEnabled ? "Hardware off"
        : !enabled ? "Off"
        : activeNetwork ? activeNetwork.name
        : "Available"
    readonly property string detailText: activeNetwork ? `${signalPercent(activeNetwork)}% ${securityText(activeNetwork)}`
        : enabled ? `${networks.length} networks`
        : statusText
    readonly property var activeVpn: vpnProfiles.find(profile => profile.active) ?? null
    readonly property string vpnStatusText: activeVpn ? activeVpn.name : vpnProfiles.length > 0 ? "Disconnected" : "No VPN"

    property bool scanBusy: false
    property string lastError: ""
    property var passwordNetwork: null
    property var vpnProfiles: []
    property string vpnListText: ""
    property string activeVpnListText: ""
    property string pendingVpnListText: ""
    property string pendingActiveVpnListText: ""
    property bool vpnRefreshing: false
    property bool vpnListReady: false
    property bool activeVpnReady: false
    property bool vpnRefreshFailed: false

    function setEnabled(value) {
        if (!available)
            return;
        Networking.wifiEnabled = value;
        if (value)
            scan();
    }

    function toggleEnabled() {
        setEnabled(!enabled);
    }

    function scan() {
        if (!available || !enabled)
            return;
        lastError = "";
        scanBusy = true;
        wifiDevice.scannerEnabled = true;
        scanTimer.restart();
    }

    function isSecured(network) {
        if (!network)
            return false;
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
    }

    function shouldPromptPassword(network) {
        return isSecured(network) && !network.known;
    }

    function securityText(network) {
        if (!network)
            return "--";
        if (network.security === WifiSecurityType.Open)
            return "Open";
        if (network.security === WifiSecurityType.Unknown)
            return "Unknown";
        return "Secured";
    }

    function signalPercent(network) {
        const value = Number(network?.signalStrength ?? 0);
        if (value <= 1)
            return Math.round(value * 100);
        return Math.round(Math.max(0, Math.min(100, value)));
    }

    function networkStatusText(network) {
        if (!network)
            return "";
        if (network.connected)
            return "Connected";
        if (network.stateChanging)
            return ConnectionState.toString(network.state);
        if (network.known)
            return "Saved";
        return securityText(network);
    }

    function connectNetwork(network) {
        if (!network)
            return;
        lastError = "";
        passwordNetwork = shouldPromptPassword(network) ? network : null;
        if (passwordNetwork)
            return;
        network.connect();
    }

    function connectWithPassword(network, password) {
        if (!network)
            return;
        const psk = String(password ?? "");
        if (psk.length <= 0) {
            lastError = "Password required";
            passwordNetwork = network;
            return;
        }
        lastError = "";
        passwordNetwork = null;
        network.connectWithPsk(psk);
    }

    function disconnectNetwork(network) {
        if (network)
            network.disconnect();
    }

    function cancelPassword() {
        passwordNetwork = null;
    }

    function recordConnectionFailure(reason) {
        lastError = `Wi-Fi connection failed: ${ConnectionFailReason.toString(reason)}`;
    }

    function splitNmcliLine(line) {
        const fields = [];
        let current = "";
        let escaped = false;
        for (let i = 0; i < line.length; i++) {
            const char = line[i];
            if (escaped) {
                current += char;
                escaped = false;
            } else if (char === "\\") {
                escaped = true;
            } else if (char === ":") {
                fields.push(current);
                current = "";
            } else {
                current += char;
            }
        }
        fields.push(current);
        return fields;
    }

    function isVpnType(type) {
        const lowered = String(type ?? "").toLowerCase();
        return lowered === "vpn" || lowered === "wireguard" || lowered === "tun";
    }

    function buildVpnProfiles(vpnText, activeText) {
        const activeNames = new Set(activeText.trim().split("\n")
            .filter(line => line.length > 0)
            .map(splitNmcliLine)
            .filter(fields => isVpnType(fields[1]))
            .map(fields => fields[0]));

        return vpnText.trim().split("\n")
            .filter(line => line.length > 0)
            .map(splitNmcliLine)
            .filter(fields => isVpnType(fields[1]))
            .map(fields => ({
                name: fields[0],
                type: fields[1],
                active: activeNames.has(fields[0]),
            }))
            .sort((a, b) => a.name.localeCompare(b.name) || a.type.localeCompare(b.type));
    }

    function vpnProfilesEqual(left, right) {
        if (left.length !== right.length)
            return false;

        for (let i = 0; i < left.length; i++) {
            if (left[i].name !== right[i].name
                    || left[i].type !== right[i].type
                    || left[i].active !== right[i].active) {
                return false;
            }
        }

        return true;
    }

    function parseVpnProfiles() {
        const nextProfiles = buildVpnProfiles(vpnListText, activeVpnListText);
        if (!vpnProfilesEqual(vpnProfiles, nextProfiles))
            vpnProfiles = nextProfiles;
    }

    function commitVpnRefreshIfReady() {
        if (!vpnListReady || !activeVpnReady)
            return;

        vpnRefreshing = false;
        if (vpnRefreshFailed)
            return;

        const nextProfiles = buildVpnProfiles(pendingVpnListText, pendingActiveVpnListText);
        vpnListText = pendingVpnListText;
        activeVpnListText = pendingActiveVpnListText;
        if (!vpnProfilesEqual(vpnProfiles, nextProfiles))
            vpnProfiles = nextProfiles;
    }

    function refreshVpn() {
        if (vpnRefreshing || vpnListProcess.running || activeVpnProcess.running)
            return;

        pendingVpnListText = "";
        pendingActiveVpnListText = "";
        vpnListReady = false;
        activeVpnReady = false;
        vpnRefreshFailed = false;
        vpnRefreshing = true;
        vpnListProcess.running = true;
        activeVpnProcess.running = true;
    }

    function toggleVpn(profile) {
        if (!profile)
            return;
        vpnActionProcess.exec(["nmcli", "connection", profile.active ? "down" : "up", profile.name]);
    }

    Component.onCompleted: {
        scan();
        refreshVpn();
    }

    Timer {
        id: scanTimer
        interval: 6000
        repeat: false
        onTriggered: {
            root.scanBusy = false;
            if (root.available)
                root.wifiDevice.scannerEnabled = false;
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refreshVpn()
    }

    Process {
        id: vpnListProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingVpnListText = text;
                root.vpnListReady = true;
                root.commitVpnRefreshIfReady();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.vpnRefreshFailed = true;
                    root.vpnRefreshing = false;
                    root.lastError = "Could not list VPN connections";
                }
            }
        }
    }

    Process {
        id: activeVpnProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingActiveVpnListText = text;
                root.activeVpnReady = true;
                root.commitVpnRefreshIfReady();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.vpnRefreshFailed = true;
                    root.vpnRefreshing = false;
                    root.lastError = "Could not list active VPN connections";
                }
            }
        }
    }

    Process {
        id: vpnActionProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.lastError = "VPN action failed";
            root.refreshVpn();
        }
    }
}
