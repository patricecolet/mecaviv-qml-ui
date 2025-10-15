VARYING vec3 vPosition;
VARYING vec3 vNormal;

void MAIN()
{
    // Utiliser le matériau de base
    BASE_COLOR = vec4(baseColor.rgb, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

