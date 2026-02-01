# 📖 Guide de Migration Progressive

Ce guide explique comment migrer votre code existant vers les nouvelles APIs sans tout casser.

---

## 🔄 Approche Recommandée: Côte à Côte

Les anciennes et nouvelles versions peuvent coexister. Vous pouvez migrer page par page.

```
Avant:                        Après migration progressive:
┌─────────────────┐           ┌─────────────────┐
│ FinancialPage   │           │ FinancialPage   │
│ (ancien code)   │     →     │ (nouveau code)  │
└─────────────────┘           └─────────────────┘
       │                             │
       ▼                             ▼
┌─────────────────┐           ┌─────────────────┐
│ FinancialService│           │ FinancialServiceV2 │
│ (legacy)        │           │ (nouveau)       │
└─────────────────┘           └─────────────────┘
       │                             │
       ▼                             ▼
/api/financial/*              /api/financial/v2/*
```

---

## 📱 Migration Mobile (Flutter)

### Étape 1: Remplacer _parseDouble (5 minutes par fichier)

**Fichier**: N'importe quel fichier avec `_parseDouble`

```dart
// 1. Ajouter l'import en haut du fichier
import '../core/extensions/number_extensions.dart';

// 2. Supprimer la méthode _parseDouble locale
// SUPPRIMER:
// double _parseDouble(dynamic v) {
//   if (v == null) return 0;
//   ...
// }

// 3. Remplacer les appels
// AVANT:
// final total = _parseDouble(order['total']);

// APRÈS:
final total = order['total'].toDoubleOrZero();

// Avec les extensions JsonParsing sur Map:
// final total = order.getDouble('total');
```

### Étape 2: Utiliser les Modèles Typés (10 minutes par fichier)

**Fichier**: `financial_page.dart` ou `admin_dashboard.dart`

```dart
// 1. Ajouter l'import
import '../core/models/financial_models.dart';

// 2. Changer les types des variables d'état
// AVANT:
// Map<String, dynamic>? _overview;
// List<dynamic> _debts = [];

// APRÈS:
FinancialOverview? _overview;
List<CustomerDebt> _debts = [];

// 3. Mettre à jour la méthode de chargement
// AVANT:
// Future<void> _loadData() async {
//   final response = await _financialService.getFinancialOverview();
//   setState(() {
//     _overview = response['data'];
//   });
// }

// APRÈS:
Future<void> _loadData() async {
  final service = FinancialServiceV2();
  final overview = await service.getOverview();
  setState(() {
    _overview = overview;  // Typé, pas besoin de ['data']
  });
}
```

### Étape 3: Mettre à jour les Widgets (15 minutes par fichier)

```dart
// AVANT:
ListView.builder(
  itemCount: _debts.length,
  itemBuilder: (context, index) {
    final debt = _debts[index];  // dynamic
    return ListTile(
      title: Text(debt['name']),  // Pas d'autocomplétion
      subtitle: Text('${debt['totalDebt']} DA'),  // Risque d'erreur
    );
  },
)

// APRÈS:
ListView.builder(
  itemCount: _debts.length,
  itemBuilder: (context, index) {
    final debt = _debts[index];  // CustomerDebt
    return ListTile(
      title: Text(debt.name),  // ✅ Autocomplétion
      subtitle: Text(debt.totalDebt.toCurrency()),  // ✅ Extension
      trailing: debt.credit?.isCritical == true  // ✅ Type safety
          ? Icon(Icons.warning, color: Colors.red)
          : null,
    );
  },
)
```

---

## 🧪 Exemple Complet: Migration de `financial_page.dart`

### Avant
```dart
class _FinancialPageState extends State<FinancialPage> {
  final _financialService = FinancialService();
  Map<String, dynamic>? _overview;
  List<dynamic> _debts = [];
  
  double _parseDouble(dynamic v) {  // ❌ Dupliqué
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 0;
  }
  
  Future<void> _loadData() async {
    final results = await Future.wait([
      _financialService.getFinancialOverview(),
      _financialService.getDebts(limit: 100),
    ]);
    setState(() {
      _overview = results[0]['data'];  // ❌ dynamic
      _debts = results[1]['data'] ?? [];  // ❌ dynamic
    });
  }
  
  Widget _buildSummarySection() {
    final summary = _overview!['summary'];  // ❌ Pas de vérification
    return Text('${_parseDouble(summary['totalRevenue'])} DA');
  }
}
```

