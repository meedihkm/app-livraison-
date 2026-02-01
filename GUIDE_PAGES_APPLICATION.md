# Guide Complet des Pages de l'Application AWID Mobile v4

## Vue d'Ensemble

L'application AWID Mobile v4 est une application multi-rôles pour la gestion de livraison de repas. Elle comprend **27 pages** réparties entre **4 rôles principaux** + authentification.

---

## 📱 AUTHENTIFICATION (2 pages)

### 1. Page de Connexion
**Fichier**: `features/auth/presentation/pages/login_page.dart`  
**Route**: `/login`  
**Accès**: Public

**Fonctionnalités**:
- Formulaire de connexion (email + mot de passe)
- Validation des champs
- Gestion des erreurs d'authentification
- Redirection automatique selon le rôle après connexion
- Lien vers la page d'inscription

**Widgets**:
- Champs de saisie email/password
- Bouton de connexion
- Indicateur de chargement
- Messages d'erreur

---

### 2. Page d'Inscription
**Fichier**: `features/auth/presentation/pages/register_page.dart`  
**Route**: `/register`  
**Accès**: Public

**Fonctionnalités**:
- Formulaire d'inscription complet
- Validation des données
- Création de compte
- Redirection vers login après inscription réussie

**Widgets**:
- Formulaire multi-champs
- Validation en temps réel
- Bouton d'inscription
- Lien retour vers login

---

## 👨‍💼 ADMIN / GESTIONNAIRE (4 pages)

### 1. Dashboard Admin
**Fichier**: `features/admin/presentation/pages/admin_dashboard_page.dart`  
**Route**: `/admin/dashboard`  
**Accès**: Admin uniquement

**Fonctionnalités**:
- Vue d'ensemble des statistiques globales
- Résumé des commandes du jour
- Indicateurs de performance (KPI)
- Accès rapide aux sections principales
- Graphiques et métriques

**Sections**:
- Statistiques des commandes (total, en cours, terminées)
- Revenus du jour/semaine/mois
- Nombre de clients actifs
- Performance des livreurs
- Alertes et notifications importantes

---

### 2. Gestion des Utilisateurs
**Fichier**: `features/admin/presentation/pages/users_page.dart`  
**Route**: `/admin/users`  
**Accès**: Admin uniquement

**Fonctionnalités**:
- Liste complète des utilisateurs
- Filtrage par rôle (Admin, Atelier, Livreur, Client)
- Recherche d'utilisateurs
- Création de nouveaux utilisateurs
- Modification des informations utilisateur
- Désactivation/Activation de comptes
- Gestion des permissions

**Actions CRUD**:
- Créer un utilisateur
- Voir les détails
- Modifier les informations
- Supprimer/Désactiver

---

### 3. Gestion des Produits
**Fichier**: `features/admin/presentation/pages/products_page.dart`  
**Route**: `/admin/products`  
**Accès**: Admin uniquement

**Fonctionnalités**:
- Liste des produits/plats
- Catégorisation des produits
- Gestion des prix
- Gestion des stocks
- Ajout de nouveaux produits
- Modification des produits existants
- Activation/Désactivation de produits
- Upload d'images de produits

**Informations produit**:
- Nom, description
- Prix unitaire
- Catégorie
- Stock disponible
- Image
- Statut (actif/inactif)

---

### 4. Détail de Commande (Admin)
**Fichier**: `features/admin/presentation/pages/order_detail_page.dart`  
**Route**: `/admin/orders/:orderId`  
**Accès**: Admin uniquement

**Fonctionnalités**:
- Vue détaillée d'une commande
- Informations client
- Liste des produits commandés
- Statut de la commande
- Historique des modifications
- Actions administratives (annuler, modifier)
- Suivi de livraison
- Gestion des paiements

---

## 👨‍🍳 ATELIER / CUISINE (5 pages)

### 1. Dashboard Cuisine
**Fichier**: `features/kitchen/presentation/pages/kitchen_dashboard_page.dart`  
**Route**: `/kitchen/dashboard`  
**Accès**: Atelier uniquement

**Fonctionnalités**:
- Vue d'ensemble des commandes du jour
- Statistiques de production
- Commandes en attente
- Commandes en cours de préparation
- Alertes de stock faible
- Accès rapide au Kanban

**Métriques**:
- Nombre de commandes à préparer
- Temps moyen de préparation
- Taux de complétion
- Produits les plus commandés

---

### 2. Tableau Kanban
**Fichier**: `features/kitchen/presentation/pages/kanban_board_page.dart`  
**Route**: `/kitchen/kanban`  
**Accès**: Atelier uniquement

**Fonctionnalités**:
- Gestion visuelle des commandes par colonnes
- Drag & drop des commandes entre statuts
- Filtrage par priorité/heure
- Mise à jour en temps réel
- Notifications de nouvelles commandes

