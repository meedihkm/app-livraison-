# 🔧 Guide d'utilisation du script de correction des paiements

## 📋 Objectif

Ce script SQL corrige automatiquement les incohérences entre les commandes, paiements et dettes dans la base de données.

## 🎯 Problèmes corrigés

### 1. **Commandes marquées "paid" sans paiement**

- **Problème**: Une commande a `payment_status = 'paid'` mais aucune entrée dans la table `payments`
- **Solution**: Crée automatiquement l'entrée de paiement manquante

### 2. **Commandes marquées "unpaid" avec paiement complet**

- **Problème**: Une commande a `payment_status = 'unpaid'` mais un paiement complet existe
- **Solution**: Met à jour le statut à `'paid'`

### 3. **Paiements partiels non détectés**

- **Problème**: Une commande a un paiement partiel mais le statut n'est pas `'partial'`
- **Solution**: Met à jour le statut à `'partial'`

### 4. **Dettes incohérentes**

- **Problème**: Dettes qui ne correspondent pas aux commandes impayées
- **Solution**: Recalcule toutes les dettes basées sur les vrais montants

### 5. **Dettes orphelines**

- **Problème**: Entrées dans `debts` sans commande correspondante
- **Solution**: Supprime les dettes orphelines

## 📊 Structure du script

Le script est divisé en 4 parties :

### **PARTIE 1: DIAGNOSTIC** (Lecture seule)

- Identifie toutes les incohérences
- Affiche des rapports détaillés
- **Aucune modification** de la base de données

### **PARTIE 2: CORRECTION DES PAIEMENTS**

- Crée les paiements manquants
- Met à jour les statuts de paiement
- Corrige les paiements partiels

### **PARTIE 3: RECALCUL DES DETTES**

- Supprime les dettes pour commandes payées
- Met à jour les montants de dettes
- Crée les dettes manquantes
- Supprime les dettes orphelines

### **PARTIE 4: VÉRIFICATION**

- Vérifie qu'il n'y a plus d'incohérences
- Affiche un résumé des corrections
- Statistiques finales par client

## 🚀 Comment utiliser

### Option 1: Exécuter tout le script (recommandé)

```bash
# Se connecter à PostgreSQL
psql -h <host> -U <user> -d <database> -f api-v2/migrations/fix_payment_inconsistencies.sql
```

### Option 2: Exécuter partie par partie

#### Étape 1: Diagnostic uniquement (sans modification)

```sql
-- Copier-coller uniquement la PARTIE 1 dans votre client SQL
-- Cela vous montrera les problèmes sans rien modifier
```

#### Étape 2: Corriger les paiements

```sql
-- Copier-coller la PARTIE 2
-- Cela corrige les statuts de paiement
```

#### Étape 3: Recalculer les dettes

```sql
-- Copier-coller la PARTIE 3
-- Cela recalcule toutes les dettes
```

#### Étape 4: Vérification

```sql
-- Copier-coller la PARTIE 4
-- Cela vérifie que tout est correct
```

## ⚠️ Précautions

### Avant d'exécuter :

1. **Faire une sauvegarde de la base de données**

   ```bash
   pg_dump -h <host> -U <user> <database> > backup_before_fix.sql
   ```

2. **Tester sur une copie de la base de données** (si possible)

3. **Exécuter d'abord la PARTIE 1** pour voir l'ampleur des problèmes

### Pendant l'exécution :

- Le script peut prendre quelques secondes à quelques minutes selon le volume de données
- Aucune interruption de service n'est nécessaire
- Les utilisateurs peuvent continuer à utiliser l'application

### Après l'exécution :

1. **Vérifier les résultats** affichés par la PARTIE 4
2. **Redémarrer l'application backend** (optionnel mais recommandé)
3. **Tester la page Finance** dans l'application mobile

## 📈 Résultats attendus

Après l'exécution du script, vous devriez voir :

### ✅ Incohérences corrigées :

- 0 commandes "paid" sans paiement
- 0 commandes "unpaid" avec paiement complet
- 0 dettes orphelines

### 📊 Données cohérentes :

- Tous les paiements enregistrés correspondent aux commandes
- Toutes les dettes correspondent aux montants réellement dus
- Les statuts de paiement reflètent la réalité

### 💰 Page Finance affichera :

- **Revenus collectés** = Somme des paiements réels
- **Dettes** = Montants réellement dus (commandes - paiements)
- **Statistiques correctes** par livreur et par client

## 🔍 Vérification manuelle

Après l'exécution, vous pouvez vérifier manuellement :

```sql
-- Vérifier un client spécifique
SELECT
    o.id,
    o.total,
    o.payment_status,
    COALESCE(SUM(p.amount), 0) as paid,
    COALESCE(d.amount, 0) as debt
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
LEFT JOIN debts d ON d.order_id = o.id
WHERE o.customer_id = 'ID_DU_CLIENT'
GROUP BY o.id, o.total, o.payment_status, d.amount;
```

## 🆘 En cas de problème

Si quelque chose ne va pas :

1. **Restaurer la sauvegarde**

   ```bash
   psql -h <host> -U <user> -d <database> < backup_before_fix.sql
   ```

2. **Contacter le support** avec :
   - Les messages d'erreur
   - Le nombre de lignes affectées
   - Les résultats de la PARTIE 1 (diagnostic)

## 📝 Notes importantes

- Ce script est **idempotent** : vous pouvez l'exécuter plusieurs fois sans problème
- Il ne supprime **aucune donnée importante**, seulement les incohérences
- Les paiements créés automatiquement sont marqués comme "cash" par défaut
- Les dettes sont recalculées basées sur `orders.total - SUM(payments.amount)`

## 🎯 Prochaines étapes

Après avoir exécuté ce script :

1. ✅ Redéployer l'application sur Coolify
2. ✅ Tester la page Finance dans l'app mobile
3. ✅ Vérifier que les montants affichés sont corrects
4. ✅ Créer une nouvelle commande pour tester le flux complet

---

**Date de création**: 2026-01-25  
**Version**: 1.0  
**Auteur**: Kiro AI Assistant
