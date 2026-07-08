import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import "../common/"

// Bar background canvas: SVG vector shape with gothic side wings.
// Flush to screen top edge (no top rounding, no top margin).
// Bottom corners can round; side wings swoop down at both ends.
Item {
    id: root

    required property color bgColor
    required property color borderColor
    property bool showBorder: false
    property real borderThickness: 1
    property real wingRadius: 8       // gothic wing sweep radius (0 disables)
    property real bottomRadius: 12    // bottom inner corner radius
    property bool hasMaximizedWindow: false

    anchors.fill: parent

    // When a window is maximized, flatten wings + rounding for edge-to-edge bar.
    property real effectiveWing: hasMaximizedWindow ? 0 : wingRadius
    property real effectiveRadius: hasMaximizedWindow ? 0 : bottomRadius

    Behavior on effectiveWing {
        enabled: root.width > 0 && root.height > 0
        NumberAnimation {
            duration: Theme.animation.normal
            easing.type: Theme.animation.easing
        }
    }

    Behavior on effectiveRadius {
        enabled: root.width > 0 && root.height > 0
        NumberAnimation {
            duration: Theme.animation.normal
            easing.type: Theme.animation.easing
        }
    }

    readonly property string mainPath: {
        effectiveWing;
        effectiveRadius;
        width;
        height;
        return generateTopPath(width, height);
    }

    readonly property string borderPath: {
        effectiveWing;
        effectiveRadius;
        width;
        height;
        return generateTopBorderPath(width, height);
    }

    // --- Drop shadow (simple, no ElevationShadow dependency) ---
    DropShadow {
        anchors.fill: parent
        visible: !root.hasMaximizedWindow
        radius: 12
        samples: 25
        color: Qt.rgba(0, 0, 0, 0.35)
        verticalOffset: 2
        source: barShape
    }

    // --- Main fill shape ---
    Shape {
        id: barShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: false  // only used as shadow source; fill drawn below

        ShapePath {
            fillColor: root.bgColor
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg { path: root.mainPath }
        }
    }

    Shape {
        id: barFill
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.bgColor
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg { path: root.mainPath }
        }
    }

    // --- Border (bottom edge + wings only, since top is flush) ---
    Shape {
        id: barBorder
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.showBorder

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.borderColor
            strokeWidth: root.borderThickness
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.borderPath }
        }
    }

    // --- SVG path generators (top position only) ---
    // Top edge: flat (y=0), flush to screen.
    // Bottom edge: rounded corners + optional gothic wings swooping down.

    function generateTopPath(w, h) {
        const r = effectiveWing;   // wing radius
        const cr = effectiveRadius; // bottom corner radius

        let d = `M 0 0`;
        d += ` L ${w} 0`;

        if (r > 0) {
            // Right side: go down past bottom, arc back up (wing)
            d += ` L ${w} ${h + r}`;
            d += ` A ${r} ${r} 0 0 0 ${w - r} ${h}`;
            d += ` L ${r} ${h}`;
            d += ` A ${r} ${r} 0 0 0 0 ${h + r}`;
        } else {
            // No wings: rounded bottom corners
            d += ` L ${w} ${h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} ${h}`;
            d += ` L ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
        }

        d += ` L 0 0`;
        d += ` Z`;
        return d;
    }

    function generateTopBorderPath(w, h) {
        const r = effectiveWing;
        const cr = effectiveRadius;

        let d = "";
        if (r > 0) {
            // Only trace the bottom wing curve
            d = `M ${w} ${h + r}`;
            d += ` A ${r} ${r} 0 0 0 ${w - r} ${h}`;
            d += ` L ${r} ${h}`;
            d += ` A ${r} ${r} 0 0 0 0 ${h + r}`;
        } else {
            d = `M ${w} ${h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} ${h}`;
            d += ` L ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
        }
        return d;
    }
}