**Colonnes Kanban**:
1. **À Préparer** - Nouvelles commandes
2. **En Préparation** - Commandes en cours
3. **Prêtes** - Commandes terminées
4. **En Livraison** - Commandes parties

**Actions**:
- Déplacer une commande
- Voir les détails
- Marquer comme prête
- Ajouter des notes

---

### 3. Détail de Commande (Cuisine)
**Fichier**: `features/kitchen/presentation/pages/order_detail_page.dart`  
**Route**: `/kitchen/orders/:orderId`  
**Accès**: Atelier uniquement

**Fonctionnalités**:
- Détails complets de la commande
- Liste des produits à préparer
- Quantités et spécifications
- Instructions spéciales
- Temps de préparation estimé
- Changement de statut
- Ajout de notes de préparation

---

### 4. Gestion du Stock
**Fichier**: `features/kitchen/presentation/pages/stock_management_page.dart`  
**Route**: `/kitchen/stock`  
**Accès**: Atelier uniquement

**Fonctionnalités**:
- Liste des produits en stock
- Niveaux de stock actuels
- Alertes de stock faible
- Ajout/Retrait de stock
- Historique des mouvements
- Inventaire
- Gestion des péremptions

**Actions**:
- Entrée de stock
- Sortie de stock
- Ajustement d'inventaire
- Voir l'historique

---

### 5. Statistiques de Production
**Fichier**: `features/kitchen/presentation/pages/production_stats_page.dart`  
**Route**: `/kitchen/stats`  
**Accès**: Atelier uniquement

**Fonctionnalités**:
- Graphiques de production
- Statistiques par période
- Produits les plus préparés
- Temps moyens de préparation
- Taux de complétion
- Performance de l'équipe
- Export de rapports

**Métriques**:
- Commandes par jour/semaine/mois
- Temps moyen de préparation
- Taux de réussite
- Produits populaires

---

## 🚚 LIVREUR (10 pages)

### 1. Dashboard Livreur
**Fichier**: `features/deliverer/presentation/pages/deliverer_dashboard_page.dart`  
**Route**: `/deliverer/dashboard`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Vue d'ensemble des livraisons du jour
- Statistiques personnelles
- Livraisons actives
- Prochaines livraisons
- Gains du jour
- Tracking GPS actif/inactif
- Notifications

**Sections**:
- Livraisons en cours
- Livraisons à venir
- Statistiques du jour (nombre, gains, distance)
- Bouton démarrer/arrêter tracking
- Accès rapide aux fonctionnalités

---

### 2. Liste des Livraisons
**Fichier**: `features/deliverer/presentation/pages/deliveries_list_page.dart`  
**Route**: `/deliverer/deliveries`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Liste complète des livraisons
- Filtrage par statut (assignées, en cours, terminées)
- Recherche par client/adresse
- Tri par date/priorité
- Vue carte ou liste
- Détails rapides

**Filtres**:
- Toutes
- Assignées
- En cours
- Terminées
- Annulées

---

### 3. Détail de Livraison
**Fichier**: `features/deliverer/presentation/pages/delivery_detail_page.dart`  
**Route**: `/deliverer/deliveries/:deliveryId`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Informations complètes de la livraison
- Détails client (nom, téléphone, adresse)
- Liste des commandes
- Montant total à encaisser
- Instructions spéciales
- Actions de livraison
- Bouton navigation GPS

**Actions**:
- Appeler le client
- Démarrer navigation
- Marquer comme arrivé
- Compléter la livraison
- Signaler un problème

---

### 4. Carte de Navigation GPS
**Fichier**: `features/deliverer/presentation/pages/route_map_page.dart`  
**Route**: `/deliverer/route/:deliveryId`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Carte interactive avec itinéraire
- Position en temps réel du livreur
- Destination du client
- Itinéraire optimisé
- Distance et temps restant
- Trafic en temps réel
- Instructions de navigation

**Éléments carte**:
- Marqueur position livreur
- Marqueur destination
- Tracé de l'itinéraire
- Informations de navigation

---

### 5. Preuve de Livraison
**Fichier**: `features/deliverer/presentation/pages/proof_of_delivery_page.dart`  
**Route**: `/deliverer/proof/:deliveryId`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Capture de signature client
- Prise de photo de livraison
- Sélection du lieu de dépôt
- Notes de livraison
- Validation de la livraison
- Horodatage automatique
- Géolocalisation

**Éléments**:
- Canvas de signature
- Appareil photo
- Champ notes
- Bouton valider
- Confirmation

---

### 6. Encaissement de Paiement
**Fichier**: `features/deliverer/presentation/pages/payment_collection_page.dart`  
**Route**: `/deliverer/payment/:customerId`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Montant à encaisser
- Sélection du mode de paiement
- Saisie du montant reçu
- Calcul de la monnaie à rendre
- Validation du paiement
- Historique des paiements client
- Génération de reçu

