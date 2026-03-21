import QtQuick 2.15

Item {
    id: root

    // Dernière valeur brute envoyée par le protocole (0–127), -1 = non initialisé
    property int lastValue: -1
    // Durée pour considérer un appui long (en ms)
    property int longPressDurationMs: 1000

    // Signaux normalisés pour la navigation
    signal step(int delta)         // delta peut être ±1, ±N selon la vitesse / wrap
    signal clicked()               // appui court
    signal longPressed()           // appui long
    signal encoderPressedChanged(bool down)

    // Timer pour distinguer clic court / appui long
    Timer {
        id: longPressTimer
        interval: root.longPressDurationMs
        repeat: false
        onTriggered: {
            // Vérifier à nouveau que le bouton est toujours pressé (protection contre messages asynchrones)
            if (root._pressed && !root._longPressEmitted) {
                console.log("[EncoderController] Long press timer triggered, emitting longPressed()")
                root._longPressEmitted = true
                root.longPressed()
            } else {
                console.log("[EncoderController] Long press timer triggered but button already released or longPress already emitted")
            }
        }
    }

    // État courant du poussoir (interne)
    property bool _pressed: false
    property bool _longPressEmitted: false  // Flag pour éviter d'émettre clicked() après un long press
    property int _lastPressedValue: -1  // Dernière valeur de pressed reçue pour détecter les changements

    // Fonction appelée avec l'objet "controllers" des messages binaires 0x06 (value) et 0x07 (push)
    // Structure: { encoder: { value?: 0-127, pressed?: bool } }
    // Les messages sont séparés : 0x06 pour value seul, 0x07 pour pressed seul
    function updateFromControllers(controllers) {
        if (!controllers || !controllers.encoder)
            return

        var value = controllers.encoder.value
        // pressed peut être un booléen ou un nombre (0 = relâché, >0 = pressé)
        // Si pressed n'est pas défini, on garde l'état précédent
        var pressedValue = controllers.encoder.pressed
        var isPressed = (pressedValue !== undefined) ? (pressedValue > 0 || pressedValue === true) : root._pressed
        
        // Détecter les changements de pressed même si le timer est en cours
        // (pour gérer le cas où PureData met du temps à envoyer pressed: false)
        // Mais seulement si pressed est présent dans ce message
        if (pressedValue !== undefined && root._pressed && longPressTimer.running && !isPressed) {
            // Le bouton vient d'être relâché alors que le timer était en cours → clic court
            console.log("[EncoderController] Early release detected while timer running - emitting clicked()")
            longPressTimer.stop()
            root._pressed = false
            root._longPressEmitted = false
            root.encoderPressedChanged(false)
            root.clicked()
            root._lastPressedValue = pressedValue
            return  // Ne pas continuer le traitement pour éviter les doubles événements
        }
        
        // Mettre à jour _lastPressedValue seulement si pressed est présent
        if (pressedValue !== undefined) {
            root._lastPressedValue = pressedValue
        }

        // --- 1) Calcul du delta de rotation (0–127 avec wrap autour de 64) ---
        // Traiter uniquement si value est présent dans ce message
        if (value !== undefined && value >= 0 && value <= 127) {
            if (root.lastValue < 0) {
                // Première valeur : juste initialiser la référence
                root.lastValue = value
            } else {
                var rawDelta = value - root.lastValue

                // Gestion du wrap 0/127 : si on dépasse la moitié de la plage, on considère que ça a tourné dans l'autre sens
                if (rawDelta > 64)
                    rawDelta -= 128
                else if (rawDelta < -64)
                    rawDelta += 128

                if (rawDelta !== 0) {
                    console.log("[EncoderController] step delta:", rawDelta, "value:", value, "lastValue:", root.lastValue)
                    root.step(rawDelta)
                }

                root.lastValue = value
            }
        }

        // --- 2) Gestion du poussoir (clic / appui long) ---
        // Traiter uniquement si pressed est présent dans ce message
        if (pressedValue !== undefined) {
            if (isPressed && !root._pressed) {
                // Transition relâché → pressé
                console.log("[EncoderController] Pressed detected (value:", controllers.encoder.pressed, "isPressed:", isPressed, "): starting longPressTimer (", root.longPressDurationMs, "ms)")
                root._pressed = true
                root._longPressEmitted = false  // Reset le flag au début de l'appui
                root.encoderPressedChanged(true)
                longPressTimer.restart()
            } else if (!isPressed && root._pressed) {
            // Transition pressé → relâché
            var timerWasRunning = longPressTimer.running
            console.log("[EncoderController] Released detected (value:", controllers.encoder.pressed, "isPressed:", isPressed, "): timerWasRunning:", timerWasRunning, "longPressEmitted:", root._longPressEmitted)
            
            // Si le timer n'était pas en cours, c'est probablement un état incohérent
            // (par exemple _pressed était resté à true d'un appui précédent)
            // On réinitialise silencieusement sans émettre de signal
            if (!timerWasRunning && !root._longPressEmitted) {
                console.log("[EncoderController] State inconsistent (_pressed=true but timer not running), resetting silently")
                root._pressed = false
                root._longPressEmitted = false
                root.encoderPressedChanged(false)
                return
            }
            
            // Timer était en cours → c'est un vrai relâchement après un appui valide
            longPressTimer.stop()
            
            // Réinitialiser le flag AVANT de vérifier si on doit émettre clicked()
            var wasLongPress = root._longPressEmitted
            root._longPressEmitted = false
            
            root._pressed = false
            root.encoderPressedChanged(false)

            // Si le timer était encore en cours ET qu'on n'a pas déjà émis longPressed → clic court
            if (timerWasRunning && !wasLongPress) {
                console.log("[EncoderController] Emitting clicked() - short press detected")
                root.clicked()
            } else if (wasLongPress) {
                console.log("[EncoderController] Long press was already emitted, not emitting clicked()")
            }
            } else if (!isPressed && !root._pressed) {
                // État cohérent : relâché et on était déjà relâché
                // Réinitialiser le flag au cas où il serait resté à true d'un état précédent
                if (root._longPressEmitted) {
                    console.log("[EncoderController] Resetting _longPressEmitted flag (state cleanup)")
                    root._longPressEmitted = false
                }
            }
        }
    }
}

