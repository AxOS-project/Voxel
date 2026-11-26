pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Horizontally scrolling path bar showing clickable folder parts (e.g. / > home > user).
Flickable {
    id: breadcrumbs

    property var model: []
    property string currentPath: ""

    signal navigate(string path)
    signal dropRequested(string path, var uris, bool isInternal)

    height: 28
    contentWidth: crumbRow.width
    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds

    function scrollToEnd() {
        contentX = Math.max(0, contentWidth - width);
    }

    onContentWidthChanged: scrollToEnd()
    onWidthChanged: scrollToEnd()
    onCurrentPathChanged: scrollToEnd()

    Row {
        id: crumbRow
        height: breadcrumbs.height

        Repeater {
            model: breadcrumbs.model

            delegate: Item {
                id: crumbItem
                required property var modelData
                required property int index

                width: crumbButton.width + separatorIcon.width
                height: breadcrumbs.height

                Rectangle {
                    id: crumbButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: crumbLabel.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: (mouseArea.containsMouse || dropArea.containsDrag)
                        ? Appearance.colors.colLayer0Hover
                        : "transparent"

                    Text {
                        id: crumbLabel
                        anchors.centerIn: parent
                        text: crumbItem.modelData.name
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: breadcrumbs.navigate(crumbItem.modelData.path)
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        onDropped: (drop) => {
                            if (!drop.hasUrls) return;
                            const uris = [];
                            for (let i = 0; i < drop.urls.length; i++) {
                                uris.push(String(drop.urls[i]));
                            }
                            drop.accept(Qt.MoveAction);
                            const isInternal = drop.formats.indexOf("application/x-voxel-internal") >= 0;
                            breadcrumbs.dropRequested(crumbItem.modelData.path, uris, isInternal);
                        }
                    }
                }

                MaterialSymbol {
                    id: separatorIcon
                    anchors {
                        left: crumbButton.right
                        verticalCenter: parent.verticalCenter
                    }
                    visible: crumbItem.index < breadcrumbs.model.length - 1
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
