const cacheService = require('../services/cache.service');
const logger = require('../config/logger');
const { cacheHitsTotal, cacheMissesTotal } = require('./metrics.middleware');

/**
 * Middleware de Cache
 * @param {number} ttlSeconds DurÃ©e de vie en secondes
 * @param {string} keyPrefix PrÃ©fixe pour la clÃ© de cache (ex: 'users')
 */
const cacheMiddleware = (ttlSeconds = 300, keyPrefix = null) => {
    return async (req, res, next) => {
        // Ne cacher que les requÃªtes GET
        if (req.method !== 'GET') {
            return next();
        }

        try {
            // DÃ©terminer le prÃ©fixe (soit passÃ© explicitement, soit basÃ© sur l'URL)
            const prefix = keyPrefix || req.baseUrl.split('/').pop() || 'global';
            const orgId = req.user ? req.user.organization_id : 'public';

            // GÃ©nÃ©rer la clÃ© unique (inclure path pour unicitÃ©)
            const cachedParams = { ...req.query, ...req.params };
            if (req.path && req.path !== '/') cachedParams._path = req.path;
            const key = cacheService.generateKey(prefix, orgId, cachedParams);

            // 1. Essayer de rÃ©cupÃ©rer du cache
            const cachedData = await cacheService.get(key);

            if (cachedData) {
                // HIT: Retourner directement la donnÃ©e
                res.setHeader('X-Cache', 'HIT');
                cacheHitsTotal.inc({ route: req.baseUrl });
                return res.json(cachedData);
            }

            // MISS: Surcharger res.json pour capturer et cacher la rÃ©ponse
            res.setHeader('X-Cache', 'MISS');
            cacheMissesTotal.inc({ route: req.baseUrl });
            const originalJson = res.json;

            res.json = function (body) {
                // Restaurer la fonction d'origine pour Ã©viter boucle infinie si rappelÃ©e
                res.json = originalJson;

                // Ne cacher que les succÃ¨s (200-299)
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    // Stocker en arriÃ¨re-plan (ne bloque pas la rÃ©ponse)
                    cacheService.set(key, body, ttlSeconds).catch(() => { });
                }

                // Envoyer la rÃ©ponse
                return originalJson.call(this, body);
            };

            next();
        } catch (error) {
            logger.error('Cache middleware error:', error);
            next(); // Continuer sans cache en cas d'erreur
        }
    };
};

module.exports = cacheMiddleware;
