const Redis = require('ioredis');

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const redis = new Redis(redisUrl, {
    maxRetriesPerRequest: 3,
    retryStrategy(times) {
        const delay = Math.min(times * 50, 2000);
        return delay;
    },
    reconnectOnError(err) {
        const targetError = 'READONLY';
        if (err.message.slice(0, targetError.length) === targetError) {
            // Only reconnect when the error starts with "READONLY"
            return true;
        }
    },
    lazyConnect: true, // Don't connect immediately, wait for first use
});

redis.on('connect', () => {
    console.log('Redis connected successfully');
});

redis.on('error', (err) => {
    // Suppress connection refused errors in development to allow working without Redis
    if (err.code === 'ECONNREFUSED') {
        // console.warn('Redis connection failed (Cache will be disabled)');
    } else {
        console.error('Redis error:', err.message);
    }
});

module.exports = redis;
