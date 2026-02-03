/**
 * Configuration de sÃ©curitÃ© Helmet pour AWID API v2
 * CSP strict + HSTS + autres headers de sÃ©curitÃ©
 */

const helmet = require('helmet');

// Configuration Helmet pour API
const getHelmetConfig = () => {
    const isProduction = process.env.NODE_ENV === 'production';

    return {
        // Content Security Policy
        contentSecurityPolicy: {
            directives: {
                defaultSrc: ["'self'"],
                scriptSrc: ["'self'", "'unsafe-inline'"], // NÃ©cessaire pour la page admin inline
                scriptSrcAttr: ["'unsafe-inline'"], // Permettre onclick, onsubmit, etc.
                styleSrc: ["'self'", "'unsafe-inline'"],  // Styles inline pour admin
                imgSrc: ["'self'", "data:", "https:"],
                connectSrc: ["'self'"],
                fontSrc: ["'self'"],
                objectSrc: ["'none'"],
                mediaSrc: ["'self'"],
                frameSrc: ["'none'"],
                // Rapport CSP (optionnel)
                ...(isProduction && process.env.CSP_REPORT_URI ? {
                    reportUri: process.env.CSP_REPORT_URI
                } : {})
            }
        },

        // HTTP Strict Transport Security
        // max-age 1 an, includeSubDomains, preload
        hsts: isProduction ? {
            maxAge: 31536000, // 1 an
            includeSubDomains: true,
            preload: true
        } : false,

        // DÃ©sactiver X-Frame-Options car on utilise frameSrc dans CSP
        frameguard: { action: 'deny' },

        // X-Content-Type-Options: nosniff
        noSniff: true,

        // X-XSS-Protection (legacy mais utile pour anciens navigateurs)
        xssFilter: true,

        // Referrer-Policy
        referrerPolicy: { policy: 'strict-origin-when-cross-origin' },

        // DÃ©sactiver pour apps mobiles
        crossOriginEmbedderPolicy: false,
        crossOriginOpenerPolicy: false,
        crossOriginResourcePolicy: { policy: 'cross-origin' }, // Permettre les ressources cross-origin pour l'API

        // Cacher le header X-Powered-By
        hidePoweredBy: true,

        // DNS Prefetch Control
        dnsPrefetchControl: { allow: false },

        // IE No Open
        ieNoOpen: true,

        // Permissions Policy (anciennement Feature Policy)
        permittedCrossDomainPolicies: { permittedPolicies: 'none' }
    };
};

// Middleware Helmet configurÃ©
const securityMiddleware = helmet(getHelmetConfig());

// Headers de sÃ©curitÃ© additionnels
const additionalSecurityHeaders = (req, res, next) => {
    // Permissions-Policy (remplace Feature-Policy)
    res.setHeader('Permissions-Policy',
        'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()'
    );

    // Cache-Control pour API (pas de cache par dÃ©faut)
    if (!res.getHeader('Cache-Control')) {
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
    }

    next();
};

module.exports = {
    securityMiddleware,
    additionalSecurityHeaders,
    getHelmetConfig
};
