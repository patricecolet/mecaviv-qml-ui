VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // VIBRATO : ondulation de la hauteur (pitch)
    // Le cube ondule latéralement de manière progressive
    float vibratoWave = sin(timeValue * vibratoSpeed) * vibratoIntensity;
    
    // Appliquer une ondulation progressive basée sur Y
    // Crée un effet de serpent/vague
    pos.x += vibratoWave * (pos.y * 0.1);
    pos.z += cos(timeValue * vibratoSpeed) * vibratoIntensity * (pos.y * 0.08);
    
    // Passer la position modifiée
    VERTEX = pos;
    
    vNormal = NORMAL;
    vPosition = pos;
}

