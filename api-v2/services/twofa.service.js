/**
 * Service 2FA TOTP pour AWID Super-Admin
 * Utilise otplib pour génération et validation de codes TOTP
 */

const crypto = require('crypto');
const logger = require('../config/logger');

// Import dynamique pour gérer le cas où otplib n'est pas installé
let authenticator;
try {
    const { authenticator: auth } = require('otplib');
    authenticator = auth;
} catch (err) {
    logger.warn('[2FA] Module otplib non disponible - 2FA désactivé');
    authenticator = null;
}

// Configuration TOTP
const TOTP_CONFIG = {
    issuer: process.env.SUPER_ADMIN_2FA_ISSUER || 'AWID Admin',
    algorithm: 'sha1',
    digits: 6,
    period: 30 // 30 secondes par code
};

// Nombre de backup codes à générer
const BACKUP_CODES_COUNT = 8;

/**
 * Génère un nouveau secret TOTP
 * @returns {Object} { secret, otpauthUrl }
 */
const generateSecret = (accountName = 'super-admin') => {
    if (!authenticator) {
        throw new Error('2FA non disponible - otplib non installé');
    }

    const secret = authenticator.generateSecret();

    // URL pour QR code (compatible Google Authenticator, Authy, etc.)
    const otpauthUrl = authenticator.keyuri(
        accountName,
        TOTP_CONFIG.issuer,
        secret
    );

    return {
        secret,
        otpauthUrl,
        issuer: TOTP_CONFIG.issuer
    };
};

/**
 * Vérifie un code TOTP
 * @param {string} token - Code à 6 chiffres
 * @param {string} secret - Secret TOTP
 * @returns {boolean}
 */
const verifyToken = (token, secret) => {
    if (!authenticator) {
        throw new Error('2FA non disponible - otplib non installé');
    }

    if (!token || !secret) {
        return false;
    }

    // Nettoyer le token (supprimer espaces)
    const cleanToken = token.replace(/\s/g, '');

    try {
        return authenticator.verify({
            token: cleanToken,
            secret
        });
    } catch (err) {
        logger.error('[2FA] Erreur vérification:', err.message);
        return false;
    }
};

/**
 * Génère des backup codes (usage unique)
 * @returns {Array<string>} Liste de codes de 8 caractères
 */
const generateBackupCodes = () => {
    const codes = [];

    for (let i = 0; i < BACKUP_CODES_COUNT; i++) {
        // Format: XXXX-XXXX (8 caractères alphanumériques)
        const part1 = crypto.randomBytes(2).toString('hex').toUpperCase();
        const part2 = crypto.randomBytes(2).toString('hex').toUpperCase();
        codes.push(`${part1}-${part2}`);
    }

    return codes;
};

/**
 * Hash les backup codes pour stockage sécurisé
 * @param {Array<string>} codes - Codes en clair
 * @returns {Array<string>} Codes hashés
 */
const hashBackupCodes = (codes) => {
    return codes.map(code => {
        return crypto.createHash('sha256').update(code).digest('hex');
    });
};

/**
 * Vérifie un backup code contre les codes hashés
 * @param {string} inputCode - Code saisi par l'utilisateur
 * @param {Array<string>} hashedCodes - Codes hashés stockés
 * @returns {Object} { valid: boolean, index: number }
 */
const verifyBackupCode = (inputCode, hashedCodes) => {
    if (!inputCode || !Array.isArray(hashedCodes)) {
        return { valid: false, index: -1 };
    }

    // Normaliser le code (majuscules, supprimer espaces)
    const cleanCode = inputCode.toUpperCase().replace(/\s/g, '');
    const hashedInput = crypto.createHash('sha256').update(cleanCode).digest('hex');

    const index = hashedCodes.findIndex(hashed => hashed === hashedInput);

    return {
        valid: index !== -1,
        index
    };
};

/**
 * Vérifie si le module 2FA est disponible
 * @returns {boolean}
 */
const isAvailable = () => {
    return authenticator !== null;
};

module.exports = {
    generateSecret,
    verifyToken,
    generateBackupCodes,
    hashBackupCodes,
    verifyBackupCode,
    isAvailable,
    TOTP_CONFIG
};
