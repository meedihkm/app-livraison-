#!/bin/bash
# Script de build APK pour AWID Mobile

set -e

echo "════════════════════════════════════════════════════════════"
echo "  🚚 BUILD APK - AWID Mobile v3.0"
echo "════════════════════════════════════════════════════════════"

# Vérifier Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter n'est pas installé ou pas dans le PATH"
    exit 1
fi

echo "✅ Flutter version: $(flutter --version | head -1)"

# Nettoyer le projet
echo ""
echo "🧹 Nettoyage du projet..."
flutter clean

# Récupérer les dépendances
echo ""
echo "📦 Récupération des dépendances..."
flutter pub get

# Build APK Release
echo ""
echo "🔨 Construction de l'APK Release..."
flutter build apk --release \
    --target-platform android-arm64 \
    --dart-define=API_URL=http://62.171.130.92:3500/api/v1

# Vérifier le résultat
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ BUILD RÉUSSI !"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "📱 APK généré:"
    echo "   build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "📊 Taille: $(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
    echo ""
    echo "🔧 Informations:"
    echo "   - Version: $(grep 'version:' pubspec.yaml | head -1)"
    echo "   - API URL: http://62.171.130.92:3500/api/v1"
    echo ""
    echo "📲 Installation:"
    echo "   adb install build/app/outputs/flutter-apk/app-release.apk"
    echo ""
else
    echo "❌ Échec de la construction de l'APK"
    exit 1
fi
