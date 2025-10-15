VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // ===== 1. TRANSFORMER CYLINDRE EN CUBE =====
    // Le cylindre a des vertices en cercle, on les transforme en carré
    float angle = atan(pos.z, pos.x);
    float radius = length(vec2(pos.x, pos.z));
    
    // Créer une forme carrée au lieu de ronde
    // En divisant par max(abs(cos), abs(sin)), on obtient un carré
    float squareRadius = radius / max(abs(cos(angle)), abs(sin(angle)));
    pos.x = squareRadius * cos(angle);
    pos.z = squareRadius * sin(angle);
    
    // ===== 2. QUEUE DE RELEASE (tapering) =====
    // Position Y normalisée (-0.5 à +0.5)
    float normalizedY = pos.y;
    
    float releaseTaper = 1.0;  // Par défaut, largeur normale
    
    // Sécurité : appliquer uniquement si releaseRatio est valide
    if (releaseRatio > 0.01 && releaseRatio < 0.99) {
        float releaseStart = 0.5 - releaseRatio;  // Y où commence la queue
        
        if (normalizedY > releaseStart) {
            // On est dans la zone de release (queue)
            // Calculer la progression de 0 (bas de la queue) à 1 (pointe)
            float releaseProgress = (normalizedY - releaseStart) / releaseRatio;
            releaseProgress = clamp(releaseProgress, 0.0, 1.0);
            
            // Réduire la largeur de 100% à 5% (éviter 0 pour le rendu)
            releaseTaper = 1.0 - (releaseProgress * 0.95);
        }
    }
    
    // Appliquer le tapering sur X et Z
    pos.x *= releaseTaper;
    pos.z *= releaseTaper;
    
    // ===== 3. TREMOLO : variation de la largeur =====
    float tremoloAmount = sin(timeValue * tremoloSpeed) * tremoloIntensity;
    float widthScale = 1.0 + tremoloAmount;
    
    pos.x *= widthScale;
    pos.z *= widthScale;
    
    // ===== 4. VIBRATO : ondulation latérale =====
    float vibratoWave = sin(timeValue * vibratoSpeed) * vibratoIntensity;
    
    pos.x += vibratoWave * (pos.y * 0.1);
    pos.z += cos(timeValue * vibratoSpeed) * vibratoIntensity * (pos.y * 0.08);
    
    // Passer la position modifiée
    VERTEX = pos;
    
    vNormal = NORMAL;
    vPosition = pos;
}

