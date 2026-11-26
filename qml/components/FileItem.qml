import QtQuick
import QtQuick.Controls
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import SleexUiKit.Functions
import "../Utils.js" as Utils

// Displays a single file or folder, either as a horizontal row (List view)
// or as a vertical card (Grid view).
Rectangle {
    id: fileItem

    required property var modelData
    required property int index

    property bool rowLayout: false
    property bool selected: false
    property bool hovered: false
    property bool isCut: false
    property var xdgDirs: ({})

    signal dropRequested(string targetPath, var uris, bool isInternal)

    readonly property bool isImageFile: Utils.isImage(fileItem.modelData)
    readonly property bool isDropActive: folderDropArea.containsDrag
    readonly property int iconPixels: fileItem.rowLayout ? 36 : 64

    radius: Appearance.rounding.small
    border.width: fileItem.isDropActive ? 1 : 0
    border.color: Appearance.colors.colPrimary

    color: {
        if (fileItem.isDropActive) return Qt.rgba(1, 1, 1, 0.18);
        if (fileItem.selected) return Qt.rgba(1, 1, 1, 0.11);
        if (fileItem.hovered) return Qt.rgba(1, 1, 1, 0.05);
        return "transparent";
    }
    Behavior on color { ColorAnimation { duration: 100 } }

    // Left accent bar shown on selected rows in List view
    Rectangle {
        visible: fileItem.rowLayout && fileItem.selected
        anchors {
            left: parent.left
            leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        width: 3
        height: Math.max(0, parent.height - 14)
        radius: 1.5
        color: Appearance.colors.colPrimary
    }

    // Allow dropping files onto a folder item
    DropArea {
        id: folderDropArea
        anchors.fill: parent
        enabled: fileItem.modelData.dir
        onDropped: (drop) => {
            if (!drop.hasUrls) return;
            const uris = [];
            for (let i = 0; i < drop.urls.length; i++) {
                uris.push(String(drop.urls[i]));
            }
            drop.accept(Qt.MoveAction);
            const isInternal = drop.formats.indexOf("application/x-voxel-internal") >= 0;
            fileItem.dropRequested(fileItem.modelData.path, uris, isInternal);
        }
    }

    // Shared icon or image thumbnail component
    Component {
        id: iconComponent

        Item {
            width: fileItem.iconPixels
            height: fileItem.iconPixels

            Button {
                anchors.fill: parent
                visible: !fileItem.isImageFile || thumbnail.status !== Image.Ready
                icon.name: {
                    const specialIcon = Utils.xdgFolderIcon(fileItem.modelData, fileItem.xdgDirs);
                    if (specialIcon !== "") return specialIcon;
                    return DesktopUtils.getIconName(fileItem.modelData.path, fileItem.modelData.dir);
                }
                icon.width: fileItem.iconPixels
                icon.height: fileItem.iconPixels
                icon.color: "transparent"
                background: Item {}
                hoverEnabled: false
                focusPolicy: Qt.NoFocus
            }

            Image {
                id: thumbnail
                anchors.fill: parent
                anchors.margins: fileItem.rowLayout ? 2 : 0
                visible: fileItem.isImageFile && status === Image.Ready
                source: fileItem.isImageFile ? Utils.fileUri(fileItem.modelData.path) : ""
                asynchronous: true
                cache: true
                sourceSize.width: fileItem.iconPixels * 2
                sourceSize.height: fileItem.iconPixels * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
    }

    // ---- List View Layout (Horizontal Row) ---------------------------------
    Row {
        visible: fileItem.rowLayout
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 14
        }
        spacing: 12
        opacity: fileItem.isCut ? 0.55 : 1.0

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: iconComponent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 276
            text: fileItem.modelData.name
            color: fileItem.modelData.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            horizontalAlignment: Text.AlignRight
            text: Utils.fmtSize(fileItem.modelData)
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Utils.fmtTime(fileItem.modelData.mtime)
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
        }
    }

    // ---- Grid View Layout (Vertical Card) ----------------------------------
    Column {
        visible: !fileItem.rowLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        opacity: fileItem.isCut ? 0.55 : 1.0

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: iconComponent
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: fileItem.modelData.name
            color: fileItem.modelData.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}
