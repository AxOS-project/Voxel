import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import Voxel
import "../Utils.js" as Utils

Rectangle {
    id: sidebar
    width: 250
    color: Appearance.colors.colLayer2

    Udisk { id: udisk }

    signal navigate(string path)
    property string curPath: ""
    property var xdgDirs: ({})
    property var udiskDevices: (udisk.list_devices() ? JSON.parse(udisk.list_devices()) : [])
    property string lastUdiskJson: ""

    function refreshDevices() {
        let json = udisk.list_devices();
        if (json !== sidebar.lastUdiskJson && !json.startsWith("error:")) {
            sidebar.lastUdiskJson = json;
            sidebar.udiskDevices = JSON.parse(json);
        }
    }

    Component.onCompleted: refreshDevices()

    ListModel {
        id: dirModel
    }

    onXdgDirsChanged: {
        dirModel.clear();
        if (!xdgDirs || !xdgDirs.home) return;
        
        // Adding udisk objects to prevent errors when accessing properties of undefined objects
        let def = { isUdisk: false, mounted: false, isSeparator: false, mount_point: "" };

        dirModel.append(Object.assign({ name: "Home", path: xdgDirs.home, glyph: "home" }, def));
        if (xdgDirs.desktop) dirModel.append(Object.assign({ name: "Desktop", path: xdgDirs.desktop, glyph: "desktop_windows" }, def));
        if (xdgDirs.documents) dirModel.append(Object.assign({ name: "Documents", path: xdgDirs.documents, glyph: "description" }, def));
        if (xdgDirs.download) dirModel.append(Object.assign({ name: "Downloads", path: xdgDirs.download, glyph: "file_download" }, def));
        if (xdgDirs.music) dirModel.append(Object.assign({ name: "Music", path: xdgDirs.music, glyph: "library_music" }, def));
        if (xdgDirs.pictures) dirModel.append(Object.assign({ name: "Pictures", path: xdgDirs.pictures, glyph: "photo_library" }, def));
        if (xdgDirs.videos) dirModel.append(Object.assign({ name: "Videos", path: xdgDirs.videos, glyph: "video_library" }, def));
    }

    onUdiskDevicesChanged: {
        for (let i = dirModel.count - 1; i >= 0; i--) {
            if (dirModel.get(i).isUdisk || dirModel.get(i).isSeparator) {
                dirModel.remove(i);
            }
        }

        if (udiskDevices.length > 0) {
            dirModel.append({ name: "", path: "", mount_point: "", glyph: "", isUdisk: false, mounted: false, isSeparator: true });
        }

        for (let device of udiskDevices) {
            dirModel.append({
                name: device.name,
                path: device.path,
                mount_point: device.mount_point,
                glyph: "hard_disk",
                isUdisk: true,
                mounted: device.mounted
            });
        }
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
            height: model.isSeparator ? 1 : 44

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 48
                height: 1
                color: Appearance.colors.colOutlineVariant
                visible: model.isSeparator === true
            }

            RowLayout {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 24 }
                spacing: 12
                z: 1
                visible: !model.isSeparator

                MaterialSymbol { 
                    text: model.glyph
                    iconSize: 20
                }
                
                Label {
                    text: model.name
                    color: Appearance.colors.colOnLayer0
                }

                RippleButton {
                    visible: model.isUdisk && model.mounted
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: {
                        let result = udisk.unmount_device(model.path)
                        if (result.startsWith("error:")) {
                            console.error("Failed to unmount device:", result.substring(6))
                        } else {
                            console.log("Successfully unmounted device at path:", model.path)
                            sidebar.refreshDevices()
                            sidebar.navigate(xdgDirs.home)
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "eject"
                        iconSize: 20
                    }
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
                onClicked: {
                    if (model.isUdisk) {
                        if (model.mounted === false || model.mounted === "false") {
                            console.log("Tentative de montage...");
                            let result = udisk.mount_device(model.path)
                            
                            if (result.startsWith("error:")) {
                                console.error("Erreur de montage:", result.substring(6))
                            } else {
                                console.log("Monté avec succès:", result)
                                sidebar.refreshDevices()
                                sidebar.navigate(result)
                            }
                        } else {
                            console.log("Le disque est déjà monté, on navigue vers:", model.mount_point)
                            sidebar.navigate(model.mount_point)
                        }
                    } else {
                        sidebar.navigate(model.path)
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: sidebar.refreshDevices()
    }
}
