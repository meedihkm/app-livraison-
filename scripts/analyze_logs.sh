#!/bin/bash
# Script d'analyse des logs
# Usage: ./scripts/analyze_logs.sh [fichier_log]

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$1" ]; then
    # Analyser le dernier fichier de log
    LOG_FILE=$(ls -t logs/flutter_*.log 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo -e "${RED}❌ Aucun fichier de log trouvé!${NC}"
        echo "Lance d'abord: ./scripts/monitor_all.sh"
        exit 1
    fi
else
    LOG_FILE=$1
fi

echo -e "${BLUE}📊 Analyse du fichier: $LOG_FILE${NC}"
echo ""

# Statistiques
TOTAL_LINES=$(wc -l < "$LOG_FILE")
ERRORS=$(grep -c "Error\|Exception\|Failed\|❌" "$LOG_FILE" 2>/dev/null || echo "0")
SUCCESS=$(grep -c "✅\|success" "$LOG_FILE" 2>/dev/null || echo "0")
API_CALLS=$(grep -c "🔍\|📦\|🚚" "$LOG_FILE" 2>/dev/null || echo "0")

echo -e "${GREEN}📈 Statistiques:${NC}"
echo "  Total de lignes: $TOTAL_LINES"
echo "  Erreurs: $ERRORS"
echo "  Succès: $SUCCESS"
echo "  Appels API: $API_CALLS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Erreurs trouvées:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -E "Error|Exception|Failed|❌" "$LOG_FILE" | head -20
    echo ""
    
    if [ $ERRORS -gt 20 ]; then
        echo -e "${YELLOW}... et $(($ERRORS - 20)) autres erreurs${NC}"
        echo ""
    fi
fi

# Rechercher des patterns spécifiques
echo -e "${BLUE}🔍 Patterns détectés:${NC}"

TYPE_ERRORS=$(grep -c "type.*is not a subtype" "$LOG_FILE" 2>/dev/null || echo "0")
if [ $TYPE_ERRORS -gt 0 ]; then
    echo -e "  ${RED}⚠️  Erreurs de type: $TYPE_ERRORS${NC}"
    grep "type.*is not a subtype" "$LOG_FILE" | head -3
fi

NULL_ERRORS=$(grep -c "null.*Exception\|NoSuchMethodError" "$LOG_FILE" 2>/dev/null || echo "0")
if [ $NULL_ERRORS -gt 0 ]; then
    echo -e "  ${RED}⚠️  Erreurs null: $NULL_ERRORS${NC}"
fi

API_ERRORS=$(grep -c "401\|403\|404\|500" "$LOG_FILE" 2>/dev/null || echo "0")
if [ $API_ERRORS -gt 0 ]; then
    echo -e "  ${RED}⚠️  Erreurs API: $API_ERRORS${NC}"
fi

echo ""
echo -e "${GREEN}✅ Analyse terminée!${NC}"
echo -e "${YELLOW}💡 Pour voir le fichier complet: cat $LOG_FILE${NC}"
