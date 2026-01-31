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

# Exposer le port (Coolify utilise PORT=3000)
EXPOSE 3000

# Healthcheck - CORRIGÉ (pas de backtick)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Démarrer l'application
CMD ["node", "index.js"]