const Redis = require('ioredis');

// URL Redis
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

// Configuration de connexion pour BullMQ
// BullMQ crÃ©e ses propres connexions, on lui passe les options
const connection = new Redis(redisUrl, {
    maxRetriesPerRequest: null, // Requis par BullMQ
    enableReadyCheck: false,
});

const defaultJobOptions = {
    attempts: 3,
    backoff: {
        type: 'exponential',
        delay: 1000,
    },
    removeOnComplete: {
        age: 24 * 3600, // Garder 24h
        count: 1000,
    },
    removeOnFail: {
        age: 7 * 24 * 3600, // Garder 7 jours pour inspection
    },
};

module.exports = {
    connection,
    defaultJobOptions,
};
