pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

// Floating tooltip that appears when hovering over a file or folder.
Rectangle {
    id: popup

    property bool shown: false
    property var entry: null
    property var info: null

    readonly property var detailRows: {
        if (!popup.entry) return [];

        let sizeOrCount = "--";
        if (popup.entry.dir) {
            const count = (popup.info && popup.info.count >= 0) ? popup.info.count : 0;
            sizeOrCount = count + (count === 1 ? " item" : " items");
        } else {
            const bytes = (popup.info && popup.info.bytes !== undefined) ? popup.info.bytes : (popup.entry.bytes || 0);
            sizeOrCount = Utils.fmtBytes(bytes);
        }

        const created = (popup.info && popup.info.created) ? Utils.fmtTime(popup.info.created) : "--";
        const modified = (popup.info && popup.info.modified)
            ? Utils.fmtTime(popup.info.modified)
            : Utils.fmtTime(popup.entry.mtime);
        const owner = (popup.info && popup.info.owner) ? popup.info.owner : "--";

        return [
            { label: popup.entry.dir ? "Content" : "Size", value: sizeOrCount },
            { label: "Created at", value: created },
            { label: "Modified at", value: modified },
            { label: "Owner", value: owner }
        ];
    }

    width: 248
    height: contentColumn.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    opacity: (popup.shown && popup.entry !== null) ? 1 : 0
    scale: (popup.shown && popup.entry !== null) ? 1 : 0.97
    visible: opacity > 0.01
    z: 115

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Column {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 12
            rightMargin: 12
            topMargin: 10
        }
        spacing: 6

        // Header: icon + file/folder name
        Row {
            width: parent.width
            spacing: 8

            MaterialSymbol {
                id: headerIcon
                anchors.verticalCenter: parent.verticalCenter
                text: (popup.entry && popup.entry.dir) ? "folder" : "description"
                color: Appearance.colors.colPrimary
                iconSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - headerIcon.width - 8
                text: popup.entry ? popup.entry.name : ""
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        // Metadata key-value rows
        Repeater {
            model: popup.detailRows

            delegate: Item {
                id: detailRow
                required property var modelData
                width: contentColumn.width
                height: 16

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: detailRow.modelData.label
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 11
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - 75
                    horizontalAlignment: Text.AlignRight
                    text: detailRow.modelData.value
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
}
