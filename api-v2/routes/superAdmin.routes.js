const express = require('express');
const bcrypt = require('bcryptjs');
const router = express.Router();

const pool = require('../config/database');
const logger = require('../config/logger');
const { authenticateSuperAdmin } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { superAdminLimiter } = require('../middleware/rateLimit');
const { logAudit, getAllAuditLogs } = require('../services/audit.service');
const { revokeAllOrgTokens } = require('../services/token.service');
const twofa = require('../services/twofa.service');

// GET /api/super-admin/test
router.get('/test', superAdminLimiter, authenticateSuperAdmin, (req, res) => {
  res.json({ success: true, message: 'Super-admin OK' });
});

// GET /api/super-admin/stats
router.get('/stats', authenticateSuperAdmin, async (req, res) => {
  try {
    const orgs = await pool.query('SELECT COUNT(*) as count FROM organizations');
    const activeOrgs = await pool.query('SELECT COUNT(*) as count FROM organizations WHERE active = true');
    const users = await pool.query('SELECT COUNT(*) as count FROM users');
    const orders = await pool.query('SELECT COUNT(*) as count FROM orders');

    res.json({
      success: true,
      data: {
        totalOrganizations: parseInt(orgs.rows[0].count),
        activeOrganizations: parseInt(activeOrgs.rows[0].count),
        totalUsers: parseInt(users.rows[0].count),
        totalOrders: parseInt(orders.rows[0].count)
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/super-admin/organizations
router.get('/organizations', authenticateSuperAdmin, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM organizations ORDER BY created_at DESC');
    res.json({ success: true, data: result.rows });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// POST /api/super-admin/organizations
router.post('/organizations', authenticateSuperAdmin, validate('createOrganization'), async (req, res) => {
  try {
    const { name, type, adminEmail, adminPassword, adminName, adminPhone } = req.body;

    const orgResult = await pool.query(
      'INSERT INTO organizations (name, type) VALUES ($1, $2) RETURNING *',
      [name, type || 'restaurant']
    );
    const org = orgResult.rows[0];

    const hashedPassword = await bcrypt.hash(adminPassword, 12);
    await pool.query(
      'INSERT INTO users (organization_id, email, password, name, phone, role) VALUES ($1, $2, $3, $4, $5, $6)',
      [org.id, adminEmail.trim().toLowerCase(), hashedPassword, adminName, adminPhone || '', 'admin']
    );

    await logAudit('ORG_CREATED', null, org.id, { name, adminEmail }, req);

    res.json({ success: true, data: org });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur', details: error.message });
  }
});

// DELETE /api/super-admin/organizations/:id
router.delete('/organizations/:id', authenticateSuperAdmin, async (req, res) => {
  try {
    // Supprimer les refresh tokens des utilisateurs de cette org
    await pool.query(`
      DELETE FROM refresh_tokens WHERE user_id IN (
        SELECT id FROM users WHERE organization_id = $1
      )
    `, [req.params.id]);

    // Supprimer les audit logs
    await pool.query('DELETE FROM audit_logs WHERE organization_id = $1', [req.params.id]);

    // Supprimer les order_items
    await pool.query(`
      DELETE FROM order_items WHERE order_id IN (
        SELECT id FROM orders WHERE organization_id = $1
      )
    `, [req.params.id]);

    // Supprimer les livraisons
    await pool.query('DELETE FROM deliveries WHERE organization_id = $1', [req.params.id]);

    // Supprimer les commandes
    await pool.query('DELETE FROM orders WHERE organization_id = $1', [req.params.id]);

    // Supprimer les produits
    await pool.query('DELETE FROM products WHERE organization_id = $1', [req.params.id]);

    // Supprimer les utilisateurs
    await pool.query('DELETE FROM users WHERE organization_id = $1', [req.params.id]);

    // Supprimer l'organisation
    await pool.query('DELETE FROM organizations WHERE id = $1', [req.params.id]);

    res.json({ success: true });
  } catch (error) {
    logger.error('Delete org error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur serveur: ' + error.message });
  }
});

// GET /api/super-admin/users
router.get('/users', authenticateSuperAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.email, u.name, u.phone, u.role, u.active, u.created_at, 
              o.name as organization_name, o.id as organization_id
       FROM users u 
       JOIN organizations o ON u.organization_id = o.id 
       ORDER BY u.created_at DESC`
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// PATCH /api/super-admin/organizations/:id/status
router.patch('/organizations/:id/status', authenticateSuperAdmin, validate('toggleOrgStatus'), async (req, res) => {
  try {
    const { active } = req.body;
    await pool.query('UPDATE organizations SET active = $1 WHERE id = $2', [active, req.params.id]);
    await pool.query('UPDATE users SET active = $1 WHERE organization_id = $2', [active, req.params.id]);

    // RÃ©voquer tous les tokens si dÃ©sactivation
    if (!active) {
      await revokeAllOrgTokens(req.params.id);
    }

    await logAudit('ORG_STATUS_CHANGED', null, req.params.id, { active }, req);

    res.json({ success: true });
  } catch (error) {
    logger.error('Toggle org status error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/super-admin/audit-logs
router.get('/audit-logs', authenticateSuperAdmin, async (req, res) => {
  try {
    const { limit, offset } = req.query;
    const logs = await getAllAuditLogs({ limit, offset });
    res.json({ success: true, data: logs });
  } catch (error) {
    logger.error('Super admin audit logs error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// 2FA ENDPOINTS
// ============================================

// GET /api/super-admin/2fa/status - VÃ©rifier si 2FA est activÃ©
router.get('/2fa/status', authenticateSuperAdmin, async (req, res) => {
  try {
    if (!twofa.isAvailable()) {
      return res.json({
        success: true,
        data: { available: false, enabled: false, message: '2FA non disponible (otplib manquant)' }
      });
    }

    const result = await pool.query(
      'SELECT twofa_enabled FROM super_admin_config WHERE id = 1'
    );

    const enabled = result.rows.length > 0 && result.rows[0].twofa_enabled;

    res.json({
      success: true,
      data: { available: true, enabled }
    });
  } catch (error) {
    // Table n'existe peut-Ãªtre pas encore
    res.json({ success: true, data: { available: twofa.isAvailable(), enabled: false } });
  }
});

// POST /api/super-admin/2fa/setup - Configurer 2FA
router.post('/2fa/setup', superAdminLimiter, authenticateSuperAdmin, async (req, res) => {
  try {
    if (!twofa.isAvailable()) {
      return res.status(503).json({ error: '2FA non disponible - installer otplib' });
    }

    // GÃ©nÃ©rer secret et backup codes
    const { secret, otpauthUrl, issuer } = twofa.generateSecret();
    const backupCodes = twofa.generateBackupCodes();
    const hashedBackupCodes = twofa.hashBackupCodes(backupCodes);

    // CrÃ©er la table si elle n'existe pas et stocker temporairement
    await pool.query(`
      CREATE TABLE IF NOT EXISTS super_admin_config (
        id INTEGER PRIMARY KEY DEFAULT 1,
        twofa_secret VARCHAR(255),
        twofa_enabled BOOLEAN DEFAULT false,
        twofa_backup_codes TEXT[],
        twofa_setup_at TIMESTAMP,
        updated_at TIMESTAMP DEFAULT NOW(),
        CHECK (id = 1)
      )
    `);

    // InsÃ©rer ou mettre Ã  jour (secret non activÃ© encore)
    await pool.query(`
      INSERT INTO super_admin_config (id, twofa_secret, twofa_backup_codes, twofa_enabled)
      VALUES (1, $1, $2, false)
      ON CONFLICT (id) DO UPDATE SET 
        twofa_secret = $1,
        twofa_backup_codes = $2,
        twofa_enabled = false,
        updated_at = NOW()
    `, [secret, hashedBackupCodes]);

    res.json({
      success: true,
      data: {
        secret,
        otpauthUrl,
        issuer,
        backupCodes, // Afficher UNE FOIS Ã  l'utilisateur
        message: 'Scannez le QR code puis vÃ©rifiez avec un code pour activer le 2FA'
      }
    });
  } catch (error) {
    logger.error('2FA setup error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur configuration 2FA' });
  }
});

// POST /api/super-admin/2fa/verify - VÃ©rifier et activer 2FA
router.post('/2fa/verify', superAdminLimiter, authenticateSuperAdmin, async (req, res) => {
  try {
    const { code } = req.body;

    if (!code) {
      return res.status(400).json({ error: 'Code requis' });
    }

    // RÃ©cupÃ©rer le secret
    const result = await pool.query(
      'SELECT twofa_secret FROM super_admin_config WHERE id = 1'
    );

    if (result.rows.length === 0 || !result.rows[0].twofa_secret) {
      return res.status(400).json({ error: 'Configuration 2FA non trouvÃ©e. Lancez /2fa/setup d\'abord' });
    }

    const secret = result.rows[0].twofa_secret;

    // VÃ©rifier le code
    if (!twofa.verifyToken(code, secret)) {
      return res.status(401).json({ error: 'Code invalide' });
    }

    // Activer 2FA
    await pool.query(`
      UPDATE super_admin_config SET 
        twofa_enabled = true,
        twofa_setup_at = NOW(),
        updated_at = NOW()
      WHERE id = 1
    `);

    res.json({
      success: true,
      message: '2FA activÃ© avec succÃ¨s'
    });
  } catch (error) {
    logger.error('2FA verify error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur vérification 2FA' });
  }
});

// POST /api/super-admin/2fa/disable - DÃ©sactiver 2FA
router.post('/2fa/disable', superAdminLimiter, authenticateSuperAdmin, async (req, res) => {
  try {
    const { code } = req.body;

    if (!code) {
      return res.status(400).json({ error: 'Code 2FA requis pour dÃ©sactiver' });
    }

    // RÃ©cupÃ©rer le secret
    const result = await pool.query(
      'SELECT twofa_secret, twofa_backup_codes FROM super_admin_config WHERE id = 1'
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: '2FA non configurÃ©' });
    }

    const { twofa_secret, twofa_backup_codes } = result.rows[0];

    // VÃ©rifier code TOTP ou backup code
    let valid = twofa.verifyToken(code, twofa_secret);

    if (!valid && twofa_backup_codes) {
      const backupResult = twofa.verifyBackupCode(code, twofa_backup_codes);
      valid = backupResult.valid;
    }

    if (!valid) {
      return res.status(401).json({ error: 'Code invalide' });
    }

    // DÃ©sactiver 2FA
    await pool.query(`
      UPDATE super_admin_config SET 
        twofa_enabled = false,
        twofa_secret = NULL,
        twofa_backup_codes = NULL,
        updated_at = NOW()
      WHERE id = 1
    `);

    res.json({
      success: true,
      message: '2FA dÃ©sactivÃ©'
    });
  } catch (error) {
    logger.error('2FA disable error:', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Erreur désactivation 2FA' });
  }
});

module.exports = router;
