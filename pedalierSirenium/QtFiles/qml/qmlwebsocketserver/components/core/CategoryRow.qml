import QtQuick
import QtQuick.Controls

Row {
    property string name: ""
    property string emoji: ""
    property int level: 0
    property string iconName: ""
    
    signal levelChangeRequested(int newLevel)
    
    spacing: 10
    
    // Icône à gauche du nom
    Image {
                    source: iconName !== "" ? "qrc:/qml/icons/" + iconName : ""
        width: 20
        height: 20
        fillMode: Image.PreserveAspectFit
        visible: source != ""
    }
    
    Text {
        text: name + ":"
        color: "white"
        width: 120
        font.pixelSize: 14
        font.family: "" // Forcer la police système pour les emojis
    }
    
    Text {
        text: ["OFF", "ERROR", "WARN", "INFO", "DEBUG", "TRACE"][level] || "OFF"
        color: {
            if (level === 0) return "#888888";
            else if (level <= 2) return "#ff8888";
            else if (level === 3) return "#88ff88";
            else return "#8888ff";
        }
        width: 60
        font.pixelSize: 12
        font.bold: true
    }
    
    Button {
        text: "-"
        width: 25
        height: 25
        enabled: level > 0
        onClicked: levelChangeRequested(level - 1)
    }
    
    Button {
        text: "+"
        width: 25
        height: 25
        enabled: level < 5
        onClicked: levelChangeRequested(level + 1)
    }
}
