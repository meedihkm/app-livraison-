# 🚀 Guide d'Implémentation - Refactorisation Finance

## Résumé

Ce guide vous permet d'implémenter la solution de refactorisation **sans interruption de service**.

---

## 📋 Prérequis

- [ ] Backup de la base de données
- [ ] Node.js 18+ et Flutter 3.16+
- [ ] Accès SSH au serveur de production
- [ ] Plan de rollback préparé

---

## Phase 1: Backend (Semaine 1)

### Jour 1: Préparation Base de Données

```bash
# 1. Backup
pg_dump -h your-host -U your-user your-db > backup_pre_financial_refactor.sql

# 2. Exécuter la migration
psql -h your-host -U your-user your-db -f api-v2/migrations/004_create_financial_schema.sql
```

**Vérification:**
```sql
-- Vérifier que les tables sont créées
SELECT tablename FROM pg_tables WHERE tablename IN ('payments', 'payment_orders', 'debt_history');

-- Vérifier que les vues matérialisées existent
SELECT matviewname FROM pg_matviews WHERE matviewname LIKE 'mv_%';
```

### Jour 2-3: Déployer le FinancialService

```bash
# 1. Copier le nouveau service
cp api-v2/services/financial.service.js your-server/api-v2/services/

# 2. Mettre à jour les routes pour utiliser le service
# (voir section "Refactorisation des Routes" ci-dessous)

# 3. Redémarrer le serveur
pm2 restart your-app
```

### Jour 4-5: Tests et Monitoring

```bash
# Test des nouveaux endpoints
curl -X GET "https://your-api/api/financial/overview" \
  -H "Authorization: Bearer YOUR_TOKEN"

curl -X POST "https://your-api/api/financial/payments" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "xxx",
    "amount": 1000,
    "mode": "cash"
  }'
```

---

## Phase 2: Mobile (Semaine 2)

### Jour 1-2: Mise à jour des Modèles

```bash
# Dans le dossier mobile/
cd mobile

# 1. Ajouter les dépendances (si pas déjà présentes)
flutter pub add freezed_annotation json_annotation
flutter pub add dev:build_runner dev:freezed dev:json_serializable

# 2. Créer les fichiers
mkdir -p lib/core/extensions
cp mobile/lib/core/extensions/number_extensions.dart lib/core/extensions/
cp mobile/lib/core/models/financial_models.dart lib/core/models/

# 3. Générer le code
dart run build_runner build --delete-conflicting-outputs
```

### Jour 3-4: Refactorisation des Services

**Avant (api_service.dart):**
```dart
// ❌ SUPPRIMER ces méthodes de ApiService:
- getDailyFinancial()
- getDebts()
- getCustomerDebt()
- recordDebtPayment()
- getMyCollections()
```

**Après (financial_service.dart):**
```dart
// ✅ Utiliser uniquement FinancialService
final financialService = FinancialService();
final overview = await financialService.getOverview();
final debts = await financialService.getDebts();
```

### Jour 5: Tests sur Device

```bash
# Build de test
flutter build apk --debug

# Tests sur différents devices
flutter test integration_test/financial_flow_test.dart
```

---

## Phase 3: Nettoyage (Semaine 3)

### Suppression du Code Legacy

**Côté API:**
```javascript
// ❌ SUPPRIMER dans organization.routes.js:
// GET /api/organization/daily
// GET /api/organization/debts

// ❌ SUPPRIMER les duplications dans financial.routes.js:
// - Fonctions parseNumber() locales
// - Requêres SQL en dur (utiliser FinancialService)
```

**Côté Mobile:**
```dart
// ❌ SUPPRIMER dans tous les fichiers:
// - double _parseDouble(dynamic v) { ... }
// 
// ✅ REMPLACER PAR:
// - import 'package:your_app/core/extensions/number_extensions.dart';
// - value.toDoubleOrZero()
```

---

