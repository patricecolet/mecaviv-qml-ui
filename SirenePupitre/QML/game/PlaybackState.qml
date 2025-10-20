import QtQuick

QtObject {
    id: playbackState
    
    // État de lecture
    property bool playing: false
    property int bar: 0
    property int beatInBar: 0
    property real beat: 0.0
    
    // Info fichier
    property string file: ""
    property int durationMs: 0
    
    // Méthode helper pour mettre à jour depuis un message binaire
    function updateFromPosition(isPlaying, barNum, beatNum, beatTotal) {
        playing = isPlaying;
        bar = barNum;
        beatInBar = beatNum;
        beat = beatTotal;
    }
}


