# Script de configuration des variables d'environnement pour Flutter

Write-Host "Configuration des variables d'environnement Flutter..." -ForegroundColor Green

# Chemins
$flutterPath = "D:\app-sauvegarde\app-livraison\flutter_windows_3.38.5-stable\flutter\bin"
$androidSdkPath = "$env:LOCALAPPDATA\Android\Sdk"

# Vérifier si Flutter existe
if (Test-Path $flutterPath) {
    Write-Host "✅ Flutter trouvé: $flutterPath" -ForegroundColor Green
    
    # Ajouter au PATH utilisateur
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$flutterPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterPath", "User")
        Write-Host "✅ Flutter ajouté au PATH" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Flutter déjà dans le PATH" -ForegroundColor Yellow
    }
    
    # Définir FLUTTER_ROOT
    [Environment]::SetEnvironmentVariable("FLUTTER_ROOT", "D:\app-sauvegarde\app-livraison\flutter_windows_3.38.5-stable\flutter", "User")
    Write-Host "✅ FLUTTER_ROOT défini" -ForegroundColor Green
    
} else {
    Write-Host "❌ Flutter non trouvé à: $flutterPath" -ForegroundColor Red
}

# Vérifier Android SDK
if (Test-Path $androidSdkPath) {
    Write-Host "✅ Android SDK trouvé: $androidSdkPath" -ForegroundColor Green
    
    [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidSdkPath, "User")
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "User")
    Write-Host "✅ ANDROID_SDK_ROOT défini" -ForegroundColor Green
    
    # Ajouter platform-tools au PATH
    $platformTools = "$androidSdkPath\platform-tools"
    if (Test-Path $platformTools) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$platformTools*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$platformTools", "User")
            Write-Host "✅ platform-tools ajouté au PATH" -ForegroundColor Green
        }
    }
} else {
    Write-Host "⚠️ Android SDK non trouvé à: $androidSdkPath" -ForegroundColor Yellow
    Write-Host "   Installez Android Studio ou le SDK Android" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔄 Redémarrez votre terminal/PowerShell pour appliquer les changements" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vérification avec: flutter doctor" -ForegroundColor Cyan
