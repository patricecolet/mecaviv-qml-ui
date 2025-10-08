import QtQuick
import "../../../sirenSpec.js" as SirenSpec

QtObject {
    id: provider
    // Spécification par défaut depuis le module JS packagé
    property var spec: ({})
    Component.onCompleted: { spec = SirenSpec.SPEC }
    function applySpecFromWs(obj) {
        if (!obj) return
        spec = obj
    }
}


