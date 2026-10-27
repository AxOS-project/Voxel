import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import SleexUiKit.Functions
import "../Utils.js" as Utils

// A single file/folder item in the grid view.
Rectangle {
    id: item
    required property var modelData
    required property int index
    property bool selected: false
    property bool hovered: false
    property var xdgDirs: ({})

    signal rowContext(int index, real x, real y)
    signal dropRequested(string target, var uris, bool internal)

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight
    radius: Appearance.rounding.small
    color: item.dropActive ? Qt.rgba(0.84, 0.84, 0.86, 0.18)
         : item.selected ? Qt.rgba(1, 1, 1, 0.11)
         : item.hovered ? Appearance.colors.colLayer0Hover
         : "transparent"
    border.width: item.dropActive || item.selected ? 1 : 0
    border.color: Appearance.colors.colPrimary
    Behavior on color { ColorAnimation { duration: 100 } }

    opacity: 0
    SequentialAnimation {
        id: entrance
        PauseAnimation { duration: Math.min(item.index, 10) * 12 }
        NumberAnimation { target: item; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }
    Component.onCompleted: entrance.start()

    DropArea {
        id: dropTarget
        anchors.fill: parent
        enabled: item.modelData.dir
        onDropped: drop => {
            if (!drop.hasUrls) return;
            const uris = [];
            for (let i = 0; i < drop.urls.length; i++) uris.push(String(drop.urls[i]));
            drop.accept(Qt.MoveAction);
            item.dropRequested(item.modelData.path, uris, drop.formats.indexOf("application/x-voxel-internal") >= 0);
        }
    }
    readonly property bool dropActive: dropTarget.containsDrag

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64

            readonly property bool isImg: Utils.isImage(item.modelData)

            Button {
                anchors.fill: parent
                visible: !parent.isImg || thumb.status !== Image.Ready
                icon.name: {
                    if (item.modelData.dir && item.xdgDirs) {
                        if (item.modelData.path === item.xdgDirs.desktop) return "user-desktop";
                        if (item.modelData.path === item.xdgDirs.documents) return "folder-documents";
                        if (item.modelData.path === item.xdgDirs.download) return "folder-download";
                        if (item.modelData.path === item.xdgDirs.music) return "folder-music";
                        if (item.modelData.path === item.xdgDirs.pictures) return "folder-pictures";
                        if (item.modelData.path === item.xdgDirs.videos) return "folder-videos";
                        if (item.modelData.path === item.xdgDirs.home) return "user-home";
                    }
                    return DesktopUtils.getIconName(item.modelData.path, item.modelData.dir);
                }
                icon.width: 64
                icon.height: 64
                icon.color: "transparent"
                background: Item {}
                hoverEnabled: false
                focusPolicy: Qt.NoFocus
            }

            Image {
                id: thumb
                anchors.fill: parent
                visible: parent.isImg && status === Image.Ready
                source: parent.isImg ? Utils.fileUri(item.modelData.path) : ""
                asynchronous: true
                cache: true
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: item.modelData.name
            color: item.modelData.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}
