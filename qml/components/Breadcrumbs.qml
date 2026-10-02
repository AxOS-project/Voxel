pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Horizontally scrolling breadcrumb bar. `model` is a list of {name, path}.
Flickable {
    id: crumbs
    property var model: []
    property string currentPath: ""

    signal navigate(string path)
    signal dropRequested(string path, var uris, bool internal)

    height: 28
    contentWidth: crumbRow.width
    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds

    function toEnd() { contentX = Math.max(0, contentWidth - width); }

    onContentWidthChanged: toEnd()
    onWidthChanged: toEnd()
    onCurrentPathChanged: toEnd()

    Row {
        id: crumbRow
        height: crumbs.height
        spacing: 0

        Repeater {
            model: crumbs.model

            delegate: Item {
                id: crumb
                required property var modelData
                required property int index

                width: crumbBtn.width + crumbSep.width
                height: crumbs.height

                Rectangle {
                    id: crumbBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: crumbText.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: (crumbMa.containsMouse || crumbDrop.containsDrag) ? Appearance.colors.colLayer0Hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 90 } }

                    Text {
                        id: crumbText
                        anchors.centerIn: parent
                        text: crumb.modelData.name
                        color: crumb.modelData.path === crumbs.currentPath ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnLayer0
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: crumbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: crumbs.navigate(crumb.modelData.path)
                    }
                    DropArea {
                        id: crumbDrop
                        anchors.fill: parent
                        onDropped: drop => {
                            if (!drop.hasUrls)
                                return;
                            const uris = [];
                            for (let i = 0; i < drop.urls.length; i++) uris.push(String(drop.urls[i]));
                            drop.accept(Qt.MoveAction);
                            crumbs.dropRequested(crumb.modelData.path, uris, drop.formats.indexOf("application/x-voxel-internal") >= 0);
                        }
                    }
                }

                MaterialSymbol {
                    id: crumbSep
                    anchors { left: crumbBtn.right; verticalCenter: parent.verticalCenter }
                    visible: crumb.index < crumbs.model.length - 1
                    width: visible ? 14 : 0
                    text: "chevron_right"
                    color: Appearance.colors.colOnLayer0
                    iconSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
