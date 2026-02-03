# 🚚 AWID v3.0 - Système de Livraison B2B Algérien

<p align="center">
  <img src="docs/logo.png" alt="AWID Logo" width="200"/>
</p>

> **Application complète de gestion des livraisons B2B** conçue spécifiquement pour le marché algérien (boulangeries, pâtisseries livrant aux cafés, restaurants, épiceries).

---

## ✨ Fonctionnalités Principales

### 📱 Trois Applications Mobiles

| Application | Utilisateurs | Fonctions clés |
|-------------|--------------|----------------|
| **Client** | Points de vente | Commander, suivre livraisons, voir dette |
| **Livreur** | Employés livreurs | Tournée, encaissement, mode offline |
| **Admin** | Gestionnaires | Dashboard, clients, finance, rapports |

### 💰 Gestion Financière Adaptée

- ✅ **100% Cash** - Pas de paiement en ligne
- ✅ **Système de crédit** - Limites par client
- ✅ **Gestion des dettes** - Suivi FIFO
- ✅ **Encaissement flexible** - Paiement total, partiel ou crédit
- ✅ **Réconciliation** - Caisse journalière livreur

### 🌐 Mode Offline

- ✅ Synchronisation automatique
- ✅ Transactions stockées localement
- ✅ Fonctionne sans connexion

### 🖨️ Impression

- ✅ Support imprimantes thermiques Bluetooth (58mm/80mm)
- ✅ Alternative PDF via WhatsApp

---

## 🏗️ Architecture Technique

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND                              │
├─────────────────────┬─────────────────────┬─────────────────┤
│    Client App       │    Livreur App      │    Admin App    │
│    (Flutter)        │    (Flutter)        │ (React + Flutter)│
└─────────────────────┴─────────────────────┴─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     API BACKEND                              │
│           Node.js + Express + TypeScript                     │
│                  Validation: Zod                             │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│     PostgreSQL 16       │     │       Redis 7           │
│   (RLS Multi-tenant)    │     │   (Cache + Queue)       │
└─────────────────────────┘     └─────────────────────────┘
```

---

## 📂 Structure du Projet

```
awid-v3-complete/
├── 📄 ARCHITECTURE-COMPLETE.md    # Documentation architecture détaillée
├── 📄 IMPLEMENTATION-GUIDE.md     # Guide de développement
├── 📄 docker-compose.yml          # Configuration Docker
├── 📄 Caddyfile                   # Reverse proxy HTTPS
├── 📄 .env.example                # Variables d'environnement
│
├── 📁 backend/                    # API Node.js
│   ├── src/
│   │   ├── controllers/           # Logique des routes
│   │   ├── middlewares/           # Auth, validation
│   │   ├── routes/                # Définition API
│   │   └── validators/            # Schémas Zod
│   └── Dockerfile
│
├── 📁 database/
│   └── schema.sql                 # Schéma PostgreSQL complet
│
├── 📁 mobile/
│   ├── livreur/                   # App Flutter livreur
│   ├── client/                    # App Flutter client
│   └── admin/                     # App Flutter admin (mobile)
│
└── 📁 admin/                      # Dashboard React (web)
    └── src/
        └── pages/Dashboard.tsx
```

---

## 🚀 Démarrage Rapide

### Prérequis

- Docker & Docker Compose
- Node.js 20+ (pour développement local)
- Flutter 3.x (pour les apps mobiles)

### Installation

```bash
# Cloner le projet
git clone https://github.com/votre-repo/awid-v3.git
cd awid-v3

# Configurer l'environnement
cp .env.example .env
# Éditer .env avec vos valeurs

# Lancer avec Docker
docker-compose up -d

# L'API est accessible sur http://localhost:3000
# L'admin web sur http://localhost:8080
```

### Développement Local

```bash
# Backend
cd backend
npm install
npm run dev

# App Livreur
cd mobile/livreur
flutter pub get
flutter run

# Admin Web
cd admin
npm install
npm run dev
```

---

## 📊 Base de Données

### Tables Principales

| Table | Description |
|-------|-------------|
| `organizations` | Multi-tenant (isolation complète) |
| `users` | Admin, managers, livreurs, cuisine |
| `customers` | Points de vente avec crédit |
| `products` | Catalogue par catégorie |
| `orders` | Commandes avec workflow statuts |
| `deliveries` | Assignation et suivi livraisons |
| `payment_history` | Tous les paiements (FIFO) |
| `daily_cash` | Caisse journalière livreur |

### Sécurité

- **Row Level Security (RLS)** : Isolation totale entre organisations
- **Triggers automatiques** : Calcul dette, numérotation
- **Audit log** : Traçabilité complète

---

## 📱 Applications Mobiles

### App Livreur

```
┌──────────────────────────────┐
│  🚚 Ma Tournée              │
│  Lundi 26 Janvier 2026       │
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │ 📦 5/8 livraisons      │  │
│  │ [████████░░] 62%       │  │
│  │ Collecté: 45,500 DZD   │  │
│  └────────────────────────┘  │
├──────────────────────────────┤
│  1. Café El Baraka    ✅     │
│     2,500 DZD                │
│  2. Restaurant Saha   ⏳     │
│     15,000 DZD + Dette       │
│  3. Épicerie Amir     📍     │
│     8,200 DZD                │
└──────────────────────────────┘
```

### App Client

```
┌──────────────────────────────┐
│  Bonjour,                    │
│  Café El Baraka             │
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │ 💳 Ma dette: 12,500 DZD│  │
│  │ Limite: 50,000 DZD     │  │
│  │ [██░░░░░░] 25%         │  │
│  └────────────────────────┘  │
├──────────────────────────────┤
│  [🛒 Commander]  [🔄 Recom.] │
│  [📋 Historique] [📊 Relevé] │
└──────────────────────────────┘
```

---

## 🔒 Sécurité

- ✅ Authentification JWT avec refresh tokens
- ✅ Validation Zod côté serveur
- ✅ Rate limiting
- ✅ HTTPS automatique (Let's Encrypt)
- ✅ Isolation multi-tenant RLS
- ✅ Logs d'audit

---

## 📈 Roadmap

### Phase 1: MVP ✅
- [x] Architecture complète
- [x] Schéma base de données
- [x] Validation API (Zod)
- [x] UI livreur (Flutter)
- [x] Dashboard admin (React)

### Phase 2: En cours 🔄
- [ ] Implémentation backend complète
- [ ] Tests unitaires
- [ ] Mode offline livreur
- [ ] Notifications push

### Phase 3: Futur 📋
- [ ] Optimisation tournées
- [ ] Analytics avancés
- [ ] Multi-organisation (franchise)

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📄 Licence

MIT License - Voir [LICENSE](LICENSE).

---

## 📞 Support

Pour toute question :
- 📧 Email: support@awid.dz
- 📚 Documentation: [docs.awid.dz](https://docs.awid.dz)

---

<p align="center">
  Fait avec ❤️ pour l'Algérie
</p>