### Après
```dart
import '../core/extensions/number_extensions.dart';
import '../core/models/financial_models.dart';
import '../core/services/financial_service_v2.dart';

class _FinancialPageState extends State<FinancialPage> {
  final _financialService = FinancialServiceV2();  // ✅ Nouveau service
  FinancialOverview? _overview;  // ✅ Typé
  List<CustomerDebt> _debts = [];  // ✅ Typé
  
  Future<void> _loadData() async {
    try {
      final overview = await _financialService.getOverview();
      final debts = await _financialService.getDebts(limit: 100);
      setState(() {
        _overview = overview;  // ✅ Direct, pas besoin de ['data']
        _debts = debts.data;  // ✅ PaginatedDebts.data
      });
    } on FinancialException catch (e) {
      // ✅ Gestion d'erreur typée
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
  
  Widget _buildSummarySection() {
    final summary = _overview!.summary;  // ✅ Autocomplétion
    return Text(summary.totalRevenue.toCurrency());  // ✅ Extension
  }
}
```

---

## 🗄️ Migration Base de Données

### Étape 1: Vérifier le Backup

```bash
# Avant toute manipulation de la DB
pg_dump -h votre-host -U votre-user votre-db > backup_avant_migration.sql
```

### Étape 2: Exécuter la Migration

```bash
# Se connecter
psql -h votre-host -U votre-user votre-db

# Exécuter
\i api-v2/migrations/004_create_financial_schema.sql

# Vérifier
\dt payments payment_orders debt_history
```

### Étape 3: Migrer les Données (Optionnel)

```bash
# Migrer les anciens paiements depuis audit_logs
\i api-v2/migrations/005_migrate_payment_data.sql
```

---

## 🧪 Vérifier que Tout Fonctionne

### Tests Backend

```bash
# Test rapide avec curl
curl /api/financial/v2/overview -H "Authorization: Bearer TOKEN"

# Test complet
./test/financial_api_test.sh http://localhost:3000/api YOUR_TOKEN
```

### Tests Mobile

```bash
# Tests unitaires
flutter test test/extensions_test.dart

# Test d'intégration
flutter test integration_test/financial_flow_test.dart
```

---

## ✅ Checklist de Validation

### Pour chaque fichier migré:

- [ ] Les imports sont corrects
- [ ] `_parseDouble` est remplacé par `.toDoubleOrZero()`
- [ ] Les types `Map<String, dynamic>` sont remplacés par des modèles
- [ ] Aucune erreur de compilation (`flutter analyze`)
- [ ] Les tests passent (`flutter test`)
- [ ] L'UI fonctionne correctement en test manuel

### Pour le backend:

- [ ] Migration SQL exécutée sans erreur
- [ ] Routes `/api/financial/v2/*` répondent
- [ ] Anciennes routes `/api/financial/*` fonctionnent toujours
- [ ] Les logs ne montrent pas d'erreurs

---

## 🚨 Rollback (En Cas de Problème)

### Backend
```bash
# Simplement redémarrer avec l'ancienne version
git checkout HEAD -- api-v2/index.js
npm restart

# Les tables nouvellement créées n'affectent pas l'ancien code
```

### Mobile
```bash
# Revenir au fichier précédent
git checkout HEAD -- mobile/lib/features/admin/presentation/pages/financial_page.dart

# Ou simplement annuler les modifications manuelles
```

---

## 📊 Temps de Migration Estimé

| Étape | Temps | Complexité |
|-------|-------|------------|
| Remplacer `_parseDouble` | 30 min | ⭐ Facile |
| Migrer 1 page vers modèles | 1h | ⭐⭐ Moyen |
| Migrer tous les services | 4h | ⭐⭐ Moyen |
| Tests complets | 2h | ⭐⭐ Moyen |
| **Total** | **~8h** | |

---

## 💡 Conseils

1. **Commencez par une page simple** (pas le dashboard principal)
2. **Testez après chaque fichier** modifié
3. **Gardez l'ancien code commenté** temporairement
4. **Utilisez Git** pour pouvoir revenir en arrière
5. **Migrez par petits commits** (un fichier à la fois)

---

*Questions? Référez-vous à `REFACTORING_STATUS.md` pour le statut complet.*
