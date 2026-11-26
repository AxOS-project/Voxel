import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import SleexUiKit.Functions
import "../Utils.js" as Utils

// Main file browser area. Supports both Grid mode and List mode using a single view,
// plus drag-and-drop, rubber-band (marquee) selection, and an empty-folder message.
Item {
    id: fileView

    property var model: []
    property bool rowLayout: false
    property int hoverIndex: -1
    property bool filtered: false
    property var xdgDirs: ({})
    property var selectedMap: ({})
    property var cutMap: ({})

    // Injected helper from Main.qml that builds the list of file:// URIs to drag
    property var dragUrisForIndex: null

    signal itemClicked(int index, int modifiers)
    signal itemDoubleClicked(int index)
    signal contextMenuRequested(int index, real sceneX, real sceneY)
    signal dropRequested(string targetPath, var uris, bool isInternal)
    signal selectionCleared()
    signal marqueeSelected(var newSelection)
    signal hoverUpdated(int index, real sceneX, real sceneY)
    signal interactionStarted()

    // Rubber-band selection box state
    property bool marqueeActive: false
    property real marqueeStartX: 0
    property real marqueeStartY: 0
    property real marqueeEndX: 0
    property real marqueeEndY: 0

    // Number of items per row (1 in List mode, multiple in Grid mode)
    readonly property int columns: fileView.rowLayout
        ? 1
        : Math.max(1, Math.floor(grid.width / grid.cellWidth))

    // Number of items that fit on a single screen (used for PageUp / PageDown)
    readonly property int itemsPerPage: {
        const visibleRows = Math.max(1, Math.floor(grid.height / grid.cellHeight));
        return fileView.columns * visibleRows;
    }

    anchors.margins: 8

    function scrollToIndex(index) {
        if (index >= 0 && index < fileView.model.length) {
            grid.positionViewAtIndex(index, GridView.Contain);
        }
    }

    function resetScroll() {
        grid.contentY = 0;
    }

    // ---- File Grid / List --------------------------------------------------
    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        model: fileView.model
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 2000
        highlightFollowsCurrentItem: false

        cellWidth: fileView.rowLayout ? Math.max(1, grid.width) : 125
        cellHeight: fileView.rowLayout ? 36 : 125

        delegate: FileItem {
            width: fileView.rowLayout ? grid.width : (grid.cellWidth - 4)
            height: fileView.rowLayout ? 36 : (grid.cellHeight - 4)
            rowLayout: fileView.rowLayout
            selected: !!(fileView.selectedMap && fileView.selectedMap[modelData.path])
            hovered: index === fileView.hoverIndex
            isCut: !!(fileView.cutMap && fileView.cutMap[modelData.path])
            xdgDirs: fileView.xdgDirs
            onDropRequested: (targetPath, uris, isInternal) => {
                fileView.dropRequested(targetPath, uris, isInternal);
            }
        }

        ScrollBar.vertical: StyledScrollBar {}
    }

    // Invisible item used as a target when dragging files out of the window
    Item {
        id: dragProxy
        width: 1
        height: 1
        x: -1000
        y: -1000
    }

    // ---- Mouse Interaction (Click, Drag, Rubber-band, Right-click) ---------
    MouseArea {
        id: mouseArea
        anchors.fill: grid
        z: 55
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: true

        property int pressIndex: -1
        property real pressX: 0
        property real pressY: 0
        property bool moved: false
        property bool canDragItem: false
        property bool doubleClickedFlag: false
        property var grabbedImage: null
        property url dragPreviewUrl: ""

        drag.target: mouseArea.canDragItem ? dragProxy : null
        drag.threshold: 8

        Drag.active: mouseArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: 12
        Drag.hotSpot.y: 19
        Drag.imageSource: mouseArea.dragPreviewUrl
        Drag.imageSourceSize: Qt.size(grid.cellWidth, grid.cellHeight)
        Drag.mimeData: ({
            "text/uri-list": (mouseArea.pressIndex >= 0 && fileView.dragUrisForIndex)
                ? fileView.dragUrisForIndex(mouseArea.pressIndex).join("\r\n")
                : "",
            "application/x-voxel-internal": "1"
        })

        function itemIndexAt(mouseX, mouseY) {
            return grid.indexAt(mouseX + grid.contentX, mouseY + grid.contentY);
        }

        function isItemSelected(index) {
            const entry = fileView.model[index];
            return !!entry && !!(fileView.selectedMap && fileView.selectedMap[entry.path]);
        }

        function updateMarqueeSelection() {
            const boxX = Math.min(fileView.marqueeStartX, fileView.marqueeEndX) + grid.contentX;
            const boxY = Math.min(fileView.marqueeStartY, fileView.marqueeEndY) + grid.contentY;
            const boxW = Math.abs(fileView.marqueeEndX - fileView.marqueeStartX);
            const boxH = Math.abs(fileView.marqueeEndY - fileView.marqueeStartY);

            const nextSelection = {};
            const cols = fileView.columns;

            for (let i = 0; i < fileView.model.length; i++) {
                const itemX = (i % cols) * grid.cellWidth;
                const itemY = Math.floor(i / cols) * grid.cellHeight;
                const overlapsX = itemX < (boxX + boxW) && (itemX + grid.cellWidth) > boxX;
                const overlapsY = itemY < (boxY + boxH) && (itemY + grid.cellHeight) > boxY;

                if (overlapsX && overlapsY) {
                    nextSelection[fileView.model[i].path] = true;
                }
            }
            fileView.marqueeSelected(nextSelection);
        }

        function resetPressState() {
            fileView.marqueeActive = false;
            mouseArea.moved = false;
            mouseArea.canDragItem = false;
            mouseArea.pressIndex = -1;
        }

        onEntered: {
            const scenePos = mouseArea.mapToItem(null, mouseX, mouseY);
            fileView.hoverUpdated(itemIndexAt(mouseX, mouseY), scenePos.x, scenePos.y);
        }

        onExited: fileView.hoverUpdated(-1, 0, 0)

        onPressed: (mouse) => {
            fileView.interactionStarted();
            const clickedIndex = itemIndexAt(mouse.x, mouse.y);
            const scenePos = mouseArea.mapToItem(null, mouse.x, mouse.y);

            if (mouse.button === Qt.RightButton) {
                fileView.contextMenuRequested(clickedIndex, scenePos.x, scenePos.y);
                return;
            }

            mouseArea.pressX = mouse.x;
            mouseArea.pressY = mouse.y;
            mouseArea.moved = false;
            mouseArea.doubleClickedFlag = false;
            mouseArea.pressIndex = clickedIndex;
            fileView.marqueeActive = false;

            fileView.hoverUpdated(clickedIndex, scenePos.x, scenePos.y);
            fileView.interactionStarted();
            mouseArea.canDragItem = clickedIndex >= 0 && isItemSelected(clickedIndex);
        }

        onPositionChanged: (mouse) => {
            const scenePos = mouseArea.mapToItem(null, mouse.x, mouse.y);
            fileView.hoverUpdated(itemIndexAt(mouse.x, mouse.y), scenePos.x, scenePos.y);

            if (!pressed || (mouse.buttons & Qt.RightButton)) return;

            const movedEnough = Math.abs(mouse.x - mouseArea.pressX) > 6
                             || Math.abs(mouse.y - mouseArea.pressY) > 6;

            if (!mouseArea.moved && movedEnough) {
                mouseArea.moved = true;
                if (mouseArea.canDragItem) {
                    const itemWidget = grid.itemAtIndex(mouseArea.pressIndex);
                    if (itemWidget) {
                        itemWidget.grabToImage(function(result) {
                            mouseArea.grabbedImage = result;
                            mouseArea.dragPreviewUrl = result.url;
                        });
                    }
                }
            }

            if (mouseArea.canDragItem || !mouseArea.moved) return;

            if (!fileView.marqueeActive) {
                fileView.marqueeActive = true;
                fileView.marqueeStartX = mouseArea.pressX;
                fileView.marqueeStartY = mouseArea.pressY;
            }
            fileView.marqueeEndX = mouse.x;
            fileView.marqueeEndY = mouse.y;
            updateMarqueeSelection();
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return;
            if (mouseArea.doubleClickedFlag) {
                mouseArea.doubleClickedFlag = false;
                resetPressState();
                return;
            }

            if (fileView.marqueeActive) {
                updateMarqueeSelection();
            } else if (!mouseArea.moved) {
                if (mouseArea.pressIndex >= 0) {
                    fileView.itemClicked(mouseArea.pressIndex, mouse.modifiers);
                } else {
                    fileView.selectionCleared();
                }
            }
            resetPressState();
        }

        onCanceled: {
            mouseArea.doubleClickedFlag = false;
            resetPressState();
        }

        onDoubleClicked: (mouse) => {
            const clickedIndex = itemIndexAt(mouse.x, mouse.y);
            mouseArea.doubleClickedFlag = true;
            resetPressState();
            if (clickedIndex >= 0) {
                Qt.callLater(function() { fileView.itemDoubleClicked(clickedIndex); });
            }
        }

        WheelHandler {
            onWheel: (event) => {
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                const maxScroll = Math.max(0, grid.contentHeight - grid.height);
                grid.contentY = Math.max(0, Math.min(maxScroll, grid.contentY - delta));
                event.accepted = true;
            }
        }
    }

    // ---- Empty Folder / No Search Matches Message --------------------------
    Column {
        anchors.centerIn: grid
        spacing: 8
        visible: fileView.model.length === 0

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fileView.filtered ? "search" : "folder"
            color: Appearance.colors.colPrimary
            iconSize: 34
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fileView.filtered ? "No matches" : "Empty folder"
            color: Appearance.colors.colSubtext
            font.pixelSize: 13
        }
    }

    // ---- Rubber-Band Selection Box -----------------------------------------
    Rectangle {
        visible: fileView.marqueeActive
        z: 60
        x: Math.min(fileView.marqueeStartX, fileView.marqueeEndX)
        y: Math.min(fileView.marqueeStartY, fileView.marqueeEndY)
        width: Math.abs(fileView.marqueeEndX - fileView.marqueeStartX)
        height: Math.abs(fileView.marqueeEndY - fileView.marqueeStartY)
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
        border.width: 1
        border.color: Appearance.colors.colPrimary
        radius: Appearance.rounding.small
    }
}
