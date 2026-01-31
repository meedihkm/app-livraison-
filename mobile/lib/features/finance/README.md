# Module Finance - Documentation

## Vue d'ensemble

Ce module regroupe toute la gestion financière de l'application avec une architecture sans duplication.

## Structure

```
lib/features/finance/
├── finance.dart                    # Export principal
├── presentation/
│   ├── pages/
│   │   ├── finance_dashboard_page.dart   # Dashboard complet avec filtres
│   │   └── statistics_page.dart          # Statistiques détaillées
│   └── widgets/
│       ├── debt_payment_dialog.dart      # Dialog d'encaissement
│       ├── finance_filters.dart          # Filtres de période
│       └── finance_summary_cards.dart   # Cartes de résumé
```

## Utilisation

### 1. Importer le module

```dart
import 'package:awid/features/finance/finance.dart';
```

### 2. Naviguer vers le dashboard financier

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const FinanceDashboardPage()),
);
```

### 3. Naviguer vers les statistiques

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const StatisticsPage()),
);
```

### 4. Imprimer un rapport

```dart
final printService = PrintService();

await printService.printFinancialReport(
  context: context,
  overview: overview,
  debts: debts,
  dateFrom: dateFrom,
  dateTo: dateTo,
);
```

## Fonctionnalités

### Dashboard Financier (FinanceDashboardPage)

- **Onglet Tableau de bord** : Vue d'ensemble avec filtres de période
- **Onglet Clients & Dettes** : Liste filtrable et triable des dettes
- **Onglet Stats Livreurs** : Performance des livreurs
- **Impression** : Bouton pour imprimer le rapport complet

### Statistiques (StatisticsPage)

- **Par Client** : Classement, CA, détail par client
- **Par Livreur** : Nombre de livraisons, taux de réussite, montants collectés

### Paiement de Dette (DebtPaymentDialog)

- Montant personnalisable
- 3 modes de paiement (Espèces, Chèque, Virement)
- Notes optionnelles
- Impression automatique du reçu

## Services utilisés (existants)

- `FinancialServiceV2` - Service API existant
- `FinancialModels` - Modèles de données existants
- `PrintService` - Nouveau service d'impression

## Pas de duplication !

Ce module utilise :
- ✅ Les modèles existants (`financial_models.dart`)
- ✅ Les services existants (`financial_service_v2.dart`)
- ✅ Les extensions existantes (`number_extensions.dart`)

Les nouveaux fichiers créés sont uniquement :
- Pages et widgets UI
- Service d'impression (`print_utils.dart`)
