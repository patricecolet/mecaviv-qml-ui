// Utilitaires microtonaux (cents, pitch bend 14 bits centre 8192)

function pitchBend14ToSignedNorm(value14) {
    var v = Math.max(0, Math.min(16383, value14 | 0))
    return (v - 8192) / 8192
}

/** ±1.0 norm → cents par rapport au centre (±200 ct typique pour ±1 demi-ton selon réglage DAW ; ici ±100 ct par unité MIDI standard = 2 demi-tons sur 8192) */
function pitchBendToCents(value14, semitoneRange) {
    var range = (typeof semitoneRange === "number" && semitoneRange > 0) ? semitoneRange : 2
    return pitchBend14ToSignedNorm(value14) * (range * 100)
}

function centsBetweenFloatMidi(a, b) {
    return (b - a) * 100
}
