-- Migration complÃ¨te pour corriger tous les problÃ¨mes de base de donnÃ©es
-- Date: 2026-01-24
-- Description: Correction des erreurs de structure et standardisation

-- ============================================
-- 1. CORRECTION: Supprimer la rÃ©fÃ©rence invalide Ã  cafeterias
-- ============================================
-- La table cafeterias n'existe pas, donc on supprime cette rÃ©fÃ©rence
ALTER TABLE recurring_orders DROP COLUMN IF EXISTS cafeteria_id;

-- ============================================
-- 2. CORRECTION: Ajouter les colonnes manquantes dans recurring_orders
-- ============================================
-- Remplacer cron_expression par des colonnes plus simples
ALTER TABLE recurring_orders DROP COLUMN IF EXISTS cron_expression;
ALTER TABLE recurring_orders DROP COLUMN IF EXISTS delivery_note;

ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS frequency VARCHAR(20) NOT NULL DEFAULT 'weekly';
ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS day_of_week INTEGER; -- 0=Dimanche, 1=Lundi, etc.
ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS day_of_month INTEGER; -- 1-31
ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS time_of_day TIME DEFAULT '06:00:00';
ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS last_generated_at TIMESTAMP;
ALTER TABLE recurring_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Ajouter une contrainte pour frequency
ALTER TABLE recurring_orders DROP CONSTRAINT IF EXISTS recurring_orders_frequency_check;
ALTER TABLE recurring_orders ADD CONSTRAINT recurring_orders_frequency_check 
  CHECK (frequency IN ('daily', 'weekly', 'monthly'));

-- ============================================
-- 3. CORRECTION: Standardiser customer_id partout
-- ============================================
-- VÃ©rifier si la colonne cafeteria_id existe encore dans orders
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'cafeteria_id'
    ) THEN
        -- Renommer cafeteria_id en customer_id
        ALTER TABLE orders RENAME COLUMN cafeteria_id TO customer_id;
    END IF;
END $$;

-- ============================================
-- 4. CORRECTION: Ajouter les colonnes manquantes dans audit_logs
-- ============================================
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS entity_type VARCHAR(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS entity_id TEXT;

-- ============================================
-- 5. CORRECTION: Ajouter les colonnes manquantes dans debt_payments
-- ============================================
-- Changer customer_id de INTEGER Ã  TEXT pour correspondre aux UUIDs
ALTER TABLE debt_payments ALTER COLUMN customer_id TYPE TEXT USING customer_id::TEXT;
ALTER TABLE debt_payments ALTER COLUMN recorded_by TYPE TEXT USING recorded_by::TEXT;
ALTER TABLE debt_payments ALTER COLUMN organization_id TYPE TEXT USING organization_id::TEXT;

-- Ajouter les colonnes manquantes
ALTER TABLE debt_payments ADD COLUMN IF NOT EXISTS payment_type VARCHAR(50) DEFAULT 'cash';
ALTER TABLE debt_payments ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE debt_payments ADD COLUMN IF NOT EXISTS collector_name VARCHAR(255);

-- Renommer payment_method en payment_type si nÃ©cessaire
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'debt_payments' AND column_name = 'payment_method'
    ) THEN
        ALTER TABLE debt_payments RENAME COLUMN payment_method TO payment_type;
    END IF;
END $$;

-- Renommer reference en note si nÃ©cessaire
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'debt_payments' AND column_name = 'reference'
    ) THEN
        ALTER TABLE debt_payments RENAME COLUMN reference TO note;
    END IF;
END $$;

-- ============================================
-- 6. CORRECTION: Ajouter les colonnes manquantes dans packaging_deposits
-- ============================================
-- Changer les types INTEGER en TEXT pour les UUIDs
ALTER TABLE packaging_deposits ALTER COLUMN customer_id TYPE TEXT USING customer_id::TEXT;
ALTER TABLE packaging_deposits ALTER COLUMN order_id TYPE TEXT USING order_id::TEXT;
ALTER TABLE packaging_deposits ALTER COLUMN organization_id TYPE TEXT USING organization_id::TEXT;

-- Ajouter colonne note
ALTER TABLE packaging_deposits ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE packaging_deposits ADD COLUMN IF NOT EXISTS recorded_by TEXT;

-- ============================================
-- 7. CORRECTION: RecrÃ©er les vues avec customer_id
-- ============================================

