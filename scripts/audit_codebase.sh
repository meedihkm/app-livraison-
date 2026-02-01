#!/bin/bash

# 🔍 Script d'Audit Automatique - Application AWID
# Vérifie la cohérence entre Backend et Mobile

set -e

echo "🔍 AUDIT DE COHÉRENCE BACKEND ↔ MOBILE"
echo "========================================"
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
ERRORS=0
WARNINGS=0
SUCCESS=0

# ============================================
# 1. VÉRIFIER ROUTES BACKEND MONTÉES
# ============================================
echo -e "${BLUE}📋 1. Vérification des routes backend...${NC}"

# Lister tous les fichiers de routes
ROUTE_FILES=$(find api-v2/routes -name "*.routes.js" -type f)

for route_file in $ROUTE_FILES; do
    route_name=$(basename "$route_file" .routes.js)
    
    # Vérifier si la route est montée dans index.js
    if grep -q "require.*$route_name" api-v2/index.js && grep -q "app.use.*$route_name" api-v2/index.js; then
        echo -e "  ${GREEN}✓${NC} $route_name montée"
        ((SUCCESS++))
    else
        echo -e "  ${RED}✗${NC} $route_name NON MONTÉE (code mort potentiel)"
        ((ERRORS++))
    fi
done

echo ""

# ============================================
# 2. VÉRIFIER MÉTHODES API SERVICE UTILISÉES
# ============================================
echo -e "${BLUE}📱 2. Vérification des méthodes API Service...${NC}"

# Extraire toutes les méthodes publiques de api_service.dart
API_METHODS=$(grep -E "^\s*Future<.*>\s+\w+\(" mobile/lib/core/services/api_service.dart | \
              sed -E 's/.*Future<.*>\s+([a-zA-Z0-9_]+)\(.*/\1/' | \
              grep -v "^_" | \
              sort -u)

for method in $API_METHODS; do
    # Chercher utilisation dans les features
    if grep -r "$method()" mobile/lib/features/ > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $method() utilisée"
        ((SUCCESS++))
    else
        # Vérifier si c'est une méthode privée ou helper
        if [[ "$method" == "_"* ]] || [[ "$method" == "request" ]] || [[ "$method" == "getHeaders" ]]; then
            continue
        fi
        echo -e "  ${YELLOW}⚠${NC} $method() NON UTILISÉE (code mort potentiel)"
        ((WARNINGS++))
    fi
done

echo ""

# ============================================
# 3. VÉRIFIER MÉTHODES DÉPRÉCIÉES
# ============================================
echo -e "${BLUE}🗑️  3. Vérification des méthodes dépréciées...${NC}"

DEPRECATED_COUNT=$(grep -c "@Deprecated" mobile/lib/core/services/api_service.dart || echo "0")

