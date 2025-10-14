import QtQuick

Item {
    id: root

    FontLoader {
        id: clefFont
        source: "qrc:/QML/fonts/NotoMusic-Regular.ttf"
        onStatusChanged: {
            root.updateTick++
        }
    }

    FontLoader {
        id: clefFallback
        source: "qrc:/QML/fonts/MusiSync.ttf"
        onStatusChanged: {
            root.updateTick++
        }
    }

    // "treble" (𝄞) ou "bass" (𝄢)
    property string clefType: "treble"
    // Couleur du texte
    property color clefColor: "#DADADA"
    // Espacement des lignes de la portée (en px 2D)
    property real lineSpacing: 20
    // Offsets 2D par rapport au coin gauche de la portée visible
    property real clefOffsetX: 0
    property real clefOffsetY: -20
    // Facteur d'échelle supplémentaire pour la taille de la clé
    property real clefScale: 1.1
    // Police (idéal: "Noto Music" ou "Bravura")
    property string clefFontFamily: (clefFont.status === FontLoader.Ready && clefFont.name && clefFont.name.length > 0)
                                    ? clefFont.name
                                    : ((clefFallback.status === FontLoader.Ready && clefFallback.name && clefFallback.name.length > 0)
                                        ? clefFallback.name
                                        : "MusiSync")
    // Taille liée à la hauteur de la portée (≈ 5 lignes)
    property real clefPixelSize: lineSpacing * 5.2
    // Fallback ASCII si la police musicale n’est pas dispo (évite le carré manquant)
    property bool fallbackAscii: {
        // Si le nom de police est déjà résolu, on tente les glyphes Unicode
        if (clefFont.name && clefFont.name.length > 0)
            return false
        return clefFont.status !== FontLoader.Ready
    }

    // Tick pour forcer le rebinding lorsqu'on reçoit Ready
    property int updateTick: 0

    // Sonde périodique tant que la police n'est pas prête
    Timer {
        id: fontProbe
        interval: 250
        repeat: true
        running: clefFont.status !== FontLoader.Ready
        onTriggered: {
            if (clefFont.status === FontLoader.Ready) {
                root.updateTick++
                fontProbe.stop()
            }
        }
    }

    Component.onCompleted: {
    }

    // Largeur/hauteur calculées pour la zone du texte
    implicitWidth: clefText.implicitWidth
    implicitHeight: clefText.implicitHeight

    // Positionnement relatif: à placer par le parent avec x/y,
    // ce composant applique juste un petit offset fin.
    x: clefOffsetX
    y: clefOffsetY

    Text {
        id: clefText
        text: {
            var _ = root.updateTick // force rebind quand la police change d'état
            var useAscii = root.fallbackAscii && !(clefFallback.status === FontLoader.Ready || clefFont.status === FontLoader.Ready)
            var t = useAscii ? (root.clefType === "treble" ? "G" : "F") : (root.clefType === "treble" ? "\uD834\uDD1E" : "\uD834\uDD22")
            return t
        }
        color: root.clefColor
        font.family: root.clefFontFamily
        font.pixelSize: root.clefPixelSize
        scale: root.clefScale
        renderType: Text.QtRendering
    }
}


