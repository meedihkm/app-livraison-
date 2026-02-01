# 🚀 PLAN D'AMÉLIORATION COMPLET AWID v4.0

## Système de Livraison Multi-Organisation pour le Marché Algérien

---

## 📋 TABLE DES MATIÈRES

1. [Vision & Contexte Métier](#1-vision--contexte-métier)
2. [Analyse des Besoins par Persona](#2-analyse-des-besoins-par-persona)
3. [Architecture Technique Proposée](#3-architecture-technique-proposée)
4. [Fonctionnalités Prioritaires](#4-fonctionnalités-prioritaires)
5. [Stack Technologique Open Source](#5-stack-technologique-open-source)
6. [Roadmap d'Implémentation](#6-roadmap-dimplémentation)
7. [Sécurité & Conformité](#7-sécurité--conformité)
8. [Déploiement & Scalabilité](#8-déploiement--scalabilité)

---

## 1. VISION & CONTEXTE MÉTIER

### 1.1 Problématique du Marché Algérien

**Contexte spécifique** :

- Paiement principalement en espèces (cash-based economy)
- Système de crédit basé sur la confiance interpersonnelle
- Livreurs employés directs (pas de freelance)
- Relations commerciales B2B de proximité
- Besoin de traçabilité comptable rigoureuse
- Connectivité internet parfois instable

### 1.2 Modèle d'Organisation

```
┌─────────────────────────────────────────────────────────────┐
│                    ORGANISATION                              │
│  (Pizzeria, Boulangerie, Laiterie, etc.)                   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   ADMIN      │  │   ATELIER    │  │  LIVREURS    │     │
│  │  (Gérant)    │  │  (Cuisine)   │  │  (Employés)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  Livre à ↓                                                  │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    CLIENTS FIDÈLES                           │
│  (Cafétérias, Restaurants, Points de vente)                 │
│                                                              │
│  - Commandes régulières                                     │
│  - Crédit accordé selon confiance                           │
│  - Paiement différé ou partiel                              │
│  - Historique comptable complet                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 Exemples d'Usage Réels

**Cas 1 : Pizzeria → Cafétérias**

- Produits : Pizzas, pâtisseries, boissons
- Livraison : Quotidienne (matin)
- Paiement : Hebdomadaire en espèces
- Crédit : 50 000 DZD maximum

**Cas 2 : Boulangerie → Points de vente**

- Produits : Pain, viennoiseries
- Livraison : 2x/jour (matin + après-midi)
- Paiement : Fin de semaine
- Crédit : 30 000 DZD maximum

**Cas 3 : Laiterie → Restaurants**

- Produits : Lait, yaourt, fromage
- Livraison : Tous les 2 jours
- Paiement : Mensuel
- Crédit : 100 000 DZD maximum

---

## 2. ANALYSE DES BESOINS PAR PERSONA

### 2.1 👔 ADMIN (Gérant d'Organisation)

#### Profil

- Propriétaire ou gérant de l'entreprise
- Gère 3-15 livreurs
- 20-200 clients réguliers
- Besoin de contrôle total et visibilité

#### Frustrations Actuelles

❌ Pas de vue d'ensemble en temps réel
❌ Comptabilité manuelle fastidieuse
❌ Difficile de suivre les dettes clients
❌ Pas d'alertes automatiques
❌ Rapports manuels chronophages
❌ Gestion des prix complexe

#### Besoins Essentiels

**A1. Dashboard Temps Réel** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  📊 TABLEAU DE BORD - Aujourd'hui                       │
├─────────────────────────────────────────────────────────┤
│  Commandes                                              │
│  ├─ En attente        : 12                              │
│  ├─ En préparation    : 8                               │
│  ├─ En livraison      : 15                              │
│  └─ Livrées           : 47                              │
│                                                          │
│  Finance                                                │
│  ├─ CA du jour        : 245 000 DZD                     │
│  ├─ Encaissé         : 180 000 DZD                     │
│  ├─ Crédit accordé   : 65 000 DZD                      │
│  └─ Dette totale     : 1 250 000 DZD                   │
│                                                          │
│  Livreurs Actifs                                        │
│  ├─ Ahmed (5 livraisons) 🟢 En route                   │
│  ├─ Karim (3 livraisons) 🟢 En route                   │
│  └─ Yacine (7 livraisons) 🟡 Pause                     │
│                                                          │
│  🚨 Alertes                                             │
│  ├─ Client "Café Central" : Limite crédit atteinte     │
│  ├─ Stock pain : Niveau bas (20 unités)                │
│  └─ Livraison #1234 : Retard 25 min                    │
└─────────────────────────────────────────────────────────┘
```

**A2. Gestion Financière Complète** 🔴 CRITIQUE

- Vue dette par client avec vieillissement (0-7j, 8-15j, 16-30j, >30j)
- Historique complet des transactions
- Prévisions de trésorerie
- Export comptable (Excel, PDF)
- Rapports automatiques (quotidien, hebdo, mensuel)

**A3. Gestion des Livreurs** 🔴 CRITIQUE

- Suivi en temps réel sur carte
- Historique des performances
- Calcul automatique des commissions
- Gestion des horaires et disponibilités
- Statistiques détaillées (nb livraisons, CA généré, taux réussite)

**A4. Gestion des Clients** 🔴 CRITIQUE

- Fiche client complète (coordonnées, historique, dette)
- Limite de crédit personnalisée
- Alertes dépassement
- Historique des commandes
- Statistiques d'achat
- Notes et commentaires

**A5. Gestion des Produits** 🟡 IMPORTANT

- Catalogue avec photos
- Prix par client (tarification différenciée)
- Gestion des stocks
- Alertes stock bas
- Historique des prix

**A6. Système d'Alertes Intelligent** 🟡 IMPORTANT

- Limite crédit atteinte/dépassée
- Stock bas
- Livraison en retard
- Paiement important reçu
- Activité inhabituelle
- Notifications : Push + SMS + Email

**A7. Rapports Automatisés** 🟡 IMPORTANT

- Rapport journalier (envoi automatique 20h)
- Rapport hebdomadaire (lundi matin)
- Rapport mensuel (1er du mois)
- Rapport de vieillissement des créances
- Rapport de performance livreurs
- Export PDF/Excel

### 2.2 🚚 LIVREUR (Employé de l'Organisation)

#### Profil

- Employé à temps plein
- 15-40 livraisons/jour
- Utilise smartphone Android (majoritaire en Algérie)
- Connexion internet parfois instable
- Gère espèces et encaissements

#### Frustrations Actuelles

❌ Pas d'optimisation d'itinéraire
❌ Perte de temps à chercher adresses
❌ Pas de preuve de livraison
❌ Difficile de gérer les paiements multiples
❌ Pas de visibilité sur ses gains
❌ Mode hors-ligne limité

#### Besoins Essentiels

**L1. Interface Simple et Rapide** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  🚚 MES LIVRAISONS - Ahmed                              │
├─────────────────────────────────────────────────────────┤
│  📍 Prochaine : Café Central (2.3 km)                   │
│  ⏱️  ETA : 8 min                                         │
│  💰 À encaisser : 12 500 DZD                            │
│  [🗺️  NAVIGATION]  [📞 APPELER]                         │
│                                                          │
│  ─────────────────────────────────────────────────────  │
│                                                          │
│  📦 Commande #1234                                      │
│  ├─ 10x Pain complet                                    │
│  ├─ 5x Croissant                                        │
│  └─ Total : 12 500 DZD                                  │
│                                                          │
│  [✅ LIVRÉ]  [❌ ÉCHEC]  [📸 PHOTO]                      │
└─────────────────────────────────────────────────────────┘
```

**L2. Optimisation d'Itinéraire** 🔴 CRITIQUE

- Calcul automatique du meilleur ordre de livraison
- Intégration Google Maps / OpenStreetMap
- Prise en compte du trafic en temps réel
- Estimation temps et distance
- Navigation turn-by-turn

**L3. Mode Hors-Ligne Complet** 🔴 CRITIQUE

- Synchronisation au démarrage de la journée
- Toutes les livraisons disponibles offline
- Enregistrement des actions localement
- Sync automatique dès connexion retrouvée
- Indicateur visuel du statut sync

**L4. Gestion des Paiements Simplifiée** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  💰 ENCAISSER PAIEMENT                                  │
├─────────────────────────────────────────────────────────┤
│  Client : Café Central                                  │
│  Dette actuelle : 45 000 DZD                            │
│                                                          │
│  Montant reçu : [________] DZD                          │
│                                                          │
│  Mode paiement :                                        │
│  ● Espèces    ○ Chèque    ○ Virement                   │
│                                                          │
│  Affecter à :                                           │
│  ☑ Livraison actuelle (12 500 DZD)                     │
│  ☑ Commande #1230 (8 000 DZD)                          │
│  ☑ Commande #1225 (15 000 DZD)                         │
│  ☐ Dette ancienne (9 500 DZD)                          │
│                                                          │
│  [VALIDER]                                              │
└─────────────────────────────────────────────────────────┘
```

**L5. Preuve de Livraison** 🔴 CRITIQUE

- Signature électronique du client
- Photo du produit livré
- Photo du lieu de livraison
- Géolocalisation automatique
- Horodatage
- Nom du signataire

**L6. Gestion des Consignes** 🟡 IMPORTANT

- Enregistrement dépôt/retour consignes
- Scan QR code ou saisie manuelle
- Historique par client
- Solde en temps réel

**L7. Historique et Gains** 🟡 IMPORTANT

- Historique des livraisons
- Statistiques personnelles
- Calcul automatique des commissions
- Objectifs et bonus
- Classement entre livreurs (gamification)

**L8. Communication** 🟢 BONUS

- Chat avec l'admin
- Appel direct client
- Signalement de problème
- Demande d'assistance

### 2.3 🏪 CLIENT (Cafétéria/Restaurant/Commerce)

#### Profil

- Commande régulièrement (quotidien à hebdomadaire)
- Gère un budget mensuel
- Relation de confiance avec le fournisseur
- Besoin de simplicité et rapidité
- Veut suivre ses dépenses

#### Frustrations Actuelles

❌ Création de commande trop longue
❌ Pas de suivi de livraison
❌ Historique incomplet
❌ Pas de visibilité sur la dette
❌ Difficile de faire une réclamation
❌ Pas de catalogue visuel

#### Besoins Essentiels

**C1. Commande Ultra-Rapide** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  🛒 NOUVELLE COMMANDE                                   │
├─────────────────────────────────────────────────────────┤
│  ⭐ FAVORIS                                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📦 Ma commande habituelle                       │   │
│  │ 20x Pain complet + 10x Croissant                │   │
│  │ Total : 25 000 DZD                              │   │
│  │ [COMMANDER]                                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  📋 CATALOGUE                                           │
│  ┌──────┐ ┌──────┐ ┌──────┐                            │
│  │ 🥖   │ │ 🥐   │ │ 🍕   │                            │
│  │ Pain │ │Croiss│ │Pizza │                            │
│  │ 500  │ │ 150  │ │ 800  │                            │
│  │ [+]  │ │ [+]  │ │ [+]  │                            │
│  └──────┘ └──────┘ └──────┘                            │
│                                                          │
│  🔄 COMMANDES RÉCURRENTES                               │
│  ☑ Tous les jours à 7h                                  │
│  ☐ Lundi/Mercredi/Vendredi à 8h                        │
│                                                          │
│  [VALIDER LA COMMANDE]                                  │
└─────────────────────────────────────────────────────────┘
```

**C2. Favoris et Commandes Récurrentes** 🔴 CRITIQUE

- Sauvegarder commandes fréquentes
- Commande en 1 clic
- Programmation automatique
- Modification facile
- Historique des favoris

**C3. Tracking en Temps Réel** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  📍 SUIVI DE LIVRAISON                                  │
├─────────────────────────────────────────────────────────┤
│  Commande #1234                                         │
│  Statut : En livraison 🚚                               │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │         [CARTE INTERACTIVE]                     │   │
│  │                                                  │   │
│  │    📍 Vous                                       │   │
│  │         ↑                                        │   │
│  │         │ 2.3 km                                │   │
│  │         │                                        │   │
│  │    🚚 Ahmed (livreur)                           │   │
│  │                                                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ⏱️  Arrivée estimée : 8 minutes                        │
│  📞 Appeler le livreur                                  │
│                                                          │
│  Historique :                                           │
│  ✅ 14:30 - Commande confirmée                          │
│  ✅ 14:45 - En préparation                              │
│  ✅ 15:10 - Prête pour livraison                        │
│  🚚 15:20 - En cours de livraison                       │
└─────────────────────────────────────────────────────────┘
```

**C4. Gestion Financière Client** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  💰 MA COMPTABILITÉ                                     │
├─────────────────────────────────────────────────────────┤
│  Dette actuelle : 45 000 DZD                            │
│  Limite crédit : 50 000 DZD                             │
│  ⚠️  Attention : 90% de la limite atteinte              │
│                                                          │
│  📊 Détail par ancienneté :                             │
│  ├─ 0-7 jours    : 25 000 DZD                           │
│  ├─ 8-15 jours   : 15 000 DZD                           │
│  └─ 16-30 jours  : 5 000 DZD                            │
│                                                          │
│  📄 Dernières factures :                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ #1234 - 25/01 - 12 500 DZD - ❌ Non payée      │   │
│  │ #1230 - 24/01 - 8 000 DZD  - ❌ Non payée      │   │
│  │ #1225 - 23/01 - 15 000 DZD - ✅ Payée          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  [📥 TÉLÉCHARGER RELEVÉ PDF]                            │
└─────────────────────────────────────────────────────────┘
```

**C5. Historique et Factures** 🟡 IMPORTANT

- Historique complet des commandes
- Téléchargement factures PDF
- Recherche et filtres
- Export Excel
- Statistiques d'achat

**C6. Système de Réclamation** 🟡 IMPORTANT

```
┌─────────────────────────────────────────────────────────┐
│  ⚠️  NOUVELLE RÉCLAMATION                               │
├─────────────────────────────────────────────────────────┤
│  Commande : #1234                                       │
│                                                          │
│  Type de problème :                                     │
│  ○ Produit manquant                                     │
│  ○ Mauvais produit                                      │
│  ● Qualité insuffisante                                 │
│  ○ Retard de livraison                                  │
│  ○ Comportement livreur                                 │
│  ○ Autre                                                │
│                                                          │
│  Description :                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Le pain était rassis...                         │   │
│  │                                                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  Photos (optionnel) :                                   │
│  [📸 AJOUTER PHOTO]                                     │
│                                                          │
│  [ENVOYER LA RÉCLAMATION]                               │
└─────────────────────────────────────────────────────────┘
```

**C7. Notifications** 🟡 IMPORTANT

- Commande confirmée
- En préparation
- En livraison (avec tracking)
- Livrée
- Rappel paiement
- Promotions

**C8. Évaluation** 🟢 BONUS

- Noter la livraison (1-5 étoiles)
- Évaluer ponctualité, qualité, comportement
- Commentaire optionnel
- Historique des évaluations

### 2.4 👨‍🍳 ATELIER/CUISINE (Préparateur)

#### Profil

- Prépare les commandes
- Travaille debout, mains occupées
- Besoin d'interface tactile grande
- Gère les stocks au quotidien
- Coordonne avec les livreurs

#### Frustrations Actuelles

❌ Liste de commandes peu claire
❌ Pas de priorisation visuelle
❌ Difficile de voir l'avancement
❌ Pas d'alertes stock
❌ Interface pas adaptée tactile

#### Besoins Essentiels

**K1. Vue Kanban Tactile** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────────────────────┐
│  👨‍🍳 PRODUCTION - Vue Cuisine                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  EN ATTENTE    │  EN COURS      │  PRÊT          │  RÉCUPÉRÉ           │
│  (8)           │  (5)           │  (3)           │  (12)               │
│ ─────────────────────────────────────────────────────────────────────── │
│                │                │                │                      │
│  ┌──────────┐  │  ┌──────────┐  │  ┌──────────┐  │  ┌──────────┐      │
│  │ #1234 🔴 │  │  │ #1230    │  │  │ #1225    │  │  │ #1220    │      │
│  │ URGENT   │  │  │ 15:45    │  │  │ Ahmed    │  │  │ 14:30    │      │
│  │ Café     │  │  │ 10 items │  │  │ 8 items  │  │  │ Livré    │      │
│  │ Central  │  │  │          │  │  │          │  │  │          │      │
│  │ 12 items │  │  │ [PRÊT]   │  │  │ [PRIS]   │  │  │          │      │
│  └──────────┘  │  └──────────┘  │  └──────────┘  │  └──────────┘      │
│                │                │                │                      │
│  ┌──────────┐  │  ┌──────────┐  │  ┌──────────┐  │                     │
│  │ #1235    │  │  │ #1231    │  │  │ #1226    │  │                     │
│  │ 16:00    │  │  │ 16:15    │  │  │ Karim    │  │                     │
│  │ Rest.    │  │  │ 5 items  │  │  │ 15 items │  │                     │
│  │ Paix     │  │  │          │  │  │          │  │                     │
│  │ 8 items  │  │  │ [PRÊT]   │  │  │ [PRIS]   │  │                     │
│  └──────────┘  │  └──────────┘  │  └──────────┘  │                     │
│                │                │                │                      │
│  [Glisser-déposer pour changer le statut]                              │
└─────────────────────────────────────────────────────────────────────────┘
```

**K2. Détail Commande Optimisé** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  📦 COMMANDE #1234                                      │
├─────────────────────────────────────────────────────────┤
│  Client : Café Central                                  │
│  Heure : 15:30                                          │
│  Priorité : 🔴 URGENT                                   │
│  Livreur : Ahmed                                        │
│                                                          │
│  Articles :                                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ✅ 10x Pain complet                             │   │
│  │ ✅ 5x Croissant                                 │   │
│  │ ⏳ 3x Pizza margherita                          │   │
│  │ ⏳ 2x Tarte aux pommes                          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  Notes : "Bien cuit SVP"                                │
│                                                          │
│  ⏱️  Temps écoulé : 12 min                              │
│  ⏱️  Temps estimé restant : 8 min                       │
│                                                          │
│  [MARQUER PRÊT]  [IMPRIMER BON]                         │
└─────────────────────────────────────────────────────────┘
```

**K3. Gestion des Stocks** 🔴 CRITIQUE

```
┌─────────────────────────────────────────────────────────┐
│  📦 STOCKS                                              │
├─────────────────────────────────────────────────────────┤
│  🔴 ALERTES (3)                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ⚠️  Pain complet : 15 unités (seuil: 20)       │   │
│  │ ⚠️  Farine : 5 kg (seuil: 10 kg)               │   │
│  │ ⚠️  Levure : 200g (seuil: 500g)                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  🟢 STOCK NORMAL                                        │
│  ├─ Croissant : 45 unités                               │
│  ├─ Pizza : 12 unités                                   │
│  └─ Tarte : 8 unités                                    │
│                                                          │
│  📊 Consommation du jour :                              │
│  ├─ Pain : 85 unités                                    │
│  ├─ Croissant : 42 unités                               │
│  └─ Pizza : 23 unités                                   │
│                                                          │
│  [AJUSTER STOCK]  [COMMANDER]                           │
└─────────────────────────────────────────────────────────┘
```

**K4. Impression Bons de Production** 🟡 IMPORTANT

- Impression automatique nouvelle commande
- Bon de préparation détaillé
- Étiquettes produits
- Bon de livraison
- Support imprimantes thermiques

**K5. Statistiques Production** 🟢 BONUS

- Temps moyen de préparation
- Produits les plus demandés
- Heures de pointe
- Performance équipe

---

## 3. ARCHITECTURE TECHNIQUE PROPOSÉE

### 3.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MOBILE APPS (Flutter)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │   Admin      │  │   Livreur    │  │   Client     │  │  Cuisine   │ │
│  │  Dashboard   │  │   Delivery   │  │   Orders     │  │  Kitchen   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬─────┘ │
│         │                  │                  │                  │       │
│         └──────────────────┼──────────────────┼──────────────────┘       │
│                            │                  │                          │
└────────────────────────────┼──────────────────┼──────────────────────────┘
                             │                  │
                             │ REST API         │ WebSocket
                             │ (HTTPS)          │ (WSS)
                             ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         BACKEND API (Node.js/TypeScript)                 │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    PRESENTATION LAYER                               │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │  │ REST Routes  │  │ WebSocket    │  │ GraphQL      │            │ │
│  │  │ (Express)    │  │ (Socket.io)  │  │ (Optional)   │            │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │ │
│  └─────────┼──────────────────┼──────────────────┼────────────────────┘ │
│            │                  │                  │                       │
│  ┌─────────▼──────────────────▼──────────────────▼────────────────────┐ │
│  │                    APPLICATION LAYER                                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │  │  Use Cases   │  │     DTOs     │  │  Validators  │            │ │
│  │  │              │  │              │  │    (Zod)     │            │ │
│  │  └──────┬───────┘  └──────────────┘  └──────────────┘            │ │
│  └─────────┼──────────────────────────────────────────────────────────┘ │
│            │                                                             │
│  ┌─────────▼──────────────────────────────────────────────────────────┐ │
│  │                      DOMAIN LAYER                                   │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │  │   Entities   │  │   Services   │  │    Events    │            │ │
│  │  │              │  │              │  │              │            │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│            │                                                             │
│  ┌─────────▼──────────────────────────────────────────────────────────┐ │
│  │                  INFRASTRUCTURE LAYER                               │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │  │ Repositories │  │    Cache     │  │    Queue     │            │ │
│  │  │ (PostgreSQL) │  │   (Redis)    │  │  (BullMQ)    │            │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SERVICES                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │   Maps API   │  │ Notification │  │   Storage    │  │  Printing  │ │
│  │ (OSM/Google) │  │ (OneSignal)  │  │   (S3/Min)   │  │  (CUPS)    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Structure de Dossiers Backend

```
awid-backend/
├── src/
│   ├── domain/                          # 🎯 LOGIQUE MÉTIER PURE
│   │   ├── entities/
│   │   │   ├── Organization.ts
│   │   │   ├── User.ts
│   │   │   ├── Product.ts
│   │   │   ├── Order.ts
│   │   │   ├── Delivery.ts
│   │   │   ├── Payment.ts
│   │   │   ├── Packaging.ts
│   │   │   └── Stock.ts
│   │   │
│   │   ├── value-objects/
│   │   │   ├── Money.ts
│   │   │   ├── Address.ts
│   │   │   ├── Coordinates.ts
│   │   │   ├── PhoneNumber.ts
│   │   │   └── OrderStatus.ts
│   │   │
│   │   ├── services/
│   │   │   ├── PricingService.ts
│   │   │   ├── CreditService.ts
│   │   │   ├── RouteOptimizationService.ts
│   │   │   └── DebtAgingService.ts
│   │   │
│   │   ├── events/
│   │   │   ├── OrderCreated.ts
│   │   │   ├── OrderDelivered.ts
│   │   │   ├── PaymentReceived.ts
│   │   │   ├── CreditLimitExceeded.ts
│   │   │   └── StockLow.ts
│   │   │
│   │   └── repositories/                # Interfaces
│   │       ├── IOrderRepository.ts
│   │       ├── IUserRepository.ts
│   │       └── IProductRepository.ts
│   │
│   ├── application/                     # 🔄 CAS D'UTILISATION
│   │   ├── use-cases/
│   │   │   ├── orders/
│   │   │   │   ├── CreateOrder.ts
│   │   │   │   ├── UpdateOrderStatus.ts
│   │   │   │   ├── AssignDeliverer.ts
│   │   │   │   └── CancelOrder.ts
│   │   │   │
│   │   │   ├── deliveries/
│   │   │   │   ├── OptimizeRoute.ts
│   │   │   │   ├── CompleteDelivery.ts
│   │   │   │   ├── RecordProofOfDelivery.ts
│   │   │   │   └── UpdateDelivererLocation.ts
│   │   │   │
│   │   │   ├── payments/
│   │   │   │   ├── RecordPayment.ts
│   │   │   │   ├── AllocatePaymentToOrders.ts
│   │   │   │   └── GenerateInvoice.ts
│   │   │   │
│   │   │   ├── financial/
│   │   │   │   ├── GetDebtsByCustomer.ts
│   │   │   │   ├── GetAgingReport.ts
│   │   │   │   ├── GetCashFlowForecast.ts
│   │   │   │   └── GenerateDailyReport.ts
│   │   │   │
│   │   │   └── notifications/
│   │   │       ├── SendOrderNotification.ts
│   │   │       ├── SendDeliveryAlert.ts
│   │   │       └── SendCreditAlert.ts
│   │   │
│   │   ├── dto/
│   │   │   ├── requests/
│   │   │   └── responses/
│   │   │
│   │   ├── validators/                  # 🔷 ZOD SCHEMAS
│   │   │   ├── common.schema.ts
│   │   │   ├── auth.schema.ts
│   │   │   ├── order.schema.ts
│   │   │   ├── delivery.schema.ts
│   │   │   ├── payment.schema.ts
│   │   │   └── product.schema.ts
│   │   │
│   │   └── mappers/
│   │       ├── OrderMapper.ts
│   │       └── UserMapper.ts
│   │
│   ├── infrastructure/                  # 🔌 ADAPTATEURS
│   │   ├── database/
│   │   │   ├── PostgresConnection.ts
│   │   │   ├── repositories/
│   │   │   │   ├── PostgresOrderRepository.ts
│   │   │   │   ├── PostgresUserRepository.ts
│   │   │   │   └── PostgresProductRepository.ts
│   │   │   └── migrations/
│   │   │
│   │   ├── cache/
│   │   │   └── RedisCache.ts
│   │   │
│   │   ├── queue/
│   │   │   ├── BullMQAdapter.ts
│   │   │   └── jobs/
│   │   │       ├── SendNotificationJob.ts
│   │   │       ├── GenerateReportJob.ts
│   │   │       ├── OptimizeRoutesJob.ts
│   │   │       └── CleanupJob.ts
│   │   │
│   │   ├── external/
│   │   │   ├── maps/
│   │   │   │   ├── OpenStreetMapService.ts
│   │   │   │   └── GoogleMapsService.ts
│   │   │   │
│   │   │   ├── notifications/
│   │   │   │   ├── OneSignalService.ts
│   │   │   │   ├── SMSService.ts          # Mobilis/Djezzy/Ooredoo
│   │   │   │   └── EmailService.ts        # SMTP
│   │   │   │
│   │   │   ├── storage/
│   │   │   │   ├── MinioService.ts        # S3-compatible
│   │   │   │   └── LocalStorageService.ts
│   │   │   │
│   │   │   └── printing/
│   │   │       └── CUPSService.ts         # Linux printing
│   │   │
│   │   └── logging/
│   │       ├── WinstonLogger.ts
│   │       └── SentryErrorReporter.ts
│   │
│   ├── presentation/                    # 🌐 API
│   │   ├── http/
│   │   │   ├── controllers/
│   │   │   │   ├── AuthController.ts
│   │   │   │   ├── OrderController.ts
│   │   │   │   ├── DeliveryController.ts
│   │   │   │   ├── PaymentController.ts
│   │   │   │   ├── FinancialController.ts
│   │   │   │   └── ReportController.ts
│   │   │   │
│   │   │   ├── routes/
│   │   │   │   ├── v1/
│   │   │   │   │   ├── index.ts
│   │   │   │   │   ├── auth.routes.ts
│   │   │   │   │   ├── orders.routes.ts
│   │   │   │   │   ├── deliveries.routes.ts
│   │   │   │   │   ├── payments.routes.ts
│   │   │   │   │   ├── financial.routes.ts
│   │   │   │   │   └── products.routes.ts
│   │   │   │   └── v2/
│   │   │   │
│   │   │   └── middlewares/
│   │   │       ├── auth.middleware.ts
│   │   │       ├── validate.middleware.ts
│   │   │       ├── rateLimit.middleware.ts
│   │   │       ├── errorHandler.middleware.ts
│   │   │       └── organizationContext.middleware.ts
│   │   │
│   │   └── websocket/
│   │       ├── SocketServer.ts
│   │       ├── handlers/
│   │       │   ├── DeliveryTrackingHandler.ts
│   │       │   ├── DashboardHandler.ts
│   │       │   └── KitchenHandler.ts
│   │       └── rooms/
│   │           ├── OrganizationRoom.ts
│   │           └── DeliveryRoom.ts
│   │
│   ├── shared/                          # 🔧 UTILITAIRES
│   │   ├── errors/
│   │   │   ├── AppError.ts
│   │   │   ├── ValidationError.ts
│   │   │   ├── NotFoundError.ts
│   │   │   └── UnauthorizedError.ts
│   │   │
│   │   ├── utils/
│   │   │   ├── date.utils.ts
│   │   │   ├── crypto.utils.ts
│   │   │   ├── pagination.utils.ts
│   │   │   └── pdf.utils.ts
│   │   │
│   │   └── constants/
│   │       ├── orderStatuses.ts
│   │       ├── paymentModes.ts
│   │       └── userRoles.ts
│   │
│   ├── config/                          # ⚙️ CONFIGURATION
│   │   ├── app.config.ts
│   │   ├── database.config.ts
│   │   ├── redis.config.ts
│   │   ├── jwt.config.ts
│   │   ├── maps.config.ts
│   │   └── env.validation.ts
│   │
│   └── main.ts                          # Point d'entrée
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── docs/
│   ├── api/
│   ├── architecture/
│   └── deployment/
│
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   └── docker-compose.yml
│
├── .env.example
├── tsconfig.json
├── package.json
└── README.md
```

### 3.3 Structure Mobile (Flutter)

```
awid-mobile/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart
│   │   │   ├── app_constants.dart
│   │   │   └── storage_keys.dart
│   │   │
│   │   ├── database/
│   │   │   ├── hive_service.dart
│   │   │   ├── sync_service.dart
│   │   │   └── models/
│   │   │       ├── cached_order.dart
│   │   │       ├── cached_delivery.dart
│   │   │       └── pending_action.dart
│   │   │
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── order_model.dart
│   │   │   ├── delivery_model.dart
│   │   │   ├── payment_model.dart
│   │   │   └── product_model.dart
│   │   │
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── location_service.dart
│   │   │   ├── notification_service.dart
│   │   │   ├── offline_service.dart
│   │   │   ├── websocket_service.dart
│   │   │   └── print_service.dart
│   │   │
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── theme_provider.dart
│   │   │   └── connectivity_provider.dart
│   │   │
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   │
│   │   └── widgets/
│   │       ├── custom_button.dart
│   │       ├── loading_indicator.dart
│   │       ├── offline_indicator.dart
│   │       └── sync_indicator.dart
│   │
│   ├── features/
│   │   ├── admin/
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── admin_dashboard.dart
│   │   │   │   │   ├── orders_page.dart
│   │   │   │   │   ├── deliveries_page.dart
│   │   │   │   │   ├── financial_page.dart
│   │   │   │   │   ├── users_page.dart
│   │   │   │   │   ├── products_page.dart
│   │   │   │   │   ├── reports_page.dart
│   │   │   │   │   └── settings_page.dart
│   │   │   │   │
│   │   │   │   └── widgets/
│   │   │   │       ├── dashboard_card.dart
│   │   │   │       ├── financial_chart.dart
│   │   │   │       ├── alert_card.dart
│   │   │   │       └── deliverer_map.dart
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── dashboard_provider.dart
│   │   │       ├── orders_provider.dart
│   │   │       └── financial_provider.dart
│   │   │
│   │   ├── deliverer/
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── deliverer_dashboard.dart
│   │   │   │   │   ├── delivery_detail_page.dart
│   │   │   │   │   ├── route_optimization_page.dart
│   │   │   │   │   ├── payment_collection_page.dart
│   │   │   │   │   ├── proof_of_delivery_page.dart
│   │   │   │   │   └── earnings_page.dart
│   │   │   │   │
│   │   │   │   └── widgets/
│   │   │   │       ├── delivery_card.dart
│   │   │   │       ├── signature_pad.dart
│   │   │   │       ├── photo_capture.dart
│   │   │   │       └── navigation_button.dart
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── deliveries_provider.dart
│   │   │       ├── location_provider.dart
│   │   │       └── route_provider.dart
│   │   │
│   │   ├── customer/
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── customer_dashboard.dart
│   │   │   │   │   ├── new_order_page.dart
│   │   │   │   │   ├── favorites_page.dart
│   │   │   │   │   ├── order_tracking_page.dart
│   │   │   │   │   ├── order_history_page.dart
│   │   │   │   │   ├── financial_page.dart
│   │   │   │   │   ├── claims_page.dart
│   │   │   │   │   └── settings_page.dart
│   │   │   │   │
│   │   │   │   └── widgets/
│   │   │   │       ├── product_card.dart
│   │   │   │       ├── favorite_card.dart
│   │   │   │       ├── tracking_map.dart
│   │   │   │       └── debt_summary.dart
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── orders_provider.dart
│   │   │       ├── favorites_provider.dart
│   │   │       └── tracking_provider.dart
│   │   │
│   │   ├── kitchen/
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── kitchen_dashboard.dart
│   │   │   │   │   ├── kanban_board_page.dart
│   │   │   │   │   ├── order_detail_page.dart
│   │   │   │   │   ├── stock_management_page.dart
│   │   │   │   │   └── production_stats_page.dart
│   │   │   │   │
│   │   │   │   └── widgets/
│   │   │   │       ├── kanban_column.dart
│   │   │   │       ├── order_card.dart
│   │   │   │       ├── stock_alert.dart
│   │   │   │       └── timer_widget.dart
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── kitchen_provider.dart
│   │   │       └── stock_provider.dart
│   │   │
│   │   └── auth/
│   │       ├── presentation/
│   │       │   └── pages/
│   │       │       ├── login_page.dart
│   │       │       └── onboarding_page.dart
│   │       │
│   │       └── providers/
│   │           └── auth_provider.dart
│   │
│   └── main.dart
│
├── android/
├── ios/
├── test/
├── pubspec.yaml
└── README.md
```

---

## 4. FONCTIONNALITÉS PRIORITAIRES

### 4.1 Matrice de Priorisation

| ID      | Fonctionnalité          | Persona | Impact        | Effort | Priorité | Sprint |
| ------- | ----------------------- | ------- | ------------- | ------ | -------- | ------ |
| **F1**  | Dashboard temps réel    | Admin   | 🔴 Très élevé | Moyen  | P0       | 1-2    |
| **F2**  | Mode hors-ligne complet | Livreur | 🔴 Très élevé | Élevé  | P0       | 2-3    |
| **F3**  | Commande ultra-rapide   | Client  | 🔴 Très élevé | Faible | P0       | 1      |
| **F4**  | Vue Kanban tactile      | Cuisine | 🔴 Très élevé | Moyen  | P0       | 2      |
| **F5**  | Tracking temps réel     | Client  | 🔴 Très élevé | Moyen  | P0       | 3      |
| **F6**  | Optimisation itinéraire | Livreur | 🟡 Élevé      | Élevé  | P1       | 4      |
| **F7**  | Preuve de livraison     | Livreur | 🟡 Élevé      | Faible | P1       | 3      |
| **F8**  | Gestion financière      | Admin   | 🟡 Élevé      | Moyen  | P1       | 2      |
| **F9**  | Système alertes         | Admin   | 🟡 Élevé      | Moyen  | P1       | 3      |
| **F10** | Gestion stocks          | Cuisine | 🟡 Élevé      | Moyen  | P1       | 4      |
| **F11** | Réclamations            | Client  | 🟢 Moyen      | Faible | P2       | 5      |
| **F12** | Évaluations             | Client  | 🟢 Moyen      | Faible | P2       | 5      |
| **F13** | Rapports automatisés    | Admin   | 🟢 Moyen      | Moyen  | P2       | 6      |
| **F14** | Multi-organisation      | Admin   | 🟢 Moyen      | Élevé  | P3       | 7-8    |

### 4.2 Détail des Fonctionnalités P0 (MVP)

#### F1. Dashboard Temps Réel (Admin)

**Description** : Tableau de bord avec métriques clés mises à jour en temps réel via WebSocket

**Composants** :

- Statistiques du jour (commandes, CA, encaissements)
- Carte avec livreurs actifs
- Liste des alertes
- Graphiques d'évolution
- Notifications push

**Technologies** :

- Backend : Socket.io
- Frontend : Flutter WebSocket + Provider
- Cache : Redis pour agrégations

**Endpoints** :

```typescript
// WebSocket events
socket.on("dashboard:stats", (data) => {});
socket.on("dashboard:alert", (alert) => {});
socket.on("deliverer:location", (location) => {});

// REST fallback
GET / api / dashboard / stats;
GET / api / dashboard / alerts;
```

**Estimation** : 2 sprints (4 semaines)

---

#### F2. Mode Hors-Ligne Complet (Livreur)

**Description** : Application fonctionnelle sans connexion internet avec synchronisation automatique

**Composants** :

- Synchronisation au démarrage
- Base de données locale (Hive)
- Queue d'actions en attente
- Sync automatique dès connexion
- Indicateurs visuels

**Technologies** :

- Flutter : Hive (NoSQL local)
- Sync : Background service
- Détection : connectivity_plus

**Flux** :

```
1. Démarrage app → Sync complète
2. Perte connexion → Mode offline activé
3. Actions → Enregistrées localement
4. Connexion retrouvée → Sync automatique
5. Conflits → Résolution côté serveur
```

**Estimation** : 3 sprints (6 semaines)

---

#### F3. Commande Ultra-Rapide (Client)

**Description** : Interface optimisée pour créer une commande en moins de 30 secondes

**Composants** :

- Favoris en 1 clic
- Catalogue visuel avec photos
- Panier intelligent
- Commandes récurrentes
- Validation rapide

**Technologies** :

- Flutter : Cached images
- Backend : Cache Redis pour catalogue
- Optimisation : Lazy loading

**Flux** :

```
1. Ouvrir app → Favoris affichés
2. Clic sur favori → Panier pré-rempli
3. Ajuster quantités (optionnel)
4. Valider → Commande créée
Total : < 30 secondes
```

**Estimation** : 1 sprint (2 semaines)

---

#### F4. Vue Kanban Tactile (Cuisine)

**Description** : Interface drag & drop pour gérer les commandes en production

**Composants** :

- 4 colonnes (Attente, En cours, Prêt, Récupéré)
- Drag & drop
- Détail commande
- Timer de préparation
- Impression bons

**Technologies** :

- Flutter : flutter_slidable, reorderable_list
- Backend : WebSocket pour sync temps réel
- UI : Optimisée tablette

**Estimation** : 2 sprints (4 semaines)

---

#### F5. Tracking Temps Réel (Client)

**Description** : Suivi de la livraison sur carte avec ETA

**Composants** :

- Carte interactive
- Position livreur en temps réel
- ETA dynamique
- Notifications étapes
- Appel livreur

**Technologies** :

- Maps : OpenStreetMap (gratuit) ou Google Maps
- WebSocket : Position livreur
- Flutter : flutter_map ou google_maps_flutter

**Flux** :

```
1. Commande confirmée → Notification
2. En préparation → Notification
3. Assignée livreur → Tracking activé
4. En livraison → Carte + ETA
5. Livrée → Notification + évaluation
```

**Estimation** : 3 sprints (6 semaines)

---

## 5. STACK TECHNOLOGIQUE OPEN SOURCE

### 5.1 Backend

| Composant      | Technologie          | Justification                 | Licence    |
| -------------- | -------------------- | ----------------------------- | ---------- |
| **Runtime**    | Node.js 20 LTS       | Performance, écosystème riche | MIT        |
| **Langage**    | TypeScript 5.x       | Type safety, meilleure DX     | Apache 2.0 |
| **Framework**  | Express.js           | Léger, flexible, mature       | MIT        |
| **Validation** | Zod                  | Type inference, moderne       | MIT        |
| **Database**   | PostgreSQL 16        | Robuste, ACID, JSON support   | PostgreSQL |
| **Cache**      | Redis 7.x            | Performance, pub/sub          | BSD        |
| **Queue**      | BullMQ               | Fiable, dashboard, retry      | MIT        |
| **WebSocket**  | Socket.io            | Temps réel, fallback          | MIT        |
| **ORM**        | Kysely ou Drizzle    | Type-safe, léger              | MIT        |
| **Auth**       | JWT + bcrypt         | Standard, sécurisé            | MIT        |
| **Logging**    | Winston + Pino       | Structuré, performant         | MIT        |
| **Monitoring** | Sentry (self-hosted) | Error tracking                | BSD        |
| **Testing**    | Vitest + Supertest   | Rapide, moderne               | MIT        |

### 5.2 Mobile

| Composant         | Technologie          | Justification              | Licence      |
| ----------------- | -------------------- | -------------------------- | ------------ |
| **Framework**     | Flutter 3.x          | Cross-platform, performant | BSD          |
| **Langage**       | Dart 3.x             | Null-safety, async/await   | BSD          |
| **State**         | Provider + Riverpod  | Simple, scalable           | MIT          |
| **Storage**       | Hive                 | NoSQL local, rapide        | Apache 2.0   |
| **HTTP**          | Dio                  | Interceptors, retry        | MIT          |
| **WebSocket**     | socket_io_client     | Compatible Socket.io       | MIT          |
| **Maps**          | flutter_map (OSM)    | Gratuit, pas de quota      | BSD          |
| **Location**      | geolocator           | GPS, permissions           | MIT          |
| **Notifications** | OneSignal            | Gratuit jusqu'à 10k users  | Propriétaire |
| **Images**        | cached_network_image | Cache, performance         | MIT          |
| **PDF**           | pdf + printing       | Génération factures        | Apache 2.0   |
| **Signature**     | signature            | Preuve livraison           | MIT          |
| **QR Code**       | qr_flutter           | Consignes                  | BSD          |

### 5.3 Infrastructure

| Composant         | Technologie          | Justification              | Licence      |
| ----------------- | -------------------- | -------------------------- | ------------ |
| **Container**     | Docker               | Isolation, portabilité     | Apache 2.0   |
| **Orchestration** | Docker Compose       | Simple, suffisant          | Apache 2.0   |
| **Reverse Proxy** | Nginx                | Performance, SSL           | BSD          |
| **Storage**       | MinIO                | S3-compatible, self-hosted | AGPL         |
| **Backup**        | pg_dump + cron       | Natif PostgreSQL           | PostgreSQL   |
| **Monitoring**    | Prometheus + Grafana | Métriques, dashboards      | Apache 2.0   |
| **CI/CD**         | GitHub Actions       | Gratuit, intégré           | Propriétaire |

### 5.4 Services Externes (Optionnels)

| Service         | Usage              | Coût                  | Alternative             |
| --------------- | ------------------ | --------------------- | ----------------------- |
| **Google Maps** | Navigation         | Payant après quota    | OpenStreetMap (gratuit) |
| **OneSignal**   | Push notifications | Gratuit < 10k users   | Firebase (gratuit)      |
| **SMS Gateway** | Alertes SMS        | Variable              | Mobilis/Djezzy API      |
| **Email**       | SMTP               | Gratuit (self-hosted) | Mailgun (payant)        |

### 5.5 Recommandations Spécifiques Algérie

**Maps & Navigation** :

- **Recommandé** : OpenStreetMap + OSRM (gratuit, self-hosted)
- **Alternative** : Google Maps (payant mais meilleure qualité)
- **Données** : OSM Algérie bien couvert pour grandes villes

**SMS** :

- **Mobilis** : API SMS disponible
- **Djezzy** : API SMS disponible
- **Ooredoo** : API SMS disponible
- **Coût** : ~2-5 DZD par SMS

**Hébergement** :

- **Local** : Algérie Télécom, Icosnet
- **International** : Hetzner (Allemagne), OVH (France)
- **Recommandation** : Hetzner (bon rapport qualité/prix)

**Paiement** :

- **CIB** : Carte interbancaire algérienne
- **Satim** : Plateforme de paiement
- **Note** : Intégration complexe, privilégier cash pour MVP

---

## 6. ROADMAP D'IMPLÉMENTATION

### 6.1 Vue d'Ensemble (6 mois)

```
Phase 1: Fondations (Mois 1-2)
├─ Sprint 1-2: Migration TypeScript + Architecture
├─ Sprint 3-4: Sécurité & Performance
└─ Livrable: Base technique solide

Phase 2: MVP (Mois 3-4)
├─ Sprint 5-6: Fonctionnalités P0 Admin
├─ Sprint 7-8: Fonctionnalités P0 Livreur
├─ Sprint 9-10: Fonctionnalités P0 Client/Cuisine
└─ Livrable: Application fonctionnelle complète

Phase 3: Amélioration (Mois 5-6)
├─ Sprint 11-12: Fonctionnalités P1
├─ Sprint 13-14: Fonctionnalités P2
└─ Livrable: Application enrichie

Phase 4: Production (Continu)
├─ Tests utilisateurs
├─ Corrections bugs
├─ Optimisations
└─ Déploiement progressif
```

### 6.2 Phase 1 : Fondations (8 semaines)

#### Sprint 1-2 : Migration TypeScript + Architecture (4 semaines)

**Objectifs** :

- Convertir le backend en TypeScript
- Implémenter Clean Architecture
- Migrer Joi → Zod
- Mettre en place les tests

**Tâches** :

**Semaine 1-2 : Backend**

- [ ] Initialiser projet TypeScript
- [ ] Configurer tsconfig.json, ESLint, Prettier
- [ ] Créer structure de dossiers (domain, application, infrastructure, presentation)
- [ ] Migrer les entités du domaine
- [ ] Créer les interfaces de repositories
- [ ] Migrer tous les schémas Joi vers Zod
- [ ] Créer middleware de validation Zod
- [ ] Tests unitaires domaine

**Semaine 3-4 : Infrastructure & API**

- [ ] Implémenter repositories PostgreSQL
- [ ] Configurer Redis pour cache
- [ ] Configurer BullMQ pour jobs
- [ ] Migrer toutes les routes vers nouvelle architecture
- [ ] Implémenter use cases principaux
- [ ] Tests d'intégration
- [ ] Documentation API (OpenAPI/Swagger)

**Livrables** :

- ✅ Backend TypeScript fonctionnel
- ✅ Architecture Clean implémentée
- ✅ Validation Zod complète
- ✅ Tests > 70% couverture
- ✅ Documentation API

---

#### Sprint 3-4 : Sécurité & Performance (4 semaines)

**Objectifs** :

- Renforcer la sécurité
- Optimiser les performances
- Implémenter monitoring

**Tâches** :

**Semaine 5 : Sécurité**

- [ ] Implémenter rate limiting intelligent (par IP, par user, par endpoint)
- [ ] Ajouter helmet.js avec configuration stricte
- [ ] Implémenter CORS configuré par organisation
- [ ] Rotation automatique des tokens JWT
- [ ] Audit logging complet (qui, quoi, quand)
- [ ] Chiffrement données sensibles (bcrypt, crypto)
- [ ] Tests de sécurité (OWASP Top 10)

**Semaine 6 : Performance**

- [ ] Optimiser requêtes SQL (index, explain analyze)
- [ ] Implémenter cache multi-niveau (Redis + in-memory)
- [ ] Compression responses (gzip)
- [ ] Lazy loading images
- [ ] Pagination optimisée
- [ ] Connection pooling PostgreSQL
- [ ] Load testing (Artillery ou k6)

**Semaine 7 : Monitoring**

- [ ] Configurer Winston pour logs structurés
- [ ] Intégrer Sentry pour error tracking
- [ ] Métriques Prometheus (requests, latency, errors)
- [ ] Dashboards Grafana
- [ ] Alertes (Slack/Email)
- [ ] Health checks (/health, /ready)

**Semaine 8 : Mobile Offline**

- [ ] Configurer Hive pour storage local
- [ ] Implémenter sync service
- [ ] Queue d'actions en attente
- [ ] Détection connectivité
- [ ] Résolution conflits
- [ ] Tests offline

**Livrables** :

- ✅ Sécurité renforcée (rate limiting, audit)
- ✅ Performance optimisée (< 200ms p95)
- ✅ Monitoring opérationnel
- ✅ Mode offline fonctionnel

---

### 6.3 Phase 2 : MVP (8 semaines)

#### Sprint 5-6 : Admin Dashboard (4 semaines)

**Objectifs** :

- Dashboard temps réel
- Gestion financière
- Système d'alertes

**Tâches** :

**Semaine 9 : WebSocket & Dashboard Backend**

- [ ] Configurer Socket.io
- [ ] Implémenter rooms par organisation
- [ ] Events dashboard (stats, alerts, locations)
- [ ] Agrégations Redis pour performance
- [ ] API REST fallback
- [ ] Tests WebSocket

**Semaine 10 : Dashboard Frontend**

- [ ] Page dashboard avec Provider
- [ ] Connexion WebSocket
- [ ] Cartes statistiques temps réel
- [ ] Graphiques (fl_chart)
- [ ] Liste alertes
- [ ] Notifications push

**Semaine 11 : Gestion Financière**

- [ ] Page vue d'ensemble financière
- [ ] Rapport vieillissement créances
- [ ] Historique paiements avec filtres
- [ ] Export PDF/Excel
- [ ] Graphiques évolution
- [ ] Alertes crédit

**Semaine 12 : Système Alertes**

- [ ] Définition règles d'alertes
- [ ] Moteur d'évaluation (BullMQ job)
- [ ] Notifications multi-canal (push, SMS, email)
- [ ] Configuration par admin
- [ ] Historique alertes
- [ ] Tests alertes

**Livrables** :

- ✅ Dashboard temps réel fonctionnel
- ✅ Gestion financière complète
- ✅ Alertes automatiques

---

#### Sprint 7-8 : Livreur (4 semaines)

**Objectifs** :

- Interface livreur optimisée
- Preuve de livraison
- Gestion paiements

**Tâches** :

**Semaine 13 : Interface Livreur**

- [ ] Dashboard livreur
- [ ] Liste livraisons du jour
- [ ] Détail livraison
- [ ] Navigation vers client
- [ ] Appel client
- [ ] Statuts livraison

**Semaine 14 : Preuve de Livraison**

- [ ] Signature électronique (signature package)
- [ ] Capture photo (camera)
- [ ] Géolocalisation automatique
- [ ] Upload photos (MinIO)
- [ ] Validation preuve
- [ ] Historique preuves

**Semaine 15 : Gestion Paiements**

- [ ] Interface encaissement
- [ ] Sélection commandes à payer
- [ ] Modes de paiement
- [ ] Allocation automatique (FIFO)
- [ ] Reçu numérique
- [ ] Historique encaissements

**Semaine 16 : Consignes & Gains**

- [ ] Gestion consignes (dépôt/retour)
- [ ] Scan QR code
- [ ] Solde consignes par client
- [ ] Page gains livreur
- [ ] Calcul commissions
- [ ] Statistiques personnelles

**Livrables** :

- ✅ App livreur complète
- ✅ Preuve de livraison
- ✅ Gestion paiements/consignes

---

#### Sprint 9-10 : Client & Cuisine (4 semaines)

**Objectifs** :

- Commande ultra-rapide
- Tracking temps réel
- Vue Kanban cuisine

**Tâches** :

**Semaine 17 : Client - Commande Rapide**

- [ ] Page nouvelle commande
- [ ] Catalogue produits avec photos
- [ ] Favoris en 1 clic
- [ ] Panier intelligent
- [ ] Commandes récurrentes
- [ ] Validation rapide

**Semaine 18 : Client - Tracking**

- [ ] Intégration flutter_map (OSM)
- [ ] WebSocket position livreur
- [ ] Calcul ETA
- [ ] Notifications étapes
- [ ] Historique commandes
- [ ] Détail commande

**Semaine 19 : Cuisine - Kanban**

- [ ] Page Kanban avec 4 colonnes
- [ ] Drag & drop (flutter_slidable)
- [ ] Détail commande
- [ ] Timer préparation
- [ ] Changement statut
- [ ] WebSocket sync temps réel

**Semaine 20 : Cuisine - Stocks**

- [ ] Page gestion stocks
- [ ] Alertes stock bas
- [ ] Ajustement stocks
- [ ] Historique mouvements
- [ ] Statistiques consommation
- [ ] Impression bons

**Livrables** :

- ✅ Commande client optimisée
- ✅ Tracking temps réel
- ✅ Kanban cuisine fonctionnel
- ✅ Gestion stocks

---

### 6.4 Phase 3 : Amélioration (8 semaines)

#### Sprint 11-12 : Fonctionnalités P1 (4 semaines)

**Semaine 21 : Optimisation Itinéraire**

- [ ] Intégration OSRM (Open Source Routing Machine)
- [ ] Algorithme optimisation (TSP)
- [ ] Calcul itinéraire optimal
- [ ] Estimation temps/distance
- [ ] Navigation turn-by-turn
- [ ] Tests performance

**Semaine 22 : Rapports Automatisés**

- [ ] Templates PDF (pdfmake)
- [ ] Rapport journalier
- [ ] Rapport hebdomadaire
- [ ] Rapport mensuel
- [ ] Envoi automatique (BullMQ cron)
- [ ] Export Excel

**Semaine 23 : Réclamations**

- [ ] Page nouvelle réclamation
- [ ] Types de problèmes
- [ ] Upload photos
- [ ] Suivi réclamation
- [ ] Résolution admin
- [ ] Notifications

**Semaine 24 : Évaluations**

- [ ] Page évaluation livraison
- [ ] Note 1-5 étoiles
- [ ] Catégories (ponctualité, qualité, comportement)
- [ ] Commentaire
- [ ] Historique évaluations
- [ ] Statistiques livreur

**Livrables** :

- ✅ Optimisation itinéraire
- ✅ Rapports automatisés
- ✅ Réclamations & évaluations

---

#### Sprint 13-14 : Fonctionnalités P2 (4 semaines)

**Semaine 25 : Tarification Avancée**

- [ ] Prix par client
- [ ] Prix par zone
- [ ] Remises volume
- [ ] Promotions temporaires
- [ ] Historique prix
- [ ] Règles automatiques

**Semaine 26 : Programme Fidélité**

- [ ] Système de points
- [ ] Récompenses
- [ ] Niveaux (bronze, argent, or)
- [ ] Historique points
- [ ] Catalogue récompenses
- [ ] Notifications

**Semaine 27 : Améliorations UX**

- [ ] Onboarding interactif
- [ ] Tutoriels in-app
- [ ] Recherche avancée
- [ ] Filtres multiples
- [ ] Thème sombre
- [ ] Accessibilité

**Semaine 28 : Tests & Optimisations**

- [ ] Tests E2E (Maestro ou Patrol)
- [ ] Tests de charge
- [ ] Optimisations performance
- [ ] Corrections bugs
- [ ] Documentation utilisateur
- [ ] Préparation déploiement

**Livrables** :

- ✅ Tarification flexible
- ✅ Programme fidélité
- ✅ UX améliorée
- ✅ Application prête production

---

## 7. SÉCURITÉ & CONFORMITÉ

### 7.1 Sécurité des Données

#### Authentification & Autorisation

```typescript
// JWT avec rotation automatique
interface TokenPair {
  accessToken: string; // 15 minutes
  refreshToken: string; // 7 jours
}

// Middleware d'authentification
const authenticate = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Non authentifié" });

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = await getUserById(payload.userId);
    req.organizationId = payload.organizationId;
    next();
  } catch (error) {
    return res.status(401).json({ error: "Token invalide" });
  }
};

// Middleware d'autorisation
const authorize = (roles: string[]) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Accès refusé" });
    }
    next();
  };
};

// Isolation multi-organisation
const organizationContext = (req, res, next) => {
  // Toutes les requêtes sont filtrées par organizationId
  req.query.organizationId = req.user.organizationId;
  next();
};
```

#### Chiffrement

```typescript
// Données sensibles chiffrées
- Mots de passe : bcrypt (cost 12)
- Tokens : crypto.randomBytes(32)
- Données personnelles : AES-256-GCM
- Communications : HTTPS/TLS 1.3
- Base de données : PostgreSQL encryption at rest
```

#### Rate Limiting

```typescript
// Rate limiting intelligent
const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: (req) => {
    // Limites par rôle
    if (req.user?.role === "admin") return 1000;
    if (req.user?.role === "deliverer") return 500;
    return 100; // Anonymous
  },
  keyGenerator: (req) => {
    // Par user si authentifié, sinon par IP
    return req.user?.id || req.ip;
  },
  handler: (req, res) => {
    res.status(429).json({
      error: "Trop de requêtes, réessayez plus tard",
      retryAfter: res.getHeader("Retry-After"),
    });
  },
});

// Rate limiting par endpoint
app.use("/api/auth/login", rateLimit({ max: 5, windowMs: 15 * 60 * 1000 }));
app.use("/api/orders", rateLimit({ max: 100, windowMs: 60 * 1000 }));
```

#### Audit Logging

```typescript
// Traçabilité complète
interface AuditLog {
  id: string;
  userId: string;
  organizationId: string;
  action: string; // 'order.create', 'payment.record', etc.
  resource: string; // 'order', 'payment', etc.
  resourceId: string;
  changes: {
    before: any;
    after: any;
  };
  ipAddress: string;
  userAgent: string;
  timestamp: Date;
}

// Middleware d'audit
const auditLog = (action: string) => {
  return async (req, res, next) => {
    const originalSend = res.send;
    res.send = function (data) {
      // Log après succès
      if (res.statusCode < 400) {
        logAudit({
          userId: req.user.id,
          organizationId: req.user.organizationId,
          action,
          resource: req.params.resource,
          resourceId: req.params.id,
          ipAddress: req.ip,
          userAgent: req.headers["user-agent"],
        });
      }
      return originalSend.call(this, data);
    };
    next();
  };
};
```

### 7.2 Protection des Données Personnelles

#### RGPD / Loi Algérienne

```typescript
// Consentement utilisateur
interface UserConsent {
  userId: string;
  dataProcessing: boolean; // Traitement données
  marketing: boolean; // Communications marketing
  analytics: boolean; // Statistiques anonymes
  thirdParty: boolean; // Partage tiers (maps, etc.)
  consentDate: Date;
  ipAddress: string;
}

// Droit à l'oubli
const deleteUserData = async (userId: string) => {
  // Anonymiser au lieu de supprimer (historique comptable)
  await db.transaction(async (trx) => {
    await trx("users")
      .where({ id: userId })
      .update({
        email: `deleted_${userId}@anonymized.local`,
        name: "Utilisateur supprimé",
        phone: null,
        address: null,
        deletedAt: new Date(),
      });

    // Supprimer données non essentielles
    await trx("user_sessions").where({ userId }).delete();
    await trx("user_devices").where({ userId }).delete();
    await trx("audit_logs").where({ userId }).update({ userId: null });
  });
};

// Export données (portabilité)
const exportUserData = async (userId: string) => {
  const data = {
    user: await getUser(userId),
    orders: await getOrders(userId),
    payments: await getPayments(userId),
    deliveries: await getDeliveries(userId),
  };
  return generatePDF(data);
};
```

### 7.3 Sécurité Mobile

```dart
// Stockage sécurisé
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = FlutterSecureStorage();

  // Tokens chiffrés
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  // Biométrie
  Future<bool> authenticateWithBiometrics() async {
    final auth = LocalAuthentication();
    return await auth.authenticate(
      localizedReason: 'Authentifiez-vous pour accéder',
      options: AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}

// Certificate pinning
class ApiService {
  final dio = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // Vérifier le certificat
          return cert.sha256 == EXPECTED_CERT_SHA256;
        };
        return client;
      },
    );
}

