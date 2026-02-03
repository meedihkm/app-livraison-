# 🚚 AWID v3.0 - Système de Livraison B2B Algérien
## Architecture Complète & Spécifications Fonctionnelles

---

# 📋 Table des Matières

1. [Vision & Contexte Métier](#1-vision--contexte-métier)
2. [Architecture Multi-Tenant](#2-architecture-multi-tenant)
3. [Les 3 Applications](#3-les-3-applications)
4. [Modèle de Données](#4-modèle-de-données)
5. [Flux Métier Détaillés](#5-flux-métier-détaillés)
6. [Stack Technique Open Source](#6-stack-technique-open-source)
7. [API Endpoints](#7-api-endpoints)
8. [Sécurité & Isolation](#8-sécurité--isolation)

---

# 1. Vision & Contexte Métier

## 1.1 Le Marché Algérien

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ÉCOSYSTÈME LIVRAISON B2B                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   🏭 ORGANISATION                    🏪 CLIENTS                     │
│   ┌──────────────┐                   ┌──────────────┐               │
│   │ Boulangerie  │                   │ Cafétéria A  │               │
│   │ Pâtisserie   │  ───── 🚚 ─────▶  │ Cafétéria B  │               │
│   │ Pizzeria     │     Livreurs      │ Épicerie C   │               │
│   │ Laiterie     │                   │ Restaurant D │               │
│   └──────────────┘                   └──────────────┘               │
│         │                                   │                       │
│         │                                   │                       │
│    Produit ses                        Commande                      │
│    marchandises                       régulièrement                 │
│         │                                   │                       │
│         ▼                                   ▼                       │
│   ┌─────────────────────────────────────────────────┐               │
│   │              💵 FLUX FINANCIER                   │               │
│   │  • Paiement comptant (cash)                     │               │
│   │  • Paiement partiel                             │               │
│   │  • Crédit (dette) - basé sur la confiance       │               │
│   │  • Encaissement ultérieur des dettes            │               │
│   └─────────────────────────────────────────────────┘               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 1.2 Règles Métier Fondamentales

### Organisation
- Chaque organisation est **totalement isolée** (multi-tenant)
- Possède ses propres : produits, clients, livreurs, tarifs
- Maîtrise totale sur sa comptabilité et ses données
- Peut configurer ses propres règles (limite crédit, impression, etc.)

### Client (Point de vente)
- Appartient à **une seule organisation**
- A une **limite de crédit** configurable
- Historique complet des commandes et paiements
- Peut avoir des **tarifs personnalisés**
- Commande via app mobile simple et rapide

### Livreur
- **Employé** de l'organisation
- Responsable de :
  - Livrer les commandes
  - Encaisser les paiements (cash)
  - Enregistrer les dettes
  - Reporter les paiements partiels
  - Encaisser les anciennes dettes
- Travaille avec une **caisse journalière**
- Doit rendre des comptes chaque soir

### Flux Financier
```
COMMANDE (1000 DZD)
       │
       ▼
┌──────────────────────────────────────┐
│  À la livraison, le client peut :    │
├──────────────────────────────────────┤
│  1. Payer tout     → 1000 cash       │
│  2. Payer partiel  → 500 cash        │
│                      500 dette       │
│  3. Tout à crédit  → 1000 dette      │
└──────────────────────────────────────┘
       │
       ▼
La dette s'accumule sur le compte client
Le livreur peut encaisser lors de futures visites
```

---

# 2. Architecture Multi-Tenant

## 2.1 Isolation des Données

```
┌─────────────────────────────────────────────────────────────────┐
│                      BASE DE DONNÉES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   ORG #1    │  │   ORG #2    │  │   ORG #3    │             │
│  │ Boulangerie │  │ Pâtisserie  │  │  Laiterie   │             │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤             │
│  │ • Produits  │  │ • Produits  │  │ • Produits  │             │
│  │ • Clients   │  │ • Clients   │  │ • Clients   │             │
│  │ • Livreurs  │  │ • Livreurs  │  │ • Livreurs  │             │
│  │ • Commandes │  │ • Commandes │  │ • Commandes │             │
│  │ • Paiements │  │ • Paiements │  │ • Paiements │             │
│  │ • Finance   │  │ • Finance   │  │ • Finance   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│         └────────────────┴────────────────┘                     │
│                          │                                      │
│                    organization_id                              │
│              (clé étrangère sur TOUTES les tables)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2.2 Stratégie d'Isolation

```sql
-- CHAQUE requête est automatiquement filtrée par organization_id
-- Via Row Level Security (RLS) de PostgreSQL

-- Politique RLS sur la table orders
CREATE POLICY org_isolation_orders ON orders
  USING (organization_id = current_setting('app.current_org_id')::uuid);

-- Le middleware injecte l'org_id dans chaque requête
SET app.current_org_id = 'uuid-de-l-organisation';
```

---

# 3. Les 3 Applications

## 3.1 Vue d'Ensemble

```
┌────────────────────────────────────────────────────────────────────┐
│                        AWID PLATFORM                               │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐           │
│  │  📱 CLIENT   │   │ 🚚 LIVREUR   │   │  💼 ADMIN    │           │
│  │     APP      │   │     APP      │   │     APP      │           │
│  ├──────────────┤   ├──────────────┤   ├──────────────┤           │
│  │ • Commander  │   │ • Tournée    │   │ • Dashboard  │           │
│  │ • Historique │   │ • Livrer     │   │ • Clients    │           │
│  │ • Ma dette   │   │ • Encaisser  │   │ • Livreurs   │           │
│  │ • Catalogue  │   │ • Imprimer   │   │ • Produits   │           │
│  │              │   │ • Navigation │   │ • Commandes  │           │
│  │              │   │              │   │ • Finance    │           │
│  │              │   │              │   │ • Rapports   │           │
│  └──────────────┘   └──────────────┘   └──────────────┘           │
│        │                   │                   │                   │
│        └───────────────────┼───────────────────┘                   │
│                            │                                       │
│                     ┌──────▼──────┐                                │
│                     │   🔌 API    │                                │
│                     │   Backend   │                                │
│                     └─────────────┘                                │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 3.2 📱 APPLICATION CLIENT

### Philosophie
> **"Simple, rapide, efficace"**
> Le client veut commander en 30 secondes, pas naviguer dans des menus complexes.

### Écrans Principaux

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP CLIENT - NAVIGATION                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐      │
│  │   🏠    │    │   📦    │    │   📋    │    │   👤    │      │
│  │ Accueil │    │Commander│    │Historiq.│    │ Compte  │      │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  🏠 ACCUEIL (Dashboard simplifié)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  Bonjour, Cafétéria El Baraka ☕                    │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │  💰 Ma dette     │  │  📦 En cours     │                     │
│  │   12,500 DZD     │  │   2 commandes    │                     │
│  └──────────────────┘  └──────────────────┘                     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  ⚡ COMMANDER RAPIDEMENT                [+]         │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  🥖 Pain tradition      ×20    [−][+]              │        │
│  │  🥐 Croissant           ×10    [−][+]              │        │
│  │  🍞 Baguette            ×15    [−][+]              │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │       Dernière commande : il y a 2 jours            │        │
│  │                                                     │        │
│  │  [ 🔄 Recommander la dernière ]                     │        │
│  │  [ ➕ Nouvelle commande       ]                     │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📅 Prochaine livraison                             │        │
│  │  Demain 06:00 - Ahmed (livreur)                     │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  📦 COMMANDER (Interface optimisée)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔍 Rechercher un produit...                                    │
│                                                                 │
│  ┌─────────┬─────────┬─────────┬─────────┐                      │
│  │  Tous   │  Pain   │Viennois.│ Gâteaux │   ← Catégories      │
│  └─────────┴─────────┴─────────┴─────────┘                      │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 🥖 Pain tradition                         25 DZD   │        │
│  │    ┌────────────────────────────────┐              │        │
│  │    │  [−]      20      [+]          │              │        │
│  │    └────────────────────────────────┘              │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 🥐 Croissant beurre                       40 DZD   │        │
│  │    ┌────────────────────────────────┐              │        │
│  │    │  [−]      10      [+]          │              │        │
│  │    └────────────────────────────────┘              │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 🍞 Baguette                               20 DZD   │        │
│  │    ┌────────────────────────────────┐              │        │
│  │    │  [−]       0      [+]          │              │        │
│  │    └────────────────────────────────┘              │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ═══════════════════════════════════════════════════════        │
│  │ 🛒 Panier: 30 articles           Total: 900 DZD   │         │
│  │                                                    │         │
│  │  [ 📅 Livraison demain 06:00 ▼ ]                  │         │
│  │                                                    │         │
│  │  [        ✓ CONFIRMER COMMANDE        ]           │         │
│  ═══════════════════════════════════════════════════════        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  📋 HISTORIQUE & COMPTABILITÉ                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  💳 SITUATION FINANCIÈRE                            │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  Dette actuelle:              12,500 DZD           │        │
│  │  Limite crédit:               50,000 DZD           │        │
│  │  Disponible:                  37,500 DZD           │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  Ce mois:                                           │        │
│  │    Commandé:    45,000 DZD                         │        │
│  │    Payé:        32,500 DZD                         │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  📅 Janvier 2026                              [< Mois >]        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 📦 25 Jan - Commande #1234                          │        │
│  │    15 articles • 2,500 DZD                          │        │
│  │    ✅ Livré • 💵 Payé comptant                      │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 📦 24 Jan - Commande #1233                          │        │
│  │    22 articles • 3,200 DZD                          │        │
│  │    ✅ Livré • ⏳ 1,200 DZD en dette                 │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 💰 23 Jan - Paiement reçu                           │        │
│  │    Encaissé par Ahmed • 5,000 DZD                   │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  [ 📄 Télécharger relevé du mois ]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Fonctionnalités Clés Client

| Fonctionnalité | Description | Priorité |
|----------------|-------------|----------|
| **Commande rapide** | Rééditer la dernière commande en 1 tap | 🔴 P0 |
| **Catalogue simple** | Liste produits avec quantités, pas de fioritures | 🔴 P0 |
| **Vue dette** | Toujours visible, savoir où on en est | 🔴 P0 |
| **Historique** | Commandes + paiements, filtrable par mois | 🔴 P0 |
| **Notifications** | Commande confirmée, livreur en route | 🟡 P1 |
| **Relevé PDF** | Export mensuel pour comptabilité | 🟡 P1 |

---

## 3.3 🚚 APPLICATION LIVREUR

### Philosophie
> **"Tournée efficace, encaissement fiable"**
> Le livreur doit pouvoir travailler même sans connexion, et tout doit être tracé.

### Écrans Principaux

```
┌─────────────────────────────────────────────────────────────────┐
│                   APP LIVREUR - NAVIGATION                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐      │
│  │   🗺️   │    │   📋    │    │   💰    │    │   👤    │      │
│  │ Tournée │    │Livraisons│    │ Caisse  │    │ Profil  │      │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  🗺️ MA TOURNÉE DU JOUR                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📅 Lundi 26 Janvier 2026                           │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  🚚 12 livraisons • 💵 45,000 DZD à collecter       │        │
│  │  ✅ 3 complétées • ⏳ 9 restantes                   │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  [ 🗺️ Voir sur la carte ]  [ 🔄 Optimiser itinéraire ]         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 1. ☕ Cafétéria El Baraka              ⏳ En attente │        │
│  │    📍 Rue Didouche Mourad, Alger                    │        │
│  │    📦 Commande #1234 • 2,500 DZD                    │        │
│  │    💳 Dette client: 12,500 DZD                      │        │
│  │    ─────────────────────────────────────────────    │        │
│  │    [ 🧭 Naviguer ]  [ 📞 Appeler ]  [ ▶ Livrer ]   │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 2. 🍕 Restaurant Pizzaïolo             ✅ Livré     │        │
│  │    📍 Boulevard Mohamed V                           │        │
│  │    📦 #1235 • 4,200 DZD → 💵 Payé cash             │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 3. 🏪 Épicerie Chez Mahmoud            ⏳ En attente │        │
│  │    📍 Cité 500 logements, Bab Ezzouar              │        │
│  │    📦 #1236 • 1,800 DZD                            │        │
│  │    ⚠️ Limite crédit proche!                        │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  📦 LIVRAISON EN COURS                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  ☕ Cafétéria El Baraka                              │        │
│  │  📍 Rue Didouche Mourad, Alger                      │        │
│  │  📞 0551 23 45 67                                   │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📦 COMMANDE #1234                                  │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  🥖 Pain tradition          ×20       500 DZD      │        │
│  │  🥐 Croissant               ×10       400 DZD      │        │
│  │  🍞 Baguette                ×15       300 DZD      │        │
│  │  🎂 Gâteau chocolat         ×5      1,300 DZD      │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  TOTAL COMMANDE:                    2,500 DZD      │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  💳 Dette existante:               12,500 DZD      │        │
│  │  ═════════════════════════════════════════════════  │        │
│  │  TOTAL À COLLECTER:                15,000 DZD      │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  💰 ENCAISSEMENT                                    │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │                                                     │        │
│  │  Montant reçu:  [        5,000        ] DZD        │        │
│  │                                                     │        │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌───────┐                │        │
│  │  │ +500│ │+1000│ │+5000│ │ TOUT  │                │        │
│  │  └─────┘ └─────┘ └─────┘ └───────┘                │        │
│  │                                                     │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  Commande:        2,500 DZD                        │        │
│  │  Sur dette:       2,500 DZD                        │        │
│  │  Reste dette:    10,000 DZD                        │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │                                                     │        │
│  │  [ ] Imprimer bon de livraison                     │        │
│  │  [ ] Imprimer reçu de paiement                     │        │
│  │                                                     │        │
│  │  [      ✓ CONFIRMER LIVRAISON      ]               │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  [ ❌ Livraison impossible ]                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  💰 ENCAISSEMENT DETTE (Visite sans commande)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Client: Cafétéria El Baraka                                    │
│  Dette actuelle: 10,000 DZD                                     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  Montant encaissé:                                  │        │
│  │  ┌──────────────────────────────────────────┐       │        │
│  │  │              10,000                      │       │        │
│  │  └──────────────────────────────────────────┘       │        │
│  │                                                     │        │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐              │        │
│  │  │ 1000 │ │ 2000 │ │ 5000 │ │ TOUT │              │        │
│  │  └──────┘ └──────┘ └──────┘ └──────┘              │        │
│  │                                                     │        │
│  │  Note: ________________________________             │        │
│  │                                                     │        │
│  │  [ ] Imprimer reçu                                 │        │
│  │                                                     │        │
│  │  [       ✓ ENREGISTRER PAIEMENT       ]            │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  💼 MA CAISSE DU JOUR                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📅 Lundi 26 Janvier 2026                           │        │
│  │  ═════════════════════════════════════════════════  │        │
│  │                                                     │        │
│  │  💵 CASH COLLECTÉ                      32,500 DZD  │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │    Sur livraisons:        18,000 DZD               │        │
│  │    Sur dettes anciennes:  14,500 DZD               │        │
│  │                                                     │        │
│  │  📦 LIVRAISONS                                      │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │    Complétées:            8/12                      │        │
│  │    Valeur livrée:         28,500 DZD               │        │
│  │    Nouvelles dettes:      10,500 DZD               │        │
│  │                                                     │        │
│  │  ═════════════════════════════════════════════════  │        │
│  │  💰 À REMETTRE CE SOIR:            32,500 DZD      │        │
│  │  ═════════════════════════════════════════════════  │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📋 DÉTAIL DES TRANSACTIONS                         │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ 08:15  Cafétéria El Baraka      💵 +5,000 DZD      │        │
│  │ 08:45  Restaurant Pizzaïolo     💵 +4,200 DZD      │        │
│  │ 09:20  Épicerie Mahmoud         💵 +3,800 DZD      │        │
│  │ 09:50  Snack El Amir            💳 Dette 2,500     │        │
│  │ ...                                                 │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  [ 📄 Générer rapport de journée ]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Fonctionnalités Clés Livreur

| Fonctionnalité | Description | Priorité |
|----------------|-------------|----------|
| **Tournée du jour** | Liste des livraisons avec itinéraire | 🔴 P0 |
| **Livraison + encaissement** | Workflow complet de livraison | 🔴 P0 |
| **Encaissement dette** | Collecter anciennes dettes | 🔴 P0 |
| **Caisse journalière** | Suivi de l'argent collecté | 🔴 P0 |
| **Mode hors-ligne** | Travail sans réseau, sync auto | 🔴 P0 |
| **Navigation GPS** | Ouvrir Maps/Waze externe | 🟡 P1 |
| **Impression Bluetooth** | Bon de livraison, reçu | 🟡 P1 |
| **Appel client** | Un tap pour appeler | 🟡 P1 |
| **Rapport de journée** | Récap pour l'admin | 🟡 P1 |

### Mode Hors-Ligne

```
┌─────────────────────────────────────────────────────────────────┐
│  📵 FONCTIONNEMENT HORS-LIGNE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AU DÉMARRAGE (avec connexion):                                 │
│  ─────────────────────────────────────────────────────          │
│  • Télécharge la tournée du jour                                │
│  • Télécharge les infos clients (nom, tel, dette)               │
│  • Télécharge les produits (pour vérification)                  │
│                                                                 │
│  PENDANT LA JOURNÉE (même sans connexion):                      │
│  ─────────────────────────────────────────────────────          │
│  • Peut consulter sa tournée                                    │
│  • Peut effectuer des livraisons                                │
│  • Peut encaisser des paiements                                 │
│  • Tout est stocké localement (SQLite)                          │
│                                                                 │
│  À LA RECONNEXION:                                              │
│  ─────────────────────────────────────────────────────          │
│  • Synchronisation automatique                                  │
│  • Upload des transactions                                      │
│  • Gestion des conflits (serveur prioritaire)                   │
│                                                                 │
│  INDICATEUR VISUEL:                                             │
│  ─────────────────────────────────────────────────────          │
│  🟢 En ligne   │  🟡 Sync en cours   │  🔴 Hors-ligne           │
│                                                                 │
│  Transactions en attente: 5 📤                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3.4 💼 APPLICATION ADMIN

### Philosophie
> **"Contrôle total, visibilité complète"**
> L'admin est le propriétaire, il doit tout voir, tout gérer, tout exporter.

### Navigation Principale

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP ADMIN - MENU PRINCIPAL                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  🏭 Boulangerie El Nour                              │        │
│  │  admin@boulangerie-elnour.dz                        │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │   📊    │  │   📦    │  │   👥    │  │   🚚    │            │
│  │Dashboard│  │Commandes│  │ Clients │  │Livreurs │            │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘            │
│                                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │   📦    │  │   💰    │  │   📈    │  │   ⚙️    │            │
│  │Produits │  │ Finance │  │Rapports │  │Réglages │            │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Écrans Détaillés

```
┌─────────────────────────────────────────────────────────────────┐
│  📊 DASHBOARD (Vue temps réel)                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📅 Aujourd'hui, Lundi 26 Janvier 2026                          │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ 📦 Commandes │ │ 💵 Collecté  │ │ 💳 Dettes    │            │
│  │     24       │ │  125,000 DZD │ │  458,000 DZD │            │
│  │   +3 vs hier │ │ +15% vs hier │ │   15 clients │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  🚚 LIVRAISONS EN COURS                              │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │                                                     │        │
│  │  Ahmed     ████████░░░░░░░  8/12   💵 32,500 DZD   │        │
│  │  Karim     ██████░░░░░░░░░  5/10   💵 18,200 DZD   │        │
│  │  Youcef    ████████████░░░ 10/12   💵 45,000 DZD   │        │
│  │                                                     │        │
│  │  Total: 23/34 livraisons • 95,700 DZD collecté     │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌────────────────────────┐ ┌────────────────────────┐         │
│  │ ⚠️ ALERTES             │ │ 📈 TENDANCE SEMAINE    │         │
│  │ ───────────────────    │ │ ───────────────────    │         │
│  │ • Café Riad: limite    │ │     ▄                  │         │
│  │   crédit atteinte      │ │   ▄ █ ▄               │         │
│  │ • Ahmed: retard 2h     │ │ ▄ █ █ █ ▄ ▄           │         │
│  │ • Stock pain bas       │ │ L M M J V S D         │         │
│  └────────────────────────┘ └────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  👥 GESTION CLIENTS                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔍 Rechercher...          [+ Nouveau client]                   │
│                                                                 │
│  Filtres: [Tous ▼] [Avec dette ▼] [Zone: Toutes ▼]             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  Nom           │ Zone      │ Dette    │ Actions    │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │ ☕ Cafétéria    │ Centre    │ 12,500   │ [👁] [✏] │        │
│  │    El Baraka   │           │ DZD      │           │        │
│  │ 🍕 Restaurant  │ Est       │ 0        │ [👁] [✏] │        │
│  │    Pizzaïolo   │           │          │           │        │
│  │ 🏪 Épicerie    │ Bab Ezz.  │ 45,000   │ [👁] [✏] │        │
│  │    Mahmoud     │           │ DZD ⚠️   │           │        │
│  │ ...           │           │          │           │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  Total: 45 clients • Dette globale: 458,000 DZD                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  👤 FICHE CLIENT - Cafétéria El Baraka                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 📍 Adresse: Rue Didouche Mourad, Alger Centre       │        │
│  │ 📞 Téléphone: 0551 23 45 67                         │        │
│  │ 👤 Contact: Mohamed                                  │        │
│  │ 📅 Client depuis: Mars 2024                         │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌───────────────────┐  ┌───────────────────┐                   │
│  │ 💳 Dette actuelle │  │ 💰 Limite crédit  │                   │
│  │    12,500 DZD     │  │    50,000 DZD     │ [Modifier]        │
│  └───────────────────┘  └───────────────────┘                   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 📊 STATISTIQUES                                     │        │
│  │ ──────────────────────────────────────────────────  │        │
│  │ CA total (2025):         1,250,000 DZD             │        │
│  │ Commandes:               156                        │        │
│  │ Panier moyen:            8,012 DZD                 │        │
│  │ Délai moyen paiement:    12 jours                  │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  📋 Historique  │  💰 Paiements  │  📦 Commandes                │
│  ────────────────────────────────────────────────────           │
│  │ 26/01 │ Commande #1234    │ 2,500 DZD │ ⏳ En cours │       │
│  │ 25/01 │ Paiement          │ 5,000 DZD │ ✅ Cash     │       │
│  │ 24/01 │ Commande #1230    │ 3,200 DZD │ ✅ Livré    │       │
│  │ ...   │                   │           │            │        │
│                                                                 │
│  [ 💰 Enregistrer paiement ]  [ 📄 Relevé de compte ]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  💰 FINANCE - Vue complète                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📅 Période: [Janvier 2026 ▼]    [📄 Exporter]                  │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ 💵 CA Mois   │ │ 💰 Encaissé  │ │ 💳 Créances  │            │
│  │ 2,450,000    │ │ 1,980,000    │ │   458,000    │            │
│  │    DZD       │ │    DZD       │ │    DZD       │            │
│  │  +8% vs M-1  │ │ 81% du CA    │ │  15 clients  │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📊 ANALYSE DES CRÉANCES (Aging Report)             │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │                                                     │        │
│  │  🟢 0-30 jours:    180,000 DZD   (39%)             │        │
│  │  🟡 31-60 jours:   120,000 DZD   (26%)             │        │
│  │  🟠 61-90 jours:    85,000 DZD   (19%)             │        │
│  │  🔴 > 90 jours:     73,000 DZD   (16%) ⚠️          │        │
│  │                                                     │        │
│  │  [ Voir détail par client ]                        │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  🚚 COLLECTE PAR LIVREUR                            │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  Ahmed     ████████████████   680,000 DZD  (34%)   │        │
│  │  Karim     ███████████        520,000 DZD  (26%)   │        │
│  │  Youcef    █████████████████  780,000 DZD  (40%)   │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📋 DERNIÈRES TRANSACTIONS                          │        │
│  │  ─────────────────────────────────────────────────  │        │
│  │  Aujourd'hui                                        │        │
│  │  14:32  Cafétéria El Baraka   💵 +5,000  Ahmed     │        │
│  │  14:15  Snack El Amir         💵 +3,200  Karim     │        │
│  │  13:50  Restaurant Riad       💳 -4,500  (dette)   │        │
│  │  ...                                                │        │
│  │                           [ Voir tout l'historique] │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  📈 RAPPORTS                                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  📊 RAPPORTS DISPONIBLES                            │        │
│  ├─────────────────────────────────────────────────────┤        │
│  │                                                     │        │
│  │  📅 Rapport journalier                              │        │
│  │     Résumé quotidien: livraisons, encaissements    │        │
│  │     [ Générer ] [ Automatiser chaque soir ]        │        │
│  │                                                     │        │
│  │  📆 Rapport hebdomadaire                            │        │
│  │     Tendances, comparaisons, alertes               │        │
│  │     [ Générer ] [ Envoyer chaque lundi ]           │        │
│  │                                                     │        │
│  │  📈 Rapport mensuel                                 │        │
│  │     Analyse complète, prévisions                   │        │
│  │     [ Générer ] [ Exporter PDF ]                   │        │
│  │                                                     │        │
│  │  💳 Relevé client                                   │        │
│  │     Historique commandes/paiements par client      │        │
│  │     [ Sélectionner client... ]                     │        │
│  │                                                     │        │
│  │  🚚 Performance livreurs                            │        │
│  │     KPIs par livreur: livraisons, collecte, temps  │        │
│  │     [ Générer ]                                    │        │
│  │                                                     │        │
│  │  📦 Analyse produits                                │        │
│  │     Ventes par produit, tendances                  │        │
│  │     [ Générer ]                                    │        │
│  │                                                     │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚙️ PARAMÈTRES ORGANISATION                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 Général                                                     │
│  ────────────────────────────────────────────────────           │
│  Nom: [Boulangerie El Nour                    ]                 │
│  Adresse: [123 Rue Hassiba Ben Bouali, Alger  ]                 │
│  Téléphone: [021 XX XX XX                     ]                 │
│  Email: [contact@boulangerie-elnour.dz        ]                 │
│                                                                 │
│  💰 Finance                                                     │
│  ────────────────────────────────────────────────────           │
│  Limite crédit par défaut: [50,000     ] DZD                    │
│  Délai paiement par défaut: [30        ] jours                  │
│  Alerte dette ancienne après: [60      ] jours                  │
│                                                                 │
│  🖨️ Impression                                                  │
│  ────────────────────────────────────────────────────           │
│  [x] Activer impression Bluetooth                               │
│  Type imprimante: [58mm ▼]                                      │
│  [ ] Impression auto bon de livraison                           │
│  [x] Impression auto reçu paiement                              │
│                                                                 │
│  📱 Fonctionnalités optionnelles                                │
│  ────────────────────────────────────────────────────           │
│  [ ] Signature électronique obligatoire                         │
│  [ ] Photo preuve de livraison                                  │
│  [x] QR Code sur les bons                                       │
│  [x] Notifications push aux clients                             │
│                                                                 │
│  🔔 Notifications Admin                                         │
│  ────────────────────────────────────────────────────           │
│  [x] Alerte limite crédit atteinte                              │
│  [x] Alerte dette > 60 jours                                    │
│  [x] Résumé journalier à 20h00                                  │
│  [ ] Alerte chaque paiement > 50,000 DZD                        │
│                                                                 │
│  [           💾 Enregistrer           ]                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Fonctionnalités Clés Admin

| Module | Fonctionnalités | Priorité |
|--------|-----------------|----------|
| **Dashboard** | KPIs temps réel, alertes, progression livreurs | 🔴 P0 |
| **Clients** | CRUD, limite crédit, historique complet, relevés | 🔴 P0 |
| **Livreurs** | CRUD, suivi temps réel, performance, caisse | 🔴 P0 |
| **Produits** | CRUD, catégories, tarifs par client | 🔴 P0 |
| **Commandes** | Liste, filtres, statuts, modification | 🔴 P0 |
| **Finance** | Vue globale, aging report, encaissements, dettes | 🔴 P0 |
| **Rapports** | Journalier, hebdo, mensuel, export PDF/Excel | 🟡 P1 |
| **Paramètres** | Config organisation, impression, notifications | 🟡 P1 |

---

# 4. Modèle de Données

## 4.1 Schéma Entité-Relation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MODÈLE DE DONNÉES AWID                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐                                                           │
│  │ ORGANIZATION │──────────────────────────────────────────────┐            │
│  └──────┬───────┘                                              │            │
│         │ 1:N                                                  │            │
│         │                                                      │            │
│  ┌──────┼────────────────────────────────────────┐             │            │
│  │      │                                        │             │            │
│  │      ▼                    ▼                   ▼             ▼            │
│  │ ┌────────┐          ┌──────────┐        ┌─────────┐   ┌──────────┐      │
│  │ │  USER  │          │ CUSTOMER │        │ PRODUCT │   │ SETTINGS │      │
│  │ │(Admin/ │          │          │        │         │   │          │      │
│  │ │Livreur)│          │          │        │         │   │          │      │
│  │ └────┬───┘          └────┬─────┘        └────┬────┘   └──────────┘      │
│  │      │                   │                   │                           │
│  │      │              ┌────┴─────┐             │                           │
│  │      │              │          │             │                           │
│  │      │              ▼          ▼             │                           │
│  │      │        ┌─────────┐ ┌─────────┐        │                           │
│  │      │        │  ORDER  │ │ PAYMENT │        │                           │
│  │      │        └────┬────┘ │ HISTORY │        │                           │
│  │      │             │      └─────────┘        │                           │
│  │      │             │                         │                           │
│  │      │             ▼                         │                           │
│  │      │      ┌────────────┐                   │                           │
│  │      │      │ ORDER_ITEM │◄──────────────────┘                           │
│  │      │      └────────────┘                                               │
│  │      │                                                                   │
│  │      │             ┌────────────┐                                        │
│  │      └────────────►│  DELIVERY  │                                        │
│  │                    └─────┬──────┘                                        │
│  │                          │                                               │
│  │                          ▼                                               │
│  │                   ┌──────────────┐                                       │
│  │                   │   DELIVERY   │                                       │
│  │                   │ TRANSACTION  │                                       │
│  │                   └──────────────┘                                       │
│  │                                                                          │
│  └──────────────────────────────────────────────────────────────────────────┘
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4.2 Tables Détaillées

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- ORGANISATION (Multi-tenant root)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,           -- URL-friendly identifier
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(100),
    logo_url VARCHAR(255),
    
    -- Paramètres par défaut
    default_credit_limit DECIMAL(12,2) DEFAULT 50000,
    default_payment_delay_days INTEGER DEFAULT 30,
    currency VARCHAR(3) DEFAULT 'DZD',
    
    -- Fonctionnalités activées
    features JSONB DEFAULT '{
        "signature_required": false,
        "photo_required": false,
        "qr_code_enabled": true,
        "bluetooth_printing": true,
        "push_notifications": true
    }',
    
    -- Paramètres impression
    print_settings JSONB DEFAULT '{
        "printer_type": "58mm",
        "auto_print_delivery": false,
        "auto_print_receipt": true,
        "header_text": "",
        "footer_text": "Merci pour votre confiance!"
    }',
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILISATEURS (Admin, Livreurs)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'deliverer', 'kitchen')),
    
    -- Pour les livreurs
    vehicle_type VARCHAR(20),                   -- 'car', 'motorcycle', 'bicycle', 'foot'
    license_plate VARCHAR(20),
    
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    last_position JSONB,                        -- {lat, lng, updated_at}
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_org ON users(organization_id);
CREATE INDEX idx_users_role ON users(organization_id, role);

-- ═══════════════════════════════════════════════════════════════════════════
-- CLIENTS (Points de vente)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    
    -- Adresse
    address TEXT NOT NULL,
    city VARCHAR(50),
    zone VARCHAR(50),                           -- Zone de livraison
    coordinates JSONB,                          -- {lat, lng}
    
    -- Finance
    credit_limit DECIMAL(12,2) DEFAULT 50000,
    credit_limit_enabled BOOLEAN DEFAULT true,
    current_debt DECIMAL(12,2) DEFAULT 0,       -- Calculé, mis à jour par trigger
    payment_delay_days INTEGER DEFAULT 30,
    
    -- Tarification personnalisée
    custom_prices JSONB DEFAULT '{}',           -- {product_id: price}
    discount_percent DECIMAL(5,2) DEFAULT 0,
    
    -- Stats
    total_orders INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0,
    last_order_at TIMESTAMP,
    last_payment_at TIMESTAMP,
    
    -- App mobile
    app_user_id UUID,                           -- Si connecté à l'app
    push_token VARCHAR(255),
    
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_customers_org ON customers(organization_id);
CREATE INDEX idx_customers_zone ON customers(organization_id, zone);
CREATE INDEX idx_customers_debt ON customers(organization_id, current_debt) WHERE current_debt > 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- PRODUITS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    
    price DECIMAL(10,2) NOT NULL,
    unit VARCHAR(20) DEFAULT 'piece',           -- 'piece', 'kg', 'pack'
    
    sku VARCHAR(50),
    barcode VARCHAR(50),
    image_url VARCHAR(255),
    
    -- Stock (optionnel)
    track_stock BOOLEAN DEFAULT false,
    current_stock DECIMAL(10,2),
    min_stock_alert DECIMAL(10,2),
    
    sort_order INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_products_org ON products(organization_id);
CREATE INDEX idx_products_category ON products(organization_id, category);

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    order_number VARCHAR(20) NOT NULL,          -- Numéro lisible: ORG-YYYYMMDD-XXX
    
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- En attente de confirmation
        'confirmed',    -- Confirmée
        'preparing',    -- En préparation
        'ready',        -- Prête
        'assigned',     -- Assignée à un livreur
        'in_delivery',  -- En cours de livraison
        'delivered',    -- Livrée
        'cancelled'     -- Annulée
    )),
    
    -- Montants
    subtotal DECIMAL(12,2) NOT NULL,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL,
    
    -- Paiement
    payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN (
        'unpaid',       -- Non payé
        'partial',      -- Partiellement payé
        'paid'          -- Entièrement payé
    )),
    amount_paid DECIMAL(12,2) DEFAULT 0,
    amount_due DECIMAL(12,2) GENERATED ALWAYS AS (total - amount_paid) STORED,
    
    -- Livraison
    delivery_date DATE,
    delivery_time_slot VARCHAR(20),             -- 'morning', 'afternoon', 'evening'
    delivery_address TEXT,
    delivery_notes TEXT,
    
    -- Récurrence
    is_recurring BOOLEAN DEFAULT false,
    recurring_config JSONB,                     -- {frequency, days_of_week, end_date}
    parent_order_id UUID REFERENCES orders(id), -- Si généré par récurrence
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    confirmed_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT
);

CREATE INDEX idx_orders_org ON orders(organization_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(organization_id, status);
CREATE INDEX idx_orders_date ON orders(organization_id, delivery_date);
CREATE INDEX idx_orders_payment ON orders(organization_id, payment_status) WHERE payment_status != 'paid';

-- Génération automatique du numéro de commande
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
    org_prefix VARCHAR(3);
    date_part VARCHAR(8);
    seq_num INTEGER;
BEGIN
    -- Obtenir le préfixe de l'organisation (3 premières lettres)
    SELECT UPPER(SUBSTRING(slug, 1, 3)) INTO org_prefix 
    FROM organizations WHERE id = NEW.organization_id;
    
    -- Date du jour
    date_part := TO_CHAR(NOW(), 'YYYYMMDD');
    
    -- Numéro séquentiel du jour
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(order_number FROM '[0-9]+$') AS INTEGER)
    ), 0) + 1 INTO seq_num
    FROM orders
    WHERE organization_id = NEW.organization_id
    AND DATE(created_at) = CURRENT_DATE;
    
    NEW.order_number := org_prefix || '-' || date_part || '-' || LPAD(seq_num::TEXT, 3, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_number
    BEFORE INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_order_number();

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS DE COMMANDE
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    product_name VARCHAR(100) NOT NULL,         -- Snapshot au moment de la commande
    quantity DECIMAL(10,2) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- LIVRAISONS (Tournées)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    order_id UUID NOT NULL REFERENCES orders(id),
    deliverer_id UUID NOT NULL REFERENCES users(id),
    
    status VARCHAR(20) DEFAULT 'assigned' CHECK (status IN (
        'assigned',     -- Assignée
        'picked_up',    -- Récupérée du dépôt
        'in_transit',   -- En route
        'arrived',      -- Arrivé chez le client
        'delivered',    -- Livrée avec succès
        'failed',       -- Échec de livraison
        'returned'      -- Retournée
    )),
    
    -- Ordre dans la tournée
    sequence_number INTEGER,
    priority INTEGER DEFAULT 50,                -- 1-100, plus haut = plus prioritaire
    
    -- Temps
    scheduled_date DATE NOT NULL,
    scheduled_time TIME,
    picked_up_at TIMESTAMP,
    arrived_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Encaissement à la livraison
    amount_to_collect DECIMAL(12,2),            -- Total commande + dette existante
    amount_collected DECIMAL(12,2) DEFAULT 0,
    collection_mode VARCHAR(20),                -- 'cash', 'none'
    
    -- Preuve de livraison (optionnel)
    signature_data TEXT,                        -- Base64 SVG
    signature_name VARCHAR(100),
    photos JSONB DEFAULT '[]',                  -- [{url, type, taken_at}]
    delivery_location JSONB,                    -- {lat, lng}
    
    -- Échec
    failure_reason TEXT,
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_deliveries_org ON deliveries(organization_id);
CREATE INDEX idx_deliveries_deliverer ON deliveries(deliverer_id, scheduled_date);
CREATE INDEX idx_deliveries_date ON deliveries(organization_id, scheduled_date);
CREATE INDEX idx_deliveries_status ON deliveries(organization_id, status);

-- ═══════════════════════════════════════════════════════════════════════════
-- HISTORIQUE PAIEMENTS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE payment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    amount DECIMAL(12,2) NOT NULL,
    mode VARCHAR(20) NOT NULL CHECK (mode IN ('cash', 'bank', 'check', 'mobile')),
    
    -- Contexte du paiement
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN (
        'order_payment',    -- Paiement d'une commande
        'debt_payment',     -- Encaissement de dette
        'advance_payment',  -- Paiement d'avance
        'refund'            -- Remboursement
    )),
    
    -- Références
    delivery_id UUID REFERENCES deliveries(id),
    order_id UUID REFERENCES orders(id),
    
    -- Qui a collecté
    collected_by UUID REFERENCES users(id),
    collected_at TIMESTAMP DEFAULT NOW(),
    
    -- Pour réconciliation
    receipt_number VARCHAR(50),
    
    -- Balance après ce paiement
    customer_balance_after DECIMAL(12,2),
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_payments_org ON payment_history(organization_id);
CREATE INDEX idx_payments_customer ON payment_history(customer_id);
CREATE INDEX idx_payments_date ON payment_history(organization_id, created_at);
CREATE INDEX idx_payments_collector ON payment_history(collected_by, created_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- TRANSACTIONS LIVRAISON (détail de ce qui s'est passé)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE delivery_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id),
    
    type VARCHAR(30) NOT NULL CHECK (type IN (
        'order_delivery',       -- Livraison de commande
        'order_partial_pay',    -- Paiement partiel commande
        'order_full_pay',       -- Paiement total commande
        'debt_collection',      -- Encaissement dette ancienne
        'delivery_failed',      -- Échec livraison
        'return'                -- Retour marchandise
    )),
    
    amount DECIMAL(12,2),
    
    -- Détails
    order_amount DECIMAL(12,2),                 -- Montant de la commande
    debt_amount_before DECIMAL(12,2),           -- Dette avant transaction
    amount_paid DECIMAL(12,2),                  -- Ce qui a été payé
    new_debt_created DECIMAL(12,2),             -- Nouvelle dette créée
    debt_amount_after DECIMAL(12,2),            -- Dette après transaction
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_delivery_tx_delivery ON delivery_transactions(delivery_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- CAISSE JOURNALIÈRE LIVREUR
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE daily_cash (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    deliverer_id UUID NOT NULL REFERENCES users(id),
    
    date DATE NOT NULL,
    
    -- Montants
    total_to_collect DECIMAL(12,2) DEFAULT 0,   -- Total attendu
    total_collected DECIMAL(12,2) DEFAULT 0,    -- Total encaissé
    total_new_debt DECIMAL(12,2) DEFAULT 0,     -- Nouvelles dettes
    
    -- Stats
    deliveries_count INTEGER DEFAULT 0,
    deliveries_completed INTEGER DEFAULT 0,
    deliveries_failed INTEGER DEFAULT 0,
    
    -- Clôture
    is_closed BOOLEAN DEFAULT false,
    closed_at TIMESTAMP,
    closed_by UUID REFERENCES users(id),
    cash_handed_over DECIMAL(12,2),             -- Argent remis à l'admin
    discrepancy DECIMAL(12,2),                  -- Écart éventuel
    discrepancy_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(deliverer_id, date)
);

CREATE INDEX idx_daily_cash_deliverer ON daily_cash(deliverer_id, date);

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    user_id UUID REFERENCES users(id),          -- Pour admin/livreur
    customer_id UUID REFERENCES customers(id),  -- Pour client
    
    type VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    
    channel VARCHAR(20) DEFAULT 'push',         -- 'push', 'sms', 'email', 'in_app'
    
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP,
    
    sent_at TIMESTAMP,
    is_sent BOOLEAN DEFAULT false,
    send_error TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_customer ON notifications(customer_id, is_read);

-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGERS POUR MISE À JOUR AUTOMATIQUE DES DETTES
-- ═══════════════════════════════════════════════════════════════════════════

-- Trigger pour mettre à jour current_debt du client
CREATE OR REPLACE FUNCTION update_customer_debt()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculer la dette totale du client
    UPDATE customers
    SET current_debt = (
        SELECT COALESCE(SUM(amount_due), 0)
        FROM orders
        WHERE customer_id = COALESCE(NEW.customer_id, OLD.customer_id)
        AND payment_status != 'paid'
    ),
    updated_at = NOW()
    WHERE id = COALESCE(NEW.customer_id, OLD.customer_id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_debt_on_order
    AFTER INSERT OR UPDATE OF amount_paid, payment_status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_debt();

-- Trigger pour mettre à jour les stats client
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE customers
        SET 
            total_orders = total_orders + 1,
            total_revenue = total_revenue + NEW.total,
            last_order_at = NOW(),
            updated_at = NOW()
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customer_stats
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_stats();
```

---

# 5. Flux Métier Détaillés

## 5.1 Flux de Commande

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUX DE COMMANDE                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CLIENT                          ADMIN                         LIVREUR      │
│  ──────                          ─────                         ───────      │
│                                                                             │
│  ┌─────────────┐                                                            │
│  │ 1. Passe    │                                                            │
│  │   commande  │─────────────────────┐                                      │
│  └─────────────┘                     │                                      │
│                                      ▼                                      │
│                              ┌──────────────┐                               │
│                              │ 2. Commande  │                               │
│                              │   reçue      │                               │
│                              │   (pending)  │                               │
│                              └──────┬───────┘                               │
│                                     │                                       │
│                                     ▼                                       │
│                              ┌──────────────┐                               │
│                              │ 3. Confirme  │                               │
│                              │   (confirmed)│                               │
│  ┌─────────────┐             └──────┬───────┘                               │
│  │ Notif:      │◄────────────────────                                       │
│  │ "Commande   │                     │                                      │
│  │ confirmée"  │                     ▼                                      │
│  └─────────────┘             ┌──────────────┐                               │
│                              │ 4. Prépare   │                               │
│                              │  (preparing) │                               │
│                              └──────┬───────┘                               │
│                                     │                                       │
│                                     ▼                                       │
│                              ┌──────────────┐                               │
│                              │ 5. Prête     │                               │
│                              │   (ready)    │                               │
│                              └──────┬───────┘                               │
│                                     │                                       │
│                                     ▼                                       │
│                              ┌──────────────┐      ┌─────────────┐          │
│                              │ 6. Assigne   │─────►│ 7. Reçoit   │          │
│                              │   livreur    │      │   tournée   │          │
│                              │  (assigned)  │      │             │          │
│                              └──────────────┘      └──────┬──────┘          │
│                                                          │                  │
│                                                          ▼                  │
│  ┌─────────────┐                               ┌──────────────┐             │
│  │ Notif:      │◄──────────────────────────────│ 8. En route  │             │
│  │ "Livreur en │                               │ (in_delivery)│             │
│  │ route"      │                               └──────┬───────┘             │
│  └─────────────┘                                      │                     │
│                                                       ▼                     │
│                                               ┌──────────────┐              │
│  ┌─────────────┐                              │ 9. Arrive    │              │
│  │ 10. Reçoit  │◄─────────────────────────────│    chez      │              │
│  │ marchandise │                              │   client     │              │
│  └──────┬──────┘                              └──────┬───────┘              │
│         │                                            │                      │
│         ▼                                            ▼                      │
│  ┌─────────────┐                              ┌──────────────┐              │
│  │ 11. Paye    │─────────────────────────────►│ 12. Encaisse │              │
│  │ (tout/      │                              │  + confirme  │              │
│  │ partiel/    │                              │  livraison   │              │
│  │ crédit)     │                              └──────┬───────┘              │
│  └─────────────┘                                     │                      │
│                                                      ▼                      │
│                              ┌──────────────┐       │                       │
│                              │ 13. Mise à   │◄──────┘                       │
│                              │ jour finance │                               │
│                              │ (delivered)  │                               │
│                              └──────────────┘                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 5.2 Flux de Paiement

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FLUX DE PAIEMENT À LA LIVRAISON                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Situation au moment de la livraison:                                       │
│  ───────────────────────────────────────────                                │
│  • Commande du jour: 2,500 DZD                                              │
│  • Dette existante: 12,500 DZD                                              │
│  • Total potentiel à collecter: 15,000 DZD                                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    SCÉNARIOS DE PAIEMENT                            │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │                                                                     │    │
│  │  SCÉNARIO A: Paiement total                                         │    │
│  │  ─────────────────────────────────────                              │    │
│  │  Client paie: 15,000 DZD                                            │    │
│  │  → Commande: PAYÉE                                                  │    │
│  │  → Dette ancienne: SOLDÉE                                           │    │
│  │  → Nouvelle dette: 0 DZD                                            │    │
│  │                                                                     │    │
│  │  SCÉNARIO B: Paiement commande uniquement                           │    │
│  │  ─────────────────────────────────────────                          │    │
│  │  Client paie: 2,500 DZD                                             │    │
│  │  → Commande: PAYÉE                                                  │    │
│  │  → Dette ancienne: INCHANGÉE (12,500 DZD)                           │    │
│  │  → Nouvelle dette: 0 DZD                                            │    │
│  │                                                                     │    │
│  │  SCÉNARIO C: Paiement partiel                                       │    │
│  │  ─────────────────────────────────────                              │    │
│  │  Client paie: 5,000 DZD                                             │    │
│  │  Application automatique (FIFO):                                    │    │
│  │  1. 2,500 DZD → Commande du jour (PAYÉE)                            │    │
│  │  2. 2,500 DZD → Réduction dette ancienne                            │    │
│  │  → Dette restante: 10,000 DZD                                       │    │
│  │                                                                     │    │
│  │  SCÉNARIO D: Tout à crédit                                          │    │
│  │  ─────────────────────────────────                                  │    │
│  │  Client paie: 0 DZD                                                 │    │
│  │  → Commande: NON PAYÉE                                              │    │
│  │  → Nouvelle dette: +2,500 DZD                                       │    │
│  │  → Dette totale: 15,000 DZD                                         │    │
│  │  ⚠️ Vérifier limite crédit!                                         │    │
│  │                                                                     │    │
│  │  SCÉNARIO E: Encaissement dette sans commande                       │    │
│  │  ────────────────────────────────────────                           │    │
│  │  Visite du livreur, pas de commande                                 │    │
│  │  Client paie: 5,000 DZD sur sa dette                                │    │
│  │  → Dette réduite à: 7,500 DZD                                       │    │
│  │                                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 5.3 Flux de Réconciliation Journalière

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLÔTURE DE JOURNÉE LIVREUR                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FIN DE JOURNÉE (vers 18h-20h)                                              │
│  ─────────────────────────────────                                          │
│                                                                             │
│  LIVREUR                                 ADMIN                              │
│  ───────                                 ─────                              │
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │ 1. Consulte     │                                                        │
│  │    "Ma caisse"  │                                                        │
│  │                 │                                                        │
│  │ Cash collecté:  │                                                        │
│  │   32,500 DZD    │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐                                                        │
│  │ 2. Compte son   │                                                        │
│  │    argent       │                                                        │
│  │                 │                                                        │
│  │ En main:        │                                                        │
│  │   32,500 DZD ✓  │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐        ┌─────────────────┐                             │
│  │ 3. Remet        │───────►│ 4. Vérifie      │                             │
│  │    l'argent     │        │    et valide    │                             │
│  │    à l'admin    │        │                 │                             │
│  └─────────────────┘        │ ✓ Montant OK    │                             │
│                             │ ✓ Réconcilié    │                             │
│                             └────────┬────────┘                             │
│                                      │                                      │
│                                      ▼                                      │
│                             ┌─────────────────┐                             │
│                             │ 5. Clôture      │                             │
│                             │    journée      │                             │
│                             │                 │                             │
│                             │ Rapport généré  │                             │
│                             └─────────────────┘                             │
│                                                                             │
│  EN CAS D'ÉCART                                                             │
│  ──────────────                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Déclaré par app:  32,500 DZD                                       │    │
│  │  Remis en main:    32,000 DZD                                       │    │
│  │  Écart:               -500 DZD                                      │    │
│  │                                                                     │    │
│  │  → L'admin note l'écart                                             │    │
│  │  → Justification demandée                                           │    │
│  │  → Historique conservé                                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# 6. Stack Technique Open Source

## 6.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          STACK TECHNIQUE AWID                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  📱 MOBILE (Flutter)                                                        │
│  ────────────────────────────────────────────                               │
│  • Framework: Flutter 3.x                                                   │
│  • State: Riverpod                                                          │
│  • Offline: Drift (SQLite) + Hive                                           │
│  • HTTP: Dio                                                                │
│  • Navigation: GoRouter                                                     │
│  • Notifications: Firebase Messaging (gratuit)                              │
│  • Impression: esc_pos_bluetooth (thermique)                                │
│  • Maps: flutter_map (OpenStreetMap) - GRATUIT                              │
│                                                                             │
│  🔌 BACKEND (Node.js)                                                       │
│  ────────────────────────────────────────────                               │
│  • Runtime: Node.js 20 LTS                                                  │
│  • Framework: Express.js ou Fastify                                         │
│  • Validation: Zod                                                          │
│  • ORM: Drizzle ORM (TypeScript natif)                                      │
│  • Auth: JWT (jose)                                                         │
│  • WebSocket: Socket.io (temps réel)                                        │
│  • Jobs: BullMQ + Redis                                                     │
│  • Logs: Pino                                                               │
│                                                                             │
│  🗄️ DATABASE                                                                │
│  ────────────────────────────────────────────                               │
│  • Principal: PostgreSQL 16                                                 │
│  • Cache: Redis                                                             │
│  • Full-text: PostgreSQL FTS (intégré)                                      │
│                                                                             │
│  📦 INFRASTRUCTURE                                                          │
│  ────────────────────────────────────────────                               │
│  • Conteneurs: Docker + Docker Compose                                      │
│  • Reverse Proxy: Nginx ou Caddy                                            │
│  • SSL: Let's Encrypt (gratuit)                                             │
│  • CI/CD: GitHub Actions                                                    │
│                                                                             │
│  📨 NOTIFICATIONS (Options gratuites/économiques)                           │
│  ────────────────────────────────────────────                               │
│  • Push: Firebase Cloud Messaging (gratuit)                                 │
│  • SMS: Twilio ou local provider (payant)                                   │
│  • Email: Resend ou SMTP                                                    │
│                                                                             │
│  🗺️ NAVIGATION (100% Gratuit)                                              │
│  ────────────────────────────────────────────                               │
│  • Cartes: OpenStreetMap (Leaflet)                                          │
│  • Routing: OSRM (self-hosted) ou GraphHopper                               │
│  • Geocoding: Nominatim (self-hosted)                                       │
│  • Alternative: Ouvrir Google Maps/Waze externe                             │
│                                                                             │
│  🖨️ IMPRESSION                                                              │
│  ────────────────────────────────────────────                               │
│  • Bluetooth: ESC/POS protocol                                              │
│  • PDF: PDFKit (Node.js)                                                    │
│  • Partage: WhatsApp deeplink                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 6.2 Comparaison des Options

### Navigation GPS

| Option | Coût | Intégration | Hors-ligne | Recommandation |
|--------|------|-------------|------------|----------------|
| **Ouvrir Google Maps** | Gratuit | 1 ligne | Oui (si installé) | ✅ **Recommandé** |
| **Ouvrir Waze** | Gratuit | 1 ligne | Non | ✅ Option |
| **OpenStreetMap** | Gratuit | Moyenne | Possible | 🟡 V2 |
| **Google Maps API** | Payant | Haute | Non | ❌ Coûteux |

### Impression

| Option | Matériel | Coût | Recommandation |
|--------|----------|------|----------------|
| **Imprimante Bluetooth 58mm** | ~3000-5000 DZD | Faible | ✅ **Recommandé** |
| **Imprimante Bluetooth 80mm** | ~8000-12000 DZD | Moyen | 🟡 Pro |
| **PDF via WhatsApp** | Aucun | Gratuit | ✅ Alternative |
| **SMS récap** | Téléphone | ~5 DZD/SMS | 🟡 Option |

### Notifications Push

| Service | Coût | Limite | Recommandation |
|---------|------|--------|----------------|
| **Firebase Cloud Messaging** | Gratuit | Illimité | ✅ **Recommandé** |
| **OneSignal** | Gratuit | 10k users | 🟡 Alternative |
| **Pusher** | Payant | - | ❌ Pas nécessaire |

---

# 7. API Endpoints

## 7.1 Structure des URLs

```
Base URL: https://api.awid.dz/v1

Authentication:
  POST   /auth/login
  POST   /auth/register
  POST   /auth/refresh
  POST   /auth/logout
  PUT    /auth/password

Organizations:
  GET    /organization                    # Info de mon organisation
  PUT    /organization                    # Modifier mon organisation
  PUT    /organization/settings           # Modifier les paramètres

Users (Admin only):
  GET    /users                           # Liste des utilisateurs
  POST   /users                           # Créer un utilisateur
  GET    /users/:id                       # Détail utilisateur
  PUT    /users/:id                       # Modifier utilisateur
  DELETE /users/:id                       # Désactiver utilisateur
  GET    /users/:id/performance           # Stats livreur

Customers:
  GET    /customers                       # Liste clients
  POST   /customers                       # Créer client
  GET    /customers/:id                   # Détail client
  PUT    /customers/:id                   # Modifier client
  DELETE /customers/:id                   # Désactiver client
  GET    /customers/:id/orders            # Commandes du client
  GET    /customers/:id/payments          # Paiements du client
  GET    /customers/:id/statement         # Relevé de compte
  PUT    /customers/:id/credit-limit      # Modifier limite crédit

Products:
  GET    /products                        # Liste produits
  POST   /products                        # Créer produit
  GET    /products/:id                    # Détail produit
  PUT    /products/:id                    # Modifier produit
  DELETE /products/:id                    # Désactiver produit
  PUT    /products/reorder                # Réorganiser l'ordre

Orders:
  GET    /orders                          # Liste commandes
  POST   /orders                          # Créer commande
  GET    /orders/:id                      # Détail commande
  PUT    /orders/:id                      # Modifier commande
  PUT    /orders/:id/status               # Changer statut
  PUT    /orders/:id/cancel               # Annuler commande
  POST   /orders/:id/duplicate            # Dupliquer commande

Deliveries:
  GET    /deliveries                      # Liste livraisons
  GET    /deliveries/my-route             # Ma tournée (livreur)
  POST   /deliveries/assign               # Assigner livraison
  PUT    /deliveries/:id/status           # Changer statut
  PUT    /deliveries/:id/complete         # Compléter livraison
  PUT    /deliveries/:id/fail             # Échec livraison
  POST   /deliveries/:id/collect          # Encaisser paiement
  PUT    /deliveries/optimize             # Optimiser tournée

Payments:
  GET    /payments                        # Historique paiements
  POST   /payments                        # Enregistrer paiement
  GET    /payments/:id                    # Détail paiement

Finance:
  GET    /finance/overview                # Vue globale
  GET    /finance/debts                   # Liste des dettes
  GET    /finance/aging-report            # Aging report
  GET    /finance/cash-flow               # Prévisions
  GET    /finance/daily-summary           # Résumé journalier
  GET    /finance/reconciliation          # Réconciliation

Reports:
  GET    /reports/daily                   # Rapport journalier
  GET    /reports/weekly                  # Rapport hebdomadaire
  GET    /reports/monthly                 # Rapport mensuel
  GET    /reports/deliverer/:id           # Rapport livreur
  GET    /reports/customer/:id            # Rapport client
  GET    /reports/export                  # Export CSV/PDF

Daily Cash (Livreur):
  GET    /daily-cash                      # Ma caisse du jour
  GET    /daily-cash/history              # Historique
  POST   /daily-cash/close                # Clôturer journée

Sync (Mobile offline):
  GET    /sync/initial                    # Données initiales
  POST   /sync/push                       # Envoyer transactions offline
  GET    /sync/pull                       # Récupérer mises à jour

Notifications:
  GET    /notifications                   # Mes notifications
  PUT    /notifications/:id/read          # Marquer comme lue
  PUT    /notifications/read-all          # Tout marquer comme lu
  POST   /notifications/register-token    # Enregistrer push token

Print:
  GET    /print/delivery/:id              # Bon de livraison
  GET    /print/receipt/:paymentId        # Reçu de paiement
  GET    /print/statement/:customerId     # Relevé client
```

## 7.2 Exemples de Requêtes/Réponses

### Créer une commande (Client App)
```http
POST /v1/orders
Authorization: Bearer {token}
Content-Type: application/json

{
  "items": [
    { "productId": "uuid-product-1", "quantity": 20 },
    { "productId": "uuid-product-2", "quantity": 10 }
  ],
  "deliveryDate": "2026-01-27",
  "notes": "Livrer avant 7h SVP"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid-order",
    "orderNumber": "BNR-20260126-001",
    "status": "pending",
    "items": [
      {
        "productId": "uuid-product-1",
        "productName": "Pain tradition",
        "quantity": 20,
        "unitPrice": 25,
        "totalPrice": 500
      },
      {
        "productId": "uuid-product-2",
        "productName": "Croissant",
        "quantity": 10,
        "unitPrice": 40,
        "totalPrice": 400
      }
    ],
    "subtotal": 900,
    "discount": 0,
    "total": 900,
    "paymentStatus": "unpaid",
    "deliveryDate": "2026-01-27",
    "createdAt": "2026-01-26T10:30:00Z"
  }
}
```

### Compléter une livraison (Livreur App)
```http
PUT /v1/deliveries/{deliveryId}/complete
Authorization: Bearer {token}
Content-Type: application/json

{
  "amountCollected": 5000,
  "collectionMode": "cash",
  "notes": "Client a payé sur la dette aussi",
  "signature": {
    "data": "base64-svg-signature",
    "name": "Mohamed"
  },
  "location": {
    "lat": 36.7538,
    "lng": 3.0588
  }
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "delivery": {
      "id": "uuid-delivery",
      "status": "delivered",
      "amountCollected": 5000,
      "completedAt": "2026-01-26T11:45:00Z"
    },
    "transaction": {
      "orderAmount": 2500,
      "debtBefore": 12500,
      "amountPaid": 5000,
      "appliedToOrder": 2500,
      "appliedToDebt": 2500,
      "debtAfter": 10000,
      "newDebtCreated": 0
    },
    "customer": {
      "id": "uuid-customer",
      "name": "Cafétéria El Baraka",
      "currentDebt": 10000
    },
    "printData": {
      "receiptUrl": "/print/receipt/uuid-payment",
      "deliveryUrl": "/print/delivery/uuid-delivery"
    }
  }
}
```

---

# 8. Sécurité & Isolation

## 8.1 Multi-Tenant Security

```typescript
// Middleware d'isolation organisation
const organizationIsolation = async (req, res, next) => {
  const user = req.user;
  
  // L'utilisateur ne peut accéder qu'aux données de son organisation
  req.organizationId = user.organizationId;
  
  // Injecter dans toutes les requêtes DB
  await db.query(`SET app.current_org_id = $1`, [user.organizationId]);
  
  next();
};

// Appliquer sur toutes les routes authentifiées
app.use('/v1/*', authenticate, organizationIsolation);
```

## 8.2 Row Level Security (PostgreSQL)

```sql
-- Activer RLS sur toutes les tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
-- etc.

-- Politique: voir uniquement les données de son organisation
CREATE POLICY org_isolation ON customers
  FOR ALL
  USING (organization_id = current_setting('app.current_org_id')::uuid);

-- Même chose pour toutes les tables...
```

## 8.3 Validation des Permissions

```typescript
// Middleware de vérification des rôles
const authorize = (...allowedRoles: string[]) => {
  return (req, res, next) => {
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: 'Accès non autorisé'
      });
    }
    next();
  };
};

// Utilisation
router.delete('/users/:id', authorize('admin'), userController.delete);
router.get('/deliveries/my-route', authorize('deliverer'), deliveryController.myRoute);
```

---

Ce document constitue la base complète de l'architecture AWID v3.0, adaptée au marché algérien B2B avec gestion des dettes et paiements en espèces.
