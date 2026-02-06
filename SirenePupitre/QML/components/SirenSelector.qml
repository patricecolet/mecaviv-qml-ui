import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 80
    height: 60

    property var configController: null
    property color accentColor: '#d1ab00'
    property var sirenInfo: null

    ComboBox {
        id: sirenSelector
        width: 80
        height: 40
        anchors.left: parent.left
        anchors.top: parent.top
        visible: configController && configController.mode === "admin"

        model: configController && configController.config ? configController.config.sirenConfig.sirens : [
            { id: "1", name: "S1" },
            { id: "2", name: "S2" }
        ]
        textRole: "name"
        valueRole: "id"

        currentIndex: {
            if (!configController || !configController.config) return 0
            var sirens = configController.config.sirenConfig.sirens
            if (!sirens || sirens.length === 0) return 0
            var list = configController.config.sirenConfig.currentSirens || []
            var currentId = list.length > 0 ? list[0] : null
            for (var i = 0; i < sirens.length; i++) {
                if (sirens[i].id === currentId) return i
            }
            return 0
        }

        onActivated: function(index) {
            if (configController && configController.config && index >= 0) {
                var sirens = configController.config.sirenConfig.sirens
                if (sirens && sirens[index])
                    configController.setValueAtPath(["sirenConfig", "currentSirens"], [sirens[index].id])
            }
        }

        delegate: ItemDelegate {
            width: sirenSelector.width
            contentItem: Text {
                text: modelData.name
                color: "#ffffff"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.hovered ? "#3a3a3a" : "#2a2a2a"
                border.color: root.accentColor
                border.width: parent.hovered ? 1 : 0
            }
        }

        contentItem: Text {
            leftPadding: 10
            rightPadding: sirenSelector.indicator.width + sirenSelector.spacing
            text: sirenSelector.displayText
            font.pixelSize: 16
            font.bold: true
            color: "#ffffff"
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: "#2a2a2a"
            border.color: root.accentColor
            border.width: 2
            radius: 6
        }

        popup: Popup {
            y: sirenSelector.height - 1
            width: sirenSelector.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: sirenSelector.popup.visible ? sirenSelector.delegateModel : null
                currentIndex: sirenSelector.highlightedIndex

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            background: Rectangle {
                color: "#2a2a2a"
                border.color: root.accentColor
                border.width: 1
                radius: 6
            }
        }
    }

    Rectangle {
        width: 60
        height: 60
        radius: 30
        color: "#2a2a2a"
        border.color: root.accentColor
        border.width: 2
        anchors.left: parent.left
        anchors.top: parent.top
        visible: (!configController || configController.mode === "restricted") 
                 && (configController ? configController.isComponentVisible("sirenCircle") : true)

        Text {
            anchors.centerIn: parent
            text: root.sirenInfo ? root.sirenInfo.name : "S1"
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }
    }
}
