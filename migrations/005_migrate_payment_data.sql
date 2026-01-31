-- =====================================================
-- MIGRATION: Migration des donnÃ©es de paiement
-- Migre les paiements depuis audit_logs vers payments
-- ATTENTION: ExÃ©cuter uniquement aprÃ¨s avoir testÃ© l'API v2
-- =====================================================

BEGIN;

-- ============================================
-- MIGRATION DES PAIEMENTS EXISTANTS
-- ============================================

INSERT INTO payments (
    organization_id,
    customer_id,
    amount,
    mode,
    recorded_by,
    notes,
    created_at
)
SELECT 
    al.organization_id,
    (al.details->>'customerId')::UUID,
    (al.details->>'amount')::DECIMAL,
    COALESCE(al.details->>'mode', 'cash'),
    al.performed_by,
    al.details->>'notes',
    al.created_at
FROM audit_logs al
WHERE al.action = 'PAYMENT_RECORDED'
AND (al.details->>'customerId') IS NOT NULL
AND (al.details->>'customerId') <> ''
AND NOT EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.created_at = al.created_at 
    AND p.customer_id = (al.details->>'customerId')::UUID
    AND p.amount = (al.details->>'amount')::DECIMAL
)
ON CONFLICT DO NOTHING;

-- ============================================
-- RÃ‰SUMÃ‰ DE LA MIGRATION
-- ============================================
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM payments;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MIGRATION DES DONNÃ‰ES TERMINÃ‰E';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'âœ… % paiements migrÃ©s depuis audit_logs', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'ðŸ“ Note: Les anciennes donnÃ©es dans audit_logs';
    RAISE NOTICE '   sont conservÃ©es pour rÃ©fÃ©rence historique.';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
