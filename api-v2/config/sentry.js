/**
 * Configuration Sentry pour AWID API v2
 * Gestion des erreurs centralisÃ©e et APM
 * NOTE: Profiling dÃ©sactivÃ© pour compatibilitÃ© Vercel serverless
 */

const Sentry = require('@sentry/node');

// Flag pour vÃ©rifier si Sentry est initialisÃ©
let sentryInitialized = false;

// Stub handlers pour quand Sentry n'est pas configurÃ©
const stubHandlers = {
    requestHandler: () => (req, res, next) => next(),
    tracingHandler: () => (req, res, next) => next(),
    errorHandler: () => (err, req, res, next) => next(err),
};

// Initialisation de Sentry
const initSentry = (app) => {
    // Ne pas initialiser si pas de DSN (ex: dev local sans monitoring)
    if (!process.env.SENTRY_DSN) {
        console.log('[Monitoring] SENTRY_DSN non dÃ©fini - Monitoring dÃ©sactivÃ©');
        return;
    }

    try {
        Sentry.init({
            dsn: process.env.SENTRY_DSN,
            environment: process.env.NODE_ENV || 'development',
            integrations: [
                // enable HTTP calls tracing
                new Sentry.Integrations.Http({ tracing: true }),
                // enable Express.js middleware tracing
                new Sentry.Integrations.Express({ app }),
                // NOTE: nodeProfilingIntegration dÃ©sactivÃ© - incompatible avec Vercel serverless
            ],
            // Performance Monitoring
            tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.2 : 1.0,

            // Filtrage des donnÃ©es sensibles avant envoi
            beforeSend(event) {
                if (event.request) {
                    // Filtrer les headers sensibles
                    if (event.request.headers) {
                        delete event.request.headers['authorization'];
                        delete event.request.headers['x-super-admin-key'];
                    }

                    // Filtrer les body sensibles
                    if (event.request.data) {
                        try {
                            const data = typeof event.request.data === 'string'
                                ? JSON.parse(event.request.data)
                                : event.request.data;

                            if (data.password) data.password = '[REDACTED]';
                            if (data.token) data.token = '[REDACTED]';
                            if (data.creditCard) data.creditCard = '[REDACTED]';

                            event.request.data = JSON.stringify(data);
                        } catch (e) {
                            // Ignorer erreurs de parsing
                        }
                    }
                }
                return event;
            },
        });

        sentryInitialized = true;
        console.log('[Monitoring] Sentry initialisÃ©');
    } catch (error) {
        console.error('[Monitoring] Erreur initialisation Sentry:', error.message);
    }
};

// Getter pour les Handlers (retourne stubs si Sentry non initialisÃ©)
const getHandlers = () => {
    if (sentryInitialized && Sentry.Handlers) {
        return Sentry.Handlers;
    }
    return stubHandlers;
};

module.exports = { initSentry, Sentry, getHandlers };

