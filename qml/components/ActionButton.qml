import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

RippleButton {
    id: ab
    property string label
    property bool primary: false
    property bool danger: false
    signal activated()

    buttonText: ab.label
    implicitHeight: 28
    buttonRadius: implicitHeight / 2
    
    colBackground: ab.primary ? Appearance.colors.colPrimary
                 : ab.danger ? Appearance.colors.colErrorContainer
                 : Appearance.colors.colLayer2
                 
    colText: ab.primary ? Appearance.colors.colOnPrimary
           : ab.danger ? Appearance.colors.colError
           : Appearance.colors.colOnLayer2

    colBackgroundHover: ab.primary ? Appearance.colors.colPrimaryHover
                      : ab.danger ? Appearance.colors.colErrorContainerHover
                      : Appearance.colors.colLayer2Hover

    onClicked: ab.activated()
}
