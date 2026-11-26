import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Top navigation toolbar with back/forward buttons, path breadcrumbs, sorting, and search.
Rectangle {
    id: topBar

    height: 52
    color: Appearance.colors.colLayer2

    property var crumbs: []
    property string curPath: ""
    property bool showHidden: false
    property bool previewVisible: false
    property int trashCount: 0
    property alias filter: searchBox.text
    property string sortBy: "Name"
    property bool rowLayout: false

    signal goBack()
    signal goForward()
    signal goUp()
    signal goHome()
    signal refresh()
    signal navigate(string path)
    signal dropRequested(string path, var uris, bool isInternal)
    signal toggleHidden()
    signal togglePreview()
    signal openTrash()
    signal searchAccepted()
    signal moveUp()
    signal moveDown()
    signal escaped()
    signal rowLayoutToggled()
    signal sortChanged(string sortBy)

    function focusSearch() { searchBox.focusInput(); }
    function typeSearch(character) { searchBox.appendInput(character); }

    // Left navigation buttons
    Row {
        id: navButtons
        anchors {
            left: parent.left
            leftMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        BarButton { glyph: "chevron_left"; onActivated: topBar.goBack() }
        BarButton { glyph: "chevron_right"; onActivated: topBar.goForward() }
        BarButton { glyph: "arrow_upward"; onActivated: topBar.goUp() }
        BarButton { glyph: "home"; onActivated: topBar.goHome() }
        BarButton { glyph: "refresh"; onActivated: topBar.refresh() }
    }

    // Center folder path breadcrumbs
    Breadcrumbs {
        anchors {
            left: navButtons.right
            leftMargin: 10
            right: toolButtons.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        model: topBar.crumbs
        currentPath: topBar.curPath
        onNavigate: (path) => topBar.navigate(path)
        onDropRequested: (path, uris, isInternal) => topBar.dropRequested(path, uris, isInternal)
    }

    // Right view & search controls
    Row {
        id: toolButtons
        anchors {
            right: parent.right
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        IconComboBox {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 32
            icon: "sort"
            model: ["Name", "Date", "Size", "Type"]
            currentIndex: Math.max(0, model.indexOf(topBar.sortBy))
            onActivated: (index) => {
                topBar.sortChanged(model[index]);
                topBar.escaped();
            }
        }

        BarButton {
            glyph: topBar.rowLayout ? "view_list" : "view_module"
            active: topBar.rowLayout
            onActivated: topBar.rowLayoutToggled()
        }

        SearchField {
            id: searchBox
            width: 180
            onAccepted: topBar.searchAccepted()
            onMoveUp: topBar.moveUp()
            onMoveDown: topBar.moveDown()
            onEscaped: topBar.escaped()
        }

        BarButton {
            glyph: topBar.showHidden ? "visibility" : "visibility_off"
            active: topBar.showHidden
            onActivated: topBar.toggleHidden()
        }

        BarButton {
            glyph: "description"
            active: topBar.previewVisible
            onActivated: topBar.togglePreview()
        }

        BarButton {
            glyph: "delete"
            active: topBar.trashCount > 0
            onActivated: topBar.openTrash()
        }
    }
}