// Détection root/jailbreak
Future<bool> isDeviceSecure() async {
  final checker = FlutterJailbreakDetection();
  final isJailbroken = await checker.jailbroken;
  final isDeveloperMode = await checker.developerMode;
  return !isJailbroken && !isDeveloperMode;
}
```

### 7.4 Backup & Disaster Recovery

```bash
#!/bin/bash
# Backup automatique PostgreSQL

# Variables
BACKUP_DIR="/var/backups/awid"
DB_NAME="awid_production"
RETENTION_DAYS=30

# Backup complet
pg_dump -Fc $DB_NAME > "$BACKUP_DIR/awid_$(date +%Y%m%d_%H%M%S).dump"

# Backup incrémental (WAL archiving)
# postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /var/backups/awid/wal/%f'

# Nettoyage anciens backups
find $BACKUP_DIR -name "*.dump" -mtime +$RETENTION_DAYS -delete

# Upload vers stockage distant (optionnel)
# rclone sync $BACKUP_DIR remote:awid-backups

# Test de restauration mensuel
if [ $(date +%d) -eq 01 ]; then
  # Restaurer sur base de test
  pg_restore -d awid_test $BACKUP_DIR/latest.dump
  # Vérifier intégrité
  psql -d awid_test -c "SELECT COUNT(*) FROM orders;"