-- Supprimer les anciennes vues
DROP VIEW IF EXISTS client_debts_view CASCADE;
DROP VIEW IF EXISTS active_deliveries_view CASCADE;

-- RecrÃ©er client_debts_view avec customer_id
CREATE OR REPLACE VIEW client_debts_view AS
SELECT 
    o.customer_id,
    u.name as customer_name,
    u.phone as customer_phone,
    u.address as customer_address,
    COUNT(o.id) as total_orders,
    SUM(o.total) as total_amount,
    SUM(COALESCE(o.amount_paid, 0)) as total_paid,
    SUM(o.total - COALESCE(o.amount_paid, 0)) as total_debt,
    MAX(o.created_at) as last_order_date
FROM orders o
JOIN users u ON o.customer_id = u.id
WHERE o.payment_status != 'paid'
GROUP BY o.customer_id, u.name, u.phone, u.address
HAVING SUM(o.total - COALESCE(o.amount_paid, 0)) > 0;

-- RecrÃ©er active_deliveries_view avec customer_id
CREATE OR REPLACE VIEW active_deliveries_view AS
SELECT 
    d.id as delivery_id,
    d.status as delivery_status,
    d.deliverer_id,
    du.name as deliverer_name,
    o.id as order_id,
    o.customer_id,
    cu.name as customer_name,
    cu.phone as customer_phone,
    cu.address as customer_address,
    cu.address_lat,
    cu.address_lng,
    o.total as order_total,
    o.created_at as order_date,
    d.created_at as delivery_created_at
FROM deliveries d
JOIN orders o ON d.order_id = o.id
JOIN users cu ON o.customer_id = cu.id
LEFT JOIN users du ON d.deliverer_id = du.id
WHERE d.status IN ('assigned', 'in_progress');

-- ============================================
-- 8. CORRECTION: DÃ©sactiver le trigger problÃ©matique
-- ============================================
-- Le trigger update_client_address_from_delivery cause des erreurs
-- car il rÃ©fÃ©rence des colonnes qui n'existent pas
DROP TRIGGER IF EXISTS update_client_address_trigger ON deliveries;
DROP FUNCTION IF EXISTS update_client_address_from_delivery() CASCADE;

-- Note: La capture GPS est dÃ©jÃ  gÃ©rÃ©e dans l'application Flutter
-- donc ce trigger n'est plus nÃ©cessaire

-- ============================================
-- 9. CORRECTION: Fonction detect_order_pattern
-- ============================================
-- RecrÃ©er la fonction avec la bonne signature
DROP FUNCTION IF EXISTS detect_order_pattern(TEXT, TEXT, JSONB) CASCADE;

CREATE OR REPLACE FUNCTION detect_order_pattern(
    p_customer_id TEXT,
    p_organization_id TEXT,
    p_items JSONB
) RETURNS TABLE(
    pattern_name TEXT,
    frequency TEXT,
    confidence DECIMAL
) AS $$
BEGIN
    -- Fonction simplifiÃ©e pour dÃ©tecter les patterns de commande
    -- Retourne des suggestions basÃ©es sur l'historique
    RETURN QUERY
    SELECT 
        'Commande habituelle'::TEXT as pattern_name,
        'weekly'::TEXT as frequency,
        0.8::DECIMAL as confidence
    LIMIT 0; -- DÃ©sactivÃ© pour l'instant
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. CORRECTION: Index pour amÃ©liorer les performances
-- ============================================
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_organization_id ON orders(organization_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_deliverer_id ON deliveries(deliverer_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_recurring_orders_customer_id ON recurring_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_recurring_orders_next_generation ON recurring_orders(next_generation_at) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_debt_payments_customer_id ON debt_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_packaging_deposits_customer_id ON packaging_deposits(customer_id);

-- ============================================
-- FIN DE LA MIGRATION
-- ============================================

-- Afficher un message de succÃ¨s
DO $$ 
BEGIN
    RAISE NOTICE 'âœ… Migration complÃ©tÃ©e avec succÃ¨s!';
    RAISE NOTICE 'ðŸ“Š VÃ©rifiez les vues: client_debts_view, active_deliveries_view';
    RAISE NOTICE 'ðŸ”§ Trigger update_client_address_from_delivery dÃ©sactivÃ© (gÃ©rÃ© par Flutter)';
END $$;
