-- =====================================================
-- MIGRATION: Renommer 'cafeteria' en 'customer'
-- Uniformiser le rÃ´le client dans toute la base de donnÃ©es
-- =====================================================

-- Ã‰tape 1: Mettre Ã  jour tous les utilisateurs avec role 'cafeteria' vers 'customer'
UPDATE users 
SET role = 'customer' 
WHERE role = 'cafeteria';

-- Ã‰tape 2: VÃ©rifier le rÃ©sultat
SELECT 
    role, 
    COUNT(*) as count 
FROM users 
GROUP BY role 
ORDER BY role;

-- Note: Cette migration est idempotente (peut Ãªtre exÃ©cutÃ©e plusieurs fois sans problÃ¨me)
