import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

Item {
    id: status
    height: 32

    property int selectedCount: 0
    property int visibleCount: 0
    property int totalCount: 0
    property string statusText: ""
    property bool pickerMode: false
    property bool pickerDirectory: false

    signal pickerCancel()
    signal pickerAccept()

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Appearance.colors.colOutlineVariant
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

        ActionButton { label: "Cancel"; onActivated: status.pickerCancel() }
        ActionButton {
            label: status.pickerDirectory ? "Choose folder" : "Choose file"
            primary: true
            onActivated: status.pickerAccept()
        }
    }
}
