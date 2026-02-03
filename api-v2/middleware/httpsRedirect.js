/**
 * Middleware de redirection HTTP â†’ HTTPS pour AWID API v2
 * Compatible avec Vercel et proxies inverses
 */

/**
 * Redirige les requÃªtes HTTP vers HTTPS en production
 * Utilise x-forwarded-proto car Vercel/proxies terminent le SSL
 */
const httpsRedirect = (req, res, next) => {
    // DÃ©sactiver la redirection HTTPS si DISABLE_HTTPS_REDIRECT=true
    if (process.env.DISABLE_HTTPS_REDIRECT === 'true') {
        return next();
    }

    // Uniquement en production
    if (process.env.NODE_ENV !== 'production') {
        return next();
    }

    // VÃ©rifier le protocole via header (proxy/load balancer)
    const proto = req.headers['x-forwarded-proto'];

    // Si dÃ©jÃ  HTTPS ou pas de header (connexion directe), continuer
    if (!proto || proto === 'https') {
        return next();
    }

    // Exclure les health checks (pour les load balancers)
    const healthPaths = ['/api/health', '/health', '/_health'];
    if (healthPaths.includes(req.path)) {
        return next();
    }

    // Construire l'URL HTTPS
    const host = req.headers.host || req.hostname;
    const httpsUrl = `https://${host}${req.originalUrl}`;

    // Redirection 301 (permanente)
    console.log(`[HTTPS] Redirection: ${req.protocol}://${host}${req.originalUrl} â†’ ${httpsUrl}`);
    return res.redirect(301, httpsUrl);
};

/**
 * Middleware pour forcer HSTS mÃªme sans Helmet
 * Utile comme backup
 */
const forceHSTS = (req, res, next) => {
    if (process.env.NODE_ENV === 'production') {
        // HSTS: 1 an, sous-domaines inclus, preload
        res.setHeader(
            'Strict-Transport-Security',
            'max-age=31536000; includeSubDomains; preload'
        );
    }
    next();
};

module.exports = httpsRedirect;
module.exports.forceHSTS = forceHSTS;
