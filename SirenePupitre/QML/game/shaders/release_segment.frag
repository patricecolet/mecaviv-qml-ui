VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Fragment shader spécifique pour les segments de release
    // Applique le brightness pour l'assombrissement progressif
    BASE_COLOR = vec4(baseColor.rgb * brightness, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

