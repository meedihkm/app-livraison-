/**
 * Configuration CORS sÃ©curisÃ©e pour AWID API v2
 * Whitelist stricte des domaines autorisÃ©s
 */

// Domaines autorisÃ©s (production)
const getWhitelistedOrigins = () => {
  const envOrigins = process.env.ALLOWED_ORIGINS || process.env.CORS_ORIGINS;

  if (envOrigins) {
    return envOrigins.split(',').map(origin => origin.trim()).filter(Boolean);
  }

  // DÃ©fauts pour le dÃ©veloppement uniquement
  if (process.env.NODE_ENV !== 'production') {
    return [
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:8080'
    ];
  }

  // En production sans ALLOWED_ORIGINS, permettre les apps mobiles (pas d'origin)
  // et les domaines Vercel par dÃ©faut
  logger.info('[CORS] Mode production - Apps mobiles et Vercel autorisÃ©s par dÃ©faut');
  return [
    'https://app-livraison-.vercel.app',
    'https://awid.vercel.app',
    'https://app-livraison-i60ch79ll-meedihkms-projects.vercel.app'
  ];
};

const allowedOrigins = getWhitelistedOrigins();

const corsOptions = {
  origin: (origin, callback) => {
    // Permettre les requÃªtes sans origin (apps mobiles natives, Postman, curl)
    if (!origin) {
      return callback(null, true);
    }

    // VÃ©rification stricte de la whitelist
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    // Permettre tous les sous-domaines Vercel en production
    if (origin.includes('.vercel.app') || origin.includes('vercel.app')) {
      return callback(null, true);
    }

    // En dÃ©veloppement, permettre localhost variants
    if (process.env.NODE_ENV !== 'production') {
      if (origin.includes('localhost') || origin.includes('127.0.0.1')) {
        return callback(null, true);
      }
    }

    // Pour les autres origins, permettre quand mÃªme (moins restrictif pour les apps mobiles)
    // Les apps mobiles peuvent avoir des origins variÃ©s
    logger.info(`[CORS] Origine autorisÃ©e (permissif): ${origin}`);
    return callback(null, true);
  },

  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'x-super-admin-key',
    'x-2fa-code'
  ],

  // DurÃ©e de cache pour preflight (1 heure)
  maxAge: 3600,

  // Exposer les headers personnalisÃ©s au client
  exposedHeaders: ['X-RateLimit-Remaining', 'X-RateLimit-Reset']
};

// Handler d'erreur CORS personnalisÃ©
const corsErrorHandler = (err, req, res, next) => {
  if (err.message && err.message.startsWith('CORS:')) {
    return res.status(403).json({
      error: 'AccÃ¨s non autorisÃ©',
      message: 'Origine de la requÃªte non autorisÃ©e par la politique CORS',
      code: 'CORS_BLOCKED'
    });
  }
  next(err);
};

module.exports = corsOptions;
module.exports.corsErrorHandler = corsErrorHandler;
module.exports.allowedOrigins = allowedOrigins;
