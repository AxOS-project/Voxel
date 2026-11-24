import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

Item {
    id: status
    height: status.pickerSave ? 40 : 32

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

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer2
    }
    Text {
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: status.selectedCount > 0
              ? (status.selectedCount + " selected")
              : (status.visibleCount + " / " + status.totalCount)
        color: Appearance.colors.colOnLayer0
        font.pixelSize: 11
    }
    Text {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        visible: !status.pickerMode
        text: status.statusText
        color: Appearance.colors.colOnLayer0
        font.pixelSize: 11
    }

    Row {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8
        visible: status.pickerMode

        Rectangle {
            visible: status.pickerSave
            width: 240
            height: 28
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: saveInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            TextInput {
                id: saveInput
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 12
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colLayer0
                clip: true

                Keys.onReturnPressed: (e) => { status.pickerAccept(); e.accepted = true; }
                Keys.onEnterPressed: (e) => { status.pickerAccept(); e.accepted = true; }
                Keys.onEscapePressed: (e) => { status.pickerCancel(); e.accepted = true; }
            }

            Text {
                anchors { left: saveInput.left; verticalCenter: parent.verticalCenter }
                visible: saveInput.text.length === 0
                text: "File name"
                color: Appearance.colors.colSubtext
                font.pixelSize: 12
            }
        }

        ActionButton { label: "Cancel"; onActivated: status.pickerCancel() }
        ActionButton {
            label: status.pickerSave ? "Save"
                 : status.pickerDirectory ? "Choose folder"
                 : "Choose file"
            primary: true
            onActivated: status.pickerAccept()
        }
    }
}
