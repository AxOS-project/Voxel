import QtQuick
import QtMultimedia
import SleexUiKit.Appearance
import SleexUiKit.Widgets
import Voxel
import "../Utils.js" as Utils

// Right-side panel showing a preview of the currently selected file (image, audio, text, or info).
Rectangle {
    id: panel

    property bool shown: false
    property var entry: null
    property var xdgDirs: ({})

    Preview { id: preview }

    readonly property bool isImage: Utils.isImage(panel.entry)
    readonly property bool isAudio: Utils.isAudio(panel.entry)
    readonly property string mediaUri: (panel.entry && !panel.entry.dir)
        ? Utils.fileUri(panel.entry.path)
        : ""
    readonly property string textSample: (panel.shown && Utils.isText(panel.entry))
        ? preview.read_text(panel.entry.path, 8000)
        : ""
    readonly property bool isText: Utils.isText(panel.entry) && panel.textSample !== ""

    width: panel.shown ? 320 : 0
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    clip: true
    visible: width > 1
    opacity: panel.shown ? 1 : 0

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }

    MediaPlayer {
        id: audioPlayer
        source: (panel.shown && panel.isAudio) ? panel.mediaUri : ""
        audioOutput: AudioOutput { volume: 1.0 }
        onSourceChanged: audioPlayer.stop()
    }

    onShownChanged: if (!panel.shown) audioPlayer.stop()

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: bodyColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: bodyColumn
            width: parent.width
            spacing: 12

            // Image preview
            Rectangle {
                visible: panel.isImage
                width: parent.width
                height: panel.isImage ? Math.round(width * 0.72) : 0
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: panel.isImage ? panel.mediaUri : ""
                    asynchronous: true
                    cache: false
                    sourceSize.width: 1024
                    sourceSize.height: 1024
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            // Audio player
            Rectangle {
                visible: panel.isAudio
                width: parent.width
                height: 208
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "music_note"
                        color: Appearance.colors.colPrimary
                        iconSize: 38
                    }

                    Text {
                        width: parent.width
                        text: panel.entry ? panel.entry.name : ""
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

            // Text / code snippet
            Rectangle {
                visible: panel.isText
                width: parent.width
                height: 200
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: codeView.contentWidth
                    contentHeight: codeView.contentHeight
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: codeView
                        width: parent.width
                        text: panel.textSample
                        readOnly: true
                        wrapMode: TextEdit.NoWrap
                        color: Appearance.colors.colSubtext
                        selectionColor: Appearance.colors.colPrimary
                        selectedTextColor: Appearance.colors.colLayer0
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 10
                    }
                }
            }

            // Generic icon for folders or non-previewable files
            MaterialSymbol {
                visible: panel.entry !== null && !panel.isImage && !panel.isAudio && !panel.isText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Utils.iconFor(panel.entry, panel.xdgDirs)
                color: Appearance.colors.colPrimary
                iconSize: 44
            }

            // File name, type/size summary, and full path
            Column {
                visible: panel.entry !== null
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: panel.entry ? panel.entry.name : ""
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: Utils.describe(panel.entry)
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: panel.entry ? panel.entry.path : ""
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                    opacity: 0.7
                    wrapMode: Text.WrapAnywhere
                }
            }

            // Placeholder when no file is selected
            Text {
                visible: panel.entry === null
                width: parent.width
                text: "Nothing selected"
                color: Appearance.colors.colSubtext
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
