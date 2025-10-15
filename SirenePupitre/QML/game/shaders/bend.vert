VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle (utilise une propriété time passée depuis QML)
    float timeValue = time * 0.001; // Convertir ms en secondes
    
    // Effet simple et doux : légère ondulation globale
    // On applique la même transformation à tous les vertices de manière cohérente
    float wave = sin(timeValue * 2.0) * 0.02; // Très subtil
    
    // Balancement latéral (X) - uniforme pour tout le cube
    pos.x += wave;
    
    // Légère oscillation sur Z avec phase différente
    float waveZ = cos(timeValue * 2.5) * 0.015;
    pos.z += waveZ;
    
    // Passer la position modifiée
    VERTEX = pos;
    
    // Garder la normale originale pour l'éclairage
    vNormal = NORMAL;
    vPosition = pos;
}

