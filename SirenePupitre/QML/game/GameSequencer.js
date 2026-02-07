/**
 * Utilitaire d'animation : calcul de la durée de chute pour notes et barres de mesure.
 * Utilisé par MelodicLine2D et AnticipationLine2D. Plus de chargement MIDI ni de tempo map.
 */

/**
 * Calcule la durée de chute (fallDurationMs) pour un élément (note ou barre de mesure).
 * Prend en compte le délai MIDI : la note au temps t sera jouée à currentTimeMs = t + midiDelay.
 *
 * @param {number} targetTimeMs - Temps de début de l'élément (note ou mesure)
 * @param {number} currentTimeMs - Temps actuel (ms depuis le play)
 * @param {number} midiDelay - Délai MIDI en ms (= fixedFallTime, typiquement 5000ms)
 * @returns {number} Durée de chute (ms), 0 si l'élément est déjà passé
 */
function calculateFallDurationMs(targetTimeMs, currentTimeMs, midiDelay) {
    var fallDurationMs = targetTimeMs + midiDelay - currentTimeMs;
    return fallDurationMs > 0 ? fallDurationMs : 0;
}