fi
```

### 7.5 Checklist Sécurité

**Backend** :

- [ ] HTTPS obligatoire (TLS 1.3)
- [ ] Helmet.js configuré
- [ ] CORS restrictif
- [ ] Rate limiting par endpoint
- [ ] JWT avec rotation
- [ ] Validation Zod sur toutes les entrées
- [ ] SQL paramétré (pas de concaténation)
- [ ] Audit logging complet
- [ ] Secrets dans variables d'environnement
- [ ] Dépendances à jour (npm audit)

**Mobile** :

- [ ] Certificate pinning
- [ ] Stockage sécurisé (flutter_secure_storage)
- [ ] Biométrie optionnelle
- [ ] Détection root/jailbreak
- [ ] Obfuscation code (ProGuard/R8)
- [ ] Pas de données sensibles en logs
- [ ] Timeout sessions
- [ ] Wipe data après X tentatives échouées

**Infrastructure** :

- [ ] Firewall configuré
- [ ] SSH par clé uniquement
- [ ] Fail2ban actif
- [ ] Backups automatiques testés
- [ ] Monitoring alertes
- [ ] Mises à jour sécurité automatiques
- [ ] Séparation environnements (dev/staging/prod)

---

## 8. DÉPLOIEMENT & SCALABILITÉ

### 8.1 Architecture de Déploiement

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUDFLARE (CDN + DDoS)                       │
│                    - Cache statique                              │
│                    - Protection DDoS                             │
│                    - SSL/TLS                                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX (Reverse Proxy)                         │
│                    - Load balancing                              │
│                    - SSL termination                             │
│                    - Rate limiting                               │
│                    - Compression                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   API Server 1           │  │   API Server 2           │
│   (Node.js + Express)    │  │   (Node.js + Express)    │
│   - REST API             │  │   - REST API             │
│   - WebSocket            │  │   - WebSocket            │
│   - Docker container     │  │   - Docker container     │
└────────────┬─────────────┘  └────────────┬─────────────┘
             │                              │
             └──────────────┬───────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ PostgreSQL   │  │    Redis     │  │   BullMQ     │
│ (Primary)    │  │   (Cache)    │  │   (Queue)    │
│              │  │              │  │              │
│ + Replica    │  │ + Sentinel   │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
        │
        ▼
┌──────────────┐
│   MinIO      │
│  (Storage)   │
│              │
└──────────────┘
```

