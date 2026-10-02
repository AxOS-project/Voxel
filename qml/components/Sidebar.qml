import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

Rectangle {
    id: sidebar
    width: 250
    color: Appearance.colors.colLayer2

    signal navigate(string path)
    property string curPath: ""
    property var xdgDirs: ({})

    ListModel {
        id: dirModel
    }

    onXdgDirsChanged: {
        dirModel.clear();
        if (!xdgDirs || !xdgDirs.home) return;
        if (xdgDirs.desktop) dirModel.append({ name: "Desktop", path: xdgDirs.desktop, glyph: "desktop_windows" });
        if (xdgDirs.documents) dirModel.append({ name: "Documents", path: xdgDirs.documents, glyph: "description" });
        if (xdgDirs.download) dirModel.append({ name: "Downloads", path: xdgDirs.download, glyph: "file_download" });
        if (xdgDirs.music) dirModel.append({ name: "Music", path: xdgDirs.music, glyph: "library_music" });
        if (xdgDirs.pictures) dirModel.append({ name: "Pictures", path: xdgDirs.pictures, glyph: "photo_library" });
        if (xdgDirs.videos) dirModel.append({ name: "Videos", path: xdgDirs.videos, glyph: "video_library" });
    }

    onCurPathChanged: {
        let found = false;
        for (let i = 0; i < dirModel.count; i++) {
            if (dirModel.get(i).path === sidebar.curPath) {
                listView.currentIndex = i;
                found = true;
                break;
            }
        }
        if (!found) listView.currentIndex = -1;
    }

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 12
        model: dirModel
        spacing: 8
        clip: true
        highlightMoveDuration: 100

        highlight: Rectangle {
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.small

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                width: 3
                height: 15
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimary
                z: 2
            }

            NumberAnimation on y {
                duration: 250
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
            }
        }

        delegate: Item {
            id: row
            width: ListView.view.width
            height: 44

            RowLayout {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 24 }
                spacing: 12

                MaterialSymbol { 
                    text: model.glyph
                    iconSize: 20
                }
                
                Label {
                    text: model.name
                    color: Appearance.colors.colOnLayer0
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: mouseArea.containsMouse && listView.currentIndex !== index
                    ? Appearance.colors.colSurfaceContainerHigh
                    : "transparent"
                z: -1
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sidebar.navigate(model.path)
            }
        }
    }
}
