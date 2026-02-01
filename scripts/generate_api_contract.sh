#!/bin/bash

# 📝 Script de Génération Automatique du Contrat API
# Extrait tous les endpoints du backend et génère API_CONTRACT.md

set -e

OUTPUT_FILE="API_CONTRACT.md"
TEMP_FILE="/tmp/api_contract_temp.md"

echo "📝 Génération du contrat API..."

# Initialiser le fichier
cat > "$TEMP_FILE" << 'EOF'
# 📋 CONTRAT API - Application AWID

**Version**: 2.0.0  
**Base URL**: `https://api.awid.com` (production) ou `http://localhost:3000` (dev)  
**Authentification**: Bearer Token (JWT)  
**Format**: JSON

---

## 🔐 Authentification

Toutes les routes protégées nécessitent un header:
```
Authorization: Bearer <access_token>
```

Les tokens expirent après 15 minutes. Utiliser `/auth/refresh` pour renouveler.

---

## 📚 TABLE DES MATIÈRES

EOF

# Fonction pour extraire les routes d'un fichier
extract_routes() {
    local file=$1
    local route_prefix=$2
    
    echo "  Analyse de $file..."
    
    # Extraire les définitions de routes
    grep -E "router\.(get|post|put|patch|delete)\(" "$file" | while IFS= read -r line; do
        # Extraire la méthode HTTP
        method=$(echo "$line" | sed -E "s/.*router\.([a-z]+)\(.*/\1/" | tr '[:lower:]' '[:upper:]')
        
        # Extraire le chemin
        path=$(echo "$line" | sed -E "s/.*router\.[a-z]+\(['\"]([^'\"]+)['\"].*/\1/")
        
        # Construire l'endpoint complet
        endpoint="$route_prefix$path"
        
        echo "$method|$endpoint"
    done
}

# Générer la table des matières
echo "## Routes par Domaine" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Parcourir tous les fichiers de routes
for route_file in api-v2/routes/*.routes.js; do
    route_name=$(basename "$route_file" .routes.js)
    
    # Déterminer le préfixe de route
    case "$route_name" in
        "auth") prefix="/api/auth" ;;
        "products") prefix="/api/products" ;;
        "users") prefix="/api/users" ;;
        "orders") prefix="/api/orders" ;;
        "deliveries") prefix="/api/deliveries" ;;
        "financial") prefix="/api/financial" ;;
        "packaging") prefix="/api/packaging" ;;
        "recurring-orders") prefix="/api/recurring-orders" ;;
        "favorites") prefix="/api/favorites" ;;
        "notifications") prefix="/api/notifications" ;;
        "organization") prefix="/api/organization" ;;
        "superAdmin") prefix="/api/super-admin" ;;
        "health") prefix="/api/health" ;;
        "realtime") prefix="/api/realtime" ;;
        *) prefix="/api/$route_name" ;;
    esac
    
    echo "- [$route_name](#$route_name)" >> "$TEMP_FILE"
done

echo "" >> "$TEMP_FILE"
echo "---" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Générer les détails pour chaque domaine
for route_file in api-v2/routes/*.routes.js; do
    route_name=$(basename "$route_file" .routes.js)
    
    # Déterminer le préfixe
    case "$route_name" in
        "auth") prefix="/api/auth" ;;
        "products") prefix="/api/products" ;;
        "users") prefix="/api/users" ;;
        "orders") prefix="/api/orders" ;;
        "deliveries") prefix="/api/deliveries" ;;
        "financial") prefix="/api/financial" ;;
        "packaging") prefix="/api/packaging" ;;
        "recurring-orders") prefix="/api/recurring-orders" ;;
        "favorites") prefix="/api/favorites" ;;
        "notifications") prefix="/api/notifications" ;;
        "organization") prefix="/api/organization" ;;
        "superAdmin") prefix="/api/super-admin" ;;
        "health") prefix="/api/health" ;;
        "realtime") prefix="/api/realtime" ;;
        *) prefix="/api/$route_name" ;;
    esac
    
    echo "## $route_name" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Vérifier si la route est montée
    if grep -q "$route_name" api-v2/index.js; then
        echo "**Statut**: ✅ Montée" >> "$TEMP_FILE"
    else
        echo "**Statut**: ❌ NON MONTÉE (code mort)" >> "$TEMP_FILE"
    fi
    
    echo "" >> "$TEMP_FILE"
    
    # Extraire et lister les endpoints
    extract_routes "$route_file" "$prefix" | sort -u | while IFS='|' read -r method endpoint; do
        echo "### $method $endpoint" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # Déterminer l'authentification requise
        if grep -A 5 "router\.$method" "$route_file" | grep -q "authenticate"; then
            echo "**Auth**: ✅ Requise" >> "$TEMP_FILE"
        else
            echo "**Auth**: ❌ Publique" >> "$TEMP_FILE"
        fi
        
        # Déterminer les rôles autorisés
        if grep -A 5 "router\.$method" "$route_file" | grep -q "requireAdmin"; then
            echo "**Rôles**: Admin" >> "$TEMP_FILE"
        elif grep -A 5 "router\.$method" "$route_file" | grep -q "requireDeliverer"; then
            echo "**Rôles**: Deliverer" >> "$TEMP_FILE"
        elif grep -A 5 "router\.$method" "$route_file" | grep -q "authorize"; then
            roles=$(grep -A 5 "router\.$method" "$route_file" | grep "authorize" | sed -E "s/.*authorize\(\[([^\]]+)\]\).*/\1/")
            echo "**Rôles**: $roles" >> "$TEMP_FILE"
        else
            echo "**Rôles**: Tous (si authentifié)" >> "$TEMP_FILE"
        fi
        
        echo "" >> "$TEMP_FILE"
        echo "**Description**: TODO - À documenter" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # Template pour body/response
        if [ "$method" == "POST" ] || [ "$method" == "PUT" ] || [ "$method" == "PATCH" ]; then
            echo "**Body**:" >> "$TEMP_FILE"
            echo '```json' >> "$TEMP_FILE"
            echo "{" >> "$TEMP_FILE"
            echo '  "TODO": "À documenter"' >> "$TEMP_FILE"
            echo "}" >> "$TEMP_FILE"
            echo '```' >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
        fi
        
        echo "**Response 200**:" >> "$TEMP_FILE"
        echo '```json' >> "$TEMP_FILE"
        echo "{" >> "$TEMP_FILE"
        echo '  "success": true,' >> "$TEMP_FILE"
        echo '  "data": {}' >> "$TEMP_FILE"
        echo "}" >> "$TEMP_FILE"
        echo '```' >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        echo "**Errors**:" >> "$TEMP_FILE"
        echo "- 400: Validation error" >> "$TEMP_FILE"
        echo "- 401: Unauthorized" >> "$TEMP_FILE"
        echo "- 403: Forbidden" >> "$TEMP_FILE"
        echo "- 404: Not found" >> "$TEMP_FILE"
        echo "- 500: Server error" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "---" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
    done
