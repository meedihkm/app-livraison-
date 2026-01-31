# ðŸ”§ Guide d'utilisation du script de correction des paiements

## ðŸ“‹ Objectif

Ce script SQL corrige automatiquement les incohÃ©rences entre les commandes, paiements et dettes dans la base de donnÃ©es.

## ðŸŽ¯ ProblÃ¨mes corrigÃ©s

### 1. **Commandes marquÃ©es "paid" sans paiement**

- **ProblÃ¨me**: Une commande a `payment_status = 'paid'` mais aucune entrÃ©e dans la table `payments`
- **Solution**: CrÃ©e automatiquement l'entrÃ©e de paiement manquante

### 2. **Commandes marquÃ©es "unpaid" avec paiement complet**

- **ProblÃ¨me**: Une commande a `payment_status = 'unpaid'` mais un paiement complet existe
- **Solution**: Met Ã  jour le statut Ã  `'paid'`

### 3. **Paiements partiels non dÃ©tectÃ©s**

- **ProblÃ¨me**: Une commande a un paiement partiel mais le statut n'est pas `'partial'`
- **Solution**: Met Ã  jour le statut Ã  `'partial'`

### 4. **Dettes incohÃ©rentes**

- **ProblÃ¨me**: Dettes qui ne correspondent pas aux commandes impayÃ©es
- **Solution**: Recalcule toutes les dettes basÃ©es sur les vrais montants

### 5. **Dettes orphelines**

- **ProblÃ¨me**: EntrÃ©es dans `debts` sans commande correspondante
- **Solution**: Supprime les dettes orphelines

## ðŸ“Š Structure du script

Le script est divisÃ© en 4 parties :

### **PARTIE 1: DIAGNOSTIC** (Lecture seule)

- Identifie toutes les incohÃ©rences
- Affiche des rapports dÃ©taillÃ©s
- **Aucune modification** de la base de donnÃ©es

### **PARTIE 2: CORRECTION DES PAIEMENTS**

- CrÃ©e les paiements manquants
- Met Ã  jour les statuts de paiement
- Corrige les paiements partiels

### **PARTIE 3: RECALCUL DES DETTES**

- Supprime les dettes pour commandes payÃ©es
- Met Ã  jour les montants de dettes
- CrÃ©e les dettes manquantes
- Supprime les dettes orphelines

### **PARTIE 4: VÃ‰RIFICATION**

- VÃ©rifie qu'il n'y a plus d'incohÃ©rences
- Affiche un rÃ©sumÃ© des corrections
- Statistiques finales par client

## ðŸš€ Comment utiliser

### Option 1: ExÃ©cuter tout le script (recommandÃ©)

```bash
# Se connecter Ã  PostgreSQL
psql -h <host> -U <user> -d <database> -f api-v2/migrations/fix_payment_inconsistencies.sql
```

### Option 2: ExÃ©cuter partie par partie

#### Ã‰tape 1: Diagnostic uniquement (sans modification)

```sql
-- Copier-coller uniquement la PARTIE 1 dans votre client SQL
-- Cela vous montrera les problÃ¨mes sans rien modifier
```

#### Ã‰tape 2: Corriger les paiements

```sql
-- Copier-coller la PARTIE 2
-- Cela corrige les statuts de paiement
```

#### Ã‰tape 3: Recalculer les dettes

```sql
-- Copier-coller la PARTIE 3
-- Cela recalcule toutes les dettes
```

#### Ã‰tape 4: VÃ©rification

```sql
-- Copier-coller la PARTIE 4
-- Cela vÃ©rifie que tout est correct
```

## âš ï¸ PrÃ©cautions

### Avant d'exÃ©cuter :

1. **Faire une sauvegarde de la base de donnÃ©es**

   ```bash
   pg_dump -h <host> -U <user> <database> > backup_before_fix.sql
   ```

2. **Tester sur une copie de la base de donnÃ©es** (si possible)

3. **ExÃ©cuter d'abord la PARTIE 1** pour voir l'ampleur des problÃ¨mes

### Pendant l'exÃ©cution :

- Le script peut prendre quelques secondes Ã  quelques minutes selon le volume de donnÃ©es
- Aucune interruption de service n'est nÃ©cessaire
- Les utilisateurs peuvent continuer Ã  utiliser l'application

### AprÃ¨s l'exÃ©cution :

1. **VÃ©rifier les rÃ©sultats** affichÃ©s par la PARTIE 4
2. **RedÃ©marrer l'application backend** (optionnel mais recommandÃ©)
3. **Tester la page Finance** dans l'application mobile

## ðŸ“ˆ RÃ©sultats attendus

AprÃ¨s l'exÃ©cution du script, vous devriez voir :

### âœ… IncohÃ©rences corrigÃ©es :

- 0 commandes "paid" sans paiement
- 0 commandes "unpaid" avec paiement complet
- 0 dettes orphelines

### ðŸ“Š DonnÃ©es cohÃ©rentes :

- Tous les paiements enregistrÃ©s correspondent aux commandes
- Toutes les dettes correspondent aux montants rÃ©ellement dus
- Les statuts de paiement reflÃ¨tent la rÃ©alitÃ©

### ðŸ’° Page Finance affichera :

- **Revenus collectÃ©s** = Somme des paiements rÃ©els
- **Dettes** = Montants rÃ©ellement dus (commandes - paiements)
- **Statistiques correctes** par livreur et par client

## ðŸ” VÃ©rification manuelle

AprÃ¨s l'exÃ©cution, vous pouvez vÃ©rifier manuellement :

```sql
-- VÃ©rifier un client spÃ©cifique
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

## ðŸ†˜ En cas de problÃ¨me

Si quelque chose ne va pas :

1. **Restaurer la sauvegarde**

   ```bash
   psql -h <host> -U <user> -d <database> < backup_before_fix.sql
   ```

2. **Contacter le support** avec :
   - Les messages d'erreur
   - Le nombre de lignes affectÃ©es
   - Les rÃ©sultats de la PARTIE 1 (diagnostic)

## ðŸ“ Notes importantes

- Ce script est **idempotent** : vous pouvez l'exÃ©cuter plusieurs fois sans problÃ¨me
- Il ne supprime **aucune donnÃ©e importante**, seulement les incohÃ©rences
- Les paiements crÃ©Ã©s automatiquement sont marquÃ©s comme "cash" par dÃ©faut
- Les dettes sont recalculÃ©es basÃ©es sur `orders.total - SUM(payments.amount)`

## ðŸŽ¯ Prochaines Ã©tapes

AprÃ¨s avoir exÃ©cutÃ© ce script :

1. âœ… RedÃ©ployer l'application sur Coolify
2. âœ… Tester la page Finance dans l'app mobile
3. âœ… VÃ©rifier que les montants affichÃ©s sont corrects
4. âœ… CrÃ©er une nouvelle commande pour tester le flux complet

---

**Date de crÃ©ation**: 2026-01-25  
**Version**: 1.0  
**Auteur**: Kiro AI Assistant
