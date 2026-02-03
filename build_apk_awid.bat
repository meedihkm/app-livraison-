@echo off
chcp 65001 >nul
echo ════════════════════════════════════════════════════════════
echo   🚚 BUILD APK - AWID Mobile v3.0
echo ════════════════════════════════════════════════════════════
echo.

:: Configuration des chemins
set FLUTTER_ROOT=D:\app-sauvegarde\app-livraison\flutter_windows_3.38.5-stable\flutter
set FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat
set PROJECT_DIR=D:\app-sauvegarde\app-livraison\mobile

echo 📍 Flutter: %FLUTTER_ROOT%
echo 📍 Projet: %PROJECT_DIR%
echo.

:: Vérifier Flutter existe
if not exist "%FLUTTER%" (
    echo ❌ Flutter non trouvé: %FLUTTER%
    exit /b 1
)

echo ✅ Flutter trouvé
echo.

:: Aller dans le projet
cd /d "%PROJECT_DIR%"
if errorlevel 1 (
    echo ❌ Impossible d'accéder au projet: %PROJECT_DIR%
    exit /b 1
)

echo 📂 Répertoire: %CD%
echo.

:: Étape 1: Nettoyer
echo 🧹 Étape 1/5: Nettoyage du projet...
"%FLUTTER%" clean
if errorlevel 1 (
    echo ⚠️  Warning lors du clean, on continue...
)
echo.

:: Étape 2: Get dependencies
echo 📦 Étape 2/5: Récupération des dépendances...
"%FLUTTER%" pub get
if errorlevel 1 (
    echo ❌ Échec de pub get
    exit /b 1
)
echo ✅ Dépendances OK
echo.

:: Étape 3: Vérifier
echo 🔍 Étape 3/5: Vérification...
"%FLUTTER%" doctor -v
if errorlevel 1 (
    echo ⚠️  flutter doctor a des warnings, on continue quand même...
)
echo.

:: Étape 4: Build APK
echo 🔨 Étape 4/5: Construction de l'APK Release...
echo    Cela peut prendre plusieurs minutes...
echo.
"%FLUTTER%" build apk --release --target-platform android-arm64
if errorlevel 1 (
    echo ❌ Échec du build
    exit /b 1
)
echo.

:: Étape 5: Vérifier et copier
echo 📱 Étape 5/5: Vérification...
set APK_PATH=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk

if exist "%APK_PATH%" (
    echo.
    echo ════════════════════════════════════════════════════════════
    echo   ✅ BUILD RÉUSSI !
    echo ════════════════════════════════════════════════════════════
    echo.
    echo 📱 APK généré:
    echo    %APK_PATH%
    echo.
    for %%F in ("%APK_PATH%") do (
        echo 📊 Taille: %%~zF bytes
echo    Taille: ~%%~zF bytes
    )
    echo.
    echo 🔧 Informations:
    echo    - API URL: http://62.171.130.92:3500/api/v1
    echo    - Version: (voir pubspec.yaml)
    echo.
    echo 📲 Installation:
    echo    adb install "%APK_PATH%"
    echo.
    echo 💡 Copiez ce fichier APK sur votre téléphone pour l'installer
    echo.
    :: Copier dans un dossier facile d'accès
    set OUTPUT_DIR=%PROJECT_DIR%\..\apk_output
    if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
    copy "%APK_PATH%" "%OUTPUT_DIR%\awid-v3-release.apk" >nul
    echo 📁 Copie créée: %OUTPUT_DIR%\awid-v3-release.apk
) else (
    echo ❌ APK non trouvé: %APK_PATH%
    exit /b 1
)

echo.
echo ════════════════════════════════════════════════════════════
pause
