import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

// Floating metadata tooltip shown when hovering over a file or folder item.
Rectangle {
    id: hp

    property bool shown: false
    property var entry: null
    property var info: null

    width: 248
    height: col.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    opacity: shown && entry !== null ? 1 : 0
    scale: shown && entry !== null ? 1 : 0.97
    visible: opacity > 0.01
    z: 115

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Column {
        id: col
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: 12; rightMargin: 12; topMargin: 10
        }
        spacing: 6

        // Item title
        Row {
            width: parent.width
            spacing: 8

            MaterialSymbol {
                id: hIcon
                anchors.verticalCenter: parent.verticalCenter
                text: (hp.entry && hp.entry.dir) ? "folder" : "description"
                color: Appearance.colors.colPrimary
                iconSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - hIcon.width - 8
                text: hp.entry ? hp.entry.name : ""
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

        // Size (files) or Content num (folder)
        Item {
            width: parent.width
            height: 16

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: (hp.entry && hp.entry.dir) ? "Content" : "Size"
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: {
                    if (!hp.entry) return "--";
                    if (hp.entry.dir) {
                        const c = (hp.info && hp.info.count !== undefined && hp.info.count >= 0) ? hp.info.count : 0;
                        return c + (c === 1 ? " item" : " items");
                    }
                    const b = (hp.info && hp.info.bytes !== undefined) ? hp.info.bytes : (hp.entry.bytes || 0);
                    return Utils.fmtBytes(b);
                }
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Created at
        Item {
            width: parent.width
            height: 16

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Created at"
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (hp.info && hp.info.created) ? Utils.fmtTime(hp.info.created) : "--"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 11
            }
        }

        // Modified at
        Item {
            width: parent.width
            height: 16

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Modified at"
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (hp.info && hp.info.modified)
                      ? Utils.fmtTime(hp.info.modified)
                      : (hp.entry ? Utils.fmtTime(hp.entry.mtime) : "--")
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 11
            }
        }

        // Owner
        Item {
            width: parent.width
            height: 16

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Owner"
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: parent.width - 70
                horizontalAlignment: Text.AlignRight
                text: (hp.info && hp.info.owner) ? hp.info.owner : "--"
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
