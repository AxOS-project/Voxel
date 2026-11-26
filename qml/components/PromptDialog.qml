import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Popup dialog with a text box, used for "New file", "New folder", and "Rename".
Item {
    id: dialog

    property bool shown: false
    property string title: ""
    property string glyph: "edit"
    property string placeholder: "Name"
    property string value: ""
    property string confirmLabel: "Create"

    signal accepted(string text)
    signal cancelled()

    anchors.fill: parent
    z: 100
    opacity: dialog.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    onShownChanged: if (dialog.shown) {
        nameInput.text = dialog.value;
        Qt.callLater(function() {
            nameInput.forceActiveFocus();
            nameInput.selectAll();
        });
    }

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
        height: 172
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer2
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
            text: dialog.glyph
            color: Appearance.colors.colPrimary
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

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 20
                rightMargin: 20
                topMargin: 62
            }
            height: 40
            radius: 10
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: nameInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            TextInput {
                id: nameInput
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 13
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colLayer0
                clip: true
                onAccepted: dialog.accepted(text)
                Keys.onEscapePressed: (event) => { dialog.cancelled(); event.accepted = true; }
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                visible: nameInput.text.length === 0
                text: dialog.placeholder
                color: Appearance.colors.colSubtext
                font.pixelSize: 13
            }
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
                primary: true
                onActivated: dialog.accepted(nameInput.text)
            }
        }
    }
}