**Modes de paiement**:
- Espèces
- Carte bancaire
- Chèque
- Crédit client

---

### 7. Gestion des Consignes
**Fichier**: `features/deliverer/presentation/pages/packaging_management_page.dart`  
**Route**: `/deliverer/packaging/:customerId`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Liste des consignes du client
- Consignes à récupérer
- Consignes à livrer
- Scan de code-barres
- Ajout/Retrait de consignes
- Historique des mouvements
- Solde de consignes

**Actions**:
- Livrer des consignes
- Récupérer des consignes
- Scanner un code
- Voir l'historique

---

### 8. Historique des Livraisons
**Fichier**: `features/deliverer/presentation/pages/delivery_history_page.dart`  
**Route**: `/deliverer/history`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Historique complet des livraisons
- Filtrage par période
- Recherche
- Détails de chaque livraison
- Statistiques cumulées
- Export de données

**Filtres**:
- Aujourd'hui
- Cette semaine
- Ce mois
- Période personnalisée

---

### 9. Gains du Livreur
**Fichier**: `features/deliverer/presentation/pages/earnings_page.dart`  
**Route**: `/deliverer/earnings`  
**Accès**: Livreur uniquement

**Fonctionnalités**:
- Gains totaux
- Gains par période
- Détail des commissions
- Graphiques d'évolution
- Nombre de livraisons
- Moyenne par livraison
- Primes et bonus

**Métriques**:
- Gains du jour
- Gains de la semaine
- Gains du mois
- Nombre de livraisons
- Taux de commission

---

### 10. Widget Tracker de Localisation
**Fichier**: `features/deliverer/presentation/widgets/location_tracker.dart`  
**Accès**: Intégré dans le dashboard

**Fonctionnalités**:
- Activation/Désactivation du GPS
- Indicateur de tracking actif
- Partage de position en temps réel
- Économie de batterie
- Précision GPS

---

## 👥 CLIENT (8 pages)

### 1. Dashboard Client
**Fichier**: `features/customer/presentation/pages/customer_dashboard_page.dart`  
**Route**: `/customer/dashboard`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Vue d'ensemble du compte
- Résumé du crédit
- Commandes actives
- Livraisons en cours
- Accès rapide aux fonctionnalités
- Notifications
- Solde de consignes

**Sections**:
- Carte de crédit
- Commandes récentes
- Livraisons actives
- Boutons d'action rapide

---

### 2. Gestion du Crédit
**Fichier**: `features/customer/presentation/pages/customer_credit_page.dart`  
**Route**: `/customer/credit`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Solde de crédit actuel
- Limite de crédit
- Historique des transactions
- Paiements effectués
- Factures en attente
- Demande d'augmentation de crédit
- Graphique d'évolution

**Informations**:
- Crédit disponible
- Crédit utilisé
- Limite autorisée
- Historique des mouvements
- Échéances de paiement

---

### 3. Liste des Commandes
**Fichier**: `features/customer/presentation/pages/customer_orders_page.dart`  
**Route**: `/customer/orders`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Liste de toutes les commandes
- Filtrage par statut
- Recherche
- Tri par date
- Détails rapides
- Récommander

**Statuts**:
- En attente
- En préparation
- Prête
- En livraison
- Livrée
- Annulée

---

### 4. Détail de Commande (Client)
**Fichier**: `features/customer/presentation/pages/customer_order_detail_page.dart`  
**Route**: `/customer/orders/:orderId`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Détails complets de la commande
- Liste des produits
- Montant total
- Statut actuel
- Date de livraison prévue
- Suivi de préparation
- Bouton de suivi livraison (si en cours)

**Informations**:
- Numéro de commande
- Date et heure
- Produits commandés
- Prix unitaires et total
- Statut de préparation
- Livreur assigné (si applicable)

---

### 5. Suivi de Livraison en Temps Réel
**Fichier**: `features/customer/presentation/pages/customer_delivery_tracking_page.dart`  
**Route**: `/customer/tracking/:deliveryId`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Carte avec position du livreur en temps réel
- Itinéraire du livreur
- Temps d'arrivée estimé
- Distance restante
- Informations du livreur (nom, photo, téléphone)
- Bouton appeler le livreur
- Notifications de progression

**Éléments**:
- Carte interactive
- Marqueur livreur (mise à jour temps réel)
- Marqueur destination
- Informations de livraison
- Bouton contact

---

### 6. Historique Client
**Fichier**: `features/customer/presentation/pages/customer_history_page.dart`  
**Route**: `/customer/history`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Historique complet des commandes
- Filtrage par période
- Recherche
- Statistiques de consommation
- Produits favoris
- Montant total dépensé
- Export de données

