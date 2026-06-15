import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputDevices: audioNodes(true, false)
    readonly property var inputDevices: audioNodes(false, false)
    readonly property var outputStreams: audioNodes(true, true)
    readonly property var inputStreams: audioNodes(false, true)
    readonly property bool available: !!sink && !!sink.audio
    readonly property bool inputAvailable: !!source && !!source.audio
    readonly property bool ready: Pipewire.ready && (sink?.ready ?? false)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool microphoneMuted: source?.audio?.muted ?? false
    readonly property real volume: Math.max(0, Math.min(1.5, sink?.audio?.volume ?? 0))
    readonly property real microphoneVolume: Math.max(0, Math.min(1.5, source?.audio?.volume ?? 0))
    readonly property int percent: Math.round(volume * 100)
    readonly property int microphonePercent: Math.round(microphoneVolume * 100)
    readonly property string percentText: available ? `${percent}%` : "--"
    readonly property string microphonePercentText: inputAvailable ? `${microphonePercent}%` : "--"
    readonly property string deviceName: cleanName(sink?.nickname || sink?.description || sink?.name || "Audio")
    readonly property string sourceName: cleanName(source?.nickname || source?.description || source?.name || "Microphone")
    readonly property string stateText: !available ? "No output" : muted ? "Muted" : "Output"
    readonly property string microphoneStateText: !inputAvailable ? "No input" : microphoneMuted ? "Muted" : "Input"
    readonly property string iconText: !available ? "A-" : muted ? "MUT" : volume >= 0.66 ? "VOL" : volume >= 0.33 ? "vol" : "low"
    property bool osdVisible: false
    property bool osdChangeNotificationsEnabled: false
    property bool observedAudioState: false
    property real observedVolume: 0
    property bool observedMuted: false

    onAvailableChanged: syncObservedAudioState(false)
    onVolumeChanged: syncObservedAudioState(true)
    onMutedChanged: syncObservedAudioState(true)

    function showOsd() {
        if (!available)
            return;
        osdVisible = true;
        osdTimer.restart();
    }

    function syncObservedAudioState(showOnChange) {
        if (!available) {
            observedAudioState = false;
            return;
        }

        const changed = observedAudioState
            && (Math.abs(volume - observedVolume) > 0.001 || muted !== observedMuted);

        observedVolume = volume;
        observedMuted = muted;
        observedAudioState = true;

        if (showOnChange && osdChangeNotificationsEnabled && changed)
            showOsd();
    }

    function cleanName(name) {
        return String(name ?? "Audio")
            .replace(/^alsa_output\./, "")
            .replace(/^alsa_input\./, "")
            .replace(/^bluez_output\./, "")
            .replace(/^bluez_input\./, "")
            .replace(/\./g, " ")
            .trim();
    }

    function nodeLabel(node) {
        return cleanName(node?.nickname || node?.description || node?.properties?.["application.name"] || node?.name || "Audio");
    }

    function audioNodes(sinkNode, streamNode) {
        return nodes.filter(node => {
            return !!node.audio && node.isSink === sinkNode && node.isStream === streamNode;
        });
    }

    function volumeText(node) {
        if (!node || !node.audio)
            return "--";
        return `${Math.round(Math.max(0, Math.min(1.5, node.audio.volume ?? 0)) * 100)}%`;
    }

    function setVolume(value) {
        if (!available)
            return;
        sink.audio.volume = Math.max(0, Math.min(1.5, value));
        showOsd();
    }

    function setSourceVolume(value) {
        if (!inputAvailable)
            return;
        source.audio.volume = Math.max(0, Math.min(1.5, value));
    }

    function changeVolume(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (!available)
            return;
        sink.audio.muted = !sink.audio.muted;
        showOsd();
    }

    function toggleMicrophoneMute() {
        if (!inputAvailable)
            return;
        source.audio.muted = !source.audio.muted;
    }

    function setDefaultSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Timer {
        id: osdStartupQuietTimer
        interval: 1800
        repeat: false
        running: true
        onTriggered: {
            root.syncObservedAudioState(false);
            root.osdVisible = false;
            root.osdChangeNotificationsEnabled = true;
        }
    }

    Timer {
        id: osdTimer
        interval: 1200
        repeat: false
        onTriggered: root.osdVisible = false
    }
}
