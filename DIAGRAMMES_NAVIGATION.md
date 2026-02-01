# Diagrammes de Navigation - AWID Mobile v4

## Vue d'Ensemble Globale

```mermaid
graph TB
    Start([Démarrage App]) --> Login[Page Login]
    Login --> CheckRole{Vérification Rôle}
    
    CheckRole -->|Admin| AdminDash[Dashboard Admin]
    CheckRole -->|Atelier| KitchenDash[Dashboard Cuisine]
    CheckRole -->|Livreur| DelivererDash[Dashboard Livreur]
    CheckRole -->|Client| CustomerDash[Dashboard Client]
    
    AdminDash --> AdminPages[Pages Admin]
    KitchenDash --> KitchenPages[Pages Cuisine]
    DelivererDash --> DelivererPages[Pages Livreur]
    CustomerDash --> CustomerPages[Pages Client]
    
    style Start fill:#e1f5ff
    style Login fill:#fff3e0
    style CheckRole fill:#f3e5f5
    style AdminDash fill:#ffebee
    style KitchenDash fill:#e8f5e9
    style DelivererDash fill:#fff9c4
    style CustomerDash fill:#e3f2fd
```

---

## 1. Navigation Authentification

```mermaid
graph LR
    Start([App Start]) --> Login[Page Login]
    Login -->|Nouveau compte| Register[Page Register]
    Register -->|Retour| Login
    Login -->|Connexion réussie| CheckRole{Rôle?}
    
    CheckRole -->|Admin| AdminDash[Dashboard Admin]
    CheckRole -->|Atelier| KitchenDash[Dashboard Cuisine]
    CheckRole -->|Livreur| DelivererDash[Dashboard Livreur]
    CheckRole -->|Client| CustomerDash[Dashboard Client]
    
    style Start fill:#e1f5ff
    style Login fill:#fff3e0
    style Register fill:#fff3e0
    style CheckRole fill:#f3e5f5
```

---

## 2. Navigation Admin

```mermaid
graph TB
    AdminDash[Dashboard Admin] --> Users[Gestion Utilisateurs]
    AdminDash --> Products[Gestion Produits]
    AdminDash --> Orders[Liste Commandes]
    
    Users -->|Créer| UserForm[Formulaire Utilisateur]
    Users -->|Modifier| UserForm
    Users -->|Voir détails| UserDetail[Détail Utilisateur]
    
    Products -->|Créer| ProductForm[Formulaire Produit]
    Products -->|Modifier| ProductForm
    Products -->|Voir détails| ProductDetail[Détail Produit]
    
    Orders -->|Voir détails| OrderDetail[Détail Commande]
    OrderDetail -->|Actions| OrderActions[Modifier/Annuler]
    
    AdminDash --> Settings[Paramètres]
    AdminDash --> Reports[Rapports]
    
    UserForm -->|Retour| Users
    ProductForm -->|Retour| Products
    OrderDetail -->|Retour| Orders
    
    style AdminDash fill:#ffebee
    style Users fill:#ffcdd2
    style Products fill:#ffcdd2
    style Orders fill:#ffcdd2
```

---

## 3. Navigation Atelier/Cuisine

```mermaid
graph TB
    KitchenDash[Dashboard Cuisine] --> Kanban[Tableau Kanban]
    KitchenDash --> Stock[Gestion Stock]
    KitchenDash --> Stats[Statistiques Production]
    KitchenDash --> OrdersList[Liste Commandes]
    
    Kanban -->|Drag & Drop| KanbanColumns[Colonnes: À Préparer/En Cours/Prêtes/Livrées]
    Kanban -->|Clic commande| OrderDetail[Détail Commande]
    
    OrderDetail -->|Changer statut| StatusUpdate[Mise à jour Statut]
    OrderDetail -->|Ajouter notes| AddNotes[Notes Préparation]
    OrderDetail -->|Retour| Kanban
    
    Stock -->|Entrée| StockIn[Ajout Stock]
    Stock -->|Sortie| StockOut[Retrait Stock]
    Stock -->|Inventaire| Inventory[Inventaire]
    Stock -->|Historique| StockHistory[Historique Mouvements]
    
    Stats -->|Filtrer période| StatsFilter[Filtres Période]
    Stats -->|Export| StatsExport[Export Rapports]
    
    OrdersList -->|Voir détails| OrderDetail
    
    style KitchenDash fill:#e8f5e9
    style Kanban fill:#c8e6c9
    style Stock fill:#c8e6c9
    style Stats fill:#c8e6c9
```

