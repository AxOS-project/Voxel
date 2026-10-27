import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import SleexUiKit.Functions
import "../Utils.js" as Utils

// A single file/folder row in the main list.
Rectangle {
    id: row
    required property var modelData
    required property int index
    property bool selected: false
    // Hover is tracked by the list overlay, not by a MouseArea here.
    property bool hovered: false
    property var xdgDirs

    signal rowContext(int index, real x, real y)
    // A drop landed on this (folder) row: move/copy `uris` into `target`.
    signal dropRequested(string target, var uris, bool internal)

    width: ListView.view.width
    height: 36
    radius: Appearance.rounding.small
    color: row.dropActive ? Qt.rgba(0.84, 0.84, 0.86, 0.18)
         : row.selected ? Qt.rgba(1, 1, 1, 0.11)
         : row.hovered ? Appearance.colors.colLayer0Hover
         : "transparent"
    border.width: row.dropActive ? 1 : 0
    border.color: Appearance.colors.colPrimary
    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    opacity: 0
    SequentialAnimation {
        id: entrance
        PauseAnimation {
            duration: Math.min(row.index, 10) * 12
        }
        NumberAnimation {
            target: row
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Component.onCompleted: entrance.start()

    // Drop target for folder rows: move the dragged selection inside.
    DropArea {
        id: dropTarget
        anchors.fill: parent
        enabled: row.modelData.dir
        onDropped: drop => {
            if (!drop.hasUrls)
                return;
            const uris = [];
            for (let i = 0; i < drop.urls.length; i++) uris.push(String(drop.urls[i]));
            drop.accept(Qt.MoveAction);
            row.dropRequested(row.modelData.path, uris,
                              drop.formats.indexOf("application/x-voxel-internal") >= 0);
        }
    }

    readonly property bool dropActive: dropTarget.containsDrag

    Row {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 14
        }
        spacing: 12

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36

            readonly property bool isImg: Utils.isImage(row.modelData)

            Button {
                anchors.fill: parent
                visible: !parent.isImg || thumb.status !== Image.Ready
                icon.name: {
                    if (row.modelData.dir && row.xdgDirs) {
                        if (row.modelData.path === row.xdgDirs.desktop) return "user-desktop";
                        if (row.modelData.path === row.xdgDirs.documents) return "folder-documents";
                        if (row.modelData.path === row.xdgDirs.download) return "folder-download";
                        if (row.modelData.path === row.xdgDirs.music) return "folder-music";
                        if (row.modelData.path === row.xdgDirs.pictures) return "folder-pictures";
                        if (row.modelData.path === row.xdgDirs.videos) return "folder-videos";
                        if (row.modelData.path === row.xdgDirs.home) return "user-home";
                    }
                    return DesktopUtils.getIconName(row.modelData.path, row.modelData.dir);
                }
                icon.width: 36
                icon.height: 36
                icon.color: "transparent"
                background: Item {}
                hoverEnabled: false
                focusPolicy: Qt.NoFocus
            }

            Image {
                id: thumb
                anchors.fill: parent
                anchors.margins: 2
                visible: parent.isImg && status === Image.Ready
                source: parent.isImg ? Utils.fileUri(row.modelData.path) : ""
                asynchronous: true
                cache: true
                sourceSize.width: 72
                sourceSize.height: 72
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 20 - 90 - 130 - 36
            text: row.modelData.name
            color: row.modelData.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
            
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            horizontalAlignment: Text.AlignRight
            text: Utils.fmtSize(row.modelData)
            color: Appearance.colors.colSubtext
            
            font.pixelSize: 11
        }
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Utils.fmtTime(row.modelData.mtime)
            color: Appearance.colors.colSubtext
            
            font.pixelSize: 11
        }
    }

    // Right-click only; left-button interaction lives in the list overlay.
    MouseArea {
        id: rowMa
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            const p = rowMa.mapToItem(null, mouse.x, mouse.y);
            row.rowContext(row.index, p.x, p.y);
        }
    }
}
