-- Script de création des tables manquantes pour le dashboard super admin
-- Phases 1-7

-- 1. Table generated_reports (Phase 5 - Rapports)
CREATE TABLE IF NOT EXISTS generated_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(50) NOT NULL,
    period JSONB NOT NULL,
    format VARCHAR(20) NOT NULL,
    data JSONB NOT NULL,
    generated_by UUID REFERENCES users(id),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_generated_reports_type ON generated_reports(type);
CREATE INDEX IF NOT EXISTS idx_generated_reports_generated_at ON generated_reports(generated_at);

-- 2. Table blocked_ips (Phase 1 - Sécurité)
CREATE TABLE IF NOT EXISTS blocked_ips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    reason TEXT,
    blocked_until TIMESTAMP WITH TIME ZONE,
    permanent BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_ips_ip ON blocked_ips(ip_address);
CREATE INDEX IF NOT EXISTS idx_blocked_ips_blocked_until ON blocked_ips(blocked_until);

-- 3. Table system_settings (Phase 6 - Paramètres)
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL,
    key VARCHAR(100) NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(category, key)
);

CREATE INDEX IF NOT EXISTS idx_system_settings_category ON system_settings(category);

-- 4. Table super_admin_config (Phase 1 - 2FA)
CREATE TABLE IF NOT EXISTS super_admin_config (
    id INTEGER PRIMARY KEY DEFAULT 1,
    twofa_secret VARCHAR(255),
    twofa_enabled BOOLEAN DEFAULT false,
    twofa_backup_codes TEXT[],
    twofa_setup_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CHECK (id = 1)
);

-- Insérer la ligne par défaut pour super_admin_config
INSERT INTO super_admin_config (id, twofa_enabled) 
VALUES (1, false) 
ON CONFLICT (id) DO NOTHING;

-- Vérification finale
SELECT 'Tables créées avec succès!' as message;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('generated_reports', 'blocked_ips', 'system_settings', 'super_admin_config')
ORDER BY table_name;
