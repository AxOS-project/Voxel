import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import SleexUiKit.Functions
import "../Utils.js" as Utils

Item {
    id: gridContainer

    property var model: []
    property int currentIndex: 0
    property int hoverIndex: -1
    property var selected: ({})
    property int anchorIndex: -1
    property bool filtered: false
    property var xdgDirs: ({})


    signal rowContext(int index, real x, real y)
    signal dropRequested(string target, var uris, bool internal)
    signal emptyContext(real x, real y)
    signal rowClicked(int index, int modifiers)
    signal doubleClicked(int index)
    signal selectionCleared()
    
    // Marquee signals
    signal marqueeBegin(real x, real y)
    signal marqueeUpdate(real x, real y)
    signal marqueeEnd()
    signal applyMarquee(real rx, real ry, real rw, real rh, real contentX, real contentY)

    // Used internally or by parent to drive marquee UI
    property bool marqueeActive: false
    property real marqueeX0: 0
    property real marqueeY0: 0
    property real marqueeX1: 0
    property real marqueeY1: 0

    // Provide access to the grid view for keyboard scrolling, etc.
    property alias cellWidth: list.cellWidth
    property alias cellHeight: list.cellHeight
    property alias gridWidth: list.width
    property alias gridHeight: list.height
    property alias contentX: list.contentX
    property alias contentY: list.contentY
    property alias contentHeight: list.contentHeight

    anchors.margins: 8

    function positionViewAtIndex(index, mode) {
        list.positionViewAtIndex(index, mode);
    }
    
    function itemAtIndex(index) {
        return list.itemAtIndex(index);
    }



    GridView {
        id: list
        anchors.fill: parent
        clip: true
        model: gridContainer.model
        currentIndex: gridContainer.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 2000

        cellWidth: 125
        cellHeight: 125

        highlightMoveDuration: 150
        highlight: Rectangle {
            color: Qt.rgba(1, 1, 1, 0.06)
            radius: Appearance.rounding.small
        }

        delegate: FileGridItem {
            width: list.cellWidth - 4
            height: list.cellHeight - 4
            selected: win.isSelected(modelData.path)
            hovered: index === gridContainer.hoverIndex
            xdgDirs: gridContainer.xdgDirs
            onRowContext: (index, x, y) => gridContainer.rowContext(index, x, y)
            onDropRequested: (target, uris, internal) => gridContainer.dropRequested(target, uris, internal)
        }
        
        ScrollBar.vertical: StyledScrollBar {}
    }

    Item {
        id: listDragProxy
        width: 1
        height: 1
        x: -1000
        y: -1000
    }

    MouseArea {
        id: listMouse
        anchors.fill: list
        z: 55
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: true

        property int pressIndex: -1
        property real pressX: 0
        property real pressY: 0
        property bool banding: false
        property bool moved: false
        property bool armed: false
        property var grab: null
        property url pixmap: ""

        drag.target: listMouse.armed ? listDragProxy : null
        drag.threshold: 8

        Drag.active: listMouse.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: 12
        Drag.hotSpot.y: 19
        Drag.imageSource: listMouse.pixmap
        Drag.imageSourceSize: Qt.size(list.cellWidth, list.cellHeight)
        Drag.mimeData: ({
            "text/uri-list": listMouse.pressIndex >= 0 ? win.dragUriList(listMouse.pressIndex).join("\r\n") : "",
            "application/x-voxel-internal": "1"
        })

        function indexAt(mx, my) {
            return list.indexAt(mx + list.contentX, my + list.contentY);
        }

        function selectedAt(i) {
            const e = win.visibleEntries[i];
            return !!e && win.isSelected(e.path);
        }

        onEntered: gridContainer.hoverIndex = indexAt(mouseX, mouseY)
        onExited: gridContainer.hoverIndex = -1

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                const i = indexAt(mouse.x, mouse.y);
                const p = listMouse.mapToItem(null, mouse.x, mouse.y);
                if (i >= 0) gridContainer.rowContext(i, p.x, p.y);
                else gridContainer.emptyContext(p.x, p.y);
                return;
            }
            pressX = mouse.x;
            pressY = mouse.y;
            banding = false;
            moved = false;
            pressIndex = indexAt(mouse.x, mouse.y);
            gridContainer.hoverIndex = pressIndex;
            armed = pressIndex >= 0 && selectedAt(pressIndex);
            if (armed) {
                const item = list.itemAtIndex(pressIndex);
                if (item)
                    item.grabToImage(function(result) {
                        listMouse.grab = result;
                        listMouse.pixmap = result.url;
                    });
            }
        }

        onPositionChanged: mouse => {
            gridContainer.hoverIndex = indexAt(mouse.x, mouse.y);
            if (!pressed || (mouse.buttons & Qt.RightButton)) return;
            if (!moved && (Math.abs(mouse.x - pressX) > 6 || Math.abs(mouse.y - pressY) > 6)) moved = true;
            if (listMouse.armed || !moved) return;
            if (!banding) {
                banding = true;
                gridContainer.marqueeBegin(pressX, pressY);
            }
            gridContainer.marqueeUpdate(mouse.x, mouse.y);
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton) return;
            if (banding) {
                gridContainer.marqueeEnd();
                const rx = Math.min(gridContainer.marqueeX0, gridContainer.marqueeX1);
                const ry = Math.min(gridContainer.marqueeY0, gridContainer.marqueeY1);
                const rw = Math.abs(gridContainer.marqueeX1 - gridContainer.marqueeX0);
                const rh = Math.abs(gridContainer.marqueeY1 - gridContainer.marqueeY0);
                gridContainer.applyMarquee(rx, ry, rw, rh, list.contentX, list.contentY);
            } else if (!moved) {
                if (pressIndex >= 0) {
                    gridContainer.rowClicked(pressIndex, mouse.modifiers);
                } else {
                    gridContainer.selectionCleared();
                }
            }
            banding = false;
            moved = false;
            armed = false;
            pressIndex = -1;
        }

        onCanceled: {
            if (banding) gridContainer.marqueeEnd();
            banding = false;
            moved = false;
            armed = false;
            pressIndex = -1;
        }

        onDoubleClicked: mouse => {
            const i = indexAt(mouse.x, mouse.y);
            if (i >= 0) gridContainer.doubleClicked(i);
        }

        WheelHandler {
            onWheel: event => {
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                const max = Math.max(0, list.contentHeight - list.height);
                list.contentY = Math.max(0, Math.min(max, list.contentY - delta));
                event.accepted = true;
            }
        }
    }

    EmptyState {
        anchors.centerIn: list
        filtered: gridContainer.filtered
        visible: gridContainer.model.length === 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: marqueeRect
        visible: gridContainer.marqueeActive
        z: 60
        x: Math.min(gridContainer.marqueeX0, gridContainer.marqueeX1)
        y: Math.min(gridContainer.marqueeY0, gridContainer.marqueeY1)
        width: Math.abs(gridContainer.marqueeX1 - gridContainer.marqueeX0)
        height: Math.abs(gridContainer.marqueeY1 - gridContainer.marqueeY0)
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
        border.width: 1
        border.color: Appearance.colors.colPrimary
        radius: Appearance.rounding.small
    }
}
