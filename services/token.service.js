const crypto = require('crypto');
const pool = require('../config/database');
const { refreshTokenExpiryDays } = require('../config/jwt');

/**
 * GÃ©nÃ¨re un refresh token sÃ©curisÃ©
 */
function generateRefreshToken() {
  return crypto.randomBytes(64).toString('hex');
}

/**
 * Sauvegarde un refresh token en base
 */
async function saveRefreshToken(userId, token, expiresInDays = refreshTokenExpiryDays) {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + expiresInDays);
  
  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)`,
    [userId, token, expiresAt]
  );
  return expiresAt;
}

/**
 * Valide un refresh token et retourne les infos utilisateur
 */
async function validateRefreshToken(token) {
  const result = await pool.query(
    `SELECT rt.*, u.id as user_id, u.organization_id, u.role, u.active
     FROM refresh_tokens rt
     JOIN users u ON rt.user_id = u.id
     WHERE rt.token = $1 AND rt.revoked = false AND rt.expires_at > NOW()`,
    [token]
  );
  return result.rows[0] || null;
}

/**
 * RÃ©voque un refresh token
 */
async function revokeRefreshToken(token) {
  await pool.query(
    `UPDATE refresh_tokens SET revoked = true WHERE token = $1`,
    [token]
  );
}

/**
 * RÃ©voque tous les refresh tokens d'un utilisateur
 */
async function revokeAllUserTokens(userId) {
  await pool.query(
    `UPDATE refresh_tokens SET revoked = true WHERE user_id = $1`,
    [userId]
  );
}

/**
 * RÃ©voque tous les tokens d'une organisation
 */
async function revokeAllOrgTokens(organizationId) {
  await pool.query(`
    UPDATE refresh_tokens SET revoked = true WHERE user_id IN (
      SELECT id FROM users WHERE organization_id = $1
    )
  `, [organizationId]);
}

/**
 * Nettoie les tokens expirÃ©s (Ã  appeler via CRON)
 */
async function cleanupExpiredTokens() {
  const result = await pool.query(
    `DELETE FROM refresh_tokens WHERE expires_at < NOW() OR revoked = true`
  );
  return result.rowCount;
}

module.exports = {
  generateRefreshToken,
  saveRefreshToken,
  validateRefreshToken,
  revokeRefreshToken,
  revokeAllUserTokens,
  revokeAllOrgTokens,
  cleanupExpiredTokens,
};
