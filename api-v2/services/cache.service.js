const redis = require('../config/redis');
const logger = require('../config/logger');

/**
 * Service de Cache Wrapper
 * GÃ¨re les interactions avec Redis de maniÃ¨re rÃ©siliente.
 * Si Redis est down, les mÃ©thodes retournent null ou ignorent l'opÃ©ration sans crasher l'app.
 */
class CacheService {
    constructor() {
        this.isConnected = false;

        // Suivre l'Ã©tat de la connexion pour optimiser les appels
        redis.on('ready', () => { this.isConnected = true; });
        redis.on('end', () => { this.isConnected = false; });
        redis.on('error', () => { this.isConnected = false; });

        // Tenter une connexion initiale (sans bloquer)
        redis.connect().catch(() => { });
    }

    /**
     * RÃ©cupÃ¨re une valeur du cache
     * @param {string} key 
     * @returns {Promise<any|null>} DonnÃ©e parsÃ©e ou null
     */
    async get(key) {
        if (!this.isConnected) return null;
        try {
            const data = await redis.get(key);
            return data ? JSON.parse(data) : null;
        } catch (error) {
            return null;
        }
    }

    /**
     * Stocke une valeur dans le cache
     * @param {string} key 
     * @param {any} value 
     * @param {number} ttlSeconds DurÃ©e de vie en secondes (dÃ©faut 300s = 5min)
     */
    async set(key, value, ttlSeconds = 300) {
        if (!this.isConnected) return;
        try {
            const stringValue = JSON.stringify(value);
            await redis.setex(key, ttlSeconds, stringValue);
        } catch (error) {
            // Ignorer erreur d'Ã©criture
        }
    }

    /**
     * Supprime une clÃ© ou un pattern
     * @param {string} pattern ClÃ© exacte ou pattern (ex: "products:*")
     */
    async invalidate(pattern) {
        if (!this.isConnected) return;
        try {
            if (pattern.includes('*')) {
                // Suppression par pattern (Scan)
                const stream = redis.scanStream({ match: pattern });
                stream.on('data', (keys) => {
                    if (keys.length) {
                        const pipeline = redis.pipeline();
                        keys.forEach(key => pipeline.del(key));
                        pipeline.exec();
                    }
                });
            } else {
                // Suppression simple
                await redis.del(pattern);
            }
        } catch (error) {
            logger.error('Cache invalidation error:', { error: error.message, stack: error.stack });
        }
    }

    /**
     * GÃ©nÃ¨re une clÃ© de cache standardisÃ©e
     * @param {string} prefix (ex: 'products')
     * @param {string} orgId 
     * @param {object} params (query params ou autres identifiants)
     */
    generateKey(prefix, orgId, params = {}) {
        const sortedParams = Object.keys(params).sort().map(k => `${k}:${params[k]}`).join(':');
        return `cache:${prefix}:${orgId}${sortedParams ? ':' + sortedParams : ''}`;
    }
}

module.exports = new CacheService();