### 8.2 Docker Compose Production

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - api-1
      - api-2
    restart: unless-stopped
    networks:
      - awid-network

  # API Server 1
  api-1:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://awid:${DB_PASSWORD}@postgres:5432/awid
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - INSTANCE_ID=api-1
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G

  # API Server 2
  api-2:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://awid:${DB_PASSWORD}@postgres:5432/awid
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - INSTANCE_ID=api-2
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G

  # PostgreSQL
  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=awid
      - POSTGRES_USER=awid
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=fr_FR.UTF-8
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G

  # Redis
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped
    networks:
      - awid-network

  # BullMQ Worker
  worker:
    build:
      context: ./backend
      dockerfile: Dockerfile.worker
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://awid:${DB_PASSWORD}@postgres:5432/awid
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network

  # MinIO (S3-compatible storage)
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    restart: unless-stopped
    networks:
      - awid-network

  # Prometheus (Monitoring)
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - awid-network

  # Grafana (Dashboards)
  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_INSTALL_PLUGINS=redis-datasource
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
    restart: unless-stopped
    networks:
      - awid-network

volumes:
  postgres-data:
  redis-data:
  minio-data:
  prometheus-data:
  grafana-data:

networks:
  awid-network:
    driver: bridge
```

### 8.3 Configuration Nginx

```nginx
# nginx/nginx.conf
upstream api_backend {
    least_conn;
    server api-1:3000 max_fails=3 fail_timeout=30s;
    server api-2:3000 max_fails=3 fail_timeout=30s;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

# Cache
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m;

server {
    listen 80;
    server_name api.awid.dz;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.awid.dz;

    # SSL
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # API endpoints
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;

        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Auth endpoints (stricter rate limit)
    location /api/auth/ {
        limit_req zone=auth_limit burst=5 nodelay;

        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # WebSocket
    location /socket.io/ {
        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;

        # WebSocket timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Health check
    location /health {
        access_log off;
        proxy_pass http://api_backend;
    }

    # Static files (if any)
    location /static/ {
        alias /var/www/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 8.4 Stratégie de Scalabilité

#### Scalabilité Horizontale

```typescript
// Configuration multi-instance
// Utiliser Redis pour session partagée
import RedisStore from "connect-redis";
import session from "express-session";

app.use(
  session({
    store: new RedisStore({ client: redisClient }),
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
  }),
);

// WebSocket avec Redis adapter pour multi-instance
import { createAdapter } from "@socket.io/redis-adapter";

const pubClient = createClient({ url: REDIS_URL });
const subClient = pubClient.duplicate();

io.adapter(createAdapter(pubClient, subClient));
```

#### Optimisation Base de Données

```sql
-- Index critiques
CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders(customer_id);
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX CONCURRENTLY idx_deliveries_deliverer_id ON deliveries(deliverer_id);
CREATE INDEX CONCURRENTLY idx_deliveries_status ON deliveries(status);
CREATE INDEX CONCURRENTLY idx_payments_customer_id ON payments(customer_id);

-- Partitionnement par date (pour historique)
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Vues matérialisées pour rapports
CREATE MATERIALIZED VIEW daily_stats AS
SELECT
    DATE(created_at) as date,
    organization_id,
    COUNT(*) as total_orders,
    SUM(total) as total_revenue,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered_orders
FROM orders
GROUP BY DATE(created_at), organization_id;

-- Refresh automatique
CREATE OR REPLACE FUNCTION refresh_daily_stats()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY daily_stats;
END;
$$ LANGUAGE plpgsql;

-- Cron job (pg_cron extension)
SELECT cron.schedule('refresh-stats', '0 1 * * *', 'SELECT refresh_daily_stats()');
```

#### Cache Strategy

```typescript
// Cache multi-niveau
class CacheService {
  private memoryCache = new Map();
  private redisClient: Redis;

  async get<T>(key: string): Promise<T | null> {
    // L1: Memory cache (très rapide)
    if (this.memoryCache.has(key)) {
      return this.memoryCache.get(key);
    }

    // L2: Redis cache
    const cached = await this.redisClient.get(key);
    if (cached) {
      const value = JSON.parse(cached);
      this.memoryCache.set(key, value);
      return value;
    }

    return null;
  }

  async set<T>(key: string, value: T, ttl: number = 3600): Promise<void> {
    // L1: Memory
    this.memoryCache.set(key, value);

    // L2: Redis
    await this.redisClient.setex(key, ttl, JSON.stringify(value));
  }

  async invalidate(pattern: string): Promise<void> {
    // Invalider memory cache
    for (const key of this.memoryCache.keys()) {
      if (key.match(pattern)) {
        this.memoryCache.delete(key);
      }
    }

    // Invalider Redis
    const keys = await this.redisClient.keys(pattern);
    if (keys.length > 0) {
      await this.redisClient.del(...keys);
    }
  }
}

// Utilisation
const cache = new CacheService();

// Cache produits (1 heure)
const products =
  (await cache.get("products:all")) ||
  (await cache.set("products:all", await db.getProducts(), 3600));

// Invalider après modification
await cache.invalidate("products:*");
```

### 8.5 Monitoring & Alertes

```typescript
// Métriques Prometheus
import promClient from "prom-client";

const register = new promClient.Registry();

// Métriques custom
const httpRequestDuration = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const activeOrders = new promClient.Gauge({
  name: "active_orders_total",
  help: "Number of active orders",
  labelNames: ["organization_id"],
});

const deliverySuccess = new promClient.Counter({
  name: "delivery_success_total",
  help: "Number of successful deliveries",
  labelNames: ["organization_id", "deliverer_id"],
});

register.registerMetric(httpRequestDuration);
register.registerMetric(activeOrders);
register.registerMetric(deliverySuccess);

// Middleware de métriques
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(
        req.method,
        req.route?.path || req.path,
        res.statusCode.toString(),
      )
      .observe(duration);
  });
  next();
});

// Endpoint métriques
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});
```

### 8.6 Checklist Déploiement

**Pré-déploiement** :

- [ ] Tests E2E passent
- [ ] Load testing effectué
- [ ] Backup base de données
- [ ] Variables d'environnement configurées
- [ ] SSL/TLS configuré
- [ ] DNS configuré
- [ ] Monitoring actif

**Déploiement** :

- [ ] Mode maintenance activé
- [ ] Migration base de données
- [ ] Déploiement code
- [ ] Vérification health checks
- [ ] Tests smoke
- [ ] Mode maintenance désactivé

**Post-déploiement** :

- [ ] Monitoring dashboards
- [ ] Logs vérifiés
- [ ] Performance vérifiée
- [ ] Alertes configurées
- [ ] Documentation mise à jour
- [ ] Communication équipe

---

## 9. CONCLUSION & PROCHAINES ÉTAPES

### 9.1 Résumé Exécutif

Ce plan d'amélioration transforme AWID en une **plateforme complète de gestion de livraison** adaptée au marché algérien, avec :

✅ **Architecture moderne** : Clean Architecture + TypeScript + Zod
✅ **Fonctionnalités complètes** : Dashboard temps réel, tracking, offline, etc.
✅ **Sécurité renforcée** : Authentification, chiffrement, audit
✅ **Performance optimisée** : Cache multi-niveau, WebSocket, optimisations SQL
✅ **Scalabilité** : Multi-instance, load balancing, monitoring
✅ **Stack 100% open source** : Pas de dépendances propriétaires coûteuses

### 9.2 Investissement

**Temps** : 6 mois (24 sprints)
**Équipe recommandée** :

- 2 développeurs backend (TypeScript/Node.js)
- 2 développeurs mobile (Flutter/Dart)
- 1 DevOps (Docker/Nginx/PostgreSQL)
- 1 Designer UI/UX (optionnel)

**Coûts estimés** :

- Développement : Selon équipe interne ou externe
- Infrastructure : ~50-100€/mois (Hetzner VPS)
- Services : ~20€/mois (OneSignal, domaine, SSL)
- **Total** : ~70-120€/mois en production

### 9.3 ROI Attendu

**Gains opérationnels** :

- ⏱️ Temps de création commande : -70% (5 min → 30 sec)
- 📊 Visibilité temps réel : +100%
- 💰 Erreurs comptables : -80%
- 🚚 Efficacité livraisons : +30% (optimisation itinéraire)
- 📱 Satisfaction utilisateurs : +50%

**Gains financiers** :

- Réduction pertes (erreurs, oublis) : ~5-10% du CA
- Augmentation productivité : ~20-30%
- Fidélisation clients : +15%

### 9.4 Démarrage Immédiat

**Semaine 1** :

1. Valider ce plan avec l'équipe
2. Préparer environnement de développement
3. Initialiser projet TypeScript
4. Configurer CI/CD

**Semaine 2** :

1. Créer structure Clean Architecture
2. Migrer premiers schémas Zod
3. Implémenter premières entités du domaine
4. Tests unitaires

**Questions à résoudre** :

- [ ] Équipe disponible ?
- [ ] Budget validé ?
- [ ] Hébergement choisi ?
- [ ] Maps : OSM ou Google ?
- [ ] Timeline validée ?

---

**Document préparé pour AWID v4.0**  
**Date** : Janvier 2026  
**Auteur** : Équipe Technique AWID  
**Version** : 1.0
