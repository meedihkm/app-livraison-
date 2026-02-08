-- ============================================
-- FIX: Adapter payment_orders pour accepter TEXT
-- Date: 2026-02-04
-- ============================================
-- Solution temporaire: Convertir payment_orders.order_id de UUID vers TEXT
-- pour correspondre à orders.id qui est en TEXT

-- Étape 1: Supprimer les contraintes existantes
ALTER TABLE payment_orders 
DROP CONSTRAINT IF EXISTS fk_payment_orders_payment;

ALTER TABLE payment_orders 
DROP CONSTRAINT IF EXISTS fk_payment_orders_order;

ALTER TABLE payment_orders 
DROP CONSTRAINT IF EXISTS unique_payment_order;

-- Étape 2: Convertir order_id de UUID vers TEXT
ALTER TABLE payment_orders 
ALTER COLUMN order_id TYPE TEXT USING order_id::TEXT;

-- Étape 3: Recréer les contraintes avec les bons types
ALTER TABLE payment_orders 
ADD CONSTRAINT fk_payment_orders_payment 
FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE;

ALTER TABLE payment_orders 
ADD CONSTRAINT fk_payment_orders_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

ALTER TABLE payment_orders 
ADD CONSTRAINT unique_payment_order 
UNIQUE(payment_id, order_id);

-- Étape 4: Adapter payments.customer_id et organization_id
-- payments.customer_id doit correspondre à users.id (TEXT)
-- payments.organization_id doit correspondre à organizations.id (TEXT)

-- Vérifier les types actuels
-- payments.customer_id est TEXT ✅
-- payments.organization_id est TEXT ✅
-- Pas besoin de conversion

-- Étape 5: Ajouter les foreign keys pour payments
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE payments 
ADD CONSTRAINT fk_payments_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Vérification finale
SELECT 
    'payment_orders' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'payment_orders'
AND column_name IN ('id', 'payment_id', 'order_id');
