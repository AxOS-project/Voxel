pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

// Popup window that lists items in the Trash and lets the user restore or permanently delete them.
Item {
    id: trashPanel

    property bool shown: false
    property var items: []
    property var loadList: null

    signal restoreRequested(var names)
    signal deleteRequested(var names)
    signal emptyRequested()

    function reload() {
        try {
            const raw = trashPanel.loadList ? trashPanel.loadList() : "[]";
            trashPanel.items = JSON.parse(raw);
        } catch (e) {
            trashPanel.items = [];
        }
    }

    anchors.fill: parent
    z: 105
    opacity: trashPanel.shown ? 1 : 0
    visible: opacity > 0.01
    focus: trashPanel.shown
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    onShownChanged: if (trashPanel.shown) trashPanel.forceActiveFocus()
    Keys.onEscapePressed: (event) => { trashPanel.shown = false; event.accepted = true; }

    // Dark background overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: trashPanel.shown = false
        }
    }

    // Center Trash window
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(640, trashPanel.parent ? trashPanel.parent.width - 48 : 592)
        height: Math.min(520, trashPanel.parent ? trashPanel.parent.height - 80 : 440)
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer2
        scale: trashPanel.shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        Text {
            id: titleText
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 20
                topMargin: 18
            }
            text: "Trash"
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            anchors {
                left: titleText.right
                leftMargin: 10
                verticalCenter: titleText.verticalCenter
            }
            text: trashPanel.items.length + (trashPanel.items.length === 1 ? " item" : " items")
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
        }

        // Top-right Empty Trash & Close buttons
        Row {
            anchors {
                right: parent.right
                rightMargin: 16
                top: parent.top
                topMargin: 14
            }
            spacing: 8

            RippleButton {
                visible: trashPanel.items.length > 0
                colBackground: Appearance.colors.colErrorContainer
                colText: Appearance.colors.colError
                height: 32
                width: 32
                buttonRadius: Appearance.rounding.full
                onClicked: trashPanel.emptyRequested()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete_forever"
                    color: Appearance.colors.colError
                    iconSize: 18
                }
            }

            RippleButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                width: 32
                buttonRadius: Appearance.rounding.full
                onClicked: trashPanel.shown = false

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    color: Appearance.colors.colSubtext
                    iconSize: 18
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 52
            }
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        // List of trashed files and folders
        ListView {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                topMargin: 58
                bottomMargin: 12
                leftMargin: 12
                rightMargin: 12
            }
            clip: true
            model: trashPanel.items
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: trashRow
                required property var modelData

                width: ListView.view.width
                height: 48
                radius: Appearance.rounding.small
                color: hoverArea.containsMouse ? Appearance.colors.colLayer0Hover : "transparent"

                MaterialSymbol {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: trashRow.modelData.dir ? "folder" : "insert_drive_file"
                    color: Appearance.colors.colSubtext
                    iconSize: 15
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 40
                        right: rowButtons.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: trashRow.modelData.original !== ""
                            ? trashRow.modelData.original
                            : trashRow.modelData.name
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }

                    Text {
                        text: Utils.fmtTime(trashRow.modelData.deleted)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 10
                    }
                }

                Row {
                    id: rowButtons
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    RippleButton {
                        height: 28
                        width: 28
                        buttonRadius: Appearance.rounding.full
                        colBackgroundHover: Appearance.colors.colLayer2
                        onClicked: if (trashRow.modelData.known) {
                            trashPanel.restoreRequested([trashRow.modelData.name]);
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "restore"
                            color: trashRow.modelData.known
                                ? Appearance.colors.colOnLayer0
                                : Appearance.colors.colSubtext
                            iconSize: 16
                        }
                    }

                    RippleButton {
                        height: 28
                        width: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colErrorContainer
                        colText: Appearance.colors.colError
                        onClicked: trashPanel.deleteRequested([trashRow.modelData.name])

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            color: Appearance.colors.colError
                            iconSize: 16
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: trashPanel.items.length === 0
            text: "Trash is empty"
            color: Appearance.colors.colSubtext
            font.pixelSize: 13
        }
    }
}
