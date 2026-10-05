import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
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
    property alias listWidth: list.width
    property alias listHeight: list.height
    property alias contentY: list.contentY
    property alias contentHeight: list.contentHeight

    anchors.margins: 8

    function positionViewAtIndex(index, mode) {
        list.positionViewAtIndex(index, mode);
    }
    
    function itemAtIndex(index) {
        return list.itemAtIndex(index);
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: gridContainer.model
        currentIndex: gridContainer.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 2000

        highlightMoveDuration: 150
        highlightResizeDuration: 0
        highlight: Rectangle {
            color: Qt.rgba(1, 1, 1, 0.06)
            radius: Appearance.rounding.small

            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: 2
                width: 3
                height: Math.max(0, parent.height - 14)
                radius: 1.5
                color: Appearance.colors.colPrimary 
            }
        }

        delegate: FileRow {
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
        Drag.imageSourceSize: Qt.size(list.width, 36)
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
                const p0 = listMouse.mapToItem(null, pressX, pressY);
                gridContainer.marqueeBegin(p0.x, p0.y);
            }
            const p = listMouse.mapToItem(null, mouse.x, mouse.y);
            gridContainer.marqueeUpdate(p.x, p.y);
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton) return;
            if (banding) {
                gridContainer.marqueeEnd();
                const rx = Math.min(gridContainer.marqueeX0, gridContainer.marqueeX1);
                const ry = Math.min(gridContainer.marqueeY0, gridContainer.marqueeY1);
                const rw = Math.abs(gridContainer.marqueeX1 - gridContainer.marqueeX0);
                const rh = Math.abs(gridContainer.marqueeY1 - gridContainer.marqueeY0);
                const tl = list.mapFromItem(null, rx, ry);
                const br = list.mapFromItem(null, rx + rw, ry + rh);
                gridContainer.applyMarquee(tl.x, tl.y, br.x - tl.x, br.y - tl.y, list.contentX, list.contentY);
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
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: Appearance.colors.colPrimary
        radius: 2
    }
}
