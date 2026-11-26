import QtQuick
import QtMultimedia
import SleexUiKit.Appearance
import "../Utils.js" as Utils

// Reusable media progress bar, timer display, and play/pause/seek buttons
// for any Audio (MediaPlayer) or Video player.
Column {
    id: mediaBar

    // The MediaPlayer or Video item to control
    property var player: null

    readonly property real position: player ? player.position : 0
    readonly property real duration: player ? player.duration : 0
    readonly property bool isPlaying: player && player.playbackState === MediaPlayer.PlayingState

    spacing: 8

    // Clickable progress bar
    Item {
        width: parent.width
        height: 16

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 5
            radius: 2.5
            color: Appearance.colors.colLayer2

            Rectangle {
                height: parent.height
                radius: 2.5
                color: Appearance.colors.colPrimary
                width: mediaBar.duration > 0
                    ? track.width * Math.max(0, Math.min(1, mediaBar.position / mediaBar.duration))
                    : 0
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mediaBar.player && mediaBar.duration > 0) {
                    const ratio = Math.max(0, Math.min(1, mouse.x / width));
                    mediaBar.player.position = ratio * mediaBar.duration;
                }
            }
        }
    }

    // Current time and total duration
    Row {
        width: parent.width

        Text {
            width: parent.width / 2
            text: Utils.fmtClock(mediaBar.position)
            color: Appearance.colors.colSubtext
            font.pixelSize: 10
        }

        Text {
            width: parent.width / 2
            horizontalAlignment: Text.AlignRight
            text: Utils.fmtClock(mediaBar.duration)
            color: Appearance.colors.colSubtext
            font.pixelSize: 10
        }
    }

    // Rewind 10s, Play/Pause, Forward 10s buttons
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        BarButton {
            glyph: "fast_rewind"
            onActivated: if (mediaBar.player) {
                mediaBar.player.position = Math.max(0, mediaBar.position - 10000);
            }
        }

        BarButton {
            glyph: mediaBar.isPlaying ? "pause" : "play_arrow"
            onActivated: if (mediaBar.player) {
                if (mediaBar.isPlaying) mediaBar.player.pause();
                else mediaBar.player.play();
            }
        }

        BarButton {
            glyph: "fast_forward"
            onActivated: if (mediaBar.player) {
                mediaBar.player.position = Math.min(mediaBar.duration, mediaBar.position + 10000);
            }
        }
    }
}