---

## 4. Navigation Livreur (Détaillée)

```mermaid
graph TB
    DelivererDash[Dashboard Livreur] --> DeliveriesList[Liste Livraisons]
    DelivererDash --> History[Historique]
    DelivererDash --> Earnings[Gains]
    DelivererDash --> GPSToggle[Activer/Désactiver GPS]
    
    DeliveriesList -->|Filtrer| FilterStatus[Filtrer par Statut]
    DeliveriesList -->|Clic livraison| DeliveryDetail[Détail Livraison]
    
    DeliveryDetail -->|Navigation| RouteMap[Carte GPS Navigation]
    DeliveryDetail -->|Appeler| CallCustomer[Appel Client]
    DeliveryDetail -->|Arrivé| ArrivalActions[Actions Arrivée]
    
    RouteMap -->|Temps réel| LiveTracking[Tracking Temps Réel]
    RouteMap -->|Retour| DeliveryDetail
    
    ArrivalActions -->|Preuve| ProofDelivery[Preuve de Livraison]
    
    ProofDelivery -->|Signature| Signature[Capture Signature]
    ProofDelivery -->|Photo| Photo[Prise Photo]
    ProofDelivery -->|Notes| Notes[Ajouter Notes]
    ProofDelivery -->|Valider| PaymentCollection[Encaissement]
    
    PaymentCollection -->|Mode paiement| PaymentMode[Espèces/Carte/Chèque/Crédit]
    PaymentCollection -->|Valider| PackagingMgmt[Gestion Consignes]
    
    PackagingMgmt -->|Livrer consignes| DeliverPackaging[Livrer]
    PackagingMgmt -->|Récupérer consignes| CollectPackaging[Récupérer]
    PackagingMgmt -->|Scanner| ScanBarcode[Scanner Code]
    PackagingMgmt -->|Terminer| Complete[Livraison Terminée]
    
    Complete -->|Retour| DelivererDash
    
    History -->|Filtrer période| HistoryFilter[Filtres Période]
    History -->|Voir détails| HistoryDetail[Détail Historique]
    
    Earnings -->|Voir détails| EarningsDetail[Détail Gains]
    Earnings -->|Graphiques| EarningsCharts[Graphiques Évolution]
    
    style DelivererDash fill:#fff9c4
    style DeliveriesList fill:#fff59d
    style DeliveryDetail fill:#fff59d
    style RouteMap fill:#aed581
    style ProofDelivery fill:#ffb74d
```

---

## 5. Navigation Client

