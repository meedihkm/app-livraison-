SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'payment_transactions'
ORDER BY ordinal_position;
