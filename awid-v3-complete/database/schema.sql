-- ═══════════════════════════════════════════════════════════════════════════════
-- AWID v3.0 - SCHÉMA DE BASE DE DONNÉES COMPLET
-- Système de livraison B2B pour le marché algérien
-- ═══════════════════════════════════════════════════════════════════════════════

-- Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Pour recherche fuzzy

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ORGANISATIONS (Multi-tenant root)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Informations de base
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    legal_name VARCHAR(150),
    
    -- Contact
    address TEXT,
    city VARCHAR(50),
    wilaya VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    
    -- Branding
    logo_url VARCHAR(255),
    primary_color VARCHAR(7) DEFAULT '#2563eb',
    
    -- Configuration financière par défaut
    default_credit_limit DECIMAL(12,2) DEFAULT 50000,
    default_payment_delay_days INTEGER DEFAULT 30,
    debt_alert_days INTEGER DEFAULT 60,
    currency VARCHAR(3) DEFAULT 'DZD',
    
    -- Fonctionnalités activées
    features JSONB DEFAULT '{
        "signature_required": false,
        "photo_required": false,
        "qr_code_enabled": true,
        "bluetooth_printing": true,
        "push_notifications": true,
        "sms_notifications": false,
        "recurring_orders": true,
        "custom_pricing": true
    }'::jsonb,
    
    -- Paramètres d'impression
    print_settings JSONB DEFAULT '{
        "printer_type": "58mm",
        "auto_print_delivery": false,
        "auto_print_receipt": true,
        "show_debt_on_receipt": true,
        "header_line1": "",
        "header_line2": "",
        "footer_text": "Merci pour votre confiance!"
    }'::jsonb,
    
    -- Paramètres de notification admin
    admin_notifications JSONB DEFAULT '{
        "credit_limit_reached": true,
        "debt_over_limit": true,
        "large_payment_threshold": 100000,
        "daily_summary_time": "20:00",
        "daily_summary_enabled": true
    }'::jsonb,
    
    -- Statistiques (dénormalisé pour performance)
    stats JSONB DEFAULT '{
        "total_customers": 0,
        "total_deliverers": 0,
        "total_products": 0
    }'::jsonb,
    
    timezone VARCHAR(50) DEFAULT 'Africa/Algiers',
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_org_slug ON organizations(slug);
CREATE INDEX idx_org_active ON organizations(is_active) WHERE is_active = true;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. UTILISATEURS (Admin, Managers, Livreurs, Cuisine)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TYPE user_role AS ENUM ('admin', 'manager', 'deliverer', 'kitchen');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Authentification
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    -- Profil
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    avatar_url VARCHAR(255),
    
    -- Rôle et permissions
    role user_role NOT NULL,
    permissions JSONB DEFAULT '[]'::jsonb,
    
    -- Pour livreurs
    vehicle_type VARCHAR(20),  -- 'car', 'motorcycle', 'bicycle', 'foot'
    license_plate VARCHAR(20),
    
    -- Position (livreur)
    last_position JSONB,  -- {lat, lng, accuracy, updated_at}
    
    -- Sécurité
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    password_changed_at TIMESTAMP WITH TIME ZONE,
    
    -- Sessions
    last_login_at TIMESTAMP WITH TIME ZONE,
    last_login_ip VARCHAR(45),
    
    -- Push notifications
    push_tokens JSONB DEFAULT '[]'::jsonb,  -- [{token, platform, device_id}]
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(organization_id, email)
);

