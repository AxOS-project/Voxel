import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Search box in the top toolbar for filtering files in the current folder.
Rectangle {
    id: searchField

    property alias text: input.text

    signal moveUp()
    signal moveDown()
    signal escaped()
    signal accepted()

    function focusInput() {
        input.forceActiveFocus();
        input.selectAll();
    }

    function appendInput(character) {
        input.forceActiveFocus();
        input.text += character;
        input.cursorPosition = input.text.length;
    }

    implicitHeight: 32
    radius: Appearance.rounding.full
    color: Appearance.colors.colLayer0
    border.width: 1
    border.color: input.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
    Behavior on border.color { ColorAnimation { duration: 120 } }

    MaterialSymbol {
        id: searchIcon
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: "search"
        color: Appearance.colors.colSubtext
        iconSize: 14
    }

    TextInput {
        id: input
        anchors {
            left: searchIcon.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 8
            rightMargin: 12
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Appearance.colors.colOnLayer0
        font.pixelSize: 13
        selectionColor: Appearance.colors.colPrimary
        selectedTextColor: Appearance.colors.colLayer0
        clip: true

        Keys.onReturnPressed: (event) => { searchField.accepted(); event.accepted = true; }
        Keys.onEnterPressed: (event) => { searchField.accepted(); event.accepted = true; }
        Keys.onDownPressed: (event) => { searchField.moveDown(); event.accepted = true; }
        Keys.onUpPressed: (event) => { searchField.moveUp(); event.accepted = true; }
        Keys.onEscapePressed: (event) => {
            input.text = "";
            searchField.escaped();
            event.accepted = true;
        }
    }

    Text {
        anchors {
            left: input.left
            verticalCenter: parent.verticalCenter
        }
        visible: input.text.length === 0
        text: "Search"
        color: Appearance.colors.colSubtext
        font.pixelSize: 13
    }
}
