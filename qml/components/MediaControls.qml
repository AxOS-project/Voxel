import QtQuick

// Rewind / play-pause / forward transport used by audio and video previews.
Row {
    id: mc
    property bool playing: false
    property string rewindGlyph: "fast_rewind"
    property string forwardGlyph: "fast_forward"
    signal rewind()
    signal forward()
    signal togglePlay()

    spacing: 10

    BarButton { glyph: mc.rewindGlyph; onActivated: mc.rewind() }
    BarButton { glyph: mc.playing ? "pause" : "play_arrow"; onActivated: mc.togglePlay() }
    BarButton { glyph: mc.forwardGlyph; onActivated: mc.forward() }
}