-- Index
CREATE INDEX idx_users_org ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(organization_id, role);
CREATE INDEX idx_users_active ON users(organization_id, is_active) WHERE is_active = true;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. CLIENTS (Points de vente - Cafétérias, Épiceries, etc.)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Identification
    code VARCHAR(20),  -- Code client optionnel (ex: CLI-001)
    name VARCHAR(100) NOT NULL,
    
    -- Contact
    contact_name VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    phone_secondary VARCHAR(20),
    email VARCHAR(100),
    
    -- Adresse
    address TEXT NOT NULL,
    city VARCHAR(50),
    wilaya VARCHAR(50),
    zone VARCHAR(50),  -- Zone de livraison pour regroupement
    coordinates JSONB,  -- {lat, lng}
    
    -- Finance
    credit_limit DECIMAL(12,2) DEFAULT 50000,
    credit_limit_enabled BOOLEAN DEFAULT true,
    current_debt DECIMAL(12,2) DEFAULT 0,  -- Mis à jour par trigger
    payment_delay_days INTEGER DEFAULT 30,
    
    -- Tarification personnalisée
    discount_percent DECIMAL(5,2) DEFAULT 0,  -- Remise globale
    custom_prices JSONB DEFAULT '{}'::jsonb,  -- {"product_id": price}
    price_list_id UUID,  -- Référence à une liste de prix (futur)
    
    -- Statistiques (dénormalisé)
    stats JSONB DEFAULT '{
        "total_orders": 0,
        "total_revenue": 0,
        "total_paid": 0,
        "avg_order_value": 0,
        "avg_payment_delay": 0,
        "last_order_at": null,
        "last_payment_at": null
    }'::jsonb,
    
    -- App client
    app_user_id UUID,  -- Si le client a un compte app
    push_token VARCHAR(255),
    
    -- Préférences de livraison
    preferred_delivery_time VARCHAR(20),  -- 'morning', 'afternoon', 'evening'
    delivery_notes TEXT,  -- Notes permanentes pour livreur
    
    notes TEXT,  -- Notes internes admin
    tags JSONB DEFAULT '[]'::jsonb,  -- Tags pour filtrage
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_customers_org ON customers(organization_id);
CREATE INDEX idx_customers_code ON customers(organization_id, code) WHERE code IS NOT NULL;
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_zone ON customers(organization_id, zone);
CREATE INDEX idx_customers_debt ON customers(organization_id, current_debt DESC) WHERE current_debt > 0;
CREATE INDEX idx_customers_active ON customers(organization_id, is_active) WHERE is_active = true;
CREATE INDEX idx_customers_search ON customers USING gin(name gin_trgm_ops);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. COMPTES CLIENT (Pour l'app mobile client)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE customer_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- Authentification
    phone VARCHAR(20) NOT NULL UNIQUE,  -- Login par téléphone
    pin_hash VARCHAR(255),  -- PIN à 4-6 chiffres
    
    -- OTP
    otp_code VARCHAR(6),
    otp_expires_at TIMESTAMP WITH TIME ZONE,
    otp_attempts INTEGER DEFAULT 0,
    
    -- Session
    last_login_at TIMESTAMP WITH TIME ZONE,
    push_token VARCHAR(255),
    device_info JSONB,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_customer_accounts_phone ON customer_accounts(phone);
CREATE INDEX idx_customer_accounts_customer ON customer_accounts(customer_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. CATÉGORIES DE PRODUITS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE product_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    name VARCHAR(50) NOT NULL,
    slug VARCHAR(50) NOT NULL,
    icon VARCHAR(50),  -- Nom de l'icône (ex: 'bread', 'cake')
    color VARCHAR(7),  -- Couleur hex
    
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(organization_id, slug)
);

CREATE INDEX idx_categories_org ON product_categories(organization_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. PRODUITS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    
    -- Identification
    name VARCHAR(100) NOT NULL,
    description TEXT,
    sku VARCHAR(50),
    barcode VARCHAR(50),
    
    -- Prix et unité
    price DECIMAL(10,2) NOT NULL,
    unit VARCHAR(20) DEFAULT 'pièce',  -- 'pièce', 'kg', 'pack', 'boîte'
    unit_quantity DECIMAL(10,2) DEFAULT 1,  -- Quantité par unité
    
    -- Images
    image_url VARCHAR(255),
    thumbnail_url VARCHAR(255),
    
    -- Stock (optionnel)
    track_stock BOOLEAN DEFAULT false,
    current_stock DECIMAL(10,2),
    min_stock_alert DECIMAL(10,2),
    
    -- Disponibilité
    is_available BOOLEAN DEFAULT true,  -- Disponible à la vente
    availability_schedule JSONB,  -- Jours/heures de disponibilité
    
    -- Affichage
    sort_order INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,  -- Mis en avant
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_products_org ON products(organization_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_available ON products(organization_id, is_available, is_active) 
    WHERE is_available = true AND is_active = true;
CREATE INDEX idx_products_search ON products USING gin(name gin_trgm_ops);
CREATE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TYPE order_status AS ENUM (
    'draft',        -- Brouillon (client app)
    'pending',      -- En attente de confirmation
    'confirmed',    -- Confirmée par admin
    'preparing',    -- En préparation (cuisine)
    'ready',        -- Prête pour livraison
    'assigned',     -- Assignée à un livreur
    'in_delivery',  -- En cours de livraison
    'delivered',    -- Livrée
    'cancelled'     -- Annulée
);

CREATE TYPE payment_status AS ENUM (
    'unpaid',       -- Non payée
    'partial',      -- Partiellement payée
    'paid'          -- Entièrement payée
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- Numéro de commande (généré automatiquement)
    order_number VARCHAR(20) NOT NULL,
    
    -- Statut
    status order_status DEFAULT 'pending',
    
    -- Montants
    subtotal DECIMAL(12,2) NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL,
    
    -- Paiement
    payment_status payment_status DEFAULT 'unpaid',
    amount_paid DECIMAL(12,2) DEFAULT 0,
    -- amount_due calculé: total - amount_paid
    
    -- Livraison
    delivery_date DATE,
    delivery_time_slot VARCHAR(20),  -- 'morning' (6-12h), 'afternoon' (12-18h), 'evening' (18-22h)
    delivery_address TEXT,
    delivery_notes TEXT,
    
    -- Commande récurrente
    is_recurring BOOLEAN DEFAULT false,
    recurring_config JSONB,  -- {frequency: 'daily'|'weekly', days: [1,3,5], end_date}
    parent_order_id UUID REFERENCES orders(id),  -- Si généré par récurrence
    
    -- Source
    source VARCHAR(20) DEFAULT 'admin',  -- 'admin', 'client_app', 'recurring'
    
    -- Timestamps détaillés
    confirmed_at TIMESTAMP WITH TIME ZONE,
    confirmed_by UUID REFERENCES users(id),
    prepared_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancelled_by UUID REFERENCES users(id),
    cancellation_reason TEXT,
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_orders_org ON orders(organization_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_number ON orders(organization_id, order_number);
CREATE INDEX idx_orders_status ON orders(organization_id, status);
CREATE INDEX idx_orders_date ON orders(organization_id, delivery_date);
CREATE INDEX idx_orders_payment ON orders(organization_id, payment_status) WHERE payment_status != 'paid';
CREATE INDEX idx_orders_created ON orders(organization_id, created_at DESC);

-- Fonction pour générer le numéro de commande
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix VARCHAR(3);
    v_date VARCHAR(8);
    v_seq INTEGER;
BEGIN
    -- Préfixe: 3 premières lettres du slug organisation
    SELECT UPPER(LEFT(slug, 3)) INTO v_prefix
    FROM organizations WHERE id = NEW.organization_id;
    
    -- Date YYYYMMDD
    v_date := TO_CHAR(COALESCE(NEW.delivery_date, CURRENT_DATE), 'YYYYMMDD');
    
    -- Séquence du jour
    SELECT COALESCE(MAX(
        CAST(NULLIF(SUBSTRING(order_number FROM '[0-9]+$'), '') AS INTEGER)
    ), 0) + 1 INTO v_seq
    FROM orders
    WHERE organization_id = NEW.organization_id
    AND order_number LIKE v_prefix || '-' || v_date || '-%';
    
    NEW.order_number := v_prefix || '-' || v_date || '-' || LPAD(v_seq::TEXT, 3, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_number
    BEFORE INSERT ON orders
    FOR EACH ROW
    WHEN (NEW.order_number IS NULL)
    EXECUTE FUNCTION generate_order_number();

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. LIGNES DE COMMANDE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    -- Snapshot au moment de la commande
    product_name VARCHAR(100) NOT NULL,
    product_sku VARCHAR(50),
    
    -- Quantité et prix
    quantity DECIMAL(10,2) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    -- total_price calculé: quantity * unit_price
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. LIVRAISONS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TYPE delivery_status AS ENUM (
    'pending',      -- En attente d'assignation
    'assigned',     -- Assignée au livreur
    'picked_up',    -- Récupérée du dépôt
    'in_transit',   -- En route vers client
    'arrived',      -- Arrivé chez le client
    'delivered',    -- Livraison réussie
    'failed',       -- Échec de livraison
    'returned'      -- Retournée
);

CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id),
    deliverer_id UUID REFERENCES users(id),
    
    -- Statut
    status delivery_status DEFAULT 'pending',
    
    -- Planification
    scheduled_date DATE NOT NULL,
    scheduled_time TIME,
    sequence_number INTEGER,  -- Ordre dans la tournée
    priority INTEGER DEFAULT 50,  -- 1-100
    
    -- Montants à collecter
    order_amount DECIMAL(12,2) NOT NULL,
    existing_debt DECIMAL(12,2) DEFAULT 0,
    total_to_collect DECIMAL(12,2) NOT NULL,  -- order_amount + existing_debt
    
    -- Collecté
    amount_collected DECIMAL(12,2) DEFAULT 0,
    collection_mode VARCHAR(20),  -- 'cash', 'check', 'bank'
    
    -- Timestamps
    assigned_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    arrived_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Preuve de livraison (optionnel selon config org)
    proof_of_delivery JSONB,  -- {signature_data, signature_name, photos[], location}
    
    -- Échec
    failure_reason TEXT,
    
    -- Distance et temps estimés (optionnel)
    estimated_distance_km DECIMAL(6,2),
    estimated_duration_min INTEGER,
    actual_duration_min INTEGER,
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_deliveries_org ON deliveries(organization_id);
CREATE INDEX idx_deliveries_order ON deliveries(order_id);
CREATE INDEX idx_deliveries_deliverer ON deliveries(deliverer_id, scheduled_date);
CREATE INDEX idx_deliveries_date ON deliveries(organization_id, scheduled_date);
CREATE INDEX idx_deliveries_status ON deliveries(organization_id, status);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. HISTORIQUE DES PAIEMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TYPE payment_type AS ENUM (
    'order_payment',    -- Paiement d'une commande
    'debt_payment',     -- Encaissement de dette
    'advance_payment',  -- Avance
    'refund'            -- Remboursement
);

CREATE TYPE payment_mode AS ENUM (
    'cash',
    'check',
    'bank_transfer',
    'mobile_payment'
);

CREATE TABLE payment_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- Montant et mode
    amount DECIMAL(12,2) NOT NULL,
    mode payment_mode NOT NULL DEFAULT 'cash',
    
    -- Type de paiement
    payment_type payment_type NOT NULL,
    
    -- Références
    delivery_id UUID REFERENCES deliveries(id),
    order_id UUID REFERENCES orders(id),
    
    -- Collecteur
    collected_by UUID REFERENCES users(id),
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Pour chèques
    check_number VARCHAR(50),
    check_bank VARCHAR(100),
    check_date DATE,
    
    -- Réconciliation
    receipt_number VARCHAR(50),
    
    -- Balance après paiement
    customer_debt_before DECIMAL(12,2),
    customer_debt_after DECIMAL(12,2),
    
    -- Application aux commandes (FIFO par défaut)
    applied_to JSONB DEFAULT '[]'::jsonb,  -- [{order_id, amount}]
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_payments_org ON payment_history(organization_id);
CREATE INDEX idx_payments_customer ON payment_history(customer_id);
CREATE INDEX idx_payments_date ON payment_history(organization_id, collected_at DESC);
CREATE INDEX idx_payments_collector ON payment_history(collected_by, collected_at);
CREATE INDEX idx_payments_delivery ON payment_history(delivery_id) WHERE delivery_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. CAISSE JOURNALIÈRE LIVREUR
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE daily_cash (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    deliverer_id UUID NOT NULL REFERENCES users(id),
    
    date DATE NOT NULL,
    
    -- Montants
    expected_collection DECIMAL(12,2) DEFAULT 0,  -- Total attendu
    actual_collection DECIMAL(12,2) DEFAULT 0,    -- Total collecté
    new_debt_created DECIMAL(12,2) DEFAULT 0,     -- Nouvelles dettes
    
    -- Statistiques
    deliveries_total INTEGER DEFAULT 0,
    deliveries_completed INTEGER DEFAULT 0,
    deliveries_failed INTEGER DEFAULT 0,
    
    -- Clôture
    is_closed BOOLEAN DEFAULT false,
    closed_at TIMESTAMP WITH TIME ZONE,
    closed_by UUID REFERENCES users(id),
    
    -- Remise d'argent
    cash_handed_over DECIMAL(12,2),
    discrepancy DECIMAL(12,2),
    discrepancy_notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(deliverer_id, date)
);

CREATE INDEX idx_daily_cash_deliverer ON daily_cash(deliverer_id, date DESC);
CREATE INDEX idx_daily_cash_org ON daily_cash(organization_id, date DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. TRANSACTIONS DE LIVRAISON (Détail)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE delivery_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    payment_id UUID REFERENCES payment_history(id),
    
    -- Type de transaction
    type VARCHAR(30) NOT NULL,  -- 'delivery', 'full_payment', 'partial_payment', 'debt_collection', 'failed'
    
    -- Détails financiers
    order_amount DECIMAL(12,2),
    debt_before DECIMAL(12,2),
    amount_paid DECIMAL(12,2),
    applied_to_order DECIMAL(12,2),
    applied_to_debt DECIMAL(12,2),
    new_debt_created DECIMAL(12,2),
    debt_after DECIMAL(12,2),
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_delivery_tx_delivery ON delivery_transactions(delivery_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Destinataire
    user_id UUID REFERENCES users(id),
    customer_id UUID REFERENCES customers(id),
    
    -- Contenu
    type VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    
    -- Canal
    channel VARCHAR(20) DEFAULT 'push',  -- 'push', 'sms', 'email', 'in_app'
    
    -- Statut
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    is_sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE,
    send_error TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX idx_notifications_customer ON notifications(customer_id, is_read, created_at DESC) WHERE customer_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. JOURNAL D'ACTIVITÉ (Audit Log)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Qui
    user_id UUID REFERENCES users(id),
    user_name VARCHAR(100),
    user_role VARCHAR(20),
    
    -- Quoi
    action VARCHAR(50) NOT NULL,  -- 'create', 'update', 'delete', 'login', etc.
    entity_type VARCHAR(50) NOT NULL,  -- 'order', 'customer', 'payment', etc.
    entity_id UUID,
    
    -- Détails
    description TEXT,
    old_values JSONB,
    new_values JSONB,
    
    -- Contexte
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_activity_org ON activity_log(organization_id, created_at DESC);
CREATE INDEX idx_activity_user ON activity_log(user_id, created_at DESC);
CREATE INDEX idx_activity_entity ON activity_log(entity_type, entity_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. REFRESH TOKENS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    customer_account_id UUID REFERENCES customer_accounts(id) ON DELETE CASCADE,
    
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Device info
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    device_id VARCHAR(100),
    
    is_revoked BOOLEAN DEFAULT false,
    revoked_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CHECK (user_id IS NOT NULL OR customer_account_id IS NOT NULL)
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_refresh_tokens_customer ON refresh_tokens(customer_account_id) WHERE customer_account_id IS NOT NULL;
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. PARAMÈTRES DE SYNCHRONISATION OFFLINE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Type de sync
    sync_type VARCHAR(20) NOT NULL,  -- 'full', 'incremental'
    direction VARCHAR(10) NOT NULL,  -- 'push', 'pull'
    
    -- Données
    entities_synced JSONB,  -- {orders: 5, payments: 3, ...}
    
    -- Statut
    status VARCHAR(20) NOT NULL,  -- 'success', 'partial', 'failed'
    error_message TEXT,
    
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Curseurs
    last_sync_at TIMESTAMP WITH TIME ZONE,
    sync_token VARCHAR(100)
);

CREATE INDEX idx_sync_log_user ON sync_log(user_id, started_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGERS POUR MISE À JOUR AUTOMATIQUE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Trigger updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer à toutes les tables avec updated_at
CREATE TRIGGER trg_updated_at_organizations BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_customers BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_products BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_orders BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_deliveries BEFORE UPDATE ON deliveries FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_updated_at_daily_cash BEFORE UPDATE ON daily_cash FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Mise à jour de la dette client
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_customer_debt()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_new_debt DECIMAL(12,2);
BEGIN
    -- Déterminer le customer_id
    IF TG_TABLE_NAME = 'orders' THEN
        v_customer_id := COALESCE(NEW.customer_id, OLD.customer_id);
    ELSIF TG_TABLE_NAME = 'payment_history' THEN
        v_customer_id := COALESCE(NEW.customer_id, OLD.customer_id);
    END IF;
    
    -- Calculer la nouvelle dette
    SELECT COALESCE(SUM(total - amount_paid), 0)
    INTO v_new_debt
    FROM orders
    WHERE customer_id = v_customer_id
    AND payment_status != 'paid'
    AND status NOT IN ('cancelled', 'draft');
    
    -- Mettre à jour le client
    UPDATE customers
    SET current_debt = v_new_debt
    WHERE id = v_customer_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_debt_on_order
    AFTER INSERT OR UPDATE OF amount_paid, payment_status, status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_debt();

CREATE TRIGGER trg_update_debt_on_payment
    AFTER INSERT OR DELETE ON payment_history
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_debt();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Mise à jour des statistiques client
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status NOT IN ('draft', 'cancelled') THEN
        UPDATE customers
        SET stats = jsonb_set(
            jsonb_set(
                jsonb_set(
                    stats,
                    '{total_orders}',
                    to_jsonb(COALESCE((stats->>'total_orders')::int, 0) + 1)
                ),
                '{total_revenue}',
                to_jsonb(COALESCE((stats->>'total_revenue')::decimal, 0) + NEW.total)
            ),
            '{last_order_at}',
            to_jsonb(NOW()::text)
        )
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customer_stats_on_order
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_stats();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Mise à jour payment stats après paiement
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_customer_payment_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE customers
    SET stats = jsonb_set(
        jsonb_set(
            stats,
            '{total_paid}',
            to_jsonb(COALESCE((stats->>'total_paid')::decimal, 0) + NEW.amount)
        ),
        '{last_payment_at}',
        to_jsonb(NOW()::text)
    )
    WHERE id = NEW.customer_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customer_stats_on_payment
    AFTER INSERT ON payment_history
    FOR EACH ROW
    WHEN (NEW.amount > 0)
    EXECUTE FUNCTION update_customer_payment_stats();

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

-- Activer RLS sur les tables principales
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_cash ENABLE ROW LEVEL SECURITY;

-- Politique: isolation par organisation
CREATE POLICY org_isolation_customers ON customers
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

CREATE POLICY org_isolation_products ON products
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

CREATE POLICY org_isolation_orders ON orders
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

CREATE POLICY org_isolation_deliveries ON deliveries
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

CREATE POLICY org_isolation_payments ON payment_history
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

CREATE POLICY org_isolation_daily_cash ON daily_cash
    FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

-- Policy pour order_items (via orders)
CREATE POLICY org_isolation_order_items ON order_items
    FOR ALL USING (
        order_id IN (
            SELECT id FROM orders 
            WHERE organization_id = current_setting('app.current_org_id', true)::uuid
        )
    );

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Fonction pour appliquer un paiement (FIFO sur les commandes)
CREATE OR REPLACE FUNCTION apply_payment_fifo(
    p_customer_id UUID,
    p_amount DECIMAL(12,2)
)
RETURNS TABLE (
    order_id UUID,
    amount_applied DECIMAL(12,2)
) AS $$
DECLARE
    v_remaining DECIMAL(12,2) := p_amount;
    v_order RECORD;
    v_to_apply DECIMAL(12,2);
BEGIN
    -- Parcourir les commandes impayées par date (FIFO)
    FOR v_order IN
        SELECT o.id, (o.total - o.amount_paid) as amount_due
        FROM orders o
        WHERE o.customer_id = p_customer_id
        AND o.payment_status != 'paid'
        AND o.status NOT IN ('cancelled', 'draft')
        ORDER BY o.created_at ASC
    LOOP
        EXIT WHEN v_remaining <= 0;
        
        v_to_apply := LEAST(v_remaining, v_order.amount_due);
        v_remaining := v_remaining - v_to_apply;
        
        -- Mettre à jour la commande
        UPDATE orders
        SET 
            amount_paid = amount_paid + v_to_apply,
            payment_status = CASE 
                WHEN amount_paid + v_to_apply >= total THEN 'paid'::payment_status
                ELSE 'partial'::payment_status
            END
        WHERE id = v_order.id;
        
        order_id := v_order.id;
        amount_applied := v_to_apply;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nettoyer les tokens expirés
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM refresh_tokens
    WHERE expires_at < NOW() OR is_revoked = true;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DONNÉES INITIALES (Catégories par défaut)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ces données seront créées lors de la création d'une nouvelle organisation
-- via la logique applicative

COMMENT ON TABLE organizations IS 'Table racine multi-tenant - chaque organisation est isolée';
COMMENT ON TABLE customers IS 'Clients/points de vente qui passent des commandes';
COMMENT ON TABLE orders IS 'Commandes des clients';
COMMENT ON TABLE deliveries IS 'Affectation des commandes aux livreurs';
COMMENT ON TABLE payment_history IS 'Historique complet des paiements';
COMMENT ON TABLE daily_cash IS 'Caisse journalière des livreurs pour réconciliation';

-- Fin du script
