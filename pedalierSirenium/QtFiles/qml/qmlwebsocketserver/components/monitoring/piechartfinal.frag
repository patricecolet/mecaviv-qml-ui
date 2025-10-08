void MAIN() {
    vec2 center = vec2(0.5, 0.5);
    vec2 pos = UV0 - center;
    float radius = length(pos);
    
    // Anneau plus fin : rayon externe 0.45, rayon interne 0.25
    if (radius > 0.45 || radius < 0.25) {
        BASE_COLOR = vec4(0.0, 0.0, 0.0, 0.0);  // Transparent
        return;
    }
    
    // Calculer l'angle pour pie chart
    float angle = atan(pos.y, pos.x);
    
    // Convertir pour commencer en haut (12h) et aller dans le sens horaire
    angle = 1.5708 - angle;  // 1.5708 = π/2
    
    // Normaliser de 0 à 2π
    if (angle < 0.0) angle += 6.28318;  // 6.28318 = 2π
    if (angle > 6.28318) angle -= 6.28318;
    
    // Convertir en progression 0-1
    float progress = angle / 6.28318;
    
    // Mode enregistrement : tout rouge
    if (uIsRecording) {
        BASE_COLOR = vec4(1.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Pie chart normal
    if (progress <= uProgress) {
        BASE_COLOR = vec4(uActiveColor.rgb, 1.0);  // Partie remplie
    } else {
        BASE_COLOR = vec4(uInactiveColor.rgb, 1.0);  // Partie vide
    }
} 