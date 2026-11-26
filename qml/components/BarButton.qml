import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Circular icon button used in the top navigation bar and media controls.
RippleButton {
    id: barButton

    property string glyph: ""
    property bool active: false

    signal activated()

    implicitWidth: 32
    implicitHeight: 32
    buttonRadius: 16

    colBackground: barButton.active ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: barButton.active ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover

    MaterialSymbol {
        anchors.centerIn: parent
        text: barButton.glyph
        color: barButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        iconSize: 18
        fill: 1
    }

    onClicked: barButton.activated()
}
