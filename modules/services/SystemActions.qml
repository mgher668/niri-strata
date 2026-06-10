import QtQuick
import Quickshell

Item {
    id: root

    required property var networkService
    required property var wifiService
    required property var bluetoothService
    required property var audioService
    required property var notificationService
    required property var powerProfilesService
    required property var brightnessService
    required property var nightModeService
    required property var captureService

    readonly property bool wifiAvailable: wifiService.available
    readonly property bool wifiEnabled: wifiService.enabled
    readonly property string wifiStatus: wifiService.statusText
    readonly property bool bluetoothAvailable: bluetoothService.available
    readonly property bool bluetoothEnabled: bluetoothService.enabled
    readonly property string bluetoothStatus: bluetoothService.statusText
    readonly property bool audioAvailable: audioService.available
    readonly property bool audioMuted: audioService.muted
    readonly property string audioStatus: audioService.available ? audioService.percentText : "Unavailable"
    readonly property bool microphoneAvailable: audioService.inputAvailable
    readonly property bool microphoneMuted: audioService.microphoneMuted
    readonly property string microphoneStatus: audioService.inputAvailable ? audioService.microphonePercentText : "Unavailable"
    readonly property bool nightModeAvailable: nightModeService.available
    readonly property bool nightModeEnabled: nightModeService.enabled
    readonly property string nightModeStatus: nightModeService.statusText || "Backend unavailable"
    readonly property bool nightModeBusy: nightModeService.busy
    readonly property int nightModeTemperature: nightModeService.temperature
    readonly property int nightModeMinTemperature: nightModeService.minTemperature
    readonly property int nightModeMaxTemperature: nightModeService.maxTemperature
    readonly property bool brightnessAvailable: brightnessService.available
    readonly property string brightnessStatus: brightnessService.statusText || "No DDC display"
    readonly property bool brightnessServiceBusy: brightnessService.busy
    readonly property var brightnessDisplays: brightnessService.displays
    readonly property bool powerProfileAvailable: powerProfilesService.available
    readonly property string powerProfileStatus: powerProfilesService.statusText
    readonly property var powerProfiles: powerProfilesService.profiles
    readonly property bool screenshotAvailable: captureService.screenshotAvailable
    readonly property string screenshotStatus: captureService.screenshotStatus
    readonly property bool screenshotBusy: captureService.screenshotBusy
    readonly property bool recordingAvailable: captureService.recordingAvailable
    readonly property bool currentOutputRecordingAvailable: captureService.currentOutputRecordingAvailable
    readonly property string recordingStatus: captureService.recordingStatus
    readonly property string recordingMode: captureService.recordingMode
    readonly property bool recordingAudioAvailable: captureService.recordingAudioAvailable
    readonly property bool recordingAudioEnabled: captureService.recordingAudioEnabled
    readonly property string recordingDegradedReason: captureService.recordingDegradedReason
    readonly property string recordingSavePath: captureService.recordingSavePath
    readonly property string recordingLastError: captureService.recordingLastError
    readonly property bool regionRecordingAvailable: captureService.regionRecordingAvailable
    readonly property string regionRecordingStatus: captureService.regionRecordingStatus
    readonly property bool regionRecordingActive: captureService.regionRecordingActive
    readonly property bool lockAvailable: true
    readonly property bool recordingActive: captureService.recordingActive
    property string pendingSessionAction: ""

    function toggleWifi() {
        wifiService.toggleEnabled();
    }

    function toggleBluetooth() {
        bluetoothService.toggleEnabled();
    }

    function toggleAudioMute() {
        audioService.toggleMute();
    }

    function toggleMicrophoneMute() {
        audioService.toggleMicrophoneMute();
    }

    function toggleNightMode() {
        nightModeService.toggle();
    }

    function setNightModeTemperature(temperature) {
        nightModeService.setTemperature(temperature);
    }

    function refreshNightMode() {
        nightModeService.refresh();
    }

    function setBrightness(display, percent) {
        brightnessService.setBrightness(display, percent);
    }

    function refreshBrightness() {
        brightnessService.refresh();
    }

    function takeScreenshot() {
        captureService.takeScreenshot();
    }

    function toggleRecording() {
        captureService.toggleRecording();
    }

    function startRecording() {
        captureService.startRecording();
    }

    function stopRecording() {
        captureService.stopRecording();
    }

    function toggleRegionRecording() {
        captureService.toggleRegionRecording();
    }

    function setRecordingMode(mode) {
        captureService.setRecordingMode(mode);
    }

    function setRecordingAudioEnabled(enabled) {
        captureService.setRecordingAudioEnabled(enabled);
    }

    function recordingModeAvailable(mode) {
        return captureService.recordingModeAvailable(mode);
    }

    function setPowerProfile(profile) {
        powerProfilesService.setProfile(profile);
    }

    function lockScreen() {
        runSessionAction("lock");
    }

    function sessionCommand(action) {
        if (action === "lock")
            return ["swaylock", "--screenshots", "--clock", "--indicator"];
        if (action === "logout")
            return ["niri", "msg", "action", "quit"];
        if (action === "suspend")
            return ["systemctl", "suspend"];
        if (action === "reboot")
            return ["systemctl", "reboot"];
        if (action === "shutdown")
            return ["systemctl", "poweroff"];
        return [];
    }

    function requiresConfirmation(action) {
        return action === "logout" || action === "suspend" || action === "reboot" || action === "shutdown";
    }

    function runSessionAction(action) {
        const command = sessionCommand(action);
        if (command.length === 0)
            return;

        if (requiresConfirmation(action) && pendingSessionAction !== action) {
            pendingSessionAction = action;
            confirmTimer.restart();
            return;
        }

        pendingSessionAction = "";
        Quickshell.execDetached(command);
    }

    function cancelSessionAction() {
        pendingSessionAction = "";
        confirmTimer.stop();
    }

    Timer {
        id: confirmTimer
        interval: 5000
        repeat: false
        onTriggered: root.pendingSessionAction = ""
    }

}
