#!/bin/bash
# Script de monitoring complet pour l'app AWID
# Usage: ./scripts/monitor_all.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Démarrage du monitoring AWID...${NC}"

# Créer le dossier logs
mkdir -p logs
DATE=$(date +%Y%m%d_%H%M%S)

# Vérifier que le téléphone est connecté
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}❌ Aucun appareil Android détecté!${NC}"
    echo "Connecte ton téléphone en USB et active le débogage USB"
    exit 1
fi

echo -e "${GREEN}✅ Appareil Android détecté${NC}"

# Clear les anciens logs Flutter
adb logcat -c

# Démarrer le monitoring Flutter
echo -e "${BLUE}📱 Monitoring Flutter démarré...${NC}"
adb logcat | grep -E "flutter|Error|Exception|Failed|❌|✅|🔍|📦|🚚" --line-buffered | while IFS= read -r line; do
    echo -e "${YELLOW}[FLUTTER]${NC} $line"
done > logs/flutter_$DATE.log 2>&1 &
FLUTTER_PID=$!

# Afficher les logs Flutter en temps réel dans le terminal
tail -f logs/flutter_$DATE.log &
TAIL_PID=$!

echo ""
echo -e "${GREEN}✅ Monitoring actif!${NC}"
echo -e "${BLUE}📱 Flutter logs:${NC} logs/flutter_$DATE.log"
echo ""
echo -e "${YELLOW}💡 Utilise l'app maintenant. Les logs s'affichent ci-dessous:${NC}"
echo -e "${YELLOW}💡 Appuie sur Ctrl+C pour arrêter${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Attendre Ctrl+C
trap "echo -e '\n${RED}🛑 Arrêt du monitoring...${NC}'; kill $FLUTTER_PID $TAIL_PID 2>/dev/null; exit 0" INT TERM

# Garder le script actif
wait
