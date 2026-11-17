pragma ComponentBehavior: Bound

import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import "../Utils.js" as Utils

// Bottom-right popup displaying active file operations (copy, move, delete, etc.)
// with byte/item progress, current file name, cancellation, and collapsible list.
Rectangle {
    id: popup

    property var tasks: []
    property bool collapsed: false

    signal cancelRequested(int taskId)

    readonly property int taskCount: popup.tasks ? popup.tasks.length : 0
    readonly property bool hasTasks: taskCount > 0

    readonly property real overallProgress: {
        if (!popup.tasks || popup.tasks.length === 0) return 0;
        let sumDoneB = 0;
        let sumTotalB = 0;
        let sumProg = 0;
        for (let i = 0; i < popup.tasks.length; i++) {
            const t = popup.tasks[i];
            sumDoneB += (t.doneBytes || 0);
            sumTotalB += (t.totalBytes || 0);
            sumProg += (t.progress || 0);
        }
        if (sumTotalB > 0) return Math.max(0, Math.min(1, sumDoneB / sumTotalB));
        return Math.max(0, Math.min(1, sumProg / popup.tasks.length));
    }

    readonly property int overallPercent: Math.round(overallProgress * 100)

    function iconForKind(kind) {
        if (kind === "copy") return "content_copy";
        if (kind === "move") return "drive_file_move";
        if (kind === "delete" || kind === "trash" || kind === "empty_trash") return "delete";
        if (kind === "restore") return "restore";
        return "sync";
    }

    width: 332
    height: popup.collapsed ? 42 : (42 + 1 + Math.min(taskList.contentHeight + 16, 232))
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    clip: true
    z: 120

    // Disappear immediately as soon as all actions finish.
    visible: popup.hasTasks

    Behavior on height {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Absorb clicks inside the popup so they don't pass through to the file view.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }

    // ---- Header bar --------------------------------------------------------
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 42

        MaterialSymbol {
            id: hdrIcon
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: popup.taskCount === 1
                  ? popup.iconForKind(popup.tasks[0].kind)
                  : "sync"
            color: Appearance.colors.colPrimary
            iconSize: 18
        }

        Text {
            id: hdrTitle
            anchors {
                left: hdrIcon.right; leftMargin: 10
                right: hdrPercent.left; rightMargin: 8
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
            id: hdrPercent
            anchors {
                right: collapseBtn.left; rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: popup.overallPercent + "%"
            color: Appearance.colors.colPrimary
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        RippleButton {
            id: collapseBtn
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: 14
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover

            MaterialSymbol {
                anchors.centerIn: parent
                text: popup.collapsed ? "expand_less" : "expand_more"
                color: Appearance.colors.colSubtext
                iconSize: 18
            }

            onClicked: popup.collapsed = !popup.collapsed
        }
    }

    Rectangle {
        id: divider
        visible: !popup.collapsed
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    // ---- Collapsible task list ---------------------------------------------
    ListView {
        id: taskList
        visible: !popup.collapsed
        anchors {
            left: parent.left; right: parent.right
            top: divider.bottom; bottom: parent.bottom
            leftMargin: 10; rightMargin: 10
            topMargin: 8; bottomMargin: 8
        }
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: popup.tasks

        delegate: Rectangle {
            id: card
            required property var modelData

            width: ListView.view ? ListView.view.width : 312
            height: 68
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            // Row 1: Icon + Title + Percent + Cancel button
            Item {
                id: topRow
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: 10; rightMargin: 6; topMargin: 6
                }
                height: 22

                MaterialSymbol {
                    id: tIcon
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: popup.iconForKind(card.modelData.kind)
                    color: Appearance.colors.colPrimary
                    iconSize: 15
                }

                Text {
                    anchors {
                        left: tIcon.right; leftMargin: 8
                        right: tPct.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: card.modelData.title || ""
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: tPct
                    anchors {
                        right: cancelBtn.left; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: (card.modelData.percent !== undefined ? card.modelData.percent : 0) + "%"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 11
                }

                RippleButton {
                    id: cancelBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    implicitWidth: 22
                    implicitHeight: 22
                    buttonRadius: 11
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colErrorContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        color: Appearance.colors.colSubtext
                        iconSize: 14
                    }

                    onClicked: popup.cancelRequested(card.modelData.id)
                }
            }

            // Row 2: Current file name + Bytes/Items transferred
            Item {
                id: midRow
                anchors {
                    left: parent.left; right: parent.right; top: topRow.bottom
                    leftMargin: 10; rightMargin: 10; topMargin: 2
                }
                height: 16

                Text {
                    anchors {
                        left: parent.left
                        right: bytesLabel.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: card.modelData.currentFile || "Preparing..."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }

                Text {
                    id: bytesLabel
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: {
                        const tb = card.modelData.totalBytes || 0;
                        const db = card.modelData.doneBytes || 0;
                        if (tb > 0) {
                            return Utils.fmtBytes(db) + " / " + Utils.fmtBytes(tb);
                        }
                        const ti = card.modelData.totalItems || 0;
                        const di = card.modelData.doneItems || 0;
                        if (ti > 0) {
                            return di + " / " + ti + (ti === 1 ? " item" : " items");
                        }
                        return "";
                    }
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                }
            }

            // Row 3: Progress bar
            Rectangle {
                id: progTrack
                anchors {
                    left: parent.left; right: parent.right; bottom: parent.bottom
                    leftMargin: 10; rightMargin: 10; bottomMargin: 8
                }
                height: 5
                radius: 2.5
                color: Appearance.colors.colLayer0

                Rectangle {
                    height: parent.height
                    radius: 2.5
                    color: Appearance.colors.colPrimary
                    width: progTrack.width * Math.max(0, Math.min(1, card.modelData.progress || 0))
                    Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
