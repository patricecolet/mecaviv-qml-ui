.pragma library

// Per-machine remote paths, keyed by MachineType id (see src/Config/MachineType.h).
//
// Linux Maître and the Artila-based sirens, voitures and pavillons all share
// the same on-disk layout under /mnt/disk/home/guest/WorkSpaceSirenes/. Only
// the Raspberry Clic (Pi5, sirenateur user) is different.
//
// id mapping (kept in sync with MachineType.h):
//   0   Linux Maître       (Artila layout)
//   1   Raspberry Clic     (Pi5 layout)
//   2-8 S1..S7             (Artila)
//   9   Voiture A          (Artila)
//   10  Voiture B          (Artila)
//   11  Pavillon 1         (Artila)
//   12  Pavillon 2         (Artila)

var ARTILA_BASE = "/mnt/disk/home/guest/WorkSpaceSirenes/"
var PI5_BASE    = "/home/sirenateur/WorkSpaceSirenes/"

function basePathFor(machineId) {
    return machineId === 1 ? PI5_BASE : ARTILA_BASE
}

function midiPath(machineId)          { return basePathFor(machineId) + "Midi/" }
function playlistPath(machineId)      { return basePathFor(machineId) + "liste_de_lecture/" }
function derniereListePath(machineId) { return basePathFor(machineId) + "derniere_liste" }

// Rewrite an absolute Maître path so it points at the equivalent location on
// `targetMachineId`. Used when forwarding the contents of `derniere_liste`
// (which embeds an absolute path) from Maître to the Raspberry Clic — the
// Pi5 doesn't have /mnt/disk/... so we swap the base.
function rewritePathForTarget(maitrePath, targetMachineId) {
    if (targetMachineId === 1 && maitrePath.indexOf(ARTILA_BASE) === 0) {
        return PI5_BASE + maitrePath.substring(ARTILA_BASE.length)
    }
    return maitrePath
}
