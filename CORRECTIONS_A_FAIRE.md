# Corrections à Faire - Build Mobile v4

**Date**: 28 janvier 2026  
**Commit actuel**: c081f98

---

## 📋 LISTE DES CORRECTIONS NÉCESSAIRES

### ✅ CORRECTION 1: Types Privés du Provider

**Fichier**: `mobile-v4/lib/features/deliverer/presentation/pages/payment_collection_page.dart`

**Ligne 327**: 
```dart
// AVANT (INCORRECT):
void _showSuccessDialog(_PaymentCollected state) {

// APRÈS (CORRECT):
void _showSuccessDialog(PaymentCollected state) {
```

**Raison**: `_PaymentCollected` est un type privé. Le type public est `PaymentCollected` (sans underscore).

---

### ✅ CORRECTION 2: Types Privés du Provider

**Fichier**: `mobile-v4/lib/features/deliverer/presentation/pages/packaging_management_page.dart`

**Ligne 375**:
```dart
// AVANT (INCORRECT):
void _showSuccessDialog(_PackagingTransactionRecorded state) {

// APRÈS (CORRECT):
void _showSuccessDialog(PackagingTransactionRecorded state) {
```

**Raison**: `_PackagingTransactionRecorded` est un type privé. Le type public est `PackagingTransactionRecorded` (sans underscore).

---

### ✅ CORRECTION 3: Conflit d'Import UnpaidOrder

**Fichier**: `mobile-v4/lib/features/deliverer/domain/repositories/delivery_actions_repository.dart`

**Lignes 145-168**: SUPPRIMER cette classe complète
```dart
// À SUPPRIMER:
/// Commande Impayée
class UnpaidOrder {
  final String id;
  final String orderNumber;
  final DateTime orderDate;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final int daysSinceOrder;

  const UnpaidOrder({
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.daysSinceOrder,
  });

  double get unpaidAmount => totalAmount - paidAmount;
  bool get isFullyUnpaid => paidAmount == 0;
  bool get isPartiallyPaid => paidAmount > 0 && paidAmount < totalAmount;
}
```

**Ajouter en haut du fichier** (dans les imports):
```dart
import '../entities/unpaid_order.dart';
```

**Raison**: `UnpaidOrder` est déjà défini dans `unpaid_order.dart` avec Freezed. Pas besoin de doublon.

---

### ✅ CORRECTION 4: Conflit PackagingBalance

**Fichier**: `mobile-v4/lib/features/deliverer/domain/repositories/delivery_actions_repository.dart`

**Lignes ~170-195**: SUPPRIMER cette classe complète
```dart
// À SUPPRIMER:
/// Solde Consignes Client
class PackagingBalance {
  final String customerId;
  final String customerName;
  final List<PackagingBalanceItem> items;
  final double totalValue;
  final DateTime lastUpdated;

  const PackagingBalance({
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.totalValue,
    required this.lastUpdated,
  });

  bool get hasPositiveBalance => totalValue > 0;
  bool get hasNegativeBalance => totalValue < 0;
  bool get isBalanced => totalValue == 0;
}
```

**Ajouter en haut du fichier** (dans les imports):
```dart
import '../entities/packaging_type.dart';
```

**Raison**: `PackagingBalance` est déjà défini dans `packaging_type.dart` avec Freezed.

---

### ✅ CORRECTION 5: Conflit PackagingBalanceItem

**Fichier**: `mobile-v4/lib/features/deliverer/domain/repositories/delivery_actions_repository.dart`

**Lignes ~197-215**: SUPPRIMER cette classe complète
```dart
// À SUPPRIMER:
/// Article du Solde Consignes
class PackagingBalanceItem {
  final String packagingId;
  final String packagingName;
  final int quantity;
  final double unitValue;
  final double totalValue;

  const PackagingBalanceItem({
    required this.packagingId,
    required this.packagingName,
    required this.quantity,
    required this.unitValue,
    required this.totalValue,
  });
}
```

