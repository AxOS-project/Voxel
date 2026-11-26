pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

// Bottom-right box showing active file operations (copying, moving, deleting) with progress bars.
Rectangle {
    id: popup

    property var tasks: []
    property bool collapsed: false

    signal cancelRequested(int taskId)

    readonly property int taskCount: popup.tasks ? popup.tasks.length : 0

    readonly property int overallPercent: {
        if (popup.taskCount === 0) return 0;
        let doneBytes = 0;
        let totalBytes = 0;
        let totalProgress = 0;

        for (let i = 0; i < popup.taskCount; i++) {
            const task = popup.tasks[i];
            doneBytes += (task.doneBytes || 0);
            totalBytes += (task.totalBytes || 0);
            totalProgress += (task.progress || 0);
        }

        const ratio = totalBytes > 0
            ? (doneBytes / totalBytes)
            : (totalProgress / popup.taskCount);
        return Math.round(Math.max(0, Math.min(1, ratio)) * 100);
    }

    function iconForKind(kind) {
        if (kind === "copy") return "content_copy";
        if (kind === "move") return "drive_file_move";
        if (kind === "delete" || kind === "trash" || kind === "empty_trash") return "delete";
        if (kind === "restore") return "restore";
        return "sync";
    }

    width: 332
    height: popup.collapsed ? 42 : (43 + Math.min(taskList.contentHeight + 16, 232))
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    clip: true
    z: 120
    visible: popup.taskCount > 0

    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Block clicks inside the popup from reaching the files underneath
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }

    // ---- Top Summary Header ------------------------------------------------
    Item {
        id: headerBar
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 42

        MaterialSymbol {
            id: headerIcon
            anchors {
                left: parent.left
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
            text: popup.taskCount === 1 ? popup.iconForKind(popup.tasks[0].kind) : "sync"
            color: Appearance.colors.colPrimary
            iconSize: 18
        }

        Text {
            anchors {
                left: headerIcon.right
                leftMargin: 10
                right: headerPercent.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: popup.taskCount === 1
                ? (popup.collapsed ? popup.tasks[0].title : "1 operation in progress")
                : (popup.taskCount + " operations in progress")
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            id: headerPercent
            anchors {
                right: collapseButton.left
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: popup.overallPercent + "%"
            color: Appearance.colors.colPrimary
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        RippleButton {
            id: collapseButton
            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: 14
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover
            onClicked: popup.collapsed = !popup.collapsed

            MaterialSymbol {
                anchors.centerIn: parent
                text: popup.collapsed ? "expand_less" : "expand_more"
                color: Appearance.colors.colSubtext
                iconSize: 18
            }
        }
    }

    Rectangle {
        id: divider
        visible: !popup.collapsed
        anchors {
            left: parent.left
            right: parent.right
            top: headerBar.bottom
        }
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    // ---- List of Running Tasks ---------------------------------------------
    ListView {
        id: taskList
        visible: !popup.collapsed
        anchors {
            left: parent.left
            right: parent.right
            top: divider.bottom
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
            topMargin: 8
            bottomMargin: 8
        }
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: popup.tasks

        delegate: Rectangle {
            id: taskCard
            required property var modelData

            width: ListView.view ? ListView.view.width : 312
            height: 68
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            // Row 1: Icon, task title, percentage, and cancel button
            Item {
                id: topRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 10
                    rightMargin: 6
                    topMargin: 6
                }
                height: 22

                MaterialSymbol {
                    id: taskIcon
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: popup.iconForKind(taskCard.modelData.kind)
                    color: Appearance.colors.colPrimary
                    iconSize: 15
                }

                Text {
                    anchors {
                        left: taskIcon.right
                        leftMargin: 8
                        right: taskPercent.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: taskCard.modelData.title || ""
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: taskPercent
                    anchors {
                        right: cancelButton.left
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: (taskCard.modelData.percent || 0) + "%"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 11
                }

                RippleButton {
                    id: cancelButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: 22
                    implicitHeight: 22
                    buttonRadius: 11
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colErrorContainer
                    onClicked: popup.cancelRequested(taskCard.modelData.id)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        color: Appearance.colors.colSubtext
                        iconSize: 14
                    }
                }
            }

            // Row 2: Current filename and bytes/items counter
            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: topRow.bottom
                    leftMargin: 10
                    rightMargin: 10
                    topMargin: 2
                }
                height: 16

                Text {
                    anchors {
                        left: parent.left
                        right: progressCount.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: taskCard.modelData.currentFile || "Preparing..."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }

                Text {
                    id: progressCount
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: {
                        const totalBytes = taskCard.modelData.totalBytes || 0;
                        const doneBytes = taskCard.modelData.doneBytes || 0;
                        if (totalBytes > 0) {
                            return Utils.fmtBytes(doneBytes) + " / " + Utils.fmtBytes(totalBytes);
                        }
                        const totalItems = taskCard.modelData.totalItems || 0;
                        const doneItems = taskCard.modelData.doneItems || 0;
                        if (totalItems > 0) {
                            return doneItems + " / " + totalItems + (totalItems === 1 ? " item" : " items");
                        }
                        return "";
                    }
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                }
            }

            // Row 3: Progress bar
            Rectangle {
                id: progressTrack
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 10
                    rightMargin: 10
                    bottomMargin: 8
                }
                height: 5
                radius: 2.5
                color: Appearance.colors.colLayer0

                Rectangle {
                    height: parent.height
                    radius: 2.5
                    color: Appearance.colors.colPrimary
                    width: progressTrack.width * Math.max(0, Math.min(1, taskCard.modelData.progress || 0))
                    Behavior on width { NumberAnimation { duration: 60 } }
                }
            }
        }
    }
}
