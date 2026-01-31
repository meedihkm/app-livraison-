const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const router = express.Router();

const pool = require('../config/database');
const { jwtSecret, accessTokenExpiry } = require('../config/jwt');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { loginLimiter } = require('../middleware/rateLimit');
const { logAudit } = require('../services/audit.service');
const {
  generateRefreshToken,
  saveRefreshToken,
  validateRefreshToken,
  revokeRefreshToken,
  revokeAllUserTokens
} = require('../services/token.service');

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentification et gestion des sessions
 */

/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         email:
 *           type: string
 *           format: email
 *         name:
 *           type: string
 *         role:
 *           type: string
 *           enum: [admin, user, deliverer, customer]
 *         organizationId:
 *           type: string
 *           format: uuid
 *         organization:
 *           type: object
 *           properties:
 *             id: 
 *               type: string
 *               format: uuid
 *             name: 
 *               type: string
 *             type: 
 *               type: string
 *     AuthResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         accessToken:
 *           type: string
 *         refreshToken:
 *           type: string
 *         expiresIn:
 *           type: integer
 *         user:
 *           $ref: '#/components/schemas/User'
 */

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Connecter un utilisateur
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: admin@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: password123
 *     responses:
 *       200:
 *         description: Connexion rÃ©ussie
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: DonnÃ©es invalides
 *       401:
 *         description: Identifiants incorrects
 *       403:
 *         description: Compte ou organisation dÃ©sactivÃ©e
 */
// POST /api/auth/login
router.post('/login', loginLimiter, validate('login'), async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await pool.query(
      `SELECT u.*, o.name as org_name, o.type as org_type, o.active as org_active 
       FROM users u 
       JOIN organizations o ON u.organization_id = o.id 
       WHERE LOWER(u.email) = LOWER($1)`,
      [email.trim()]
    );

    if (result.rows.length === 0) {
      await bcrypt.hash('dummy', 10); // Timing attack protection
      await logAudit('LOGIN_FAILED', null, null, { email, reason: 'user_not_found' }, req);
      return res.status(401).json({ error: 'Identifiants incorrects' });
    }

    const user = result.rows[0];

    if (!user.org_active) {
      await logAudit('LOGIN_FAILED', user.id, user.organization_id, { reason: 'org_disabled' }, req);
      return res.status(403).json({ error: 'Organisation dÃ©sactivÃ©e' });
    }

    if (!user.active) {
      await logAudit('LOGIN_FAILED', user.id, user.organization_id, { reason: 'user_disabled' }, req);
      return res.status(403).json({ error: 'Compte dÃ©sactivÃ©' });
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      await logAudit('LOGIN_FAILED', user.id, user.organization_id, { reason: 'wrong_password' }, req);
      return res.status(401).json({ error: 'Identifiants incorrects' });
    }

    const accessToken = jwt.sign(
      { id: user.id, organizationId: user.organization_id, role: user.role },
      jwtSecret,
      { expiresIn: accessTokenExpiry }
    );

    const refreshToken = generateRefreshToken();
    await saveRefreshToken(user.id, refreshToken);

    await logAudit('LOGIN_SUCCESS', user.id, user.organization_id, {}, req);

    res.json({
      success: true,
      accessToken,
      refreshToken,
      expiresIn: 900,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        organizationId: user.organization_id,
        organization: { id: user.organization_id, name: user.org_name || '', type: user.org_type || '' }
      }
    });
  } catch (error) {
    console.error('Login error:', error.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: RafraÃ®chir le token d'accÃ¨s
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token rafraÃ®chi avec succÃ¨s
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 accessToken:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *                 expiresIn:
 *                   type: integer
 *       401:
 *         description: Refresh token invalide ou expirÃ©
 *       403:
 *         description: Compte dÃ©sactivÃ©
 */
// POST /api/auth/refresh
router.post('/refresh', validate('refreshToken'), async (req, res) => {
  try {
    const { refreshToken } = req.body;

    const tokenData = await validateRefreshToken(refreshToken);
    if (!tokenData) {
      return res.status(401).json({ error: 'Refresh token invalide ou expirÃ©' });
    }

    if (!tokenData.active) {
      await revokeRefreshToken(refreshToken);
      return res.status(403).json({ error: 'Compte dÃ©sactivÃ©' });
    }

    await revokeRefreshToken(refreshToken);

    const accessToken = jwt.sign(
      { id: tokenData.user_id, organizationId: tokenData.organization_id, role: tokenData.role },
      jwtSecret,
      { expiresIn: accessTokenExpiry }
    );

    const newRefreshToken = generateRefreshToken();
    await saveRefreshToken(tokenData.user_id, newRefreshToken);

    await logAudit('TOKEN_REFRESH', tokenData.user_id, tokenData.organization_id, {}, req);

    res.json({
      success: true,
      accessToken,
      refreshToken: newRefreshToken,
      expiresIn: 900
    });
  } catch (error) {
    console.error('Refresh error:', error.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: DÃ©connecter l'utilisateur (rÃ©voquer le refresh token)
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: DÃ©connexion rÃ©ussie
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *       401:
 *         description: Non authentifiÃ©
 */
// POST /api/auth/logout
router.post('/logout', authenticate, async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await revokeRefreshToken(refreshToken);
    }
    await logAudit('LOGOUT', req.user.id, req.user.organization_id, {}, req);
    res.json({ success: true });
  } catch (error) {
    console.error('Logout error:', error.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// POST /api/auth/logout-all
router.post('/logout-all', authenticate, async (req, res) => {
  try {
    await revokeAllUserTokens(req.user.id);
    await logAudit('LOGOUT_ALL_DEVICES', req.user.id, req.user.organization_id, {}, req);
    res.json({ success: true });
  } catch (error) {
    console.error('Logout all error:', error.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Obtenir les informations de l'utilisateur connectÃ©
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Informations utilisateur
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Non authentifiÃ©
 */
// GET /api/auth/me
router.get('/me', authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.*, o.name as org_name, o.type as org_type 
       FROM users u 
       JOIN organizations o ON u.organization_id = o.id 
       WHERE u.id = $1`,
      [req.user.id]
    );

    const user = result.rows[0];
    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        organizationId: user.organization_id,
        organization: { id: user.organization_id, name: user.org_name || '', type: user.org_type || '' }
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