```mermaid
graph TB
    CustomerDash[Dashboard Client] --> Orders[Mes Commandes]
    CustomerDash --> Credit[Mon Crédit]
    CustomerDash --> Packaging[Mes Consignes]
    CustomerDash --> Account[Mon Compte]
    CustomerDash --> ActiveDeliveries[Livraisons Actives]
    
    Orders -->|Filtrer| OrdersFilter[Filtrer par Statut]
    Orders -->|Voir détails| OrderDetail[Détail Commande]
    Orders -->|Rechercher| OrdersSearch[Recherche]
    
    OrderDetail -->|Commande en livraison| TrackDelivery[Suivi Livraison Temps Réel]
    OrderDetail -->|Récommander| Reorder[Nouvelle Commande]
    OrderDetail -->|Retour| Orders
    
    TrackDelivery -->|Carte GPS| LiveMap[Carte Position Livreur]
    TrackDelivery -->|Appeler livreur| CallDeliverer[Appel Livreur]
    TrackDelivery -->|Temps estimé| ETA[Temps d'Arrivée]
    
    ActiveDeliveries -->|Suivre| TrackDelivery
    
    Credit -->|Voir historique| CreditHistory[Historique Transactions]
    Credit -->|Voir factures| Invoices[Factures]
    Credit -->|Demander augmentation| CreditRequest[Demande Crédit]
    
    Packaging -->|Voir détails| PackagingDetail[Détail Consignes]
    Packaging -->|Historique| PackagingHistory[Historique Mouvements]
    
    Account -->|Modifier profil| EditProfile[Modifier Profil]
    Account -->|Adresses| Addresses[Gérer Adresses]
    Account -->|Sécurité| Security[Changer Mot de Passe]
    Account -->|Notifications| NotifSettings[Paramètres Notifications]
    Account -->|Déconnexion| Logout[Déconnexion]
    
    Logout --> Login[Page Login]
    
    style CustomerDash fill:#e3f2fd
    style Orders fill:#bbdefb
    style Credit fill:#bbdefb
    style TrackDelivery fill:#81c784
    style LiveMap fill:#66bb6a
```

---

## 6. Flux Complet de Livraison (Livreur)

```mermaid
sequenceDiagram
    participant D as Dashboard Livreur
    participant L as Liste Livraisons
    participant Det as Détail Livraison
    participant GPS as Navigation GPS
    participant P as Preuve Livraison
    participant Pay as Encaissement
    participant Pkg as Consignes
    
    D->>D: Activer GPS Tracking
    D->>L: Voir livraisons assignées
    L->>Det: Sélectionner livraison
    Det->>GPS: Démarrer navigation
    GPS->>GPS: Tracking temps réel
    GPS->>Det: Arrivé à destination
    Det->>P: Capturer preuve
    P->>P: Signature client
    P->>P: Photo livraison
    P->>Pay: Encaisser paiement
    Pay->>Pay: Sélectionner mode
    Pay->>Pkg: Gérer consignes
    Pkg->>Pkg: Livrer/Récupérer
    Pkg->>D: Livraison terminée
```

---

## 7. Flux Complet de Commande (Cuisine)

```mermaid
sequenceDiagram
    participant D as Dashboard Cuisine
    participant K as Kanban
    participant Det as Détail Commande
    participant S as Stock
    
    D->>K: Nouvelle commande arrive
    K->>K: Colonne "À Préparer"
    K->>Det: Voir détails commande
    Det->>S: Vérifier stock
    S->>Det: Stock OK
    Det->>K: Déplacer "En Préparation"
    K->>K: Préparer commande
    K->>Det: Marquer comme prête
    Det->>K: Déplacer "Prêtes"
    K->>K: Attente livreur
    K->>K: Déplacer "En Livraison"
```

---

## 8. Flux Suivi Client

```mermaid
sequenceDiagram
    participant D as Dashboard Client
    participant O as Mes Commandes
    participant Det as Détail Commande
    participant T as Suivi Temps Réel
    participant M as Carte GPS
    
    D->>O: Voir commandes
    O->>Det: Sélectionner commande
    Det->>Det: Statut: En livraison
    Det->>T: Suivre livraison
    T->>M: Afficher carte
    M->>M: Position livreur (temps réel)
    M->>M: Temps d'arrivée estimé
    M->>T: Livreur proche
    T->>T: Notification: Arrivée imminente
    T->>D: Livraison terminée
```

---

## 9. Architecture de Navigation Globale

