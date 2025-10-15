VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // Position Y normalisée du vertex (-0.5 à +0.5)
    float normalizedY = pos.y;
    
    // ===== QUEUE DE RELEASE (partie haute du mesh) =====
    // releaseRatio = portion du mesh total dédiée à la queue
    // Ex: releaseRatio = 0.286 → les 28.6% supérieurs sont effilés
    
    float releaseTaper = 1.0;  // Par défaut, largeur normale
    
    // Sécurité : appliquer uniquement si releaseRatio est valide
    if (releaseRatio > 0.01 && releaseRatio < 0.99) {
        float releaseStart = 0.5 - releaseRatio;  // Y où commence la queue
        
        if (normalizedY > releaseStart) {
            // On est dans la zone de release (queue)
            // Calculer la progression de 0 (bas de la queue) à 1 (pointe)
            float releaseProgress = (normalizedY - releaseStart) / releaseRatio;
            releaseProgress = clamp(releaseProgress, 0.0, 1.0);  // Sécurité
            
            // Réduire la largeur de 100% à 5% (éviter 0 pour le rendu)
            releaseTaper = 1.0 - (releaseProgress * 0.95);
        }
    }
    
    // Appliquer le rétrécissement sur X et Z
    pos.x *= releaseTaper;
    pos.z *= releaseTaper;
    
    // ===== TREMOLO : variation de la largeur (amplitude) =====
    float tremoloAmount = sin(timeValue * tremoloSpeed) * tremoloIntensity;
    float widthScale = 1.0 + tremoloAmount;
    
    // Appliquer sur X et Z (largeur et profondeur)
    pos.x *= widthScale;
    pos.z *= widthScale;
    
    // ===== VIBRATO : ondulation de la hauteur (pitch) =====
    float vibratoWave = sin(timeValue * vibratoSpeed) * vibratoIntensity;
    
    // Appliquer une ondulation progressive basée sur Y
    pos.x += vibratoWave * (pos.y * 0.1);
    pos.z += cos(timeValue * vibratoSpeed) * vibratoIntensity * (pos.y * 0.08);
    
    // Passer la position modifiée
    VERTEX = pos;
    
    vNormal = NORMAL;
    vPosition = pos;
}

