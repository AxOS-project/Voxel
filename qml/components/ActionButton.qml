import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Pill-shaped text button used in dialogs, toasts, and the file picker bar.
RippleButton {
    id: actionButton

    property string label: ""
    property bool primary: false
    property bool danger: false

    signal activated()

    buttonText: actionButton.label
    implicitHeight: 28
    buttonRadius: implicitHeight / 2

    colBackground: {
        if (actionButton.primary) return Appearance.colors.colPrimary;
        if (actionButton.danger) return Appearance.colors.colErrorContainer;
        return Appearance.colors.colLayer2;
    }

    colText: {
        if (actionButton.primary) return Appearance.colors.colOnPrimary;
        if (actionButton.danger) return Appearance.colors.colError;
        return Appearance.colors.colOnLayer2;
    }

    colBackgroundHover: {
        if (actionButton.primary) return Appearance.colors.colPrimaryHover;
        if (actionButton.danger) return Appearance.colors.colErrorContainerHover;
        return Appearance.colors.colLayer2Hover;
    }

    onClicked: actionButton.activated()
}
