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

-- 3. Créer la fonction detect_order_pattern
DROP FUNCTION IF EXISTS detect_order_pattern(uuid, uuid, text);

CREATE OR REPLACE FUNCTION detect_order_pattern(
  p_client_id uuid,
  p_organization_id uuid,
  p_items_json text
)
RETURNS jsonb AS $$
DECLARE
  v_items jsonb;
  v_product_ids uuid[];
  v_occurrences integer;
  v_min_pattern_count integer;
  v_should_suggest boolean;
BEGIN
  -- Parser le JSON des items
  v_items := p_items_json::jsonb;
  
  -- Extraire les product_ids
  SELECT array_agg(DISTINCT (item->>'productId')::uuid)
  INTO v_product_ids
  FROM jsonb_array_elements(v_items) AS item;
  
  -- Récupérer le seuil minimum depuis les préférences utilisateur (défaut: 3)
  SELECT COALESCE(min_pattern_count, 3)
  INTO v_min_pattern_count
  FROM user_preferences
  WHERE user_id = p_client_id;
  
  -- Si pas de préférences, utiliser 3 par défaut
  IF v_min_pattern_count IS NULL THEN
    v_min_pattern_count := 3;
  END IF;
  
  -- Compter combien de fois ce pattern exact a été commandé
  -- On cherche les commandes qui contiennent EXACTEMENT les mêmes produits
  SELECT COUNT(DISTINCT o.id)
  INTO v_occurrences
  FROM orders o
  WHERE o.customer_id = p_client_id
    AND o.organization_id = p_organization_id
    AND o.status NOT IN ('cancelled')
    AND (
      -- Vérifier que la commande contient exactement les mêmes produits
      SELECT array_agg(DISTINCT oi.product_id ORDER BY oi.product_id)
      FROM order_items oi
      WHERE oi.order_id = o.id
    ) = (
      SELECT array_agg(DISTINCT pid ORDER BY pid)
      FROM unnest(v_product_ids) AS pid
    );
  
  -- Déterminer si on doit suggérer de sauvegarder comme favori
  v_should_suggest := v_occurrences >= v_min_pattern_count;
  
  -- Retourner le résultat
  RETURN jsonb_build_object(
    'hasPattern', v_should_suggest,
    'should_suggest', v_should_suggest,
    'occurrences', v_occurrences,
    'minPatternCount', v_min_pattern_count
  );
END;
$$ LANGUAGE plpgsql;

-- 4. Vérifier les autres fonctions avec TEXT qui devraient être UUID
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
