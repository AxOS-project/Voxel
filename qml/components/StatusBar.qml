import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Bottom bar showing item counts, status text, and Save/Choose buttons when running as a file picker.
Rectangle {
    id: statusBar

    height: statusBar.pickerSave ? 40 : 32
    color: Appearance.colors.colLayer2

    property int selectedCount: 0
    property int visibleCount: 0
    property int totalCount: 0
    property string statusText: ""
    property bool pickerMode: false
    property bool pickerDirectory: false
    property bool pickerSave: false
    property alias pickerFileName: saveInput.text

    signal pickerCancel()
    signal pickerAccept()

    function focusSaveInput() {
        saveInput.forceActiveFocus();
        saveInput.selectAll();
    }

    // Left: selection count or visible/total count
    Text {
        anchors {
            left: parent.left
            leftMargin: 14
            verticalCenter: parent.verticalCenter
        }
        text: statusBar.selectedCount > 0
            ? (statusBar.selectedCount + " selected")
            : (statusBar.visibleCount + " / " + statusBar.totalCount)
        color: Appearance.colors.colOnLayer0
        font.pixelSize: 11
    }

    // Right (normal mode): total item count or error message
    Text {
        anchors {
            right: parent.right
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        visible: !statusBar.pickerMode
        text: statusBar.statusText
        color: Appearance.colors.colOnLayer0
        font.pixelSize: 11
    }

    // Right (file picker mode): filename box + Cancel / Choose buttons
    Row {
        anchors {
            right: parent.right
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 8
        visible: statusBar.pickerMode

        Rectangle {
            visible: statusBar.pickerSave
            width: 240
            height: 28
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: saveInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            TextInput {
                id: saveInput
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 12
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colLayer0
                clip: true

                Keys.onReturnPressed: (event) => { statusBar.pickerAccept(); event.accepted = true; }
                Keys.onEnterPressed: (event) => { statusBar.pickerAccept(); event.accepted = true; }
                Keys.onEscapePressed: (event) => { statusBar.pickerCancel(); event.accepted = true; }
            }

            Text {
                anchors {
                    left: saveInput.left
                    verticalCenter: parent.verticalCenter
                }
                visible: saveInput.text.length === 0
                text: "File name"
                color: Appearance.colors.colSubtext
                font.pixelSize: 12
            }
        }

        ActionButton {
            label: "Cancel"
            onActivated: statusBar.pickerCancel()
        }

        ActionButton {
            label: {
                if (statusBar.pickerSave) return "Save";
                if (statusBar.pickerDirectory) return "Choose folder";
                return "Choose file";
            }
            primary: true
            onActivated: statusBar.pickerAccept()
        }
    }
}
