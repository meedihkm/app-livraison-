const express = require("express");
const bcrypt = require("bcryptjs");
const router = express.Router();

const pool = require("../config/database");
const logger = require("../config/logger");
const { authenticateSuperAdmin } = require("../middleware/auth");
const { validate } = require("../middleware/validate");
const { superAdminLimiter } = require("../middleware/rateLimit");
const { logAudit, getAllAuditLogs } = require("../services/audit.service");
const { revokeAllOrgTokens } = require("../services/token.service");
const twofa = require("../services/twofa.service");

// GET /api/super-admin/test
router.get("/test", superAdminLimiter, authenticateSuperAdmin, (req, res) => {
  res.json({ success: true, message: "Super-admin OK" });
});

// GET /api/super-admin/stats
router.get("/stats", authenticateSuperAdmin, async (req, res) => {
  try {
    const orgs = await pool.query(
      "SELECT COUNT(*) as count FROM organizations",
    );
    const activeOrgs = await pool.query(
      "SELECT COUNT(*) as count FROM organizations WHERE active = true",
    );
    const users = await pool.query("SELECT COUNT(*) as count FROM users");
    const orders = await pool.query("SELECT COUNT(*) as count FROM orders");

    // Stats temps réel (aujourd'hui)
    const today = await pool.query(`
      SELECT 
        COUNT(*) as orders_today,
        COALESCE(SUM(total), 0) as revenue_today
      FROM orders 
      WHERE DATE(created_at) = CURRENT_DATE
    `);

    // Utilisateurs actifs (connectés dans les 24h)
    const activeUsers = await pool.query(`
      SELECT COUNT(DISTINCT user_id) as count
      FROM refresh_tokens
      WHERE created_at > NOW() - INTERVAL '24 hours'
    `);

    res.json({
      success: true,
      data: {
        totalOrganizations: parseInt(orgs.rows[0].count),
        activeOrganizations: parseInt(activeOrgs.rows[0].count),
        totalUsers: parseInt(users.rows[0].count),
        totalOrders: parseInt(orders.rows[0].count),
        ordersToday: parseInt(today.rows[0].orders_today),
        revenueToday: parseFloat(today.rows[0].revenue_today),
        activeUsers24h: parseInt(activeUsers.rows[0].count),
      },
    });
  } catch (error) {
    logger.error("Stats error:", { error: error.message, stack: error.stack });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/organizations
router.get("/organizations", authenticateSuperAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM organizations ORDER BY created_at DESC",
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// POST /api/super-admin/organizations
router.post(
  "/organizations",
  authenticateSuperAdmin,
  validate("createOrganization"),
  async (req, res) => {
    try {
      const { name, type, adminEmail, adminPassword, adminName, adminPhone } =
        req.body;

      const orgResult = await pool.query(
        "INSERT INTO organizations (name, type) VALUES ($1, $2) RETURNING *",
        [name, type || "restaurant"],
      );
      const org = orgResult.rows[0];

      const hashedPassword = await bcrypt.hash(adminPassword, 12);
      await pool.query(
        "INSERT INTO users (organization_id, email, password, name, phone, role) VALUES ($1, $2, $3, $4, $5, $6)",
        [
          org.id,
          adminEmail.trim().toLowerCase(),
          hashedPassword,
          adminName,
          adminPhone || "",
          "admin",
        ],
      );

      await logAudit("ORG_CREATED", null, org.id, { name, adminEmail }, req);

      res.json({ success: true, data: org });
    } catch (error) {
      logger.error("Create org error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur", details: error.message });
    }
  },
);

// DELETE /api/super-admin/organizations/:id
router.delete(
  "/organizations/:id",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      // Supprimer les refresh tokens des utilisateurs de cette org
      await pool.query(
        `
      DELETE FROM refresh_tokens WHERE user_id IN (
        SELECT id FROM users WHERE organization_id = $1
      )
    `,
        [req.params.id],
      );

      // Supprimer les audit logs
      await pool.query("DELETE FROM audit_logs WHERE organization_id = $1", [
        req.params.id,
      ]);

      // Supprimer les order_items
      await pool.query(
        `
      DELETE FROM order_items WHERE order_id IN (
        SELECT id FROM orders WHERE organization_id = $1
      )
    `,
        [req.params.id],
      );

      // Supprimer les livraisons
      await pool.query("DELETE FROM deliveries WHERE organization_id = $1", [
        req.params.id,
      ]);

      // Supprimer les commandes
      await pool.query("DELETE FROM orders WHERE organization_id = $1", [
        req.params.id,
      ]);

      // Supprimer les produits
      await pool.query("DELETE FROM products WHERE organization_id = $1", [
        req.params.id,
      ]);

      // Supprimer les utilisateurs
      await pool.query("DELETE FROM users WHERE organization_id = $1", [
        req.params.id,
      ]);

      // Supprimer l'organisation
      await pool.query("DELETE FROM organizations WHERE id = $1", [
        req.params.id,
      ]);

      res.json({ success: true });
    } catch (error) {
      logger.error("Delete org error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur: " + error.message });
    }
  },
);

