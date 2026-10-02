import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Centered placeholder shown when the visible listing is empty.
Column {
    id: empty
    property bool filtered: false

    spacing: 8

    MaterialSymbol {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.filtered ? "search" : "folder"
        color: Appearance.colors.colPrimary
        iconSize: 34
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.filtered ? "No matches" : "Empty folder"
        color: Appearance.colors.colSubtext
        
        font.pixelSize: 13
    }
}