if [ "$DEPRECATED_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} $DEPRECATED_COUNT méthode(s) dépréciée(s) trouvée(s)"
    grep -n "@Deprecated" mobile/lib/core/services/api_service.dart | while read -r line; do
        echo -e "    ${YELLOW}→${NC} $line"
    done
    ((WARNINGS += DEPRECATED_COUNT))
else
    echo -e "  ${GREEN}✓${NC} Aucune méthode dépréciée"
    ((SUCCESS++))
fi

echo ""

# ============================================
# 4. VÉRIFIER ERREURS DE TYPAGE FLUTTER
# ============================================
echo -e "${BLUE}🔧 4. Vérification des erreurs de typage...${NC}"

if command -v flutter &> /dev/null; then
    cd mobile
    FLUTTER_ERRORS=$(flutter analyze 2>&1 | grep -c "error •" || echo "0")
    FLUTTER_WARNINGS=$(flutter analyze 2>&1 | grep -c "warning •" || echo "0")
    cd ..
    
    if [ "$FLUTTER_ERRORS" -gt 0 ]; then
        echo -e "  ${RED}✗${NC} $FLUTTER_ERRORS erreur(s) Flutter détectée(s)"
        ((ERRORS += FLUTTER_ERRORS))
    else
        echo -e "  ${GREEN}✓${NC} Aucune erreur Flutter"
        ((SUCCESS++))
    fi
    
    if [ "$FLUTTER_WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $FLUTTER_WARNINGS warning(s) Flutter"
        ((WARNINGS += FLUTTER_WARNINGS))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Flutter non installé, analyse ignorée"
fi

echo ""

# ============================================
# 5. VÉRIFIER API_CONTRACT.md
# ============================================
echo -e "${BLUE}📄 5. Vérification de la documentation...${NC}"

if [ ! -f "API_CONTRACT.md" ]; then
    echo -e "  ${RED}✗${NC} API_CONTRACT.md manquant"
    ((ERRORS++))
elif [ ! -s "API_CONTRACT.md" ]; then
    echo -e "  ${RED}✗${NC} API_CONTRACT.md vide"
    ((ERRORS++))
else
    ENDPOINT_COUNT=$(grep -c "^##.*/" API_CONTRACT.md || echo "0")
    if [ "$ENDPOINT_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} API_CONTRACT.md existe ($ENDPOINT_COUNT endpoints documentés)"
        ((SUCCESS++))
    else
        echo -e "  ${YELLOW}⚠${NC} API_CONTRACT.md existe mais aucun endpoint documenté"
        ((WARNINGS++))
    fi
fi

echo ""

# ============================================
# 6. VÉRIFIER COHÉRENCE DES ROUTES
# ============================================
echo -e "${BLUE}🔗 6. Vérification de la cohérence des routes...${NC}"

# Vérifier que chaque route montée a un fichier correspondant
MOUNTED_ROUTES=$(grep -E "app\.use\(['\"]\/api\/[^'\"]+['\"]" api-v2/index.js | \
                 sed -E "s/.*app\.use\(['\"]\/api\/([^'\"]+)['\"].*/\1/" | \
                 sort -u)

for route in $MOUNTED_ROUTES; do
    # Chercher le fichier de route correspondant
    if [ -f "api-v2/routes/${route}.routes.js" ]; then
        echo -e "  ${GREEN}✓${NC} /api/$route → ${route}.routes.js"
        ((SUCCESS++))
    else
        # Vérifier si c'est un alias ou une route spéciale
        if [ "$route" == "deliverers" ] || [ "$route" == "audit-logs" ]; then
            echo -e "  ${YELLOW}⚠${NC} /api/$route → alias ou route spéciale"
            ((WARNINGS++))
        else
            echo -e "  ${RED}✗${NC} /api/$route → fichier manquant"
            ((ERRORS++))
        fi
    fi
done

echo ""

# ============================================
# 7. VÉRIFIER ENDPOINTS SANS RÉPONSE
# ============================================
echo -e "${BLUE}🌐 7. Vérification des endpoints sans réponse...${NC}"

# Chercher les routes qui n'ont pas de res.json() ou res.send()
ROUTE_FILES=$(find api-v2/routes -name "*.routes.js" -type f)

for route_file in $ROUTE_FILES; do
    route_name=$(basename "$route_file")
    
    # Compter les définitions de routes
    ROUTE_DEFS=$(grep -c "router\.\(get\|post\|put\|patch\|delete\)" "$route_file" || echo "0")
    
    # Compter les réponses
    RESPONSES=$(grep -c "res\.\(json\|send\|status\)" "$route_file" || echo "0")
    
    if [ "$ROUTE_DEFS" -gt 0 ] && [ "$RESPONSES" -eq 0 ]; then
        echo -e "  ${RED}✗${NC} $route_name: $ROUTE_DEFS route(s) sans réponse"
        ((ERRORS++))
    elif [ "$ROUTE_DEFS" -gt "$RESPONSES" ]; then
        echo -e "  ${YELLOW}⚠${NC} $route_name: $ROUTE_DEFS routes, $RESPONSES réponses (vérifier)"
        ((WARNINGS++))
    else
        echo -e "  ${GREEN}✓${NC} $route_name: $ROUTE_DEFS routes, $RESPONSES réponses"
        ((SUCCESS++))
    fi
done

echo ""

# ============================================
# 8. VÉRIFIER IMPORTS NON UTILISÉS
# ============================================
echo -e "${BLUE}📦 8. Vérification des imports non utilisés...${NC}"

# Vérifier dans api_service.dart
UNUSED_IMPORTS=$(grep "^import" mobile/lib/core/services/api_service.dart | \
                 sed "s/import '\(.*\)';/\1/" | \
                 while read -r import; do
                     import_name=$(basename "$import" .dart)
                     if ! grep -q "$import_name" mobile/lib/core/services/api_service.dart; then
                         echo "$import"
                     fi
                 done)

if [ -z "$UNUSED_IMPORTS" ]; then
    echo -e "  ${GREEN}✓${NC} Aucun import non utilisé détecté"
    ((SUCCESS++))
else
    echo -e "  ${YELLOW}⚠${NC} Imports potentiellement non utilisés:"
    echo "$UNUSED_IMPORTS" | while read -r imp; do
        echo -e "    ${YELLOW}→${NC} $imp"
        ((WARNINGS++))
    done
fi

echo ""

# ============================================
# RÉSUMÉ
# ============================================
echo "========================================"
echo -e "${BLUE}📊 RÉSUMÉ DE L'AUDIT${NC}"
echo "========================================"
echo -e "${GREEN}✓ Succès:${NC} $SUCCESS"
echo -e "${YELLOW}⚠ Warnings:${NC} $WARNINGS"
echo -e "${RED}✗ Erreurs:${NC} $ERRORS"
echo ""

# Score de santé
TOTAL=$((SUCCESS + WARNINGS + ERRORS))
if [ "$TOTAL" -gt 0 ]; then
    HEALTH_SCORE=$((SUCCESS * 100 / TOTAL))
    echo -e "Score de santé: ${HEALTH_SCORE}%"
    
    if [ "$HEALTH_SCORE" -ge 90 ]; then
        echo -e "${GREEN}🎉 Excellent ! Codebase très sain${NC}"
    elif [ "$HEALTH_SCORE" -ge 70 ]; then
        echo -e "${YELLOW}👍 Bon, quelques améliorations possibles${NC}"
    elif [ "$HEALTH_SCORE" -ge 50 ]; then
        echo -e "${YELLOW}⚠️  Moyen, refactoring recommandé${NC}"
    else
        echo -e "${RED}❌ Critique, refactoring urgent nécessaire${NC}"
    fi
fi

echo ""

# Exit code basé sur les erreurs
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}❌ Audit échoué avec $ERRORS erreur(s)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Audit réussi !${NC}"
    exit 0
fi