// GET /api/super-admin/users
router.get("/users", authenticateSuperAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.email, u.name, u.phone, u.role, u.active, u.created_at, 
              o.name as organization_name, o.id as organization_id
       FROM users u 
       JOIN organizations o ON u.organization_id = o.id 
       ORDER BY u.created_at DESC`,
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// PATCH /api/super-admin/organizations/:id/status
router.patch(
  "/organizations/:id/status",
  authenticateSuperAdmin,
  validate("toggleOrgStatus"),
  async (req, res) => {
    try {
      const { active } = req.body;
      await pool.query("UPDATE organizations SET active = $1 WHERE id = $2", [
        active,
        req.params.id,
      ]);
      await pool.query(
        "UPDATE users SET active = $1 WHERE organization_id = $2",
        [active, req.params.id],
      );

      // RÃ©voquer tous les tokens si dÃ©sactivation
      if (!active) {
        await revokeAllOrgTokens(req.params.id);
      }

      await logAudit(
        "ORG_STATUS_CHANGED",
        null,
        req.params.id,
        { active },
        req,
      );

      res.json({ success: true });
    } catch (error) {
      logger.error("Toggle org status error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/audit-logs
router.get("/audit-logs", authenticateSuperAdmin, async (req, res) => {
  try {
    const { limit, offset } = req.query;
    const logs = await getAllAuditLogs({ limit, offset });
    res.json({ success: true, data: logs });
  } catch (error) {
    logger.error("Super admin audit logs error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// ============================================
// 2FA ENDPOINTS
// ============================================

// GET /api/super-admin/2fa/status - VÃ©rifier si 2FA est activÃ©
router.get("/2fa/status", authenticateSuperAdmin, async (req, res) => {
  try {
    if (!twofa.isAvailable()) {
      return res.json({
        success: true,
        data: {
          available: false,
          enabled: false,
          message: "2FA non disponible (otplib manquant)",
        },
      });
    }

    const result = await pool.query(
      "SELECT twofa_enabled FROM super_admin_config WHERE id = 1",
    );

    const enabled = result.rows.length > 0 && result.rows[0].twofa_enabled;

    res.json({
      success: true,
      data: { available: true, enabled },
    });
  } catch (error) {
    // Table n'existe peut-Ãªtre pas encore
    res.json({
      success: true,
      data: { available: twofa.isAvailable(), enabled: false },
    });
  }
});

// POST /api/super-admin/2fa/setup - Configurer 2FA
router.post(
  "/2fa/setup",
  superAdminLimiter,
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      if (!twofa.isAvailable()) {
        return res
          .status(503)
          .json({ error: "2FA non disponible - installer otplib" });
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
      await pool.query(
        `
      INSERT INTO super_admin_config (id, twofa_secret, twofa_backup_codes, twofa_enabled)
      VALUES (1, $1, $2, false)
      ON CONFLICT (id) DO UPDATE SET 
        twofa_secret = $1,
        twofa_backup_codes = $2,
        twofa_enabled = false,
        updated_at = NOW()
    `,
        [secret, hashedBackupCodes],
      );

      res.json({
        success: true,
        data: {
          secret,
          otpauthUrl,
          issuer,
          backupCodes, // Afficher UNE FOIS Ã  l'utilisateur
          message:
            "Scannez le QR code puis vÃ©rifiez avec un code pour activer le 2FA",
        },
      });
    } catch (error) {
      logger.error("2FA setup error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur configuration 2FA" });
    }
  },
);

// POST /api/super-admin/2fa/verify - VÃ©rifier et activer 2FA
router.post(
  "/2fa/verify",
  superAdminLimiter,
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { code } = req.body;

      if (!code) {
        return res.status(400).json({ error: "Code requis" });
      }

      // RÃ©cupÃ©rer le secret
      const result = await pool.query(
        "SELECT twofa_secret FROM super_admin_config WHERE id = 1",
      );

      if (result.rows.length === 0 || !result.rows[0].twofa_secret) {
        return res.status(400).json({
          error: "Configuration 2FA non trouvÃ©e. Lancez /2fa/setup d'abord",
        });
      }

      const secret = result.rows[0].twofa_secret;

      // VÃ©rifier le code
      if (!twofa.verifyToken(code, secret)) {
        return res.status(401).json({ error: "Code invalide" });
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
        message: "2FA activÃ© avec succÃ¨s",
      });
    } catch (error) {
      logger.error("2FA verify error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur vérification 2FA" });
    }
  },
);

// POST /api/super-admin/2fa/disable - DÃ©sactiver 2FA
router.post(
  "/2fa/disable",
  superAdminLimiter,
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { code } = req.body;

      if (!code) {
        return res
          .status(400)
          .json({ error: "Code 2FA requis pour dÃ©sactiver" });
      }

      // RÃ©cupÃ©rer le secret
      const result = await pool.query(
        "SELECT twofa_secret, twofa_backup_codes FROM super_admin_config WHERE id = 1",
      );

      if (result.rows.length === 0) {
        return res.status(400).json({ error: "2FA non configurÃ©" });
      }

      const { twofa_secret, twofa_backup_codes } = result.rows[0];

      // VÃ©rifier code TOTP ou backup code
      let valid = twofa.verifyToken(code, twofa_secret);

      if (!valid && twofa_backup_codes) {
        const backupResult = twofa.verifyBackupCode(code, twofa_backup_codes);
        valid = backupResult.valid;
      }

      if (!valid) {
        return res.status(401).json({ error: "Code invalide" });
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
        message: "2FA dÃ©sactivÃ©",
      });
    } catch (error) {
      logger.error("2FA disable error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur désactivation 2FA" });
    }
  },
);

module.exports = router;

// ============================================
// NOUVELLES FONCTIONNALITÉS SUPER ADMIN
// ============================================

// GET /api/super-admin/organizations/:id/growth
// Graphiques de croissance par organisation
router.get(
  "/organizations/:id/growth",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const days = parseInt(req.query.days) || 30;

      const growth = await pool.query(
        `
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as orders,
        COALESCE(SUM(total), 0) as revenue
      FROM orders
      WHERE organization_id = $1 
        AND created_at > NOW() - INTERVAL '${days} days'
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `,
        [id],
      );

      const users = await pool.query(
        `
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as new_users
      FROM users
      WHERE organization_id = $1 
        AND created_at > NOW() - INTERVAL '${days} days'
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `,
        [id],
      );

      res.json({
        success: true,
        data: {
          orders: growth.rows,
          users: users.rows,
        },
      });
    } catch (error) {
      logger.error("Growth stats error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/audit-logs/advanced
// Logs d'audit avec filtres avancés
router.get("/audit-logs/advanced", authenticateSuperAdmin, async (req, res) => {
  try {
    const {
      action,
      userId,
      organizationId,
      dateFrom,
      dateTo,
      limit = 100,
      offset = 0,
    } = req.query;

    let query = "SELECT * FROM audit_logs WHERE 1=1";
    const params = [];
    let paramCount = 0;

    if (action) {
      paramCount++;
      query += ` AND action = $${paramCount}`;
      params.push(action);
    }

    if (userId) {
      paramCount++;
      query += ` AND performed_by = $${paramCount}`;
      params.push(userId);
    }

    if (organizationId) {
      paramCount++;
      query += ` AND organization_id = $${paramCount}`;
      params.push(organizationId);
    }

    if (dateFrom) {
      paramCount++;
      query += ` AND created_at >= $${paramCount}`;
      params.push(dateFrom);
    }

    if (dateTo) {
      paramCount++;
      query += ` AND created_at <= $${paramCount}`;
      params.push(dateTo);
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: result.rows,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
      },
    });
  } catch (error) {
    logger.error("Advanced audit logs error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/sessions
// Voir toutes les sessions actives
router.get("/sessions", authenticateSuperAdmin, async (req, res) => {
  try {
    const sessions = await pool.query(`
      SELECT 
        rt.id,
        rt.user_id,
        rt.created_at,
        rt.expires_at,
        u.email,
        u.name,
        u.role,
        o.name as organization_name
      FROM refresh_tokens rt
      JOIN users u ON rt.user_id = u.id
      JOIN organizations o ON u.organization_id = o.id
      WHERE rt.expires_at > NOW()
      ORDER BY rt.created_at DESC
    `);

    res.json({
      success: true,
      data: sessions.rows,
    });
  } catch (error) {
    logger.error("Sessions error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// DELETE /api/super-admin/sessions/:id
// Révoquer une session
router.delete("/sessions/:id", authenticateSuperAdmin, async (req, res) => {
  try {
    await pool.query("DELETE FROM refresh_tokens WHERE id = $1", [
      req.params.id,
    ]);
    res.json({ success: true, message: "Session révoquée" });
  } catch (error) {
    logger.error("Revoke session error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/failed-logins
// Tentatives de connexion échouées
router.get("/failed-logins", authenticateSuperAdmin, async (req, res) => {
  try {
    const { hours = 24 } = req.query;

    const failed = await pool.query(`
      SELECT 
        details->>'email' as email,
        details->>'ip' as ip,
        COUNT(*) as attempts,
        MAX(created_at) as last_attempt
      FROM audit_logs
      WHERE action = 'LOGIN_FAILED'
        AND created_at > NOW() - INTERVAL '${hours} hours'
      GROUP BY details->>'email', details->>'ip'
      HAVING COUNT(*) >= 3
      ORDER BY attempts DESC, last_attempt DESC
    `);

    res.json({
      success: true,
      data: failed.rows,
    });
  } catch (error) {
    logger.error("Failed logins error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// POST /api/super-admin/backup
// Déclencher un backup manuel
router.post("/backup", authenticateSuperAdmin, async (req, res) => {
  try {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `awid_backup_${timestamp}.sql`;

    // Commande pg_dump (nécessite pg_dump installé)
    const { exec } = require("child_process");
    const backupPath = `/tmp/${filename}`;

    const dbUrl = process.env.DATABASE_URL;
    const command = `pg_dump ${dbUrl} > ${backupPath}`;

    exec(command, (error, stdout, stderr) => {
      if (error) {
        logger.error("Backup error:", { error: error.message, stderr });
        return res
          .status(500)
          .json({ error: "Erreur backup", details: stderr });
      }

      res.json({
        success: true,
        message: "Backup créé",
        filename,
        path: backupPath,
      });
    });
  } catch (error) {
    logger.error("Backup error:", { error: error.message, stack: error.stack });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// PATCH /api/super-admin/organizations/:id
// Modifier une organisation
router.patch("/organizations/:id", authenticateSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, type, kitchenMode } = req.body;

    const updates = [];
    const params = [];
    let paramCount = 0;

    if (name) {
      paramCount++;
      updates.push(`name = $${paramCount}`);
      params.push(name);
    }

    if (type) {
      paramCount++;
      updates.push(`type = $${paramCount}`);
      params.push(type);
    }

    if (kitchenMode !== undefined) {
      paramCount++;
      updates.push(`kitchen_mode = $${paramCount}`);
      params.push(kitchenMode);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: "Aucune modification" });
    }

    paramCount++;
    params.push(id);

    const query = `UPDATE organizations SET ${updates.join(", ")}, updated_at = NOW() WHERE id = $${paramCount} RETURNING *`;
    const result = await pool.query(query, params);

    await logAudit("ORG_UPDATED", null, id, { name, type, kitchenMode }, req);

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error("Update org error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/error-logs
// Logs d'erreurs de toutes les organisations
router.get("/error-logs", authenticateSuperAdmin, async (req, res) => {
  try {
    const { limit = 100, offset = 0 } = req.query;

    // Récupérer les erreurs depuis audit_logs
    const errors = await pool.query(
      `
      SELECT 
        al.*,
        o.name as organization_name,
        u.email as user_email
      FROM audit_logs al
      LEFT JOIN organizations o ON al.organization_id = o.id
      LEFT JOIN users u ON al.performed_by = u.id
      WHERE al.action LIKE '%ERROR%' OR al.action LIKE '%FAILED%'
      ORDER BY al.created_at DESC
      LIMIT $1 OFFSET $2
    `,
      [limit, offset],
    );

    res.json({
      success: true,
      data: errors.rows,
    });
  } catch (error) {
    logger.error("Error logs error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

module.exports = router;

// ============================================
// NOUVELLES FONCTIONNALITÉS SUPER ADMIN
// ============================================

// GET /api/super-admin/organizations/:id/users
// Liste détaillée des utilisateurs d'une organisation
router.get(
  "/organizations/:id/users",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;

      const users = await pool.query(
        `
      SELECT 
        u.id,
        u.email,
        u.name,
        u.phone,
        u.role,
        u.active,
        u.created_at,
        u.last_login,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT d.id) as total_deliveries,
        COALESCE(SUM(o.total), 0) as total_revenue
      FROM users u
      LEFT JOIN orders o ON u.id = o.customer_id
      LEFT JOIN deliveries d ON u.id = d.deliverer_id
      WHERE u.organization_id = $1
      GROUP BY u.id, u.email, u.name, u.phone, u.role, u.active, u.created_at, u.last_login
      ORDER BY u.created_at DESC
    `,
        [id],
      );

      res.json({
        success: true,
        data: users.rows,
      });
    } catch (error) {
      logger.error("Get org users error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/organizations/:id/stats
// Statistiques détaillées d'une organisation
router.get(
  "/organizations/:id/stats",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { days = 30 } = req.query;

      // Stats générales
      const stats = await pool.query(
        `
      SELECT 
        COUNT(DISTINCT u.id) as total_users,
        COUNT(DISTINCT CASE WHEN u.role = 'customer' THEN u.id END) as customers,
        COUNT(DISTINCT CASE WHEN u.role = 'deliverer' THEN u.id END) as deliverers,
        COUNT(DISTINCT CASE WHEN u.role = 'admin' THEN u.id END) as admins,
        COUNT(DISTINCT o.id) as total_orders,
        COALESCE(SUM(o.total), 0) as total_revenue,
        COUNT(DISTINCT d.id) as total_deliveries,
        COUNT(DISTINCT p.id) as total_products
      FROM organizations org
      LEFT JOIN users u ON org.id = u.organization_id
      LEFT JOIN orders o ON org.id = o.organization_id
      LEFT JOIN deliveries d ON org.id = d.organization_id
      LEFT JOIN products p ON org.id = p.organization_id
      WHERE org.id = $1
    `,
        [id],
      );

      // Stats période récente
      const recentStats = await pool.query(
        `
      SELECT 
        COUNT(DISTINCT o.id) as orders_period,
        COALESCE(SUM(o.total), 0) as revenue_period,
        COUNT(DISTINCT d.id) as deliveries_period,
        COUNT(DISTINCT o.customer_id) as active_customers
      FROM orders o
      LEFT JOIN deliveries d ON o.id = d.order_id
      WHERE o.organization_id = $1 
        AND o.created_at > NOW() - INTERVAL '${days} days'
    `,
        [id],
      );

      // Top clients
      const topCustomers = await pool.query(
        `
      SELECT 
        u.id,
        u.name,
        u.email,
        COUNT(o.id) as order_count,
        COALESCE(SUM(o.total), 0) as total_spent
      FROM users u
      JOIN orders o ON u.id = o.customer_id
      WHERE u.organization_id = $1
      GROUP BY u.id, u.name, u.email
      ORDER BY total_spent DESC
      LIMIT 10
    `,
        [id],
      );

      res.json({
        success: true,
        data: {
          general: stats.rows[0],
          recent: recentStats.rows[0],
          topCustomers: topCustomers.rows,
        },
      });
    } catch (error) {
      logger.error("Get org stats error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// PATCH /api/super-admin/users/:id/toggle
// Activer/désactiver un utilisateur
router.patch("/users/:id/toggle", authenticateSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { active } = req.body;

    await pool.query("UPDATE users SET active = $1 WHERE id = $2", [
      active,
      id,
    ]);

    // Révoquer les tokens si désactivation
    if (!active) {
      await pool.query("DELETE FROM refresh_tokens WHERE user_id = $1", [id]);
    }

    await logAudit("USER_TOGGLED", null, null, { userId: id, active }, req);

    res.json({ success: true });
  } catch (error) {
    logger.error("Toggle user error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// POST /api/super-admin/users/:id/reset-password
// Réinitialiser le mot de passe d'un utilisateur
router.post(
  "/users/:id/reset-password",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { newPassword } = req.body;

      if (!newPassword || newPassword.length < 6) {
        return res
          .status(400)
          .json({ error: "Mot de passe trop court (min 6)" });
      }

      const hashedPassword = await bcrypt.hash(newPassword, 12);
      await pool.query("UPDATE users SET password = $1 WHERE id = $2", [
        hashedPassword,
        id,
      ]);

      // Révoquer tous les tokens
      await pool.query("DELETE FROM refresh_tokens WHERE user_id = $1", [id]);

      await logAudit("PASSWORD_RESET", null, null, { userId: id }, req);

      res.json({ success: true, message: "Mot de passe réinitialisé" });
    } catch (error) {
      logger.error("Reset password error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/activity
// Logs d'activité récents (toutes organisations)
router.get("/activity", authenticateSuperAdmin, async (req, res) => {
  try {
    const { limit = 50 } = req.query;

    const activity = await pool.query(
      `
      SELECT 
        al.*,
        o.name as organization_name,
        u.name as user_name,
        u.email as user_email
      FROM audit_logs al
      LEFT JOIN organizations o ON al.organization_id = o.id
      LEFT JOIN users u ON al.performed_by = u.id
      ORDER BY al.created_at DESC
      LIMIT $1
    `,
      [limit],
    );

    res.json({
      success: true,
      data: activity.rows,
    });
  } catch (error) {
    logger.error("Activity logs error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/alerts
// Alertes système (erreurs critiques, tentatives suspectes)
router.get("/alerts", authenticateSuperAdmin, async (req, res) => {
  try {
    const alerts = [];

    // Tentatives de connexion échouées (≥5 en 1h)
    const failedLogins = await pool.query(`
      SELECT 
        details->>'email' as email,
        details->>'ip' as ip,
        COUNT(*) as attempts,
        MAX(created_at) as last_attempt
      FROM audit_logs
      WHERE action = 'LOGIN_FAILED'
        AND created_at > NOW() - INTERVAL '1 hour'
      GROUP BY details->>'email', details->>'ip'
      HAVING COUNT(*) >= 5
    `);

    failedLogins.rows.forEach((row) => {
      alerts.push({
        type: "security",
        severity: "high",
        message: `${row.attempts} tentatives de connexion échouées pour ${row.email} depuis ${row.ip}`,
        timestamp: row.last_attempt,
      });
    });

    // Organisations inactives (aucune commande depuis 7 jours)
    const inactiveOrgs = await pool.query(`
      SELECT 
        o.id,
        o.name,
        MAX(ord.created_at) as last_order
      FROM organizations o
      LEFT JOIN orders ord ON o.id = ord.organization_id
      WHERE o.active = true
      GROUP BY o.id, o.name
      HAVING MAX(ord.created_at) < NOW() - INTERVAL '7 days' OR MAX(ord.created_at) IS NULL
    `);

    inactiveOrgs.rows.forEach((row) => {
      alerts.push({
        type: "business",
        severity: "medium",
        message: `Organisation "${row.name}" inactive depuis ${row.last_order ? "7+ jours" : "toujours"}`,
        timestamp: row.last_order || new Date(),
      });
    });

    // Erreurs récentes (dernière heure)
    const recentErrors = await pool.query(`
      SELECT COUNT(*) as count
      FROM audit_logs
      WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
        AND created_at > NOW() - INTERVAL '1 hour'
    `);

    if (parseInt(recentErrors.rows[0].count) > 10) {
      alerts.push({
        type: "technical",
        severity: "high",
        message: `${recentErrors.rows[0].count} erreurs détectées dans la dernière heure`,
        timestamp: new Date(),
      });
    }

    res.json({
      success: true,
      data: alerts.sort(
        (a, b) => new Date(b.timestamp) - new Date(a.timestamp),
      ),
    });
  } catch (error) {
    logger.error("Alerts error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/export/organizations
// Export CSV des organisations
router.get(
  "/export/organizations",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const orgs = await pool.query(`
      SELECT 
        o.id,
        o.name,
        o.type,
        o.active,
        o.created_at,
        COUNT(DISTINCT u.id) as users_count,
        COUNT(DISTINCT ord.id) as orders_count,
        COALESCE(SUM(ord.total), 0) as total_revenue
      FROM organizations o
      LEFT JOIN users u ON o.id = u.organization_id
      LEFT JOIN orders ord ON o.id = ord.organization_id
      GROUP BY o.id, o.name, o.type, o.active, o.created_at
      ORDER BY o.created_at DESC
    `);

      // Générer CSV
      const csv = [
        "ID,Nom,Type,Actif,Date création,Utilisateurs,Commandes,CA total",
        ...orgs.rows.map(
          (row) =>
            `${row.id},"${row.name}",${row.type},${row.active},${row.created_at},${row.users_count},${row.orders_count},${row.total_revenue}`,
        ),
      ].join("\n");

      res.setHeader("Content-Type", "text/csv");
      res.setHeader(
        "Content-Disposition",
        "attachment; filename=organizations.csv",
      );
      res.send(csv);
    } catch (error) {
      logger.error("Export orgs error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);
