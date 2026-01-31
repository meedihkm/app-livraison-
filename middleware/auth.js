const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const pool = require('../config/database');
const { jwtSecret, superAdminKey } = require('../config/jwt');

// Middleware d'authentification JWT
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Token manquant' });
    }

    const token = authHeader.substring(7);
    if (!token || token.length < 10) {
      return res.status(401).json({ error: 'Token invalide' });
    }

    const decoded = jwt.verify(token, jwtSecret);

    const result = await pool.query(
      'SELECT id, organization_id, role, active FROM users WHERE id = $1',
      [decoded.id]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Utilisateur non trouvÃ©' });
    }

    const user = result.rows[0];

    if (!user.active) {
      return res.status(403).json({ error: 'Compte dÃ©sactivÃ©' });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expirÃ©' });
    }
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token invalide' });
    }
    console.error('Auth error:', error.message);
    res.status(401).json({ error: 'Erreur d\'authentification' });
  }
};

// Middleware pour vÃ©rifier le rÃ´le admin
const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'AccÃ¨s admin requis' });
  }
  next();
};

// Middleware pour vÃ©rifier le rÃ´le kitchen
const requireKitchen = (req, res, next) => {
  if (req.user.role !== 'kitchen') {
    return res.status(403).json({ error: 'AccÃ¨s atelier requis' });
  }
  next();
};

// Middleware pour vÃ©rifier le rÃ´le deliverer
const requireDeliverer = (req, res, next) => {
  if (req.user.role !== 'deliverer') {
    return res.status(403).json({ error: 'AccÃ¨s livreur requis' });
  }
  next();
};

// Middleware d'authentification super-admin (timing-safe)
const authenticateSuperAdmin = (req, res, next) => {
  const key = req.headers['x-super-admin-key'];

  if (!key || key.length !== superAdminKey.length) {
    return res.status(403).json({ error: 'AccÃ¨s super-admin requis' });
  }

  const keyBuffer = Buffer.from(key);
  const secretBuffer = Buffer.from(superAdminKey);

  if (!crypto.timingSafeEqual(keyBuffer, secretBuffer)) {
    return res.status(403).json({ error: 'AccÃ¨s super-admin requis' });
  }

  next();
};

// Middleware gÃ©nÃ©rique pour vÃ©rifier les rÃ´les
const authorize = (roles = []) => {
  if (typeof roles === 'string') {
    roles = [roles];
  }

  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Non authentifiÃ©' });
    }

    if (roles.length && !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'AccÃ¨s non autorisÃ©' });
    }
    next();
  };
};

module.exports = {
  authenticate,
  requireAdmin,
  requireKitchen,
  requireDeliverer,
  authenticateSuperAdmin,
  authorize
};
