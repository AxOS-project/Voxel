import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Popup dialog asking the user to confirm before deleting or trashing files.
Item {
    id: dialog

    property bool shown: false
    property string title: ""
    property string message: ""
    property string confirmLabel: "OK"
    property bool danger: false

    signal confirmed()
    signal cancelled()

    anchors.fill: parent
    z: 110
    opacity: dialog.shown ? 1 : 0
    visible: opacity > 0.01
    focus: dialog.shown
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    onShownChanged: if (dialog.shown) dialog.forceActiveFocus()
    Keys.onEscapePressed: (event) => { dialog.cancelled(); event.accepted = true; }
    Keys.onReturnPressed: (event) => { dialog.confirmed(); event.accepted = true; }
    Keys.onEnterPressed: (event) => { dialog.confirmed(); event.accepted = true; }

    // Dark background overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: dialog.cancelled()
        }
    }

    // Center dialog box
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(420, dialog.parent ? dialog.parent.width - 48 : 372)
        height: 168
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        scale: dialog.shown ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Prevent clicks inside the box from closing the dialog
        MouseArea { anchors.fill: parent }

        MaterialSymbol {
            id: titleIcon
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 20
                topMargin: 20
            }
            text: dialog.danger ? "delete_forever" : "delete"
            color: dialog.danger ? Appearance.colors.colError : Appearance.colors.colPrimary
            iconSize: 18
        }

        Text {
            anchors {
                left: titleIcon.right
                leftMargin: 12
                right: parent.right
                rightMargin: 20
                verticalCenter: titleIcon.verticalCenter
            }
            text: dialog.title
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 20
                rightMargin: 20
                topMargin: 58
            }
            text: dialog.message
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Row {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 16
                bottomMargin: 16
            }
            spacing: 8

            ActionButton {
                label: "Cancel"
                onActivated: dialog.cancelled()
            }

            ActionButton {
                label: dialog.confirmLabel
                primary: !dialog.danger
                danger: dialog.danger
                onActivated: dialog.confirmed()
            }
        }
    }
}
