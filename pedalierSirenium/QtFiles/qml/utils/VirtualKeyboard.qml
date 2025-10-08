import QtQuick
import QtQuick.Controls

Rectangle {
    id: keyboard
    width: 400
    height: 220
    color: "#222"
    radius: 12
    border.color: "#444"
    border.width: 2
    property Item targetField
    property bool shift: false
    property int layout: 0 // 0: lettres, 1: chiffres/spéciaux
    
    signal okClicked()

    property var azertyRows: [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["Shift", "w", "x", "c", "v", "b", "n", "Effacer"],
        ["123", "Espace", "OK"]
    ]
    property var azertyRowsMaj: [
        ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"],
        ["Shift", "W", "X", "C", "V", "B", "N", "Effacer"],
        ["123", "Espace", "OK"]
    ]
    property var numRows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["@", "#", "$", "_", "&", "-", "/", "(", ")", "'"],
        ["*", ":", ";", "!", "?", ".", ",", "Effacer"],
        ["ABC", "Espace", "OK"]
    ]
    property var numRowsMaj: [
        ["~", "|", "•", "√", "π", "÷", "×", "¶", "∆", "°"],
        ["^", "%", "=", "{", "}", "[", "]", "<", ">", "\""],
        ["+", "§", "€", "£", "¥", "`", "\\", "Effacer"],
        ["ABC", "Espace", "OK"]
    ]

    Column {
        anchors.margins: 8
        spacing: 6
        Repeater {
            model: keyboard.layout === 0 ? (keyboard.shift ? keyboard.azertyRowsMaj : keyboard.azertyRows) : (keyboard.shift ? keyboard.numRowsMaj : keyboard.numRows)
            delegate: Row {
                spacing: 4
                Repeater {
                    model: modelData
                    delegate: Button {
                        text: getDisplayText(modelData)
                        font.pixelSize: getButtonFontSize(modelData)
                        width: text === "Espace" ? 90 : (modelData === "OK" ? 60 : (modelData === "Effacer" ? 60 : (modelData === "Shift" ? 50 : 32)))
                        height: 36
                        
                        function getDisplayText(key) {
                            if (key === "Shift") return keyboard.shift ? "⬆" : "⇧"
                            if (key === "123") return "123"
                            if (key === "ABC") return "ABC"
                            if (key === "Espace") return "____"
                            if (key === "Effacer") return "⌫"
                            if (key === "OK") return "✓"
                            return key
                        }
                        
                        function getButtonFontSize(key) {
                            if (key === "Shift" || key === "Effacer" || key === "OK") return 16
                            if (key === "123" || key === "ABC") return 14
                            if (key === "Espace") return 12
                            return 18
                        }
                        onClicked: {
                            if (modelData === "Shift") {
                                keyboard.shift = !keyboard.shift
                            } else if (modelData === "123" || modelData === "ABC") {
                                keyboard.layout = 1 - keyboard.layout
                                keyboard.shift = false
                            } else if (modelData === "Espace") {
                                if (keyboard.targetField) {
                                    keyboard.targetField.insert(keyboard.targetField.cursorPosition, " ");
                                }
                            } else if (modelData === "Effacer") {
                                if (keyboard.targetField) {
                                    keyboard.targetField.backspace();
                                }
                            } else if (modelData === "OK") {
                                // Signal pour fermer depuis le parent
                                keyboard.okClicked()
                            } else {
                                if (keyboard.targetField) {
                                    keyboard.targetField.insert(keyboard.targetField.cursorPosition, modelData);
                                }
                                if (keyboard.shift && keyboard.layout === 0) keyboard.shift = false // auto-unshift après une lettre
                            }
                        }
                    }
                }
            }
        }
    }
} 