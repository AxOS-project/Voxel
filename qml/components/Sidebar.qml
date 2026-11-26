import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import Voxel

// Left sidebar showing standard user folders (Home, Documents, etc.) and removable drives.
Rectangle {
    id: sidebar

    width: 250
    color: Appearance.colors.colLayer2

    Udisk { id: udisk }

    property string curPath: ""
    property var xdgDirs: ({})
    property var udiskDevices: []
    property string lastUdiskJson: ""

    signal navigate(string path)

    // Combine standard user folders and connected drives into a single list.
    readonly property var places: {
        const list = [];
        const dirs = sidebar.xdgDirs || {};

        function addPlace(name, path, icon) {
            if (!path) return;
            list.push({
                name: name,
                path: path,
                glyph: icon,
                isSeparator: false,
                isDrive: false,
                mounted: false,
                mountPoint: ""
            });
        }

        addPlace("Home", dirs.home, "home");
        addPlace("Desktop", dirs.desktop, "desktop_windows");
        addPlace("Documents", dirs.documents, "description");
        addPlace("Downloads", dirs.download, "file_download");
        addPlace("Music", dirs.music, "library_music");
        addPlace("Pictures", dirs.pictures, "photo_library");
        addPlace("Videos", dirs.videos, "video_library");

        if (sidebar.udiskDevices.length > 0) {
            list.push({
                name: "",
                path: "",
                glyph: "",
                isSeparator: true,
                isDrive: false,
                mounted: false,
                mountPoint: ""
            });

            for (let i = 0; i < sidebar.udiskDevices.length; i++) {
                const drive = sidebar.udiskDevices[i];
                list.push({
                    name: drive.name,
                    path: drive.path,
                    glyph: "hard_disk",
                    isSeparator: false,
                    isDrive: true,
                    mounted: !!drive.mounted,
                    mountPoint: drive.mount_point || ""
                });
            }
        }

        return list;
    }

    function refreshDevices() {
        const json = udisk.list_devices();
        if (!json || json === sidebar.lastUdiskJson || json.startsWith("error:")) return;
        sidebar.lastUdiskJson = json;
        try {
            sidebar.udiskDevices = JSON.parse(json);
        } catch (e) {
            sidebar.udiskDevices = [];
        }
    }

    function updateSelectedRow() {
        for (let i = 0; i < sidebar.places.length; i++) {
            const item = sidebar.places[i];
            const targetPath = item.isDrive ? item.mountPoint : item.path;
            if (targetPath !== "" && targetPath === sidebar.curPath) {
                listView.currentIndex = i;
                return;
            }
        }
        listView.currentIndex = -1;
    }

    Component.onCompleted: refreshDevices()
    onCurPathChanged: updateSelectedRow()
    onPlacesChanged: updateSelectedRow()

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 12
        model: sidebar.places
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
            }
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index

            width: ListView.view.width
            height: row.modelData.isSeparator ? 1 : 44

            // Divider line between standard folders and drives
            Rectangle {
                visible: row.modelData.isSeparator
                anchors.centerIn: parent
                width: parent.width - 48
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            // Hover background
            Rectangle {
                visible: !row.modelData.isSeparator
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: mouseArea.containsMouse && listView.currentIndex !== row.index
                    ? Appearance.colors.colSurfaceContainerHigh
                    : "transparent"
            }

            // Click handler to open folder or mount drive
            MouseArea {
                id: mouseArea
                visible: !row.modelData.isSeparator
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (!row.modelData.isDrive) {
                        sidebar.navigate(row.modelData.path);
                        return;
                    }
                    if (!row.modelData.mounted) {
                        const mountResult = udisk.mount_device(row.modelData.path);
                        if (!mountResult.startsWith("error:")) {
                            sidebar.refreshDevices();
                            sidebar.navigate(mountResult);
                        }
                    } else {
                        sidebar.navigate(row.modelData.mountPoint);
                    }
                }
            }

            // Folder/drive icon, name, and eject button
            RowLayout {
                visible: !row.modelData.isSeparator
                anchors {
                    left: parent.left
                    leftMargin: 24
                    verticalCenter: parent.verticalCenter
                }
                spacing: 12

                MaterialSymbol {
                    text: row.modelData.glyph
                    iconSize: 20
                }

                Label {
                    text: row.modelData.name
                    color: Appearance.colors.colOnLayer0
                }

                RippleButton {
                    visible: row.modelData.isDrive && row.modelData.mounted
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: {
                        const result = udisk.unmount_device(row.modelData.path);
                        if (!result.startsWith("error:")) {
                            sidebar.refreshDevices();
                            if (sidebar.xdgDirs && sidebar.xdgDirs.home) {
                                sidebar.navigate(sidebar.xdgDirs.home);
                            }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "eject"
                        iconSize: 20
                    }
                }
            }
        }
    }

    // Periodically check for newly plugged/unplugged USB drives
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: sidebar.refreshDevices()
    }
}
