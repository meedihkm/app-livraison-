#!/bin/bash
# Script pour supprimer tous les cast ::text inutiles après conversion UUID

echo "🔧 Suppression des cast ::text inutiles..."

# Fonction pour remplacer dans un fichier
fix_file() {
    local file=$1
    echo "  Traitement: $file"
    
    # Remplacer les patterns courants
    sed -i 's/\.id::text/\.id/g' "$file"
    sed -i 's/= \$[0-9]*::text/= \$\1/g' "$file"
    sed -i 's/\$[0-9]*::text\[\]/\$\1[]/g' "$file"
    sed -i 's/customer_id::text/customer_id/g' "$file"
    sed -i 's/organization_id::text/organization_id/g' "$file"
    sed -i 's/product_id::text/product_id/g' "$file"
    sed -i 's/user_id::text/user_id/g' "$file"
    sed -i 's/order_id::text/order_id/g' "$file"
    sed -i 's/deliverer_id::text/deliverer_id/g' "$file"
    sed -i 's/packaging_type_id::text/packaging_type_id/g' "$file"
    sed -i 's/recorded_by::text/recorded_by/g' "$file"
    sed -i 's/recurring_order_id::text/recurring_order_id/g' "$file"
}

# Traiter tous les fichiers JavaScript dans api-v2
find api-v2 -name "*.js" -type f | while read file; do
    if grep -q "::text" "$file"; then
        fix_file "$file"
    fi
done

echo "✅ Terminé!"
echo ""
echo "📋 Fichiers modifiés:"
find api-v2 -name "*.js" -type f -exec grep -l "::text" {} \; 2>/dev/null || echo "  Aucun ::text restant!"
