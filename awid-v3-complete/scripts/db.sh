#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# AWID v3.0 - SCRIPTS DE MIGRATION ET SEED
# Gestion de la base de données PostgreSQL
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-awid}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour exécuter des commandes SQL
run_sql() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "$1"
}

run_sql_file() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATION
# ═══════════════════════════════════════════════════════════════════════════════

migrate() {
    log_info "Exécution des migrations..."
    
    # Créer la table de suivi des migrations si elle n'existe pas
    run_sql "
        CREATE TABLE IF NOT EXISTS _migrations (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    "
    
    # Appliquer le schéma principal
    if [ -f "../database/schema.sql" ]; then
        log_info "Application du schéma principal..."
        run_sql_file "../database/schema.sql"
        run_sql "INSERT INTO _migrations (name) VALUES ('schema.sql') ON CONFLICT (name) DO NOTHING;"
    fi
    
    # Appliquer les migrations supplémentaires
    MIGRATIONS_DIR="../database/migrations"
    if [ -d "$MIGRATIONS_DIR" ]; then
        for migration in "$MIGRATIONS_DIR"/*.sql; do
            if [ -f "$migration" ]; then
                MIGRATION_NAME=$(basename "$migration")
                
                # Vérifier si déjà exécutée
                EXECUTED=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -tAc "SELECT COUNT(*) FROM _migrations WHERE name = '$MIGRATION_NAME'")
                
                if [ "$EXECUTED" -eq "0" ]; then
                    log_info "Exécution de la migration: $MIGRATION_NAME"
                    run_sql_file "$migration"
                    run_sql "INSERT INTO _migrations (name) VALUES ('$MIGRATION_NAME');"
                else
                    log_info "Migration déjà exécutée: $MIGRATION_NAME"
                fi
            fi
        done
    fi
    
    log_info "Migrations terminées avec succès!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SEED (Données de démo)
# ═══════════════════════════════════════════════════════════════════════════════

seed() {
    log_info "Insertion des données de démonstration..."
    
    # Organisation de démo
    run_sql "
        INSERT INTO organizations (id, name, phone, address, settings, created_at)
        VALUES (
            'org_demo_001',
            'Boulangerie Patisserie El Baraka',
            '021123456',
            '15 Rue Didouche Mourad, Alger Centre',
            '{
                \"currency\": \"DZD\",
                \"language\": \"fr\",
                \"timezone\": \"Africa/Algiers\",
                \"defaultCreditLimit\": 50000,
                \"defaultPaymentTerms\": 7,
                \"deliveryFee\": 200,
                \"minOrderAmount\": 1000
            }'::jsonb,
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
    "
    
    # Utilisateurs
    run_sql "
        -- Admin
        INSERT INTO users (id, organization_id, email, password_hash, name, phone, role, is_active, created_at)
        VALUES (
            'user_admin_001',
            'org_demo_001',
            'admin@elbaraka.dz',
            '\$2b\$10\$rQZ5X9Zs8KjYjHqL1xqDOeWvJFkLnMwZP8kQvMnRxQjTlNpDwC4Gu', -- password: Admin123!
            'Administrateur',
            '0555000001',
            'admin',
            true,
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
        
        -- Manager
        INSERT INTO users (id, organization_id, email, password_hash, name, phone, role, is_active, created_at)
        VALUES (
            'user_manager_001',
            'org_demo_001',
            'manager@elbaraka.dz',
            '\$2b\$10\$rQZ5X9Zs8KjYjHqL1xqDOeWvJFkLnMwZP8kQvMnRxQjTlNpDwC4Gu',
            'Mohamed Responsable',
            '0555000002',
            'manager',
            true,
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
        
        -- Livreurs
        INSERT INTO users (id, organization_id, email, password_hash, name, phone, role, is_active, created_at)
        VALUES 
        (
            'user_livreur_001',
            'org_demo_001',
            'livreur1@elbaraka.dz',
            '\$2b\$10\$rQZ5X9Zs8KjYjHqL1xqDOeWvJFkLnMwZP8kQvMnRxQjTlNpDwC4Gu',
            'Karim Livreur',
            '0555000003',
            'deliverer',
            true,
            NOW()
        ),
        (
            'user_livreur_002',
            'org_demo_001',
            'livreur2@elbaraka.dz',
            '\$2b\$10\$rQZ5X9Zs8KjYjHqL1xqDOeWvJFkLnMwZP8kQvMnRxQjTlNpDwC4Gu',
            'Ahmed Livreur',
            '0555000004',
            'deliverer',
            true,
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
    "
    
    # Catégories de produits
    run_sql "
        INSERT INTO categories (id, organization_id, name, description, display_order, is_active, created_at)
        VALUES 
        ('cat_001', 'org_demo_001', 'Viennoiseries', 'Croissants, pains au chocolat, etc.', 1, true, NOW()),
        ('cat_002', 'org_demo_001', 'Pains', 'Baguettes, pains spéciaux', 2, true, NOW()),
        ('cat_003', 'org_demo_001', 'Pâtisseries', 'Gâteaux individuels', 3, true, NOW()),
        ('cat_004', 'org_demo_001', 'Gâteaux', 'Gâteaux de fête', 4, true, NOW()),
        ('cat_005', 'org_demo_001', 'Salés', 'Pizzas, quiches, sandwichs', 5, true, NOW())
        ON CONFLICT (id) DO NOTHING;
    "
    
    # Produits
    run_sql "
        INSERT INTO products (id, organization_id, category_id, sku, name, description, unit, base_price, current_price, stock_quantity, min_stock_level, is_active, created_at)
        VALUES 
        -- Viennoiseries
        ('prod_001', 'org_demo_001', 'cat_001', 'VIE001', 'Croissant Beurre', 'Croissant pur beurre', 'pièce', 80, 80, 100, 20, true, NOW()),
        ('prod_002', 'org_demo_001', 'cat_001', 'VIE002', 'Pain au Chocolat', 'Pain au chocolat artisanal', 'pièce', 90, 90, 80, 20, true, NOW()),
        ('prod_003', 'org_demo_001', 'cat_001', 'VIE003', 'Chausson aux Pommes', 'Chausson feuilleté aux pommes', 'pièce', 100, 100, 50, 15, true, NOW()),
        ('prod_004', 'org_demo_001', 'cat_001', 'VIE004', 'Brioche', 'Brioche nature', 'pièce', 70, 70, 40, 10, true, NOW()),
        
        -- Pains
        ('prod_005', 'org_demo_001', 'cat_002', 'PAI001', 'Baguette Tradition', 'Baguette traditionnelle', 'pièce', 50, 50, 200, 50, true, NOW()),
        ('prod_006', 'org_demo_001', 'cat_002', 'PAI002', 'Pain Complet', 'Pain aux céréales complètes', 'pièce', 70, 70, 60, 15, true, NOW()),
        ('prod_007', 'org_demo_001', 'cat_002', 'PAI003', 'Pain de Campagne', 'Pain rustique au levain', 'pièce', 120, 120, 30, 10, true, NOW()),
        
        -- Pâtisseries
        ('prod_008', 'org_demo_001', 'cat_003', 'PAT001', 'Millefeuille', 'Millefeuille à la crème pâtissière', 'pièce', 150, 150, 30, 10, true, NOW()),
        ('prod_009', 'org_demo_001', 'cat_003', 'PAT002', 'Éclair Chocolat', 'Éclair au chocolat', 'pièce', 120, 120, 40, 10, true, NOW()),
        ('prod_010', 'org_demo_001', 'cat_003', 'PAT003', 'Tarte Citron', 'Tartelette au citron meringuée', 'pièce', 140, 140, 25, 8, true, NOW()),
        ('prod_011', 'org_demo_001', 'cat_003', 'PAT004', 'Paris-Brest', 'Paris-Brest praliné', 'pièce', 180, 180, 20, 8, true, NOW()),
        
        -- Gâteaux
        ('prod_012', 'org_demo_001', 'cat_004', 'GAT001', 'Tarte aux Fruits', 'Tarte aux fruits frais (6 pers)', 'pièce', 800, 800, 10, 3, true, NOW()),
        ('prod_013', 'org_demo_001', 'cat_004', 'GAT002', 'Forêt Noire', 'Gâteau chocolat cerises (8 pers)', 'pièce', 1200, 1200, 5, 2, true, NOW()),
        
        -- Salés
        ('prod_014', 'org_demo_001', 'cat_005', 'SAL001', 'Pizza Margherita', 'Pizza tomate mozzarella', 'pièce', 250, 250, 20, 5, true, NOW()),
        ('prod_015', 'org_demo_001', 'cat_005', 'SAL002', 'Quiche Lorraine', 'Quiche lardons fromage', 'pièce', 180, 180, 15, 5, true, NOW())
        ON CONFLICT (id) DO NOTHING;
    "
    
    # Clients
    run_sql "
        INSERT INTO customers (id, organization_id, code, name, phone, address, city, wilaya, category, credit_limit_enabled, credit_limit, current_debt, is_active, created_at)
        VALUES 
        ('cust_001', 'org_demo_001', 'CLT001', 'Café Le Parisien', '0555111001', '45 Rue Larbi Ben Mhidi, Alger', 'Alger Centre', 'Alger', 'vip', true, 100000, 25000, true, NOW()),
        ('cust_002', 'org_demo_001', 'CLT002', 'Restaurant El Djazair', '0555111002', '12 Boulevard Zighout Youcef', 'Hussein Dey', 'Alger', 'wholesale', true, 200000, 45000, true, NOW()),
        ('cust_003', 'org_demo_001', 'CLT003', 'Snack Chez Mourad', '0555111003', '78 Rue de Tripoli', 'Kouba', 'Alger', 'normal', true, 50000, 8500, true, NOW()),
        ('cust_004', 'org_demo_001', 'CLT004', 'Épicerie El Amel', '0555111004', '23 Cité des Oliviers', 'Bir Mourad Rais', 'Alger', 'normal', true, 30000, 0, true, NOW()),
        ('cust_005', 'org_demo_001', 'CLT005', 'Cafétéria Université', '0555111005', 'Campus USTHB', 'Bab Ezzouar', 'Alger', 'vip', true, 150000, 62000, true, NOW()),
        ('cust_006', 'org_demo_001', 'CLT006', 'Hôtel El Aurassi', '0555111006', 'Place des Martyrs', 'Alger Centre', 'Alger', 'wholesale', true, 300000, 0, true, NOW()),
        ('cust_007', 'org_demo_001', 'CLT007', 'Café du Port', '0555111007', '5 Rue du Port', 'La Casbah', 'Alger', 'normal', true, 40000, 15000, true, NOW()),
        ('cust_008', 'org_demo_001', 'CLT008', 'Brasserie Moderne', '0555111008', '89 Rue Hassiba Ben Bouali', 'Sidi Mhamed', 'Alger', 'normal', false, NULL, 0, true, NOW())
        ON CONFLICT (id) DO NOTHING;
    "
    
    log_info "Données de démonstration insérées avec succès!"
    log_info ""
    log_info "Comptes de démonstration:"
    log_info "  Admin:   admin@elbaraka.dz / Admin123!"
    log_info "  Manager: manager@elbaraka.dz / Admin123!"
    log_info "  Livreur: livreur1@elbaraka.dz / Admin123!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESET
# ═══════════════════════════════════════════════════════════════════════════════

reset() {
    log_warn "ATTENTION: Cette action va supprimer toutes les données!"
    read -p "Êtes-vous sûr ? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Opération annulée."
        exit 0
    fi
    
    log_info "Suppression de la base de données..."
    
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "DROP DATABASE IF EXISTS $DB_NAME;"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
    
    log_info "Base de données réinitialisée."
    
    migrate
    seed
}

# ═══════════════════════════════════════════════════════════════════════════════
# BACKUP
# ═══════════════════════════════════════════════════════════════════════════════

backup() {
    BACKUP_DIR="${BACKUP_DIR:-./backups}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/awid_backup_$TIMESTAMP.sql"
    
    mkdir -p "$BACKUP_DIR"
    
    log_info "Création de la sauvegarde..."
    
    PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME > "$BACKUP_FILE"
    
    # Compresser
    gzip "$BACKUP_FILE"
    
    log_info "Sauvegarde créée: ${BACKUP_FILE}.gz"
    
    # Nettoyer les anciennes sauvegardes (garder les 7 derniers jours)
    find "$BACKUP_DIR" -name "awid_backup_*.sql.gz" -mtime +7 -delete
    
    log_info "Anciennes sauvegardes nettoyées."
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESTORE
# ═══════════════════════════════════════════════════════════════════════════════

restore() {
    if [ -z "$1" ]; then
        log_error "Usage: $0 restore <backup_file.sql.gz>"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Fichier non trouvé: $BACKUP_FILE"
        exit 1
    fi
    
    log_warn "ATTENTION: Cette action va remplacer toutes les données actuelles!"
    read -p "Êtes-vous sûr ? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Opération annulée."
        exit 0
    fi
    
    log_info "Restauration de la sauvegarde..."
    
    # Décompresser si nécessaire
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        gunzip -c "$BACKUP_FILE" | PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME
    else
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME < "$BACKUP_FILE"
    fi
    
    log_info "Restauration terminée."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

case "$1" in
    migrate)
        migrate
        ;;
    seed)
        seed
        ;;
    reset)
        reset
        ;;
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    *)
        echo "Usage: $0 {migrate|seed|reset|backup|restore <file>}"
        echo ""
        echo "Commands:"
        echo "  migrate  - Appliquer les migrations de base de données"
        echo "  seed     - Insérer les données de démonstration"
        echo "  reset    - Réinitialiser complètement la base de données"
        echo "  backup   - Créer une sauvegarde de la base de données"
        echo "  restore  - Restaurer une sauvegarde"
        exit 1
        ;;
esac
