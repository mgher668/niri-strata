import QtQuick
import "."

StyledText {
    id: root

    property string name: ""
    property int size: Theme.font.xl
    property bool filled: false
    property int weight: 500
    property color iconColor: Theme.colors.text

    text: name
    font.family: Theme.font.familyIcon
    font.pixelSize: size
    font.weight: weight
    color: iconColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    font.variableAxes: ({
        "FILL": filled ? 1 : 0,
        "GRAD": 0,
        "opsz": size,
        "wght": weight,
    })
}
