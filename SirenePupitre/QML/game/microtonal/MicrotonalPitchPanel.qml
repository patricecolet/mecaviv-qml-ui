import QtQuick
import QtQuick.Layouts
import "."

/**
 * Panneau de référence de hauteur microtonal.
 * Regroupe le ruban accordeur et tous les indicateurs qui lui sont liés :
 *   - Δ cents (écart courant)
 *   - Ouverture du volet
 *   - Vitesse de glissando
 *   + emplacement prévu pour de futurs éléments (fréquence cible, harmonique…)
 *
 * Usage : injecter viewModel (MicrotonalViewModel) ou piloter les propriétés manuellement.
 */
Item {
    id: root

    // ── Données (passées soit par viewModel, soit propriété par propriété) ──
    property var viewModel: null

    property real targetCents:  viewModel ? viewModel.targetCents  : 0
    property real currentCents: viewModel ? viewModel.currentCents : 0
    property real rangeCents:   100
    property real voletOpen:    viewModel ? viewModel.voletOpen    : 0
    property string glissSpeedLabel: viewModel ? viewModel.glissSpeedLabel : ""

    // ── Taille implicite ─────────────────────────────────────────────────
    implicitWidth:  420
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        spacing: 8

        // ── Ruban accordeur ──────────────────────────────────────────────
        MicrotonalPitchRibbon {
            Layout.alignment:     Qt.AlignHCenter
            Layout.preferredWidth: Math.min(Math.max(root.width, 280), 420)
            Layout.maximumWidth:  420
            targetCents:  root.targetCents
            currentCents: root.currentCents
            rangeCents:   root.rangeCents
        }

        // ── Ligne d'indicateurs instantanés, centrée sous le ruban ─────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            MicrotonalCentsReadout {
                cents: root.currentCents
            }

            MicrotonalVoletIndicator {
                anchors.verticalCenter: parent.verticalCenter
                openAmount: root.voletOpen
            }

            MicrotonalGlissSpeedLabel {
                anchors.verticalCenter: parent.verticalCenter
                speedText: root.glissSpeedLabel
            }

            // Futurs éléments à ajouter ici (fréquence cible, harmonique…)
        }

        // ── Ligne(s) future(s) ───────────────────────────────────────────
        // Exemples à venir : fréquence cible, numéro d'harmonique, etc.
        // Ajouter ici de nouveaux items Layout sans modifier MicrotonalDirectedView.
    }
}
