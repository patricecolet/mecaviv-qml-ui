import QtQuick
import QtQuick3D

Model {
    id: testChart
    
    // Remplacer le cylindre par un rectangle plat
    source: "#Rectangle"
    scale: Qt.vector3d(2, 2, 1)  // Rectangle carré, pas de rotation nécessaire
    position: Qt.vector3d(0, -100, 0)
    eulerRotation: Qt.vector3d(0, 0, 0)  // Pas de rotation
    
    materials: CustomMaterial {
        shadingMode: CustomMaterial.Shaded
        fragmentShader: "newsimpleshader.frag"
        
        // Désactiver le culling pour voir toutes les faces
        cullMode: Material.NoCulling
        
        property real uProgress: testChart.animatedProgress  // ANIMÉ
        property color uActiveColor: "lime"
        property color uInactiveColor: "#333333"
        property bool uIsRecording: false
    }
    
    // Propriété animée pour test
    property real animatedProgress: 0
    
    // Animation automatique pour test
    NumberAnimation {
        target: testChart
        property: "animatedProgress"
        from: 0
        to: 1
        duration: 3000  // 3 secondes
        running: true
        loops: Animation.Infinite
    }
    
    Component.onCompleted: {
        console.log("Test avec animation automatique");
    }
} 