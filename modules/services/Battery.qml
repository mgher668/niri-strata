import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool ready: device && device.ready
    readonly property bool present: ready && device.isPresent
    readonly property real percentage: present ? Math.max(0, Math.min(1, device.percentage)) : 0
    readonly property int percent: Math.round(percentage * 100)
    readonly property string percentText: `${percent}%`
    readonly property string iconName: present ? device.iconName : "battery-missing-symbolic"
    readonly property int state: ready ? device.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && percent <= 20 && !charging
    readonly property bool hasHealth: present && device.healthSupported
    readonly property int healthPercent: hasHealth ? Math.round(Math.max(0, Math.min(1, device.healthPercentage)) * 100) : 0
    readonly property string healthText: hasHealth ? `${healthPercent}%` : "--"
    readonly property string modelText: present && device.model.length > 0 ? device.model : "Battery"
    readonly property string energyText: present && device.energyCapacity > 0 ? `${device.energy.toFixed(1)} / ${device.energyCapacity.toFixed(1)} Wh` : "--"
    readonly property string powerText: present && device.changeRate > 0 ? `${device.changeRate.toFixed(1)} W` : "--"
    readonly property string timeText: charging ? secondsText(device.timeToFull)
        : state === UPowerDeviceState.Discharging ? secondsText(device.timeToEmpty)
        : "--"
    readonly property string stateText: full ? "Full"
        : charging ? "Charging"
        : state === UPowerDeviceState.Discharging ? "Battery"
        : "Power"

    function secondsText(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return "--";

        const totalMinutes = Math.round(seconds / 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        if (hours <= 0)
            return `${minutes}m`;
        return `${hours}h ${minutes}m`;
    }
}