```mermaid
graph TB
    subgraph "Authentification"
        Login[Login]
        Register[Register]
    end
    
    subgraph "Admin"
        AdminDash[Dashboard]
        Users[Utilisateurs]
        Products[Produits]
        AdminOrders[Commandes]
    end
    
    subgraph "Cuisine"
        KitchenDash[Dashboard]
        Kanban[Kanban]
        Stock[Stock]
        Stats[Statistiques]
        KitchenOrders[Commandes]
    end
    
    subgraph "Livreur"
        DelivererDash[Dashboard]
        Deliveries[Livraisons]
        DeliveryDetail[Détail]
        RouteMap[GPS]
        Proof[Preuve]
        Payment[Paiement]
        DelivererPackaging[Consignes]
        DelivererHistory[Historique]
        Earnings[Gains]
    end
    
    subgraph "Client"
        CustomerDash[Dashboard]
        CustomerOrders[Commandes]
        OrderDetail[Détail]
        Tracking[Suivi]
        Credit[Crédit]
        CustomerPackaging[Consignes]
        CustomerAccount[Compte]
        CustomerHistory[Historique]
    end
    
    Login --> AdminDash
    Login --> KitchenDash
    Login --> DelivererDash
    Login --> CustomerDash
    
    style Login fill:#fff3e0
    style AdminDash fill:#ffebee
    style KitchenDash fill:#e8f5e9
    style DelivererDash fill:#fff9c4
    style CustomerDash fill:#e3f2fd
```

---

## 10. Matrice de Navigation par Rôle

| Depuis / Vers | Dashboard | Liste | Détail | Actions | Retour |
|---------------|-----------|-------|--------|---------|--------|
| **Admin** | ✓ | Users, Products, Orders | User/Product/Order Detail | CRUD | Dashboard |
| **Cuisine** | ✓ | Kanban, Orders | Order Detail | Change Status, Stock | Dashboard/Kanban |
| **Livreur** | ✓ | Deliveries | Delivery Detail | GPS, Proof, Payment, Packaging | Dashboard |
| **Client** | ✓ | Orders | Order Detail | Track, Reorder | Dashboard |

---

## 11. Hiérarchie de Navigation

```
App Root
├── Auth
│   ├── Login
│   └── Register
│
├── Admin
│   ├── Dashboard
│   ├── Users
│   │   ├── List
│   │   ├── Create
│   │   ├── Edit
│   │   └── Detail
│   ├── Products
│   │   ├── List
│   │   ├── Create
│   │   ├── Edit
│   │   └── Detail
│   └── Orders
│       ├── List
│       └── Detail
│
├── Kitchen
│   ├── Dashboard
│   ├── Kanban
│   │   └── Order Detail
│   ├── Stock
│   │   ├── List
│   │   ├── Add/Remove
│   │   └── History
│   ├── Stats
│   └── Orders List
│
├── Deliverer
│   ├── Dashboard
│   ├── Deliveries
│   │   ├── List
│   │   └── Detail
│   │       ├── Route Map (GPS)
│   │       ├── Proof of Delivery
│   │       │   ├── Signature
│   │       │   └── Photo
│   │       ├── Payment Collection
│   │       └── Packaging Management
│   ├── History
│   └── Earnings
│
└── Customer
    ├── Dashboard
    ├── Orders
    │   ├── List
    │   └── Detail
    │       └── Tracking (Real-time)
    ├── Credit
    │   └── History
    ├── Packaging
    │   └── History
    └── Account
        ├── Profile
        ├── Addresses
        ├── Security
        └── Settings
```

---

## 12. Transitions et Animations

### Transitions Principales
- **Login → Dashboard** : Fade + Slide from bottom
- **Dashboard → Pages** : Slide from right
- **Liste → Détail** : Slide from right
- **Détail → Retour** : Slide to right
- **Modal/Dialog** : Fade + Scale
- **Bottom Sheet** : Slide from bottom

### Navigation Gestures
- **Swipe Right** : Retour page précédente
- **Pull Down** : Refresh liste
- **Long Press** : Actions rapides
- **Swipe Left/Right** : Navigation entre onglets

---

## Légende des Diagrammes

- 🟦 **Bleu** : Pages Client
- 🟨 **Jaune** : Pages Livreur  
- 🟩 **Vert** : Pages Cuisine
- 🟥 **Rouge** : Pages Admin
- 🟧 **Orange** : Authentification
- ⬜ **Blanc** : Actions/Décisions

---

Ces diagrammes représentent l'architecture complète de navigation de l'application AWID Mobile v4.