**Filtres**:
- Derniers 7 jours
- Dernier mois
- Derniers 3 mois
- Année en cours
- Période personnalisée

---

### 7. Gestion des Consignes (Client)
**Fichier**: `features/customer/presentation/pages/customer_packaging_page.dart`  
**Route**: `/customer/packaging`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Solde de consignes actuel
- Consignes en possession
- Consignes à retourner
- Historique des mouvements
- Valeur des consignes
- Alertes de retour

**Informations**:
- Nombre de consignes détenues
- Type de consignes
- Date de réception
- Valeur de caution
- Historique

---

### 8. Compte Client
**Fichier**: `features/customer/presentation/pages/customer_account_page.dart`  
**Route**: `/customer/account`  
**Accès**: Client uniquement

**Fonctionnalités**:
- Informations personnelles
- Adresses de livraison
- Modification du profil
- Changement de mot de passe
- Préférences de notification
- Paramètres de compte
- Déconnexion

**Sections**:
- Profil (nom, email, téléphone)
- Adresses
- Sécurité
- Notifications
- Préférences

---

## 🔄 Navigation et Flux

### Flux d'Authentification
```
Login → Vérification rôle → Redirection vers dashboard approprié
```

### Flux Admin
```
Dashboard → Gestion Utilisateurs/Produits/Commandes
```

### Flux Atelier
```
Dashboard → Kanban → Détail Commande → Changement Statut
Dashboard → Stock → Gestion Stock
Dashboard → Stats → Analyse Production
```

### Flux Livreur
```
Dashboard → Liste Livraisons → Détail Livraison → Navigation GPS
→ Arrivée → Preuve de Livraison → Encaissement → Gestion Consignes
Dashboard → Historique/Gains
```

### Flux Client
```
Dashboard → Commandes → Détail Commande → Suivi Livraison
Dashboard → Crédit → Historique Transactions
Dashboard → Consignes → Gestion Consignes
Dashboard → Compte → Modification Profil
```

---

## 📊 Résumé par Rôle

| Rôle | Nombre de Pages | Pages Principales |
|------|----------------|-------------------|
| **Authentification** | 2 | Login, Register |
| **Admin** | 4 | Dashboard, Users, Products, Order Detail |
| **Atelier** | 5 | Dashboard, Kanban, Order Detail, Stock, Stats |
| **Livreur** | 10 | Dashboard, Deliveries, Detail, Map, Proof, Payment, Packaging, History, Earnings |
| **Client** | 8 | Dashboard, Credit, Orders, Order Detail, Tracking, History, Packaging, Account |
| **TOTAL** | **29** | - |

---

## 🎨 Composants Partagés

### Widgets Communs
- `AppBar` personnalisé par rôle
- `BottomNavigationBar` adaptatif
- `LoadingIndicator`
- `ErrorWidget`
- `EmptyStateWidget`
- Cartes de statistiques
- Listes avec pull-to-refresh

### Providers Riverpod
- `authProvider` - État d'authentification
- `userProvider` - Données utilisateur
- Providers spécifiques par feature

---

## 🔐 Contrôle d'Accès

Chaque page vérifie le rôle de l'utilisateur via le `authProvider` :
- **Admin** : Accès complet à toutes les fonctionnalités admin
- **Atelier** : Accès aux fonctionnalités de cuisine uniquement
- **Livreur** : Accès aux fonctionnalités de livraison uniquement
- **Client** : Accès aux fonctionnalités client uniquement

La navigation est protégée par des guards qui redirigent vers la page de login si non authentifié.

---

## 📱 Responsive Design

Toutes les pages sont conçues pour s'adapter à différentes tailles d'écran :
- Smartphones (portrait/paysage)
- Tablettes
- Layout adaptatif selon l'orientation

---

## 🔔 Notifications

Intégration OneSignal pour :
- Nouvelles commandes (Atelier)
- Livraisons assignées (Livreur)
- Statut de livraison (Client)
- Alertes de stock (Atelier)
- Paiements reçus (Admin)

---

## 🗺️ Géolocalisation

Pages utilisant la géolocalisation :
- Route Map (Livreur) - Navigation GPS
- Delivery Tracking (Client) - Suivi en temps réel
- Proof of Delivery (Livreur) - Coordonnées de livraison

---

## 📸 Fonctionnalités Multimédia

- **Signature** : Preuve de livraison (Livreur)
- **Photo** : Preuve de livraison (Livreur)
- **Images produits** : Gestion produits (Admin)
- **Avatar** : Profil utilisateur (Tous)

---

## 💾 Stockage Local

- Authentification (tokens sécurisés)
- Cache des données fréquentes
- Mode hors ligne partiel
- Synchronisation automatique

---

Ce guide représente l'architecture complète de l'application mobile AWID v4 avec toutes ses pages et fonctionnalités par rôle.