**Raison**: `PackagingBalanceItem` est déjà défini dans `packaging_type.dart` avec Freezed.

---

### ✅ CORRECTION 6: Switch Non Exhaustif - PaymentMode.card

**Fichier**: `mobile-v4/lib/features/deliverer/presentation/pages/payment_collection_page.dart`

**Ligne 376**: Ajouter le cas manquant
```dart
// AVANT:
String _getModeIcon(PaymentMode mode) {
  switch (mode) {
    case PaymentMode.cash:
      return '💵';
    case PaymentMode.check:
      return '📝';
    case PaymentMode.transfer:
      return '🏦';
  }
}

// APRÈS:
String _getModeIcon(PaymentMode mode) {
  switch (mode) {
    case PaymentMode.cash:
      return '💵';
    case PaymentMode.check:
      return '📝';
    case PaymentMode.transfer:
      return '🏦';
    case PaymentMode.card:
      return '💳';
  }
}
```

---

### ✅ CORRECTION 7: Switch Non Exhaustif - PaymentMode.card

**Fichier**: `mobile-v4/lib/features/deliverer/presentation/pages/payment_collection_page.dart`

**Ligne 387**: Ajouter le cas manquant
```dart
// AVANT:
String _getModeLabel(PaymentMode mode) {
  switch (mode) {
    case PaymentMode.cash:
      return 'Espèces';
    case PaymentMode.check:
      return 'Chèque';
    case PaymentMode.transfer:
      return 'Virement';
  }
}

// APRÈS:
String _getModeLabel(PaymentMode mode) {
  switch (mode) {
    case PaymentMode.cash:
      return 'Espèces';
    case PaymentMode.check:
      return 'Chèque';
    case PaymentMode.transfer:
      return 'Virement';
    case PaymentMode.card:
      return 'Carte';
  }
}
```

---

## 📊 RÉSUMÉ DES FICHIERS À MODIFIER

1. ✅ `mobile-v4/lib/features/deliverer/presentation/pages/payment_collection_page.dart`
   - Correction 1: Ligne 327 - Remplacer `_PaymentCollected` par `PaymentCollected`
   - Correction 6: Ligne 376 - Ajouter cas `PaymentMode.card`
   - Correction 7: Ligne 387 - Ajouter cas `PaymentMode.card`

2. ✅ `mobile-v4/lib/features/deliverer/presentation/pages/packaging_management_page.dart`
   - Correction 2: Ligne 375 - Remplacer `_PackagingTransactionRecorded` par `PackagingTransactionRecorded`

3. ✅ `mobile-v4/lib/features/deliverer/domain/repositories/delivery_actions_repository.dart`
   - Correction 3: Supprimer classe `UnpaidOrder` + ajouter import
   - Correction 4: Supprimer classe `PackagingBalance` + ajouter import
   - Correction 5: Supprimer classe `PackagingBalanceItem`

---

## 🎯 ORDRE D'EXÉCUTION

1. Modifier `delivery_actions_repository.dart` (Corrections 3, 4, 5)
2. Modifier `payment_collection_page.dart` (Corrections 1, 6, 7)
3. Modifier `packaging_management_page.dart` (Correction 2)
4. Commit et push
5. Le build_runner régénérera automatiquement les fichiers `.freezed.dart`

---

## ⚠️ NOTES IMPORTANTES

- **NE PAS MODIFIER** les fichiers `.freezed.dart` - ils sont générés automatiquement
- **NE PAS COMMITER** les fichiers `.freezed.dart` - ils sont dans .gitignore
- Les erreurs Freezed (User, KitchenOrder, etc.) seront résolues automatiquement par build_runner
- Après ces corrections, le build devrait réussir

---

## ✅ VALIDATION

Après corrections, vérifier:
- [ ] Aucun type privé (`_TypeName`) n'est utilisé dans les pages
- [ ] Aucune classe n'est définie en double
- [ ] Tous les cas d'enum sont gérés dans les switch
- [ ] Les imports sont corrects
- [ ] Le build GitHub Actions réussit
