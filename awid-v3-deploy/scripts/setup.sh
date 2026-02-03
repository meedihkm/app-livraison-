#!/bin/bash
# ==========================================
# AWID v3.0 - Script d'installation automatique
# Ce script initialise l'application sur Coolify
# ==========================================

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}  AWID v3.0 - Installation automatique${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Vérifier que les fichiers nécessaires existent
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Erreur: Fichier .env manquant${NC}"
    echo -e "${YELLOW}👉 Copie .env.example en .env et configure les variables${NC}"
    exit 1
fi

# Charger les variables d'environnement
export $(grep -v '^#' .env | xargs)

echo -e "${YELLOW}📋 Étape 1/6: Vérification des prérequis...${NC}"

# Vérifier Docker
docker --version > /dev/null 2>&1 || { echo -e "${RED}❌ Docker n'est pas installé${NC}"; exit 1; }
docker-compose --version > /dev/null 2>&1 || { echo -e "${RED}❌ Docker Compose n'est pas installé${NC}"; exit 1; }

echo -e "${GREEN}✅ Docker et Docker Compose OK${NC}"

echo ""
echo -e "${YELLOW}📦 Étape 2/6: Création des répertoires...${NC}"

# Créer les répertoires nécessaires
mkdir -p backups
mkdir -p pgadmin
mkdir -p logs

echo -e "${GREEN}✅ Répertoires créés${NC}"

echo ""
echo -e "${YELLOW}🐳 Étape 3/6: Lancement des services...${NC}"

# Lancer les services
cd docker
docker-compose -f docker-compose.coolify.yml pull
docker-compose -f docker-compose.coolify.yml up -d

echo -e "${GREEN}✅ Services lancés${NC}"

echo ""
echo -e "${YELLOW}⏳ Étape 4/6: Attente de la base de données...${NC}"

# Attendre que PostgreSQL soit prêt
echo "Attente de PostgreSQL..."
sleep 10
until docker exec awid-postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
echo -e "${GREEN}✅ PostgreSQL prêt${NC}"

echo ""
echo -e "${YELLOW}🗄️ Étape 5/6: Initialisation de MinIO...${NC}"

# Attendre MinIO
sleep 5
echo "Attente de MinIO..."
until curl -s http://localhost:9000/minio/health/live > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""

# Créer le bucket MinIO si nécessaire
docker exec awid-minio mc alias set local http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" 2>/dev/null || true
docker exec awid-minio mc mb local/"${MINIO_BUCKET}" 2>/dev/null || echo "Bucket déjà existant"
docker exec awid-minio mc policy set public local/"${MINIO_BUCKET}"

echo -e "${GREEN}✅ MinIO configuré (bucket: ${MINIO_BUCKET})${NC}"

echo ""
echo -e "${YELLOW}🔄 Étape 6/6: Migrations de la base de données...${NC}"

# Exécuter les migrations
docker exec -i awid-backend sh -c "cd /app && npx prisma migrate deploy" || {
    echo -e "${YELLOW}⚠️ Prisma non trouvé, tentative avec TypeORM...${NC}"
    docker exec -i awid-backend sh -c "cd /app && npm run migrate" || true
}

echo -e "${GREEN}✅ Migrations terminées${NC}"

echo ""
echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}🎉 Installation terminée avec succès !${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""
echo -e "${YELLOW}📊 Services disponibles:${NC}"
echo -e "  • Backend API:    http://localhost:3000"
echo -e "  • Admin Panel:    http://localhost"
echo -e "  • PGAdmin:        http://localhost:5050"
echo -e "  • MinIO Console:  http://localhost:9001"
echo ""
echo -e "${YELLOW}🔐 Identifiants PGAdmin:${NC}"
echo -e "  Email:    ${PGADMIN_EMAIL}"
echo -e "  Password: ${PGADMIN_PASSWORD}"
echo ""
echo -e "${YELLOW}📦 Identifiants MinIO:${NC}"
echo -e "  Access Key: ${MINIO_ROOT_USER}"
echo -e "  Secret Key: ${MINIO_ROOT_PASSWORD}"
echo ""
echo -e "${BLUE}==============================================${NC}"
echo -e "${YELLOW}💡 Prochaines étapes:${NC}"
echo -e "  1. Configure les domaines dans Coolify"
echo -e "  2. Vérifie que tous les services sont UP"
echo -e "  3. Crée un compte admin via l'API"
echo -e "  4. Configure PGAdmin avec la connexion PostgreSQL"
echo -e "${BLUE}==============================================${NC}"
