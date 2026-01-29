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
    // Offsets 2D par rapport au coin gauche de la portée visible (utilisés si useTargetLineY est false)
    property real clefOffsetX: 0
    property real clefOffsetY: -20
    // Positionnement par ligne : centre du glyphe sur une ligne (y dans le repère parent, y vers le bas).
    // Si true, targetLineY = ordonnée de la ligne ; la clé est centrée dessus (hauteur réelle du glyphe).
    property bool useTargetLineY: false
    property real targetLineY: 0
    // Décalage vertical pour corriger le centre visuel du glyphe (police). Positif = vers le bas.
    property real verticalOffsetTreble: -20
    property real verticalOffsetBass: 12
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

    x: clefOffsetX
    y: root.useTargetLineY
        ? (root.targetLineY - clefText.implicitHeight / 2 + (root.clefType === "treble" ? root.verticalOffsetTreble : root.verticalOffsetBass))
        : clefOffsetY

    Text {
        id: clefText
        x: 0
        y: 0
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


