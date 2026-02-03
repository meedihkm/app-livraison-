/**
 * Middleware Prometheus pour AWID API v2
 * Collecte les mÃ©triques RED (Rate, Errors, Duration)
 */

const client = require('prom-client');
const responseTime = require('response-time');

// Initialisation du registre
const register = new client.Registry();

// Ajouter les mÃ©triques par dÃ©faut (CPU, Memory, etc.)
client.collectDefaultMetrics({
    register,
    labels: { app: 'awid-api-v2' }
});

// MÃ©trique: DurÃ©e des requÃªtes HTTP
const httpRequestDurationMicroseconds = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10] // Buckets pertinents pour API
});

// MÃ©trique: Compteur total de requÃªtes
const httpRequestsTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

// MÃ©trique: Connexions actives
const activeConnections = new client.Gauge({
    name: 'active_connections',
    help: 'Number of active connections currently being handled',
});

// MÃ©triques Cache
const cacheHitsTotal = new client.Counter({
    name: 'cache_hits_total',
    help: 'Total number of cache hits',
    labelNames: ['route']
});

const cacheMissesTotal = new client.Counter({
    name: 'cache_misses_total',
    help: 'Total number of cache misses',
    labelNames: ['route']
});

register.registerMetric(httpRequestDurationMicroseconds);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeConnections);
register.registerMetric(cacheHitsTotal);
register.registerMetric(cacheMissesTotal);

/**
 * Middleware pour collecter les mÃ©triques de chaque requÃªte
 */
const metricsMiddleware = responseTime((req, res, time) => {
    // Ignorer les routes de metrics et healthcheck pour ne pas polluer
    if (req.path === '/metrics' || req.path.startsWith('/api/health')) {
        return;
    }

    // Normaliser la route (Ã©viter explosion de cardinalitÃ© avec les IDs)
    // Ex: /api/orders/123 -> /api/orders/:id
    const route = req.route ? req.route.path : req.path;

    // IncrÃ©menter total
    httpRequestsTotal.inc({
        method: req.method,
        route: route,
        status_code: res.statusCode
    });

    // Observer durÃ©e (convertir ms en secondes)
    httpRequestDurationMicroseconds.observe(
        {
            method: req.method,
            route: route,
            status_code: res.statusCode
        },
        time / 1000
    );
});

/**
 * Endpoint pour exposer les mÃ©triques Ã  Prometheus
 */
const metricsEndpoint = async (req, res) => {
    // Protection basique: VÃ©rifier token ou IP si nÃ©cessaire
    // Pour l'instant, protection via rÃ©seau interne (Vercel/Private)

    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
};

module.exports = {
    metricsMiddleware,
    metricsEndpoint,
    register,
    cacheHitsTotal,
    cacheMissesTotal
};
