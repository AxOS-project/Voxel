import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

Item {
    id: top
    height: 52

    property var crumbs: []
    property string curPath: ""
    property bool showHidden: false
    property bool previewVisible: true
    property int trashCount: 0
    property alias filter: search.text

    signal goBack()
    signal goForward()
    signal goUp()
    signal goHome()
    signal refresh()
    signal navigate(string path)
    signal dropRequested(string path, var uris, bool internal)
    signal toggleHidden()
    signal togglePreview()
    signal openTrash()
    signal searchAccepted()
    signal moveUp()
    signal moveDown()
    signal escaped()

    function focusSearch() { search.focusInput(); }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    Row {
        id: navButtons
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 6

        BarButton { glyph: "chevron_left"; onActivated: top.goBack() }
        BarButton { glyph: "chevron_right"; onActivated: top.goForward() }
        BarButton { glyph: "arrow_upward"; onActivated: top.goUp() }
        BarButton { glyph: "home"; onActivated: top.goHome() }
        BarButton { glyph: "refresh"; onActivated: top.refresh() }
    }

    Breadcrumbs {
        id: crumbsView
        anchors {
            left: navButtons.right; leftMargin: 10
            right: tools.left; rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        model: top.crumbs
        currentPath: top.curPath
        onNavigate: (path) => top.navigate(path)
        onDropRequested: (path, uris, internal) => top.dropRequested(path, uris, internal)
    }

    Row {
        id: tools
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 6

        SearchField {
            id: search
            width: 180
            onAccepted: top.searchAccepted()
            onMoveUp: top.moveUp()
            onMoveDown: top.moveDown()
            onEscaped: top.escaped()
        }
        BarButton {
            glyph: top.showHidden ? "visibility" : "visibility_off"
            active: top.showHidden
            onActivated: top.toggleHidden()
        }
        BarButton {
            glyph: "description"
            active: top.previewVisible
            onActivated: top.togglePreview()
        }
        BarButton {
            glyph: "delete"
            active: top.trashCount > 0
            onActivated: top.openTrash()
        }
    }
}
