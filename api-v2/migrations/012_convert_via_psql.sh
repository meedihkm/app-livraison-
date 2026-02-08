#!/bin/bash
# Script pour exécuter la conversion via psql

# Variables de connexion (à adapter selon ton environnement Coolify)
DB_HOST="localhost"  # ou l'IP de ton service PostgreSQL
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASSWORD="ton_mot_de_passe"

# Exécuter le script SQL
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f api-v2/migrations/011_convert_uuid_simple.sql

echo "Conversion terminée!"
