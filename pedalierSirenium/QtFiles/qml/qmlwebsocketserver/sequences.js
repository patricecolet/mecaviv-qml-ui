// Les séquences de la pédale A, entre le format de PD et celui de l'éditeur.
//
// PD sert la bibliothèque <racine>/sequences/*.txt telle quelle (device SEQUENCES,
// voir sequences-io.pd) : un pas y est daté en ticks (480 la noire), la longueur
// en ticks aussi. L'éditeur, lui, compte en numéros de pas (division × vitesse
// pas par noire) et en blocs d'une mesure. Ce fichier est le seul endroit qui
// connaît les deux ; il est partagé par LiveState et le harnais de simulation.

.pragma library

function ticksParPas(division, vitesse) {
    return 480 / (Math.max(1, division) * Math.max(1, vitesse));
}

// SEQUENCES.sequences[] de PD → [{ index, division, vitesse, blocs, pas:[{ n, ... }] }]
// trié par index. Une séquence sans pas n'a pas de clé `pas` dans le JSON.
function depuisPd(liste) {
    if (!Array.isArray(liste)) return [];
    var out = [];
    for (var i = 0; i < liste.length; i++) {
        var s = liste[i];
        var tpp = ticksParPas(s.division, s.vitesse);
        var pas = [];
        var src = Array.isArray(s.pas) ? s.pas : [];
        for (var k = 0; k < src.length; k++) {
            var p = src[k];
            pas.push({ n: Math.round(p.tick / tpp), velocite: p.velocite, hauteur: p.hauteur,
                       gate: p.gate, attack: p.attack, release: p.release });
        }
        pas.sort(function (a, b) { return a.n - b.n; });
        out.push({ index: s.index, division: s.division, vitesse: s.vitesse,
                   blocs: Math.max(1, Math.round((s.length || 1920) / 1920)), pas: pas });
    }
    out.sort(function (a, b) { return a.index - b.index; });
    return out;
}

// Une séquence de l'éditeur → les lignes du fichier, sans la ligne 0 :
// [tick, vélocité, hauteur, gate, attack, release] par pas.
function versLignes(seq) {
    var tpp = ticksParPas(seq.division, seq.vitesse);
    var lignes = [];
    for (var i = 0; i < seq.pas.length; i++) {
        var p = seq.pas[i];
        lignes.push([Math.round(p.n * tpp), p.velocite, p.hauteur, p.gate, p.attack, p.release]);
    }
    return lignes;
}
