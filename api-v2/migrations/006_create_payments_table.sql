-- Création de la table payments pour les paiements de dettes
-- Date: 2026-02-03

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id TEXT NOT NULL REFERENCES organizations(id),
    customer_id TEXT NOT NULL REFERENCES users(id),
    amount DECIMAL(10, 2) NOT NULL,
    mode VARCHAR(50) NOT NULL DEFAULT 'cash', -- 'cash', 'check', 'transfer'
    recorded_by TEXT REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_organization_id ON payments(organization_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
