import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Widgets

// Brief notification banner at the bottom of the window, with an optional "Undo" button.
Rectangle {
    id: toast

    property bool shown: false
    property string message: ""
    property string actionLabel: ""
    property var actionCallback: null

    function show(text) {
        toast.actionLabel = "";
        toast.actionCallback = null;
        toast.message = text;
        toast.shown = true;
        hideTimer.restart();
    }

    function showUndo(text, callback) {
        toast.actionLabel = "Undo";
        toast.actionCallback = callback;
        toast.message = text;
        toast.shown = true;
        hideTimer.restart();
    }

    z: 130
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min((parent ? parent.width : 960) - 40, contentRow.implicitWidth + 44)
    height: 36
    radius: height / 2
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    opacity: toast.shown ? 1 : 0
    scale: toast.shown ? 1 : 0.96
    y: toast.shown ? (parent.height - height - 46) : (parent.height - height - 26)
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 14

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: toast.message
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 12
        }

        ActionButton {
            visible: toast.actionLabel.length > 0
            anchors.verticalCenter: parent.verticalCenter
            label: toast.actionLabel
            onActivated: {
                const callback = toast.actionCallback;
                toast.shown = false;
                if (callback) callback();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 4200
        repeat: false
        onTriggered: toast.shown = false
    }
}
