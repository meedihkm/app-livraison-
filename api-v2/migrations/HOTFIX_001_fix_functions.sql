-- =====================================================
-- HOTFIX 001: Corriger les fonctions PostgreSQL
-- Date: 2026-02-05
-- Problème: Fonctions avec mauvais types après conversion UUID
-- =====================================================

-- 1. Corriger get_unread_count (TEXT → UUID)
DROP FUNCTION IF EXISTS get_unread_count(text);

CREATE OR REPLACE FUNCTION get_unread_count(p_user_id uuid)
RETURNS integer AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::integer
        FROM notifications
        WHERE user_id = p_user_id
          AND is_read = false
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
    );
END;
$$ LANGUAGE plpgsql;

-- 2. Corriger audit_logs.details (VARCHAR(100) → JSONB)
ALTER TABLE audit_logs 
ALTER COLUMN details TYPE jsonb USING 
  CASE 
    WHEN details IS NULL THEN NULL
    WHEN details::text = '' THEN NULL
    ELSE details::jsonb
  END;

-- 3. Vérifier les autres fonctions avec TEXT qui devraient être UUID
-- Liste des fonctions à vérifier:
SELECT 
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND pg_get_function_arguments(p.oid) LIKE '%text%'
ORDER BY p.proname;

-- Si d'autres fonctions apparaissent, les corriger ici
