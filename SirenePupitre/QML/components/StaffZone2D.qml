import QtQuick
import "./ambitus"

Item {
    id: root

    property color accentColor: '#d1ab00'
    property real currentNoteMidi: 0
    property var sirenInfo: null
    property var configController: null
    property real lineSpacing: 20
    property real lineThickness: 2
    property real rpm: 0
    property int frequency: 0
    height: 120

    readonly property string _viewMode: configController && configController.updateCounter >= 0
        ? (configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "viewMode"], "staff") || "staff")
        : "staff"

    Component {
        id: staffComponent
        MusicalStaff2D {
            currentNoteMidi: root.currentNoteMidi
            sirenInfo: root.sirenInfo
            configController: root.configController
            lineSpacing: root.lineSpacing
            lineThickness: root.lineThickness
            staffWidth: root.width
            lineColor: Qt.rgba(1, 1, 1, 1)
            rpm: root.rpm
            frequency: root.frequency
        }
    }

    Component {
        id: pianoComponent
        AmbitusPiano2D {
            currentNoteMidi: root.currentNoteMidi
            sirenInfo: root.sirenInfo
            configController: root.configController
            lineSpacing: root.lineSpacing
            staffWidth: root.width
            accentColor: root.accentColor
        }
    }

    Loader {
        id: viewLoader
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: root._viewMode === "piano" ? pianoComponent : staffComponent
    }
}
