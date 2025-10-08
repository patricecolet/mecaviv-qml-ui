import QtQuick
import QtQuick3D

Node {
    id: root

    // Propriétés exposées
    property int value: 0  // Valeur à afficher
    property int digitCount: 3  // Nombre de chiffres à afficher
    property color activeColor: "#ffd500"  // Couleur des segments actifs
    property color inactiveColor: "#330000"  // Couleur des segments inactifs
    property real digitSpacing: 50  // Espacement entre les chiffres

    // Tableau pour stocker les références aux chiffres
    property var digits: []

    // Créer les chiffres LED
    Component.onCompleted: {
        createDigits();
        // Attendre que les digits soient créés avant de mettre à jour l'affichage
        Qt.callLater(updateDisplay);
    }

    // Fonction pour créer les chiffres
    function createDigits() {
                    let digitComponent = Qt.createComponent("qrc:/qml/utils/DigitLED3D.qml");
        if (digitComponent.status === Component.Ready) {
            // Vider le tableau digits au cas où
            digits = [];

            for (let i = 0; i < digitCount; i++) {
                let xPos = (i - (digitCount - 1) / 2) * digitSpacing;
                let digit = digitComponent.createObject(root, {
                    "position": Qt.vector3d(xPos, 0, 0),
                    "activeColor": root.activeColor,
                    "inactiveColor": root.inactiveColor
                });

                if (digit) {
                    digits.push(digit);
                } else {
                    if (logger) logger.error("INIT", "Erreur lors de la création du digit", i);
                }
            }

            if (logger) logger.debug("INIT", "Digits créés:", digits.length);
        } else if (digitComponent.status === Component.Error) {
            if (logger) logger.error("INIT", "Erreur lors du chargement du composant DigitLED3D:", digitComponent.errorString());
        } else {
            if (logger) logger.debug("INIT", "Statut du composant DigitLED3D:", digitComponent.status);
        }
    }

    // Fonction pour mettre à jour l'affichage
    function updateDisplay() {
        // Vérifier que les digits existent
        if (!digits || digits.length === 0) {
            if (logger) logger.error("INIT", "Aucun digit n'a été créé");
            return;
        }

        let val = Math.abs(value);

        // Limiter la valeur au nombre maximum pouvant être affiché
        let maxValue = Math.pow(10, digitCount) - 1;
        if (val > maxValue) val = maxValue;

        // Mettre à jour chaque chiffre
        for (let i = 0; i < digitCount && i < digits.length; i++) {
            let digitValue = Math.floor(val / Math.pow(10, i)) % 10;

            // Vérifier que le digit existe avant d'y accéder
            if (digits[digitCount - 1 - i]) {
                digits[digitCount - 1 - i].value = digitValue;
            } else {
                if (logger) logger.error("INIT", "Le digit", digitCount - 1 - i, "n'existe pas");
            }
        }
    }

    // Fonction pour définir une valeur spécifique
    function setDigitValue(index, value) {
        if (index >= 0 && index < digits.length) {
            digits[index].value = value;
        } else {
            if (logger) logger.error("INIT", "Le digit", digitCount - 1 - index, "n'existe pas");
        }
    }

    // Observer les changements de valeur
    onValueChanged: {
        updateDisplay();
    }
}
