# Script PowerShell pour configurer le projet avec CMake (Windows)
# Usage: .\scripts\configure.ps1 [preset]
# Presets: default, release, wasm, windows

param(
    [string]$Preset = "default"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🔧 Configuration CMake - Preset: $Preset" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que CMake est installé
$cmakeVersion = (cmake --version 2>$null | Select-String "version" | Out-String).Trim()
if (-not $cmakeVersion) {
    Write-Host "❌ CMake n'est pas installé" -ForegroundColor Red
    Write-Host "   Installation: https://cmake.org/download/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ $cmakeVersion" -ForegroundColor Green
Write-Host ""

# Vérifier les variables d'environnement Qt
if (-not $env:QT_DIR) {
    Write-Host "⚠️  Variable QT_DIR non définie" -ForegroundColor Yellow
    Write-Host "   Lancez d'abord: .\scripts\setup-env.ps1" -ForegroundColor Cyan
    Write-Host ""
    $continue = Read-Host "Continuer quand même? [y/N]"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Configuration
Write-Host "⚙️  Configuration du projet..." -ForegroundColor Cyan
try {
    cmake --preset=$Preset
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "✅ Configuration terminée !" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pour builder :" -ForegroundColor Cyan
    Write-Host "  cmake --build build" -ForegroundColor White
    Write-Host ""
    Write-Host "Ou avec le preset :" -ForegroundColor Cyan
    Write-Host "  cmake --build --preset=$Preset" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "❌ Erreur de configuration" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Vérifiez que:" -ForegroundColor Yellow
    Write-Host "  - CMake est installé et dans le PATH" -ForegroundColor White
    Write-Host "  - Qt est installé" -ForegroundColor White
    Write-Host "  - Les variables QT_DIR et QT_WASM_DIR sont définies" -ForegroundColor White
    Write-Host ""
    Write-Host "Lancez: .\scripts\setup-env.ps1 pour configurer Qt" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

