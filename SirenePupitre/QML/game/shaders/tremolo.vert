VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // TREMOLO : variation de la largeur (amplitude)
    // Les cubes pulsent en largeur/profondeur
    float tremoloAmount = sin(timeValue * tremoloSpeed) * tremoloIntensity;
    float widthScale = 1.0 + tremoloAmount;
    
    // Appliquer sur X et Z (largeur et profondeur)
    pos.x *= widthScale;
    pos.z *= widthScale;
    
    // Passer la position modifiée
    VERTEX = pos;
    
    vNormal = NORMAL;
    vPosition = pos;
}

