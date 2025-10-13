import QtQuick 2.15

/**
 * Police Noto Emoji partagée entre toutes les apps QML
 * Version monochrome légère (1.9 MB) - Optimisée pour WebAssembly
 * 
 * Usage:
 *   import "../../fonts" as Fonts
 *   
 *   Fonts.EmojiFont { id: emoji }
 *   
 *   Label {
 *       text: "🎵 🎼 ⏩ ⏸ ⏹"
 *       font.family: emoji.name
 *   }
 */
FontLoader {
    id: emojiFont
    source: "qrc:/fonts/NotoEmoji-VariableFont_wght.ttf"
    
    // Exposer le nom de la police
    readonly property string name: emojiFont.name
    
    Component.onCompleted: {
        console.log("✅ Police Emoji chargée:", name, "- Statut:", status === FontLoader.Ready ? "OK" : "ERREUR")
    }
}

