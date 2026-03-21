import QtQuick
import QtQuick.Controls

/**
 * Jauge de vélocité manuelle (0-127).
 * Affichée quand le pad n'est pas connecté — l'utilisateur règle la vélocité manuellement.
 * Quand le pad est connecté, la vélocité vient du message 0x03 (TopDisplays2D l'affiche).
 */
Item {
    id: root

    property int value: 100
    property bool padConnected: false  // Si true, la jauge est masquée (vélocité vient du pad/0x03)
    property color accentColor: "#d1ab00"
    property var configController: null

    signal velocityChanged(int value)

    width: 120
    height: 60

    visible: !padConnected && (configController ? configController.getConfigValue("displayConfig.components.velocityGauge.visible", true) : true)

    Column {
        anchors.fill: parent
        spacing: 4

        Text {
            text: "Vélocité"
            font.pixelSize: 11
            font.bold: true
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Slider {
            id: velocitySlider
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 10
            from: 0
            to: 127
            value: root.value
            stepSize: 1

            onValueChanged: {
                var v = Math.round(value)
                root.velocityChanged(v)
            }

            background: Rectangle {
                x: velocitySlider.leftPadding
                y: velocitySlider.topPadding + velocitySlider.availableHeight / 2 - height / 2
                implicitWidth: 100
                implicitHeight: 6
                width: velocitySlider.availableWidth
                height: implicitHeight
                radius: 3
                color: "#333"

                Rectangle {
                    width: velocitySlider.visualPosition * parent.width
                    height: parent.height
                    color: root.accentColor
                    radius: 3
                }
            }

            handle: Rectangle {
                x: velocitySlider.leftPadding + velocitySlider.visualPosition * (velocitySlider.availableWidth - width)
                y: velocitySlider.topPadding + velocitySlider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: velocitySlider.pressed ? Qt.lighter(root.accentColor, 1.2) : "#FFF"
                border.color: root.accentColor
                border.width: 2
            }
        }

        Text {
            text: Math.round(velocitySlider.value)
            font.pixelSize: 12
            font.bold: true
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

}
