/**
 * Configuration Winston Logger pour AWID API v2
 * Logs structurÃ©s JSON en production pour ingestion facile (Datadog, CloudWatch...)
 * Logs lisibles en couleur pour le dÃ©veloppement
 */

const winston = require('winston');

// Niveaux de logs personnalisÃ©s si besoin, mais standard syslog/npm ok
const levels = {
    error: 0,
    warn: 1,
    info: 2,
    http: 3,
    debug: 4,
};

// DÃ©termine le niveau de log selon l'environnement
const level = () => {
    const env = process.env.NODE_ENV || 'development';
    const isDevelopment = env === 'development';
    return isDevelopment ? 'debug' : 'info';
};

// Couleurs pour le mode dÃ©veloppement
const colors = {
    error: 'red',
    warn: 'yellow',
    info: 'green',
    http: 'magenta',
    debug: 'white',
};

winston.addColors(colors);

// Format pour la production (JSON structurÃ©)
const productionFormat = winston.format.combine(
    winston.format.timestamp({ format: 'ISO' }),
    winston.format.json()
);

// Format pour le dÃ©veloppement (Lisible + couleurs)
const developmentFormat = winston.format.combine(
    winston.format.colorize({ all: true }),
    winston.format.timestamp({ format: 'HH:mm:ss' }),
    winston.format.printf(
        (info) => `${info.timestamp} ${info.level}: ${info.message}${info.metadata ? ' ' + JSON.stringify(info.metadata) : ''}`
    )
);

// CrÃ©ation du logger principal
const logger = winston.createLogger({
    level: level(),
    levels,
    format: process.env.NODE_ENV === 'production' ? productionFormat : developmentFormat,
    transports: [
        new winston.transports.Console(),
        // On pourrait ajouter des fichiers ici, mais en container/serverless, 
        // stdout/stderr est la bonne pratique (12 factor app)
    ],
});

// Middleware pour logger les requÃªtes HTTP (remplacement de Morgan)
const requestLogger = (req, res, next) => {
    const start = Date.now();

    // Intercepter la fin de la rÃ©ponse pour calculer la durÃ©e et logger
    res.on('finish', () => {
        const duration = Date.now() - start;
        const status = res.statusCode;
        const level = status >= 500 ? 'error' : status >= 400 ? 'warn' : 'http';

        logger.log({
            level,
            message: `${req.method} ${req.originalUrl || req.url} ${status} ${duration}ms`,
            metadata: {
                method: req.method,
                url: req.originalUrl || req.url,
                status,
                duration,
                userAgent: req.get('user-agent'),
                ip: req.ip || req.connection.remoteAddress,
                userId: req.user ? req.user.id : undefined, // Log user ID si authentifiÃ©
                requestId: req.headers['x-request-id'] // Pour tracing
            }
        });
    });

    next();
};

module.exports = logger;
module.exports.requestLogger = requestLogger;
