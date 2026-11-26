import QtQuick
import QtMultimedia
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import Voxel
import "../Utils.js" as Utils

// Full-window preview opened with the Space bar. Supports image zoom/pan,
// video playback, audio playback, and text/code viewing.
Item {
    id: quickLook

    property bool shown: false
    property var entry: null
    property int index: 0
    property int total: 0
    property var xdgDirs: ({})

    Preview { id: preview }

    property string mediaSource: ""
    property string textContent: ""
    property real zoom: 1
    property real panX: 0
    property real panY: 0

    readonly property bool isImage: Utils.isImage(quickLook.entry)
    readonly property bool isVideo: Utils.isVideo(quickLook.entry)
    readonly property bool isAudio: Utils.isAudio(quickLook.entry)
    readonly property bool isText: Utils.isText(quickLook.entry) && quickLook.textContent !== ""
    readonly property bool isFallback: quickLook.entry !== null
        && !quickLook.isImage && !quickLook.isVideo && !quickLook.isAudio && !quickLook.isText

    signal stepRequested(int delta)
    signal closed()

    function open(targetEntry) {
        videoPlayer.stop();
        audioPlayer.stop();

        quickLook.entry = targetEntry;
        quickLook.mediaSource = "";
        quickLook.textContent = "";
        quickLook.zoom = 1;
        quickLook.panX = 0;
        quickLook.panY = 0;

        if (targetEntry && !targetEntry.dir) {
            if (Utils.isImage(targetEntry) || Utils.isVideo(targetEntry) || Utils.isAudio(targetEntry)) {
                quickLook.mediaSource = Utils.fileUri(targetEntry.path);
                if (Utils.isVideo(targetEntry)) videoPlayer.play();
            } else if (Utils.isText(targetEntry)) {
                quickLook.textContent = preview.read_text(targetEntry.path, 300000);
            }
        }

        quickLook.shown = true;
        quickLook.forceActiveFocus();
    }

    function close() {
        videoPlayer.stop();
        audioPlayer.stop();
        quickLook.shown = false;
        quickLook.closed();
    }

    anchors.fill: parent
    z: 108
    focus: quickLook.shown
    opacity: quickLook.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 140 } }

    // Keyboard controls inside QuickLook
    Keys.onEscapePressed: (event) => { quickLook.close(); event.accepted = true; }
    Keys.onReturnPressed: (event) => { quickLook.close(); event.accepted = true; }
    Keys.onEnterPressed: (event) => { quickLook.close(); event.accepted = true; }
    Keys.onSpacePressed: (event) => { quickLook.close(); event.accepted = true; }
    Keys.onLeftPressed: (event) => { quickLook.stepRequested(-1); event.accepted = true; }
    Keys.onRightPressed: (event) => { quickLook.stepRequested(1); event.accepted = true; }
    Keys.onUpPressed: (event) => { quickLook.stepRequested(-1); event.accepted = true; }
    Keys.onDownPressed: (event) => { quickLook.stepRequested(1); event.accepted = true; }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            quickLook.zoom = Math.min(8, quickLook.zoom * 1.25);
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus) {
            quickLook.zoom = Math.max(0.2, quickLook.zoom / 1.25);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            quickLook.zoom = 1;
            quickLook.panX = 0;
            quickLook.panY = 0;
            event.accepted = true;
        }
    }

    // Dark backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.9)
        MouseArea {
            anchors.fill: parent
            onClicked: quickLook.close()
        }
    }

    // ---- 1. Image Viewer (with Zoom and Pan) -------------------------------
    Item {
        anchors.fill: parent
        anchors.margins: 48
        anchors.bottomMargin: 44
        visible: quickLook.isImage
        clip: true

        Image {
            source: quickLook.isImage ? quickLook.mediaSource : ""
            asynchronous: true
            cache: false
            sourceSize.width: 4096
            sourceSize.height: 4096
            fillMode: Image.PreserveAspectFit
            width: parent.width
            height: parent.height
            scale: quickLook.zoom
            transformOrigin: Item.Center
            x: (parent.width - width) / 2 + quickLook.panX
            y: (parent.height - height) / 2 + quickLook.panY
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            property real lastX: 0
            property real lastY: 0
            cursorShape: (pressed && quickLook.zoom > 1) ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: (mouse) => {
                lastX = mouse.x;
                lastY = mouse.y;
            }
            onPositionChanged: (mouse) => {
                if (pressed && quickLook.zoom > 1) {
                    quickLook.panX += mouse.x - lastX;
                    quickLook.panY += mouse.y - lastY;
                    lastX = mouse.x;
                    lastY = mouse.y;
                }
            }
            onDoubleClicked: {
                quickLook.zoom = quickLook.zoom > 1 ? 1 : 2;
                quickLook.panX = 0;
                quickLook.panY = 0;
            }
            onWheel: (wheel) => {
                const factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87;
                quickLook.zoom = Math.max(0.2, Math.min(8, quickLook.zoom * factor));
            }
        }
    }

    // ---- 2. Video Player ---------------------------------------------------
    Video {
        id: videoPlayer
        visible: quickLook.isVideo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -26
        width: Math.min(parent.width - 96, 1280)
        height: Math.min(parent.height - 168, width * 9 / 16)
        source: quickLook.isVideo ? quickLook.mediaSource : ""
        fillMode: VideoOutput.PreserveAspectFit
        autoPlay: true
        onSourceChanged: if (source !== "") play()

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (videoPlayer.playbackState === MediaPlayer.PlayingState) videoPlayer.pause();
                else videoPlayer.play();
            }
        }
    }

    SeekBar {
        visible: quickLook.isVideo
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 96, 700)
        player: videoPlayer
    }

    // ---- 3. Audio Player ---------------------------------------------------
    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        source: quickLook.isAudio ? quickLook.mediaSource : ""
        onSourceChanged: stop()
    }

    Rectangle {
        visible: quickLook.isAudio
        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 460)
        height: 220
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "music_note"
                color: Appearance.colors.colPrimary
                iconSize: 44
            }

            Text {
                width: parent.width
                text: quickLook.entry ? quickLook.entry.name : ""
                color: Appearance.colors.colOnLayer0
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }

            SeekBar {
                width: parent.width
                player: audioPlayer
            }
        }
    }

    // ---- 4. Text / Code Viewer ---------------------------------------------
    Flickable {
        id: textFlickable
        visible: quickLook.isText
        anchors.fill: parent
        anchors.margins: 40
        anchors.topMargin: 64
        anchors.bottomMargin: 44
        clip: true
        contentWidth: textEditor.contentWidth + 8
        contentHeight: textEditor.contentHeight + 8
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: textEditor
            x: 4
            y: 4
            width: textFlickable.width
            text: quickLook.textContent
            readOnly: true
            wrapMode: TextEdit.NoWrap
            color: Appearance.colors.colOnLayer0
            selectionColor: Appearance.colors.colPrimary
            selectedTextColor: Appearance.colors.colLayer0
            font.family: Appearance.font.family.monospace
            font.pixelSize: 12
        }
    }

    // ---- 5. Fallback Info View (for folders and binary files) --------------
    Column {
        visible: quickLook.isFallback
        anchors.centerIn: parent
        spacing: 12

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Utils.iconFor(quickLook.entry, quickLook.xdgDirs)
            color: Appearance.colors.colPrimary
            iconSize: 72
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: quickLook.entry ? quickLook.entry.name : ""
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 15
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Utils.describe(quickLook.entry)
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
        }
    }

    // ---- Top Header Bar ----------------------------------------------------
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 48
        color: Qt.rgba(0, 0, 0, 0.35)

        Text {
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            width: parent.width - 260
            text: quickLook.entry ? quickLook.entry.name : ""
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 13
            elide: Text.ElideMiddle
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }
            text: (quickLook.index + 1) + " / " + quickLook.total
                + "   ←→ next · +/− zoom · Esc close"
            color: Appearance.colors.colSubtext
            font.pixelSize: 10
        }
    }
}
