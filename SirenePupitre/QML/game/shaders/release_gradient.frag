VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Position Y normalisée du fragment
    float normalizedY = vPosition.y;
    
    // Assombrir progressivement dans la zone de release (queue)
    float brightness = 1.0;
    
    // Sécurité : vérifier que releaseRatio est valide
    if (releaseRatio > 0.0 && releaseRatio < 1.0) {
        float releaseStart = 0.5 - releaseRatio;
        
        if (normalizedY > releaseStart) {
            // Dans la queue : assombrir de 100% (bas) à 60% (pointe)
            float releaseProgress = (normalizedY - releaseStart) / releaseRatio;
            brightness = mix(1.0, 0.6, releaseProgress);
        }
    }
    
    // Appliquer la couleur avec assombrissement
    BASE_COLOR = vec4(baseColor.rgb * brightness, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

