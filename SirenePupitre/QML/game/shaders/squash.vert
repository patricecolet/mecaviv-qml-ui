VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // Squash & Stretch : compression/étirement alterné
    // Les cubes s'écrasent et s'étirent comme des objets élastiques
    float squash = sin(timeValue * 4.0) * 0.15 + 1.0; // Oscille entre 0.85 et 1.15
    float stretch = 1.0 / squash; // Conservation du volume
    
    // Appliquer squash sur Y (hauteur) et stretch compensatoire sur X et Z
    pos.y *= squash;
    pos.x *= stretch;
    pos.z *= stretch;
    
    // Passer la position modifiée
    VERTEX = pos;
    
    // Adapter la normale à la déformation
    vNormal = NORMAL;
    vPosition = pos;
}

