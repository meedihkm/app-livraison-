-- Création de la table payment_orders pour lier les paiements aux commandes
-- Date: 2026-02-04
-- Cette table permet de tracer quels paiements ont été appliqués à quelles commandes

CREATE TABLE IF NOT EXISTS payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    order_id UUID NOT NULL,
    amount_applied NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contraintes de clés étrangères
ALTER TABLE payment_orders 
ADD CONSTRAINT fk_payment_orders_payment 
FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE;

ALTER TABLE payment_orders 
ADD CONSTRAINT fk_payment_orders_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

-- Contrainte d'unicité pour éviter les doublons
ALTER TABLE payment_orders 
ADD CONSTRAINT unique_payment_order 
UNIQUE(payment_id, order_id);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_payment_orders_payment_id ON payment_orders(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_order_id ON payment_orders(order_id);

-- Commentaires
COMMENT ON TABLE payment_orders IS 'Table de liaison entre les paiements et les commandes';
COMMENT ON COLUMN payment_orders.payment_id IS 'Référence au paiement effectué';
COMMENT ON COLUMN payment_orders.order_id IS 'Référence à la commande payée';
COMMENT ON COLUMN payment_orders.amount_applied IS 'Montant du paiement appliqué à cette commande';
