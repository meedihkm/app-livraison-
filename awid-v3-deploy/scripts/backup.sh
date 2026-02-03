#!/bin/bash
# ==========================================
# AWID v3.0 - Script de backup manuel
# ==========================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}  AWID v3.0 - Backup manuel${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}💾 Backup de la base de données...${NC}"
docker exec awid-postgres pg_dump -U awid_admin awid_v3 > "$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
echo -e "${GREEN}✅ DB backup: $BACKUP_DIR/db_backup_$TIMESTAMP.sql${NC}"

echo ""
echo -e "${YELLOW}💾 Backup des volumes Docker...${NC}"
docker run --rm \
  -v awid_postgres_data:/source/postgres:ro \
  -v awid_redis_data:/source/redis:ro \
  -v awid_minio_data:/source/minio:ro \
  -v "$(pwd)/$BACKUP_DIR:/backup" \
  alpine tar czf "/backup/volumes_backup_$TIMESTAMP.tar.gz" -C /source .

echo -e "${GREEN}✅ Volumes backup: $BACKUP_DIR/volumes_backup_$TIMESTAMP.tar.gz${NC}"

echo ""
echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}🎉 Backup terminé !${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""
echo -e "Fichiers créés :"
ls -lh "$BACKUP_DIR"/*$TIMESTAMP*