## 🔧 Refactorisation des Routes (API)

### Nouvelle structure simplifiée

**`api-v2/routes/financial.routes.js` (Nouvelle version):**
```javascript
const express = require("express");
const router = express.Router();
const { authenticate, authorize } = require("../middleware/auth");
const financialService = require("../services/financial.service");

// GET /api/financial/overview
router.get("/overview", authenticate, authorize(["admin"]), async (req, res) => {
  try {
    const { dateFrom, dateTo } = req.query;
    const data = await financialService.getOverview(req.user.organization_id, {
      dateFrom,
      dateTo,
    });
    res.json({ success: true, data });
  } catch (error) {
    console.error("Financial overview error:", error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/financial/debts
router.get("/debts", authenticate, authorize(["admin", "deliverer"]), async (req, res) => {
  try {
    const { page, limit, minDebt, customerId } = req.query;
    const result = await financialService.getDebts(req.user.organization_id, {
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 50,
      minDebt: parseFloat(minDebt) || 0,
      customerId,
      delivererId: req.user.role === "deliverer" ? req.user.id : null,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error("Get debts error:", error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/financial/payments
router.post("/payments", authenticate, authorize(["admin", "deliverer"]), async (req, res) => {
  try {
    const { customerId, amount, mode, notes, targetOrders } = req.body;
    
    const result = await financialService.recordPayment(
      { customerId, amount, mode, notes, targetOrders },
      req.user.id,
      req.user.organization_id
    );
    
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    console.error("Record payment error:", error);
    res.status(400).json({ error: error.message });
  }
});

// ... autres routes simplifiées

module.exports = router;
```

---

## 📱 Refactorisation Mobile (Exemples)

### Exemple 1: Remplacer _parseDouble

**Avant:**
```dart
// client_detail_page.dart

class _ClientDetailPageState extends State<ClientDetailPage> {
  double _parseDouble(dynamic v) {  // ❌ DUPLIQUÉ 5+ FOIS
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
  
  double get _totalDebt {
    double debt = 0;
    for (final o in _orders) {
      debt += _parseDouble(o['total']) - _parseDouble(o['amountPaid']);
    }
    return debt;
  }
}
```

**Après:**
```dart
// client_detail_page.dart
import '../../core/extensions/number_extensions.dart';

class _ClientDetailPageState extends State<ClientDetailPage> {
  double get _totalDebt {
    return _orders.fold(0.0, (sum, o) => 
      sum + o['total'].toDoubleOrZero() - o['amountPaid'].toDoubleOrZero()
    );
  }
}
```

### Exemple 2: Utiliser les Modèles Typés

**Avant:**
```dart
// financial_page.dart

class _FinancialPageState extends State<FinancialPage> {
  Map<String, dynamic>? _overview;  // ❌ Pas de type safety
  List<dynamic> _debts = [];        // ❌ Pas d'autocomplétion
  
  void _loadData() async {
    final results = await Future.wait([
      _financialService.getFinancialOverview(),
      _financialService.getDebts(),
    ]);
    setState(() {
      _overview = results[0]['data'];  // ❌ Risque d'erreur runtime
      _debts = results[1]['data'] ?? [];
    });
  }
}
```

**Après:**
```dart
// financial_page.dart
import '../../core/models/financial_models.dart';

class _FinancialPageState extends State<FinancialPage> {
  FinancialOverview? _overview;           // ✅ Type safety
  List<CustomerDebt> _debts = [];         // ✅ Autocomplétion
  
  void _loadData() async {
    final overview = await _financialService.getOverview();
    final debts = await _financialService.getDebts();
    setState(() {
      _overview = overview;  // ✅ Compilation error si mauvais type
      _debts = debts;
    });
  }
  
  Widget _buildDebtCard(CustomerDebt debt) {  // ✅ Type explicite
    return ListTile(
      title: Text(debt.name),              // ✅ Autocomplétion
      subtitle: Text('${debt.totalDebt.toCurrency()}'),  // ✅ Extension
      trailing: debt.credit?.status == CreditStatus.critical  // ✅ Enum
        ? Icon(Icons.warning, color: Colors.red)
        : null,
    );
  }
}
```

