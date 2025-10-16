VARYING vec3 vPosition;
VARYING vec3 vNormal;
VARYING vec3 vWorldPosition;

void MAIN()
{
    // Clipping magique - tout ce qui passe sous targetY disparaît
    if (vWorldPosition.y < clipY) {
        discard;  // Pixel invisible
    }
    
    // Utiliser le matériau de base
    BASE_COLOR = vec4(baseColor.rgb, 1.0);
    METALNESS = metalness;
    ROUGHNESS = roughness;
}

