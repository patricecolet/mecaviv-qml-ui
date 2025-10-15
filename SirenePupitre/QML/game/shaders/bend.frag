VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Utiliser le matériau de base
    // On laisse Qt Quick3D gérer le rendu avec les propriétés du matériau
    BASE_COLOR = vec4(baseColor.rgb, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

