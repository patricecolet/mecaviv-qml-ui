VARYING vec2 texCoord;

void MAIN() {
    vec2 center = vec2(0.5, 0.5);
    vec2 pos = texCoord - center;
    float radius = length(pos);
    
    // Cercle simple sans trou
    if (radius > 0.4) {
        FRAGCOLOR = vec4(uInactiveColor.rgb, 1.0);  // Bordure grise
    } else {
        // Test simple : moitié gauche/droite
        if (pos.x < 0.0) {
            FRAGCOLOR = vec4(uActiveColor.rgb, 1.0);  // Partie active
        } else {
            FRAGCOLOR = vec4(uInactiveColor.rgb, 1.0);  // Partie inactive
        }
    }
} 