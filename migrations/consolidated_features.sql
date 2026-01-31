-- Feature 1: Debt Management
CREATE TABLE IF NOT EXISTS debt_payments (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(id),
    customer_id INTEGER NOT NULL REFERENCES users(id),
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL, -- 'cash', 'transfer', etc.
    reference VARCHAR(100), -- Transaction ID or Note
    recorded_by INTEGER REFERENCES users(id), -- Admin/Deliverer who took the money
    created_at TIMESTAMP DEFAULT NOW()
);

-- Feature 2: Credit Limit
ALTER TABLE users ADD COLUMN IF NOT EXISTS credit_limit DECIMAL(10, 2) DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS credit_limit_enabled BOOLEAN DEFAULT false;

-- Feature 3: Packaging (Consignes)
CREATE TABLE IF NOT EXISTS packaging_types (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(id),
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    icon VARCHAR(50), 
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS packaging_deposits (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(id),
    customer_id INTEGER NOT NULL REFERENCES users(id),
    order_id INTEGER REFERENCES orders(id), -- Can be linked to an order or standalone
    packaging_type_id INTEGER REFERENCES packaging_types(id),
    quantity INTEGER NOT NULL, -- Positive = Given to customer, Negative = Returned by customer
    amount DECIMAL(10, 2) NOT NULL, -- Total value
    status VARCHAR(50) DEFAULT 'pending', -- 'pending' (delivered but not paid/returned), 'returned', 'paid'
    created_at TIMESTAMP DEFAULT NOW()
);

-- Feature 4: Recurring Orders
CREATE TABLE IF NOT EXISTS recurring_orders (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(id),
    customer_id INTEGER NOT NULL REFERENCES users(id),
    cafeteria_id INTEGER REFERENCES cafeterias(id),
    name VARCHAR(100), -- "Commande de Lundi"
    active BOOLEAN DEFAULT true,
    cron_expression VARCHAR(100) NOT NULL, -- "0 9 * * 1" (Every Monday at 9:00)
    next_generation_at TIMESTAMP,
    delivery_note TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recurring_order_items (
    id SERIAL PRIMARY KEY,
    recurring_order_id INTEGER NOT NULL REFERENCES recurring_orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL DEFAULT 1
);

-- Feature 10: Audit Log Fix
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS entity_type VARCHAR(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS entity_id INTEGER;
