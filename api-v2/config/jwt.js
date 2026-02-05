const crypto = require('crypto');
const logger = require('./logger');

// VÃ©rification des secrets en production
if (process.env.NODE_ENV === 'production') {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    logger.error('ERREUR CRITIQUE: JWT_SECRET non dÃ©fini ou trop court en production!');
    process.exit(1);
  }
  if (!process.env.SUPER_ADMIN_KEY || process.env.SUPER_ADMIN_KEY.length < 32) {
    logger.error('ERREUR CRITIQUE: SUPER_ADMIN_KEY non dÃ©fini ou trop court en production!');
    process.exit(1);
  }
}

module.exports = {
  jwtSecret: process.env.JWT_SECRET || (() => {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('JWT_SECRET requis en production');
    }
    logger.warn('âš ï¸ Utilisation du secret JWT de dÃ©veloppement');
    return 'dev-only-secret-change-in-production-' + crypto.randomBytes(16).toString('hex');
  })(),
  
  superAdminKey: process.env.SUPER_ADMIN_KEY || (() => {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('SUPER_ADMIN_KEY requis en production');
    }
    logger.warn('âš ï¸ Utilisation de la clÃ© super-admin de dÃ©veloppement');
    return 'dev-only-key-change-in-production-' + crypto.randomBytes(16).toString('hex');
  })(),
  
  accessTokenExpiry: '15m',
  refreshTokenExpiryDays: 30,
};
