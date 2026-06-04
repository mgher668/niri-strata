import QtQuick
import Quickshell

Item {
    id: root

    required property var niriState

    property bool open: false
    property string targetOutputName: niriState.focusedOutputName
    readonly property string focusedOutputName: niriState.focusedOutputName

    function openForOutput(outputName) {
        const normalizedOutput = String(outputName || focusedOutputName || "");
        if (normalizedOutput.length === 0)
            return;

        targetOutputName = normalizedOutput;
        open = true;
    }

    function toggleForOutput(outputName) {
        const normalizedOutput = String(outputName || focusedOutputName || "");
        if (open && targetOutputName === normalizedOutput) {
            close();
            return;
        }

        openForOutput(normalizedOutput);
    }

    function close() {
        open = false;
    }

    function screenMatches(screen) {
        return !!screen && screen.name === targetOutputName;
    }
}
