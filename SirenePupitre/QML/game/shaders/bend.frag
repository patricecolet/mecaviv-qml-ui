VARYING vec3 vPosition;
VARYING vec3 vNormal;
VARYING vec3 vWorldPosition;

void MAIN()
{
    // Clipping bas - tout ce qui passe sous targetY disparaît (espace monde)
    if (vWorldPosition.y < clipY) {
        discard;  // Pixel invisible
    }
    
    // Clipping haut - pour troncature monophonique (espace local, suit la note)
    // Utilise vPosition.y (coordonnées locales) pour que le clip suive la note qui descend
    if (vPosition.y > clipYTopLocal) {
        discard;  // Pixel invisible
    }
    
    // Utiliser le matériau de base
    BASE_COLOR = vec4(baseColor.rgb, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

