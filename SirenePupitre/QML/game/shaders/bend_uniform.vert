VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Récupérer la position du vertex en espace local
    vec3 pos = VERTEX;
    
    // Oscillation temporelle
    float timeValue = time * 0.001;
    
    // Bend uniforme : le cube se courbe comme une banane
    // Tous les vertices suivent la même courbe, pas de séparation
    float bendAngle = sin(timeValue * 2.0) * 0.2; // Angle de courbure
    
    // Appliquer une courbure progressive basée sur Y
    // C'est comme si le cube était flexible et se pliait
    float bendRadius = 10.0; // Rayon de courbure (plus grand = courbure plus douce)
    float normalizedY = pos.y / bendRadius;
    
    // Rotation progressive autour d'un axe
    float angle = normalizedY * bendAngle;
    float cosA = cos(angle);
    float sinA = sin(angle);
    
    // Appliquer la rotation sur l'axe X-Y
    float newX = pos.x * cosA - pos.y * sinA;
    float newY = pos.x * sinA + pos.y * cosA;
    
    pos.x = newX + pos.y * bendAngle * 0.5; // Déplacement latéral progressif
    
    // Passer la position modifiée
    VERTEX = pos;
    
    vNormal = NORMAL;
    vPosition = pos;
}