done

# Ajouter section sur les codes d'erreur
cat >> "$TEMP_FILE" << 'EOF'

## 📊 Codes de Réponse HTTP

| Code | Signification | Utilisation |
|------|---------------|-------------|
| 200 | OK | Requête réussie (GET, PUT, PATCH) |
| 201 | Created | Ressource créée (POST) |
| 204 | No Content | Suppression réussie (DELETE) |
| 400 | Bad Request | Validation échouée, paramètres invalides |
| 401 | Unauthorized | Token manquant ou invalide |
| 403 | Forbidden | Token valide mais permissions insuffisantes |
| 404 | Not Found | Ressource introuvable |
| 409 | Conflict | Conflit (ex: email déjà utilisé) |
| 429 | Too Many Requests | Rate limit dépassé |
| 500 | Internal Server Error | Erreur serveur |

---

## 🔒 Rôles et Permissions

| Rôle | Description | Accès |
|------|-------------|-------|
| `customer` | Client final | Ses propres commandes, profil |
| `deliverer` | Livreur | Ses livraisons, mise à jour statuts |
| `kitchen` | Cuisine | Commandes à préparer |
| `admin` | Administrateur | Toutes les ressources de son organisation |
| `super-admin` | Super Admin | Gestion multi-tenant |

---

## 📝 Format des Réponses

### Succès
```json
{
  "success": true,
  "data": { ... },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Erreur
```json
{
  "success": false,
  "error": "Message d'erreur explicite",
  "details": { ... }
}
```

---

## 🔄 Pagination

Les endpoints de liste supportent la pagination via query params:
- `page`: Numéro de page (défaut: 1)
- `limit`: Éléments par page (défaut: 20, max: 100)

Exemple: `GET /api/orders?page=2&limit=50`

---

## 🔍 Filtres

Certains endpoints supportent des filtres:
- `status`: Filtrer par statut
- `customerId`: Filtrer par client
- `delivererId`: Filtrer par livreur
- `dateFrom`, `dateTo`: Filtrer par période

Exemple: `GET /api/orders?status=pending&customerId=123`

---

## 📅 Format des Dates

Toutes les dates sont au format ISO 8601:
- `2026-01-25T14:30:00.000Z` (UTC)
- `2026-01-25` (date seule)

---

## 🌐 Headers Requis

```
Content-Type: application/json
Authorization: Bearer <token>
```

---

## 🚀 Rate Limiting

- **Global**: 100 requêtes / 15 minutes
- **Auth**: 5 tentatives / 15 minutes
- **Super Admin**: 10 requêtes / minute

---

**Généré automatiquement le $(date '+%Y-%m-%d %H:%M:%S')**
EOF

# Copier le fichier temporaire vers la destination
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "✅ Contrat API généré dans $OUTPUT_FILE"
echo ""
echo "📊 Statistiques:"
ENDPOINT_COUNT=$(grep -c "^### " "$OUTPUT_FILE" || echo "0")
ROUTE_COUNT=$(grep -c "^## " "$OUTPUT_FILE" || echo "0")
echo "  - $ROUTE_COUNT domaines"
echo "  - $ENDPOINT_COUNT endpoints"
echo ""
echo "⚠️  Note: Les descriptions sont à compléter manuellement"
