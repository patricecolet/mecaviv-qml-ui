# Script PowerShell pour configurer les variables d'environnement Qt (Windows)
# Usage: .\scripts\setup-env.ps1

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🔧 Configuration des variables Qt pour Windows" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Chemins Qt par défaut pour Windows
$DefaultQtDir = "C:\Qt\6.10.0\msvc2019_64"
$DefaultQtWasmDir = "C:\Qt\6.10.0\wasm_singlethread"

# Fonction pour demander un chemin
function Ask-Path {
    param(
        [string]$VarName,
        [string]$DefaultPath,
        [string]$Description
    )
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host $Description -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host ""
    
    # Vérifier si le chemin par défaut existe
    if (Test-Path $DefaultPath) {
        Write-Host "✅ Chemin trouvé: $DefaultPath" -ForegroundColor Green
        $response = Read-Host "Utiliser ce chemin? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($response) -or $response -eq "Y" -or $response -eq "y") {
            return $DefaultPath
        }
    } else {
        Write-Host "❌ Chemin par défaut introuvable: $DefaultPath" -ForegroundColor Red
    }
    
    # Demander un chemin personnalisé
    Write-Host ""
    Write-Host "Entrez le chemin de votre installation Qt:"
    $customPath = Read-Host "Chemin ($DefaultPath)"
    if ([string]::IsNullOrWhiteSpace($customPath)) {
        $customPath = $DefaultPath
    }
    
    # Vérifier que le chemin existe
    if (Test-Path $customPath) {
        Write-Host "✅ Chemin valide" -ForegroundColor Green
        return $customPath
    } else {
        Write-Host "⚠️  Attention: Ce chemin n'existe pas sur votre système" -ForegroundColor Yellow
        $force = Read-Host "Utiliser quand même? [y/N]"
        if ($force -eq "y" -or $force -eq "Y") {
            return $customPath
        } else {
            return $null
        }
    }
}

# Demander QT_DIR
Write-Host ""
$QtDir = Ask-Path -VarName "QT_DIR" -DefaultPath $DefaultQtDir -Description "Qt Desktop (pour compilation native)"

if ([string]::IsNullOrWhiteSpace($QtDir)) {
    Write-Host "❌ Configuration annulée" -ForegroundColor Red
    exit 1
}

# Demander QT_WASM_DIR
Write-Host ""
$QtWasmDir = Ask-Path -VarName "QT_WASM_DIR" -DefaultPath $DefaultQtWasmDir -Description "Qt WebAssembly (pour compilation web)"

if ([string]::IsNullOrWhiteSpace($QtWasmDir)) {
    Write-Host "❌ Configuration annulée" -ForegroundColor Red
    exit 1
}

# Définir les variables pour la session actuelle
$env:QT_DIR = $QtDir
$env:QT_WASM_DIR = $QtWasmDir

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "✅ Variables configurées pour cette session:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "QT_DIR=$QtDir"
Write-Host "QT_WASM_DIR=$QtWasmDir"
Write-Host ""

# Demander si on veut sauvegarder dans les variables système
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "Voulez-vous ajouter ces variables aux variables d'environnement système?" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""
Write-Host "Cela permettra de les avoir automatiquement dans tous les terminaux."
Write-Host ""
Write-Host "⚠️  Nécessite des droits administrateur" -ForegroundColor Yellow
Write-Host ""
$addToSystem = Read-Host "Ajouter aux variables système? [Y/n]"

if ([string]::IsNullOrWhiteSpace($addToSystem) -or $addToSystem -eq "Y" -or $addToSystem -eq "y") {
    try {
        # Variables utilisateur (ne nécessite pas admin)
        [System.Environment]::SetEnvironmentVariable("QT_DIR", $QtDir, "User")
        [System.Environment]::SetEnvironmentVariable("QT_WASM_DIR", $QtWasmDir, "User")
        
        Write-Host "✅ Variables ajoutées aux variables d'environnement utilisateur" -ForegroundColor Green
        Write-Host ""
        Write-Host "Les nouveaux terminaux auront ces variables automatiquement." -ForegroundColor Green
        Write-Host "Pour cette session, elles sont déjà configurées." -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de l'ajout aux variables système:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "ℹ️  Vous pouvez ajouter manuellement via:" -ForegroundColor Cyan
        Write-Host "   Panneau de configuration → Système → Paramètres système avancés" -ForegroundColor Cyan
        Write-Host "   → Variables d'environnement" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   QT_DIR = $QtDir" -ForegroundColor Cyan
        Write-Host "   QT_WASM_DIR = $QtWasmDir" -ForegroundColor Cyan
    }
} else {
    Write-Host "ℹ️  Configuration temporaire (session actuelle uniquement)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pour rendre permanent, vous pouvez:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Ajouter à votre profil PowerShell (`$PROFILE):" -ForegroundColor Cyan
    Write-Host "   `$env:QT_DIR = `"$QtDir`"" -ForegroundColor Cyan
    Write-Host "   `$env:QT_WASM_DIR = `"$QtWasmDir`"" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Ou via les variables système (GUI):" -ForegroundColor Cyan
    Write-Host "   Panneau de configuration → Système → Variables d'environnement" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "🚀 Configuration terminée !" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Vous pouvez maintenant builder le projet:" -ForegroundColor Cyan
Write-Host "  cmake --preset=default" -ForegroundColor White
Write-Host "  cmake --build build --parallel" -ForegroundColor White
Write-Host ""
Write-Host "Pour plus d'infos, voir CONFIG.md" -ForegroundColor Cyan
Write-Host ""

