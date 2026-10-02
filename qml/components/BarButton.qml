import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

RippleButton {
    id: btn
    property string glyph
    property bool active: false
    signal activated()

    implicitWidth: 32
    implicitHeight: 32
    buttonRadius: 16
    
    colBackground: btn.active ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: btn.active ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover
    
    MaterialSymbol {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        iconSize: 18
        fill: 1
    }

    onClicked: btn.activated()
}
