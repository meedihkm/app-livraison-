#!/bin/bash
# ==========================================
# AWID v3.0 - Script de migrations
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Exécution des migrations de base de données...${NC}"

cd docker

# Vérifier que PostgreSQL est accessible
docker-compose -f docker-compose.coolify.yml exec -T postgres pg_isready -U awid_admin > /dev/null 2>&1 || {
    echo -e "${RED}❌ PostgreSQL n'est pas accessible${NC}"
    exit 1
}

# Exécuter les migrations
docker-compose -f docker-compose.coolify.yml exec -T backend sh -c "cd /app && npm run migrate" || {
    echo -e "${RED}❌ Échec des migrations${NC}"
    exit 1
}

echo -e "${GREEN}✅ Migrations terminées avec succès${NC}"
