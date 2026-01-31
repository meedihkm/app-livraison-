# Dockerfile pour Coolify - AWID API v2
FROM node:20-alpine

# Créer le répertoire de l'application
WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci --only=production

# Copier le reste du code
COPY . .

# Exposer le port
EXPOSE 3000

# Démarrer l'application
CMD ["node", "index.js"]