---

## 🧪 Plan de Tests

### Tests Backend

```javascript
// tests/financial.service.test.js

describe('FinancialService', () => {
  describe('getOverview', () => {
    it('should return financial overview for date range', async () => {
      const result = await financialService.getOverview(orgId, {
        dateFrom: '2024-01-01',
        dateTo: '2024-01-31'
      });
      
      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('topClients');
      expect(result.summary).toHaveProperty('totalRevenue');
    });
  });
  
  describe('recordPayment', () => {
    it('should record payment and update orders', async () => {
      const result = await financialService.recordPayment({
        customerId: 'xxx',
        amount: 1000,
        mode: 'cash'
      }, userId, orgId);
      
      expect(result.paymentId).toBeDefined();
      expect(result.ordersAffected).toHaveLength GreaterThan(0);
    });
    
    it('should reject payment exceeding debt', async () => {
      await expect(
        financialService.recordPayment({
          customerId: 'xxx',
          amount: 999999  // Montant impossible
        }, userId, orgId)
      ).rejects.toThrow('supérieur à la dette');
    });
  });
});
```

### Tests Mobile

```dart
// test/financial_service_test.dart

void main() {
  group('FinancialService', () {
    test('getOverview returns typed data', () async {
      final service = FinancialService();
      final overview = await service.getOverview();
      
      expect(overview, isA<FinancialOverview>());
      expect(overview.summary.totalRevenue, isA<double>());
    });
    
    test('getDebts returns list of CustomerDebt', () async {
      final service = FinancialService();
      final debts = await service.getDebts();
      
      expect(debts, isA<List<CustomerDebt>>());
      expect(debts.first.totalDebt, isA<double>());
    });
  });
  
  group('NumberExtensions', () {
    test('toDoubleOrZero handles all types', () {
      expect(null.toDoubleOrZero(), 0.0);
      expect(42.toDoubleOrZero(), 42.0);
      expect('3.14'.toDoubleOrZero(), 3.14);
      expect('invalid'.toDoubleOrZero(), 0.0);
    });
  });
}
```

---

## 🚨 Rollback Plan

### Si problème en production:

```bash
# 1. Restaurer les anciennes routes
git checkout HEAD~1 -- api-v2/routes/financial.routes.js
git checkout HEAD~1 -- api-v2/routes/organization.routes.js

# 2. Redémarrer
pm2 restart your-app

# 3. Base de données (les nouvelles tables n'affectent pas l'ancien code)
# Les tables payments et debt_history peuvent rester, elles sont inutilisées
# par l'ancien code

# 4. Mobile: revenir à la version précédente
# Via CodePush ou nouveau build
```

---

## ✅ Checklist de Validation

### Backend
- [ ] Migration SQL exécutée sans erreur
- [ ] Nouveaux endpoints répondent correctement
- [ ] Anciens endpoints toujours fonctionnels (backward compat)
- [ ] Tests unitaires passent
- [ ] Pas d'erreur dans les logs

### Mobile
- [ ] Build sans erreur (`flutter build apk`)
- [ ] Navigation Finance fonctionne
- [ ] Paiement de dette fonctionne
- [ ] Stats dashboard s'affichent
- [ ] Tests sur iOS et Android

### Base de Données
- [ ] Tables créées
- [ ] Index créés
- [ ] Vues matérialisées rafraîchies
- [ ] Données migrées depuis audit_logs

---

## 📞 Support

En cas de problème:
1. Vérifier les logs: `pm2 logs`
2. Vérifier la DB: `\dt` et `\d+ table_name`
3. Restaurer le backup si nécessaire
4. Contacter l'équipe avec les logs d'erreur
