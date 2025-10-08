import QtQuick 2.15

Rectangle {
    id: ambitusBar
    
    property int minNote: 48  // C3
    property int maxNote: 72  // C6
    property int currentNote: 60  // C4
    
    height: 40
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 2
    radius: 6
    
    // Barre de fond (zone de l'ambitus)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "#1a4a1a"  // Vert foncé pour la zone de l'ambitus
        radius: 4
    }
    
    // Graduations (tous les 12 demi-tons)
    Repeater {
        model: Math.floor((maxNote - minNote) / 12) + 1
        delegate: Rectangle {
            x: parent.width * (index * 12) / (maxNote - minNote) - 1
            y: 0
            width: 2
            height: parent.height
            color: "#666666"
        }
    }
    
    // Curseur de note actuelle
    Rectangle {
        x: parent.width * ((currentNote - minNote) / (maxNote - minNote)) - 3
        y: -5
        width: 6
        height: parent.height + 10
        color: "#ff6b6b"
        radius: 3
        border.color: "#ffffff"
        border.width: 1
    }
    
    // Labels des octaves
    Repeater {
        model: Math.floor((maxNote - minNote) / 12) + 1
        delegate: Text {
            x: parent.width * (index * 12) / (maxNote - minNote) - 10
            y: -20
            width: 20
            text: "C" + (Math.floor(minNote / 12) - 1 + index)
            color: "#cccccc"
            font.pixelSize: 10
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
    
    // Note actuelle au centre
    Text {
        anchors.centerIn: parent
        text: noteToName(currentNote)
        color: "#ffffff"
        font.pixelSize: 12
        font.bold: true
    }
    
    function noteToName(note) {
        const names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        const octave = Math.floor(note / 12) - 1
        const noteName = names[note % 12]
        return noteName + octave
    }
}
