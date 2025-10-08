import QtQuick
import QtQuick3D

Node {
    id: digitNode

    // Propriétés pour personnaliser l'affichage
    property int value: 0
    property color activeColor: "red"
    property color inactiveColor: "#330000"  // Couleur sombre pour les segments inactifs

    // Propriétés pour ajuster les dimensions des segments
    property real segmentWidth: 5            // Réduire la largeur des segments (était probablement plus grande)
    property real horizontalLength: 20       // Augmenter la longueur des segments horizontaux
    property real verticalLength: 20         // Longueur des segments verticaux
    property real segmentSpacing: 2          // Espacement entre les segments

    // Tableau pour stocker les références aux segments
    property var segments: []

    // Tableau de correspondance entre chiffres et segments
    property var digitSegments: [
        [1, 1, 1, 1, 1, 1, 0], // 0
        [0, 1, 1, 0, 0, 0, 0], // 1
        [1, 1, 0, 1, 1, 0, 1], // 2
        [1, 1, 1, 1, 0, 0, 1], // 3
        [0, 1, 1, 0, 0, 1, 1], // 4
        [1, 0, 1, 1, 0, 1, 1], // 5
        [1, 0, 1, 1, 1, 1, 1], // 6
        [1, 1, 1, 0, 0, 0, 0], // 7
        [1, 1, 1, 1, 1, 1, 1], // 8
        [1, 1, 1, 1, 0, 1, 1]  // 9
    ]

    // Créer les segments au chargement
    Component.onCompleted: {
        createSegments();
        updateDisplay();
    }

    // Observer les changements de valeur
    onValueChanged: {
        updateDisplay();
    }

    // Fonction pour créer les segments
    function createSegments() {
        // Positions et rotations des segments
        let segmentPositions = [
            // Segment A (haut)
            { position: Qt.vector3d(0, verticalLength + segmentSpacing, 0), rotation: Qt.vector3d(0, 0, 90) },
            // Segment B (haut droite)
            { position: Qt.vector3d(horizontalLength/2, verticalLength/2, 0), rotation: Qt.vector3d(0, 0, 0) },
            // Segment C (bas droite)
            { position: Qt.vector3d(horizontalLength/2, -verticalLength/2, 0), rotation: Qt.vector3d(0, 0, 0) },
            // Segment D (bas)
            { position: Qt.vector3d(0, -verticalLength - segmentSpacing, 0), rotation: Qt.vector3d(0, 0, 90) },
            // Segment E (bas gauche)
            { position: Qt.vector3d(-horizontalLength/2, -verticalLength/2, 0), rotation: Qt.vector3d(0, 0, 0) },
            // Segment F (haut gauche)
            { position: Qt.vector3d(-horizontalLength/2, verticalLength/2, 0), rotation: Qt.vector3d(0, 0, 0) },
            // Segment G (milieu)
            { position: Qt.vector3d(0, 0, 0), rotation: Qt.vector3d(0, 0, 90) }
        ];

        // Créer chaque segment
        for (let i = 0; i < 7; i++) {
            let segmentComponent = Qt.createComponent("qrc:/qml/utils/LEDSegment.qml");
            if (segmentComponent.status === Component.Ready) {
                let segment = segmentComponent.createObject(digitNode, {
                    position: segmentPositions[i].position,
                    eulerRotation: segmentPositions[i].rotation,
                    segmentWidth: segmentWidth,
                    // Ajuster la longueur en fonction de l'orientation
                    segmentLength: (i === 0 || i === 3 || i === 6) ? horizontalLength : verticalLength,
                    segmentColor: inactiveColor  // Initialiser avec la couleur inactive
                });
                segments.push(segment);
            }
        }
    }

    // Fonction pour mettre à jour l'affichage en fonction de la valeur
    function updateDisplay() {
        // S'assurer que la valeur est entre 0 et 9
        let digit = Math.max(0, Math.min(9, value));

        // Mettre à jour chaque segment
        for (let i = 0; i < 7; i++) {
            if (segments[i]) {
                // Définir la couleur du segment en fonction de son état
                segments[i].segmentColor = digitSegments[digit][i] ? activeColor : inactiveColor;
            }
        }
    }
}
