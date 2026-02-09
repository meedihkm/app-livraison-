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

// ============================================
// PHASE 1 - ORGANISATIONS DÉTAILLÉES
// ============================================

// GET /api/super-admin/organizations/:id/details
// Vue complète d'une organisation avec toutes les stats
router.get(
  "/organizations/:id/details",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;

      // Informations générales de l'organisation
      const orgResult = await pool.query(
        `SELECT id, name, type, active, kitchen_mode, created_at 
       FROM organizations 
       WHERE id = $1`,
        [id],
      );

      if (orgResult.rows.length === 0) {
        return res.status(404).json({ error: "Organisation non trouvée" });
      }

      const org = orgResult.rows[0];

      // Dernière activité (dernière commande)
      const lastActivityResult = await pool.query(
        `SELECT MAX(created_at) as last_activity 
       FROM orders 
       WHERE organization_id = $1`,
        [id],
      );
      org.last_activity = lastActivityResult.rows[0].last_activity;

      // Statistiques détaillées
      const statsResult = await pool.query(
        `SELECT 
        COUNT(DISTINCT u.id) as total_users,
        COUNT(DISTINCT CASE WHEN u.role = 'customer' THEN u.id END) as customers,
        COUNT(DISTINCT CASE WHEN u.role = 'deliverer' THEN u.id END) as deliverers,
        COUNT(DISTINCT CASE WHEN u.role = 'admin' THEN u.id END) as admins,
        COUNT(DISTINCT CASE WHEN u.role = 'kitchen' THEN u.id END) as kitchen,
        COUNT(DISTINCT o.id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'pending' THEN o.id END) as orders_pending,
        COUNT(DISTINCT CASE WHEN o.status = 'delivered' THEN o.id END) as orders_delivered,
        COUNT(DISTINCT CASE WHEN o.status = 'cancelled' THEN o.id END) as orders_cancelled,
        COALESCE(SUM(o.total), 0) as total_revenue,
        COUNT(DISTINCT p.id) as total_products
      FROM organizations org
      LEFT JOIN users u ON org.id = u.organization_id
      LEFT JOIN orders o ON org.id = o.organization_id
      LEFT JOIN products p ON org.id = p.organization_id
      WHERE org.id = $1
      GROUP BY org.id`,
        [id],
      );

      const stats = statsResult.rows[0];

      // Chiffre d'affaires aujourd'hui
      const todayRevenueResult = await pool.query(
        `SELECT COALESCE(SUM(total), 0) as revenue_today
       FROM orders
       WHERE organization_id = $1 
         AND DATE(created_at) = CURRENT_DATE`,
        [id],
      );
      stats.revenue_today = parseFloat(
        todayRevenueResult.rows[0].revenue_today,
      );

      // Chiffre d'affaires ce mois
      const monthRevenueResult = await pool.query(
        `SELECT COALESCE(SUM(total), 0) as revenue_month
       FROM orders
       WHERE organization_id = $1 
         AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE)`,
        [id],
      );
      stats.revenue_month = parseFloat(
        monthRevenueResult.rows[0].revenue_month,
      );

      // Graphiques de croissance (30 derniers jours)
      const growthOrders = await pool.query(
        `SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
       FROM orders
       WHERE organization_id = $1 
         AND created_at > NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
        [id],
      );

      const growthRevenue = await pool.query(
        `SELECT 
        DATE(created_at) as date,
        COALESCE(SUM(total), 0) as amount
       FROM orders
       WHERE organization_id = $1 
         AND created_at > NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
        [id],
      );

      const growthUsers = await pool.query(
        `SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
       FROM users
       WHERE organization_id = $1 
         AND created_at > NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
        [id],
      );

      // Top 10 clients
      const topCustomers = await pool.query(
        `SELECT 
        u.id,
        u.name,
        u.email,
        COUNT(o.id) as order_count,
        COALESCE(SUM(o.total), 0) as total_spent
       FROM users u
       JOIN orders o ON u.id = o.customer_id
       WHERE u.organization_id = $1 AND u.role = 'customer'
       GROUP BY u.id, u.name, u.email
       ORDER BY total_spent DESC
       LIMIT 10`,
        [id],
      );

      res.json({
        success: true,
        data: {
          general: org,
          stats: {
            total_users: parseInt(stats.total_users),
            customers: parseInt(stats.customers),
            deliverers: parseInt(stats.deliverers),
            admins: parseInt(stats.admins),
            kitchen: parseInt(stats.kitchen),
            total_orders: parseInt(stats.total_orders),
            orders_pending: parseInt(stats.orders_pending),
            orders_delivered: parseInt(stats.orders_delivered),
            orders_cancelled: parseInt(stats.orders_cancelled),
            total_revenue: parseFloat(stats.total_revenue),
            revenue_today: stats.revenue_today,
            revenue_month: stats.revenue_month,
            total_products: parseInt(stats.total_products),
          },
          growth: {
            orders: growthOrders.rows,
            revenue: growthRevenue.rows,
            users: growthUsers.rows,
          },
          top_customers: topCustomers.rows,
        },
      });
    } catch (error) {
      logger.error("Get org details error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/organizations/:id/users/detailed
// Liste détaillée des utilisateurs avec stats complètes
router.get(
  "/organizations/:id/users/detailed",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { limit = 50, offset = 0 } = req.query;

      // Count total
      const countResult = await pool.query(
        `SELECT COUNT(*) as total 
       FROM users 
       WHERE organization_id = $1`,
        [id],
      );
      const total = parseInt(countResult.rows[0].total);

      // Liste des utilisateurs avec stats
      const usersResult = await pool.query(
        `SELECT 
        u.id,
        u.name,
        u.email,
        u.phone,
        u.role,
        u.active,
        u.created_at,
        u.updated_at as last_login,
        COUNT(DISTINCT CASE WHEN u.role = 'customer' THEN o.id END) as order_count,
        COUNT(DISTINCT CASE WHEN u.role = 'deliverer' THEN d.id END) as delivery_count,
        COALESCE(SUM(CASE WHEN u.role = 'customer' THEN o.total ELSE 0 END), 0) as total_revenue,
        MAX(CASE WHEN u.role = 'customer' THEN o.created_at END) as last_order_date
       FROM users u
       LEFT JOIN orders o ON u.id = o.customer_id
       LEFT JOIN deliveries d ON u.id = d.deliverer_id
       WHERE u.organization_id = $1
       GROUP BY u.id, u.name, u.email, u.phone, u.role, u.active, u.created_at, u.updated_at
       ORDER BY u.created_at DESC
       LIMIT $2 OFFSET $3`,
        [id, limit, offset],
      );

      res.json({
        success: true,
        data: usersResult.rows.map((user) => ({
          ...user,
          order_count: parseInt(user.order_count),
          delivery_count: parseInt(user.delivery_count),
          total_revenue: parseFloat(user.total_revenue),
        })),
        total,
        pagination: {
          limit: parseInt(limit),
          offset: parseInt(offset),
          pages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      logger.error("Get org users detailed error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// ============================================
// PHASE 1 - SÉCURITÉ DÉTAILLÉE
// ============================================

// GET /api/super-admin/security/failed-logins/detailed
// Tentatives de connexion échouées avec tous les détails
router.get(
  "/security/failed-logins/detailed",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { limit = 100, offset = 0, hours = 24 } = req.query;

      // Count total
      const countResult = await pool.query(
        `SELECT COUNT(*) as total
       FROM audit_logs
       WHERE action = 'LOGIN_FAILED'
         AND created_at > NOW() - INTERVAL '${hours} hours'`,
      );
      const total = parseInt(countResult.rows[0].total);

      // Détails groupés par email et IP
      const failedLogins = await pool.query(
        `SELECT 
        details->>'email' as email,
        details->>'ip' as ip,
        COUNT(*) as attempts,
        MIN(created_at) as first_attempt,
        MAX(created_at) as last_attempt,
        ARRAY_AGG(DISTINCT details->>'reason') as reasons,
        MAX(user_agent) as user_agent
       FROM audit_logs
       WHERE action = 'LOGIN_FAILED'
         AND created_at > NOW() - INTERVAL '${hours} hours'
       GROUP BY details->>'email', details->>'ip'
       ORDER BY last_attempt DESC
       LIMIT $1 OFFSET $2`,
        [limit, offset],
      );

      res.json({
        success: true,
        data: failedLogins.rows.map((row) => ({
          email: row.email,
          ip: row.ip,
          attempts: parseInt(row.attempts),
          first_attempt: row.first_attempt,
          last_attempt: row.last_attempt,
          reasons: row.reasons,
          user_agent: row.user_agent,
        })),
        total,
        pagination: {
          limit: parseInt(limit),
          offset: parseInt(offset),
          pages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      logger.error("Get failed logins detailed error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/super-admin/security/block-ip
// Bloquer une adresse IP
router.post("/security/block-ip", authenticateSuperAdmin, async (req, res) => {
  try {
    const { ip, duration, reason } = req.body;

    if (!ip) {
      return res.status(400).json({ error: "Adresse IP requise" });
    }

    let blockedUntil = null;
    let permanent = false;

    if (duration === "permanent") {
      permanent = true;
    } else if (duration === "temporary") {
      // Bloquer pour 24 heures
      blockedUntil = new Date(Date.now() + 24 * 60 * 60 * 1000);
    }

    await pool.query(
      `INSERT INTO blocked_ips (ip_address, reason, blocked_until, permanent, created_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        ip,
        reason || "Tentatives de connexion suspectes",
        blockedUntil,
        permanent,
        req.user?.id,
      ],
    );

    await logAudit(
      "IP_BLOCKED",
      req.user?.id,
      null,
      { ip, duration, reason },
      req,
    );

    res.json({
      success: true,
      message: `IP ${ip} bloquée ${permanent ? "définitivement" : "pour 24h"}`,
    });
  } catch (error) {
    logger.error("Block IP error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/security/blocked-ips
// Liste des IPs bloquées
router.get(
  "/security/blocked-ips",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const blockedIps = await pool.query(
        `SELECT 
        bi.*,
        u.name as blocked_by_name,
        u.email as blocked_by_email
       FROM blocked_ips bi
       LEFT JOIN users u ON bi.created_by = u.id
       WHERE bi.permanent = true 
          OR bi.blocked_until > NOW()
       ORDER BY bi.created_at DESC`,
      );

      res.json({
        success: true,
        data: blockedIps.rows,
      });
    } catch (error) {
      logger.error("Get blocked IPs error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// DELETE /api/super-admin/security/unblock-ip/:ip
// Débloquer une adresse IP
router.delete(
  "/security/unblock-ip/:ip",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { ip } = req.params;

      await pool.query(`DELETE FROM blocked_ips WHERE ip_address = $1`, [ip]);

      await logAudit("IP_UNBLOCKED", req.user?.id, null, { ip }, req);

      res.json({
        success: true,
        message: `IP ${ip} débloquée`,
      });
    } catch (error) {
      logger.error("Unblock IP error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// DELETE /api/super-admin/security/purge-failed-logins
// Purger les anciennes tentatives échouées
router.delete(
  "/security/purge-failed-logins",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { older_than_days = 30 } = req.body;

      const result = await pool.query(
        `DELETE FROM audit_logs
       WHERE action = 'LOGIN_FAILED'
         AND created_at < NOW() - INTERVAL '${older_than_days} days'
       RETURNING id`,
      );

      await logAudit(
        "FAILED_LOGINS_PURGED",
        req.user?.id,
        null,
        {
          deleted_count: result.rowCount,
          older_than_days,
        },
        req,
      );

      res.json({
        success: true,
        message: `${result.rowCount} tentatives échouées supprimées`,
        deleted_count: result.rowCount,
      });
    } catch (error) {
      logger.error("Purge failed logins error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// ============================================
// PHASE 1 - LOGS DÉTAILLÉS
// ============================================

// GET /api/super-admin/logs/detailed
// Logs d'erreurs avec filtres avancés
router.get("/logs/detailed", authenticateSuperAdmin, async (req, res) => {
  try {
    const {
      date_from,
      date_to,
      organization_id,
      action_type,
      limit = 100,
      offset = 0,
    } = req.query;

    let whereConditions = [];
    let params = [];
    let paramIndex = 1;

    // Filtrer par type d'action (ERROR, FAILED, etc.)
    if (action_type) {
      whereConditions.push(`al.action LIKE $${paramIndex}`);
      params.push(`%${action_type}%`);
      paramIndex++;
    } else {
      // Par défaut, montrer les erreurs et échecs
      whereConditions.push(
        `(al.action LIKE '%ERROR%' OR al.action LIKE '%FAILED%')`,
      );
    }

    // Filtrer par date
    if (date_from) {
      whereConditions.push(`al.created_at >= $${paramIndex}`);
      params.push(date_from);
      paramIndex++;
    }

    if (date_to) {
      whereConditions.push(`al.created_at <= $${paramIndex}`);
      params.push(date_to);
      paramIndex++;
    }

    // Filtrer par organisation
    if (organization_id) {
      whereConditions.push(`al.organization_id = $${paramIndex}`);
      params.push(organization_id);
      paramIndex++;
    }

    const whereClause =
      whereConditions.length > 0
        ? `WHERE ${whereConditions.join(" AND ")}`
        : "";

    // Count total
    const countQuery = `SELECT COUNT(*) as total FROM audit_logs al ${whereClause}`;
    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Récupérer les logs
    const logsQuery = `
      SELECT 
        al.*,
        o.name as organization_name,
        u.name as user_name,
        u.email as user_email,
        u.role as user_role
      FROM audit_logs al
      LEFT JOIN organizations o ON al.organization_id = o.id
      LEFT JOIN users u ON al.user_id = u.id
      ${whereClause}
      ORDER BY al.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    params.push(parseInt(limit), parseInt(offset));

    const logsResult = await pool.query(logsQuery, params);

    res.json({
      success: true,
      data: logsResult.rows,
      total,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        pages: Math.ceil(total / limit),
      },
      filters: {
        date_from,
        date_to,
        organization_id,
        action_type,
      },
    });
  } catch (error) {
    logger.error("Get logs detailed error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// DELETE /api/super-admin/logs/purge
// Purger les anciens logs
router.delete("/logs/purge", authenticateSuperAdmin, async (req, res) => {
  try {
    const { older_than_days = 90, log_type = "error" } = req.body;

    let condition = "";
    if (log_type === "error") {
      condition = `AND (action LIKE '%ERROR%' OR action LIKE '%FAILED%')`;
    }

    const result = await pool.query(
      `DELETE FROM audit_logs
       WHERE created_at < NOW() - INTERVAL '${older_than_days} days'
       ${condition}
       RETURNING id`,
    );

    await logAudit(
      "LOGS_PURGED",
      req.user?.id,
      null,
      {
        deleted_count: result.rowCount,
        older_than_days,
        log_type,
      },
      req,
    );

    res.json({
      success: true,
      message: `${result.rowCount} logs supprimés`,
      deleted_count: result.rowCount,
    });
  } catch (error) {
    logger.error("Purge logs error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// ============================================
// PHASE 1 - ACTIVITÉ DÉTAILLÉE
// ============================================

// GET /api/super-admin/activity/detailed
// Logs d'activité avec filtres et statistiques
router.get("/activity/detailed", authenticateSuperAdmin, async (req, res) => {
  try {
    const {
      date_from,
      date_to,
      organization_id,
      user_id,
      action,
      limit = 100,
      offset = 0,
    } = req.query;

    let whereConditions = [];
    let params = [];
    let paramIndex = 1;

    // Exclure les erreurs et échecs (déjà dans l'onglet Logs)
    whereConditions.push(
      `al.action NOT LIKE '%ERROR%' AND al.action NOT LIKE '%FAILED%'`,
    );

    // Filtrer par date
    if (date_from) {
      whereConditions.push(`al.created_at >= $${paramIndex}`);
      params.push(date_from);
      paramIndex++;
    }

    if (date_to) {
      whereConditions.push(`al.created_at <= $${paramIndex}`);
      params.push(date_to);
      paramIndex++;
    }

    // Filtrer par organisation
    if (organization_id) {
      whereConditions.push(`al.organization_id = $${paramIndex}`);
      params.push(organization_id);
      paramIndex++;
    }

    // Filtrer par utilisateur
    if (user_id) {
      whereConditions.push(`al.user_id = $${paramIndex}`);
      params.push(user_id);
      paramIndex++;
    }

    // Filtrer par action
    if (action) {
      whereConditions.push(`al.action = $${paramIndex}`);
      params.push(action);
      paramIndex++;
    }

    const whereClause = `WHERE ${whereConditions.join(" AND ")}`;

    // Count total
    const countQuery = `SELECT COUNT(*) as total FROM audit_logs al ${whereClause}`;
    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Récupérer les activités
    const activityQuery = `
      SELECT 
        al.*,
        o.name as organization_name,
        u.name as user_name,
        u.email as user_email,
        u.role as user_role
      FROM audit_logs al
      LEFT JOIN organizations o ON al.organization_id = o.id
      LEFT JOIN users u ON al.user_id = u.id
      ${whereClause}
      ORDER BY al.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    params.push(parseInt(limit), parseInt(offset));

    const activityResult = await pool.query(activityQuery, params);

    // Statistiques
    const statsQuery = `
      SELECT 
        DATE_TRUNC('hour', al.created_at) as hour,
        COUNT(*) as count
      FROM audit_logs al
      ${whereClause}
      GROUP BY hour
      ORDER BY hour DESC
      LIMIT 24
    `;
    const statsResult = await pool.query(statsQuery, params.slice(0, -2));

    const orgStatsQuery = `
      SELECT 
        o.name as org_name,
        COUNT(*) as count
      FROM audit_logs al
      LEFT JOIN organizations o ON al.organization_id = o.id
      ${whereClause}
      GROUP BY o.name
      ORDER BY count DESC
      LIMIT 10
    `;
    const orgStatsResult = await pool.query(orgStatsQuery, params.slice(0, -2));

    const userStatsQuery = `
      SELECT 
        u.name as user_name,
        u.email as user_email,
        COUNT(*) as count
      FROM audit_logs al
      LEFT JOIN users u ON al.user_id = u.id
      ${whereClause}
      GROUP BY u.name, u.email
      ORDER BY count DESC
      LIMIT 10
    `;
    const userStatsResult = await pool.query(
      userStatsQuery,
      params.slice(0, -2),
    );

    res.json({
      success: true,
      data: activityResult.rows,
      total,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        pages: Math.ceil(total / limit),
      },
      stats: {
        actions_per_hour: statsResult.rows,
        actions_by_org: orgStatsResult.rows,
        most_active_users: userStatsResult.rows,
      },
    });
  } catch (error) {
    logger.error("Get activity detailed error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// ============================================
// PHASE 2 - EXPORT DE DONNÉES
// ============================================

// GET /api/super-admin/organizations/:id/export/csv
// Export CSV des utilisateurs d'une organisation
router.get(
  "/organizations/:id/export/csv",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;

      // Récupérer l'organisation
      const orgResult = await pool.query(
        "SELECT name FROM organizations WHERE id = $1",
        [id],
      );
      if (orgResult.rows.length === 0) {
        return res.status(404).json({ error: "Organisation non trouvée" });
      }
      const orgName = orgResult.rows[0].name;

      // Récupérer les utilisateurs avec stats
      const users = await pool.query(
        `SELECT 
          u.id,
          u.name,
          u.email,
          u.phone,
          u.role,
          u.active,
          u.created_at,
          COUNT(DISTINCT o.id) as total_orders,
          COALESCE(SUM(o.total), 0) as total_revenue
        FROM users u
        LEFT JOIN orders o ON u.id = o.customer_id
        WHERE u.organization_id = $1
        GROUP BY u.id, u.name, u.email, u.phone, u.role, u.active, u.created_at
        ORDER BY u.created_at DESC`,
        [id],
      );

      // Générer CSV
      const csv = [
        "ID,Nom,Email,Téléphone,Rôle,Actif,Date création,Commandes,CA total",
        ...users.rows.map(
          (row) =>
            `${row.id},"${row.name}","${row.email}","${row.phone || ""}",${row.role},${row.active},${row.created_at},${row.total_orders},${row.total_revenue}`,
        ),
      ].join("\n");

      res.setHeader("Content-Type", "text/csv; charset=utf-8");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="${orgName}_utilisateurs.csv"`,
      );
      res.send("\uFEFF" + csv); // BOM pour Excel
    } catch (error) {
      logger.error("Export org users CSV error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/organizations/:id/export/stats-csv
// Export CSV des statistiques d'une organisation
router.get(
  "/organizations/:id/export/stats-csv",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { days = 30 } = req.query;

      // Récupérer l'organisation
      const orgResult = await pool.query(
        "SELECT name FROM organizations WHERE id = $1",
        [id],
      );
      if (orgResult.rows.length === 0) {
        return res.status(404).json({ error: "Organisation non trouvée" });
      }
      const orgName = orgResult.rows[0].name;

      // Statistiques par jour
      const stats = await pool.query(
        `SELECT 
          DATE(created_at) as date,
          COUNT(*) as orders,
          COALESCE(SUM(total), 0) as revenue
        FROM orders
        WHERE organization_id = $1 
          AND created_at > NOW() - INTERVAL '${days} days'
        GROUP BY DATE(created_at)
        ORDER BY date ASC`,
        [id],
      );

      // Générer CSV
      const csv = [
        "Date,Commandes,Chiffre d'affaires",
        ...stats.rows.map((row) => `${row.date},${row.orders},${row.revenue}`),
      ].join("\n");

      res.setHeader("Content-Type", "text/csv; charset=utf-8");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="${orgName}_stats_${days}j.csv"`,
      );
      res.send("\uFEFF" + csv);
    } catch (error) {
      logger.error("Export org stats CSV error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// ============================================
// PHASE 2 - RECHERCHE GLOBALE
// ============================================

// GET /api/super-admin/search
// Recherche globale dans toutes les organisations
router.get("/search", authenticateSuperAdmin, async (req, res) => {
  try {
    const { q, type = "all", limit = 50 } = req.query;

    if (!q || q.length < 2) {
      return res
        .status(400)
        .json({ error: "Requête trop courte (min 2 caractères)" });
    }

    const searchTerm = `%${q}%`;
    const results = {
      users: [],
      organizations: [],
      orders: [],
    };

    // Rechercher dans les utilisateurs
    if (type === "all" || type === "users") {
      const usersResult = await pool.query(
        `SELECT 
          u.id,
          u.name,
          u.email,
          u.phone,
          u.role,
          u.active,
          o.name as organization_name,
          o.id as organization_id
        FROM users u
        LEFT JOIN organizations o ON u.organization_id = o.id
        WHERE u.name ILIKE $1 
          OR u.email ILIKE $1 
          OR u.phone ILIKE $1
        ORDER BY u.name
        LIMIT $2`,
        [searchTerm, limit],
      );
      results.users = usersResult.rows;
    }

    // Rechercher dans les organisations
    if (type === "all" || type === "organizations") {
      const orgsResult = await pool.query(
        `SELECT 
          id,
          name,
          type,
          active,
          created_at
        FROM organizations
        WHERE name ILIKE $1 OR type ILIKE $1
        ORDER BY name
        LIMIT $2`,
        [searchTerm, limit],
      );
      results.organizations = orgsResult.rows;
    }

    // Rechercher dans les commandes (par ID)
    if (type === "all" || type === "orders") {
      const ordersResult = await pool.query(
        `SELECT 
          o.id,
          o.total,
          o.status,
          o.created_at,
          org.name as organization_name,
          u.name as customer_name,
          u.email as customer_email
        FROM orders o
        LEFT JOIN organizations org ON o.organization_id = org.id
        LEFT JOIN users u ON o.customer_id = u.id
        WHERE CAST(o.id AS TEXT) ILIKE $1
        ORDER BY o.created_at DESC
        LIMIT $2`,
        [searchTerm, limit],
      );
      results.orders = ordersResult.rows;
    }

    res.json({
      success: true,
      query: q,
      data: results,
      total:
        results.users.length +
        results.organizations.length +
        results.orders.length,
    });
  } catch (error) {
    logger.error("Global search error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// ============================================
// PHASE 2 - STATISTIQUES GLOBALES AVANCÉES
// ============================================

// GET /api/super-admin/stats/advanced
// Statistiques avancées pour le dashboard
router.get("/stats/advanced", authenticateSuperAdmin, async (req, res) => {
  try {
    const { days = 30 } = req.query;

    // Évolution des commandes par jour
    const ordersEvolution = await pool.query(
      `SELECT 
        DATE(created_at) as date,
        COUNT(*) as count,
        COALESCE(SUM(total), 0) as revenue
      FROM orders
      WHERE created_at > NOW() - INTERVAL '${days} days'
      GROUP BY DATE(created_at)
      ORDER BY date ASC`,
    );

    // Évolution des utilisateurs par jour
    const usersEvolution = await pool.query(
      `SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
      FROM users
      WHERE created_at > NOW() - INTERVAL '${days} days'
      GROUP BY DATE(created_at)
      ORDER BY date ASC`,
    );

    // Top 10 organisations par CA
    const topOrgsByRevenue = await pool.query(
      `SELECT 
        o.id,
        o.name,
        COUNT(DISTINCT ord.id) as orders_count,
        COALESCE(SUM(ord.total), 0) as total_revenue
      FROM organizations o
      LEFT JOIN orders ord ON o.id = ord.organization_id
      WHERE ord.created_at > NOW() - INTERVAL '${days} days'
      GROUP BY o.id, o.name
      ORDER BY total_revenue DESC
      LIMIT 10`,
    );

    // Top 10 organisations par nombre de commandes
    const topOrgsByOrders = await pool.query(
      `SELECT 
        o.id,
        o.name,
        COUNT(DISTINCT ord.id) as orders_count
      FROM organizations o
      LEFT JOIN orders ord ON o.id = ord.organization_id
      WHERE ord.created_at > NOW() - INTERVAL '${days} days'
      GROUP BY o.id, o.name
      ORDER BY orders_count DESC
      LIMIT 10`,
    );

    // Répartition des utilisateurs par rôle
    const usersByRole = await pool.query(
      `SELECT 
        role,
        COUNT(*) as count
      FROM users
      GROUP BY role
      ORDER BY count DESC`,
    );

    // Répartition des commandes par statut
    const ordersByStatus = await pool.query(
      `SELECT 
        status,
        COUNT(*) as count,
        COALESCE(SUM(total), 0) as revenue
      FROM orders
      WHERE created_at > NOW() - INTERVAL '${days} days'
      GROUP BY status
      ORDER BY count DESC`,
    );

    // Taux de croissance
    const previousPeriodOrders = await pool.query(
      `SELECT COUNT(*) as count
      FROM orders
      WHERE created_at BETWEEN NOW() - INTERVAL '${days * 2} days' AND NOW() - INTERVAL '${days} days'`,
    );

    const currentPeriodOrders = await pool.query(
      `SELECT COUNT(*) as count
      FROM orders
      WHERE created_at > NOW() - INTERVAL '${days} days'`,
    );

    const previousCount = parseInt(previousPeriodOrders.rows[0].count);
    const currentCount = parseInt(currentPeriodOrders.rows[0].count);
    const growthRate =
      previousCount > 0
        ? ((currentCount - previousCount) / previousCount) * 100
        : 0;

    res.json({
      success: true,
      data: {
        orders_evolution: ordersEvolution.rows,
        users_evolution: usersEvolution.rows,
        top_orgs_by_revenue: topOrgsByRevenue.rows,
        top_orgs_by_orders: topOrgsByOrders.rows,
        users_by_role: usersByRole.rows,
        orders_by_status: ordersByStatus.rows,
        growth_rate: growthRate.toFixed(2),
        period_days: days,
      },
    });
  } catch (error) {
    logger.error("Advanced stats error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// ============================================
// PHASE 3 - GESTION AVANCÉE DES ORGANISATIONS
// ============================================

// POST /api/super-admin/organizations/:id/duplicate
// Dupliquer une organisation avec ses paramètres
router.post(
  "/organizations/:id/duplicate",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { newName, copyUsers = false, copyProducts = false } = req.body;

      if (!newName) {
        return res.status(400).json({ error: "Nom requis" });
      }

      // Récupérer l'organisation source
      const orgResult = await pool.query(
        "SELECT * FROM organizations WHERE id = $1",
        [id],
      );

      if (orgResult.rows.length === 0) {
        return res.status(404).json({ error: "Organisation non trouvée" });
      }

      const sourceOrg = orgResult.rows[0];

      // Créer la nouvelle organisation
      const newOrgResult = await pool.query(
        `INSERT INTO organizations (name, type, kitchen_mode, active)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [newName, sourceOrg.type, sourceOrg.kitchen_mode, true],
      );

      const newOrg = newOrgResult.rows[0];

      // Copier les produits si demandé
      if (copyProducts) {
        await pool.query(
          `INSERT INTO products (organization_id, name, price, description, category, active)
           SELECT $1, name, price, description, category, active
           FROM products
           WHERE organization_id = $2`,
          [newOrg.id, id],
        );
      }

      // Copier les utilisateurs si demandé (sans les mots de passe)
      if (copyUsers) {
        await pool.query(
          `INSERT INTO users (organization_id, name, email, phone, role, active)
           SELECT $1, name, email || '_copy', phone, role, false
           FROM users
           WHERE organization_id = $2 AND role != 'admin'`,
          [newOrg.id, id],
        );
      }

      await logAudit(
        "ORG_DUPLICATED",
        req.user?.id,
        newOrg.id,
        {
          source_org_id: id,
          source_org_name: sourceOrg.name,
          new_org_name: newName,
          copied_users: copyUsers,
          copied_products: copyProducts,
        },
        req,
      );

      res.json({
        success: true,
        message: "Organisation dupliquée avec succès",
        data: newOrg,
      });
    } catch (error) {
      logger.error("Duplicate org error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/super-admin/organizations/:id/archive
// Archiver une organisation (désactiver sans supprimer)
router.post(
  "/organizations/:id/archive",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { reason } = req.body;

      // Désactiver l'organisation
      await pool.query(
        "UPDATE organizations SET active = false WHERE id = $1",
        [id],
      );

      // Désactiver tous les utilisateurs
      await pool.query(
        "UPDATE users SET active = false WHERE organization_id = $1",
        [id],
      );

      // Révoquer tous les tokens
      await pool.query(
        `DELETE FROM refresh_tokens 
         WHERE user_id IN (SELECT id FROM users WHERE organization_id = $1)`,
        [id],
      );

      await logAudit(
        "ORG_ARCHIVED",
        req.user?.id,
        id,
        { reason: reason || "Non spécifiée" },
        req,
      );

      res.json({
        success: true,
        message: "Organisation archivée",
      });
    } catch (error) {
      logger.error("Archive org error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/super-admin/organizations/:id/restore
// Restaurer une organisation archivée
router.post(
  "/organizations/:id/restore",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;

      // Réactiver l'organisation
      await pool.query("UPDATE organizations SET active = true WHERE id = $1", [
        id,
      ]);

      // Réactiver les utilisateurs admin
      await pool.query(
        "UPDATE users SET active = true WHERE organization_id = $1 AND role = 'admin'",
        [id],
      );

      await logAudit("ORG_RESTORED", req.user?.id, id, {}, req);

      res.json({
        success: true,
        message: "Organisation restaurée",
      });
    } catch (error) {
      logger.error("Restore org error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/super-admin/users/:userId/transfer
// Transférer un utilisateur vers une autre organisation
router.post(
  "/users/:userId/transfer",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { targetOrgId } = req.body;

      if (!targetOrgId) {
        return res.status(400).json({ error: "Organisation cible requise" });
      }

      // Vérifier que l'utilisateur existe
      const userResult = await pool.query("SELECT * FROM users WHERE id = $1", [
        userId,
      ]);

      if (userResult.rows.length === 0) {
        return res.status(404).json({ error: "Utilisateur non trouvé" });
      }

      const user = userResult.rows[0];

      // Vérifier que l'organisation cible existe
      const orgResult = await pool.query(
        "SELECT * FROM organizations WHERE id = $1",
        [targetOrgId],
      );

      if (orgResult.rows.length === 0) {
        return res
          .status(404)
          .json({ error: "Organisation cible non trouvée" });
      }

      // Transférer l'utilisateur
      await pool.query("UPDATE users SET organization_id = $1 WHERE id = $2", [
        targetOrgId,
        userId,
      ]);

      // Révoquer les tokens
      await pool.query("DELETE FROM refresh_tokens WHERE user_id = $1", [
        userId,
      ]);

      await logAudit(
        "USER_TRANSFERRED",
        req.user?.id,
        targetOrgId,
        {
          user_id: userId,
          user_email: user.email,
          from_org_id: user.organization_id,
          to_org_id: targetOrgId,
        },
        req,
      );

      res.json({
        success: true,
        message: "Utilisateur transféré",
      });
    } catch (error) {
      logger.error("Transfer user error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/reports/generate
// Générer un rapport global
router.get("/reports/generate", authenticateSuperAdmin, async (req, res) => {
  try {
    const { type = "summary", days = 30 } = req.query;

    const report = {
      generated_at: new Date(),
      period_days: days,
      type,
    };

    if (type === "summary" || type === "all") {
      // Statistiques globales
      const globalStats = await pool.query(`
        SELECT 
          COUNT(DISTINCT o.id) as total_organizations,
          COUNT(DISTINCT u.id) as total_users,
          COUNT(DISTINCT ord.id) as total_orders,
          COALESCE(SUM(ord.total), 0) as total_revenue
        FROM organizations o
        LEFT JOIN users u ON o.id = u.organization_id
        LEFT JOIN orders ord ON o.id = ord.organization_id
        WHERE ord.created_at > NOW() - INTERVAL '${days} days'
      `);

      report.global_stats = globalStats.rows[0];
    }

    if (type === "organizations" || type === "all") {
      // Performance par organisation
      const orgPerformance = await pool.query(`
        SELECT 
          o.id,
          o.name,
          o.type,
          o.active,
          COUNT(DISTINCT u.id) as users_count,
          COUNT(DISTINCT ord.id) as orders_count,
          COALESCE(SUM(ord.total), 0) as revenue,
          COALESCE(AVG(ord.total), 0) as avg_order_value
        FROM organizations o
        LEFT JOIN users u ON o.id = u.organization_id
        LEFT JOIN orders ord ON o.id = ord.organization_id 
          AND ord.created_at > NOW() - INTERVAL '${days} days'
        GROUP BY o.id, o.name, o.type, o.active
        ORDER BY revenue DESC
      `);

      report.organizations_performance = orgPerformance.rows;
    }

    if (type === "security" || type === "all") {
      // Incidents de sécurité
      const securityIncidents = await pool.query(`
        SELECT 
          COUNT(*) as failed_logins,
          COUNT(DISTINCT details->>'ip') as unique_ips,
          COUNT(DISTINCT details->>'email') as unique_emails
        FROM audit_logs
        WHERE action = 'LOGIN_FAILED'
          AND created_at > NOW() - INTERVAL '${days} days'
      `);

      report.security_incidents = securityIncidents.rows[0];
    }

    if (type === "activity" || type === "all") {
      // Activité par jour
      const dailyActivity = await pool.query(`
        SELECT 
          DATE(created_at) as date,
          COUNT(*) as actions_count
        FROM audit_logs
        WHERE created_at > NOW() - INTERVAL '${days} days'
        GROUP BY DATE(created_at)
        ORDER BY date DESC
      `);

      report.daily_activity = dailyActivity.rows;
    }

    await logAudit("REPORT_GENERATED", req.user?.id, null, { type, days }, req);

    res.json({
      success: true,
      data: report,
    });
  } catch (error) {
    logger.error("Generate report error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/health
// Vérification de la santé du système
router.get("/health", authenticateSuperAdmin, async (req, res) => {
  try {
    const health = {
      status: "healthy",
      timestamp: new Date(),
      checks: {},
    };

    // Vérifier la connexion à la base de données
    try {
      await pool.query("SELECT 1");
      health.checks.database = { status: "ok" };
    } catch (error) {
      health.checks.database = { status: "error", message: error.message };
      health.status = "unhealthy";
    }

    // Vérifier les organisations actives
    const activeOrgs = await pool.query(
      "SELECT COUNT(*) as count FROM organizations WHERE active = true",
    );
    health.checks.active_organizations = {
      status: "ok",
      count: parseInt(activeOrgs.rows[0].count),
    };

    // Vérifier les sessions actives
    const activeSessions = await pool.query(
      "SELECT COUNT(*) as count FROM refresh_tokens WHERE expires_at > NOW()",
    );
    health.checks.active_sessions = {
      status: "ok",
      count: parseInt(activeSessions.rows[0].count),
    };

    // Vérifier les erreurs récentes (dernière heure)
    const recentErrors = await pool.query(`
      SELECT COUNT(*) as count
      FROM audit_logs
      WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
        AND created_at > NOW() - INTERVAL '1 hour'
    `);

    const errorCount = parseInt(recentErrors.rows[0].count);
    health.checks.recent_errors = {
      status: errorCount > 50 ? "warning" : "ok",
      count: errorCount,
    };

    if (errorCount > 50) {
      health.status = "degraded";
    }

    // Vérifier l'espace disque (si disponible)
    health.checks.disk_space = { status: "ok", message: "Non vérifié" };

    res.json({
      success: true,
      data: health,
    });
  } catch (error) {
    logger.error("Health check error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({
      success: false,
      data: {
        status: "unhealthy",
        error: error.message,
      },
    });
  }
});

// GET /api/super-admin/organizations/archived
// Liste des organisations archivées
router.get(
  "/organizations/archived",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const archived = await pool.query(`
      SELECT 
        o.*,
        COUNT(DISTINCT u.id) as users_count,
        COUNT(DISTINCT ord.id) as orders_count,
        COALESCE(SUM(ord.total), 0) as total_revenue
      FROM organizations o
      LEFT JOIN users u ON o.id = u.organization_id
      LEFT JOIN orders ord ON o.id = ord.organization_id
      WHERE o.active = false
      GROUP BY o.id
      ORDER BY o.updated_at DESC
    `);

      res.json({
        success: true,
        data: archived.rows,
      });
    } catch (error) {
      logger.error("Get archived orgs error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/super-admin/notifications/configure
// Configurer les notifications personnalisées
router.post(
  "/notifications/configure",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const { type, enabled, threshold, recipients } = req.body;

      // Créer la table si elle n'existe pas
      await pool.query(`
        CREATE TABLE IF NOT EXISTS notification_configs (
          id SERIAL PRIMARY KEY,
          type VARCHAR(100) NOT NULL,
          enabled BOOLEAN DEFAULT true,
          threshold INTEGER,
          recipients TEXT[],
          created_at TIMESTAMP DEFAULT NOW(),
          updated_at TIMESTAMP DEFAULT NOW(),
          UNIQUE(type)
        )
      `);

      // Insérer ou mettre à jour la configuration
      await pool.query(
        `INSERT INTO notification_configs (type, enabled, threshold, recipients)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (type) DO UPDATE SET
           enabled = $2,
           threshold = $3,
           recipients = $4,
           updated_at = NOW()`,
        [type, enabled, threshold, recipients],
      );

      await logAudit(
        "NOTIFICATION_CONFIGURED",
        req.user?.id,
        null,
        { type, enabled, threshold },
        req,
      );

      res.json({
        success: true,
        message: "Configuration enregistrée",
      });
    } catch (error) {
      logger.error("Configure notification error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/super-admin/notifications/configs
// Récupérer les configurations de notifications
router.get(
  "/notifications/configs",
  authenticateSuperAdmin,
  async (req, res) => {
    try {
      const configs = await pool.query(`
      SELECT * FROM notification_configs
      ORDER BY type
    `);

      res.json({
        success: true,
        data: configs.rows,
      });
    } catch (error) {
      // Table n'existe peut-être pas encore
      res.json({
        success: true,
        data: [],
      });
    }
  },
);

// ============================================
// PHASE 4 - MONITORING ET PERFORMANCE
// ============================================

// GET /api/super-admin/metrics/performance
// Métriques de performance du système
router.get("/metrics/performance", authenticateSuperAdmin, async (req, res) => {
  try {
    const { hours = 24 } = req.query;

    // Temps de réponse moyen par endpoint (via audit_logs)
    const responseTimesByAction = await pool.query(`
      SELECT 
        action,
        COUNT(*) as request_count,
        AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_response_time
      FROM audit_logs
      WHERE created_at > NOW() - INTERVAL '${hours} hours'
        AND updated_at IS NOT NULL
      GROUP BY action
      ORDER BY request_count DESC
      LIMIT 20
    `);

    // Requêtes les plus lentes
    const slowestQueries = await pool.query(`
      SELECT 
        action,
        details,
        EXTRACT(EPOCH FROM (updated_at - created_at)) as response_time,
        created_at
      FROM audit_logs
      WHERE created_at > NOW() - INTERVAL '${hours} hours'
        AND updated_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (updated_at - created_at)) > 1
      ORDER BY response_time DESC
      LIMIT 10
    `);

    // Taux d'erreur par heure
    const errorRateByHour = await pool.query(`
      SELECT 
        DATE_TRUNC('hour', created_at) as hour,
        COUNT(*) FILTER (WHERE action LIKE '%ERROR%' OR action LIKE '%FAILED%') as errors,
        COUNT(*) as total,
        ROUND(COUNT(*) FILTER (WHERE action LIKE '%ERROR%' OR action LIKE '%FAILED%')::numeric / NULLIF(COUNT(*), 0) * 100, 2) as error_rate
      FROM audit_logs
      WHERE created_at > NOW() - INTERVAL '${hours} hours'
      GROUP BY hour
      ORDER BY hour DESC
    `);

    // Utilisation de la base de données
    const dbStats = await pool.query(`
      SELECT 
        pg_database_size(current_database()) as db_size,
        (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
        (SELECT count(*) FROM pg_stat_activity) as total_connections
    `);

    // Top organisations par activité
    const topActiveOrgs = await pool.query(`
      SELECT 
        o.id,
        o.name,
        COUNT(al.id) as activity_count
      FROM organizations o
      LEFT JOIN audit_logs al ON o.id = al.organization_id
      WHERE al.created_at > NOW() - INTERVAL '${hours} hours'
      GROUP BY o.id, o.name
      ORDER BY activity_count DESC
      LIMIT 10
    `);

    res.json({
      success: true,
      data: {
        period_hours: hours,
        response_times: responseTimesByAction.rows,
        slowest_queries: slowestQueries.rows,
        error_rate_by_hour: errorRateByHour.rows,
        database: {
          size_bytes: parseInt(dbStats.rows[0].db_size),
          size_mb: Math.round(parseInt(dbStats.rows[0].db_size) / 1024 / 1024),
          active_connections: parseInt(dbStats.rows[0].active_connections),
          total_connections: parseInt(dbStats.rows[0].total_connections),
        },
        top_active_orgs: topActiveOrgs.rows,
      },
    });
  } catch (error) {
    logger.error("Performance metrics error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/metrics/realtime
// Métriques en temps réel
router.get("/metrics/realtime", authenticateSuperAdmin, async (req, res) => {
  try {
    // Activité des 5 dernières minutes
    const recentActivity = await pool.query(`
      SELECT 
        COUNT(*) as total_actions,
        COUNT(DISTINCT organization_id) as active_orgs,
        COUNT(DISTINCT user_id) as active_users,
        COUNT(*) FILTER (WHERE action LIKE '%ERROR%') as errors
      FROM audit_logs
      WHERE created_at > NOW() - INTERVAL '5 minutes'
    `);

    // Commandes récentes (dernière minute)
    const recentOrders = await pool.query(`
      SELECT COUNT(*) as count
      FROM orders
      WHERE created_at > NOW() - INTERVAL '1 minute'
    `);

    // Sessions actives
    const activeSessions = await pool.query(`
      SELECT 
        COUNT(*) as count,
        COUNT(DISTINCT user_id) as unique_users
      FROM refresh_tokens
      WHERE expires_at > NOW()
        AND created_at > NOW() - INTERVAL '1 hour'
    `);

    // Tentatives de connexion récentes
    const recentLogins = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE action = 'LOGIN_SUCCESS') as successful,
        COUNT(*) FILTER (WHERE action = 'LOGIN_FAILED') as failed
      FROM audit_logs
      WHERE (action = 'LOGIN_SUCCESS' OR action = 'LOGIN_FAILED')
        AND created_at > NOW() - INTERVAL '5 minutes'
    `);

    res.json({
      success: true,
      data: {
        timestamp: new Date(),
        activity: recentActivity.rows[0],
        orders: recentOrders.rows[0],
        sessions: activeSessions.rows[0],
        logins: recentLogins.rows[0],
      },
    });
  } catch (error) {
    logger.error("Realtime metrics error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/analytics/trends
// Analyse des tendances et prédictions
router.get("/analytics/trends", authenticateSuperAdmin, async (req, res) => {
  try {
    const { days = 30 } = req.query;

    // Tendance des commandes (croissance jour par jour)
    const ordersTrend = await pool.query(`
      WITH daily_orders AS (
        SELECT 
          DATE(created_at) as date,
          COUNT(*) as count
        FROM orders
        WHERE created_at > NOW() - INTERVAL '${days} days'
        GROUP BY DATE(created_at)
        ORDER BY date
      )
      SELECT 
        date,
        count,
        LAG(count) OVER (ORDER BY date) as previous_day,
        CASE 
          WHEN LAG(count) OVER (ORDER BY date) > 0 
          THEN ROUND(((count - LAG(count) OVER (ORDER BY date))::numeric / LAG(count) OVER (ORDER BY date) * 100), 2)
          ELSE 0
        END as growth_rate
      FROM daily_orders
    `);

    // Tendance du chiffre d'affaires
    const revenueTrend = await pool.query(`
      WITH daily_revenue AS (
        SELECT 
          DATE(created_at) as date,
          COALESCE(SUM(total), 0) as revenue
        FROM orders
        WHERE created_at > NOW() - INTERVAL '${days} days'
        GROUP BY DATE(created_at)
        ORDER BY date
      )
      SELECT 
        date,
        revenue,
        LAG(revenue) OVER (ORDER BY date) as previous_day,
        CASE 
          WHEN LAG(revenue) OVER (ORDER BY date) > 0 
          THEN ROUND(((revenue - LAG(revenue) OVER (ORDER BY date))::numeric / LAG(revenue) OVER (ORDER BY date) * 100), 2)
          ELSE 0
        END as growth_rate
      FROM daily_revenue
    `);

    // Tendance des nouveaux utilisateurs
    const usersTrend = await pool.query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as new_users,
        role
      FROM users
      WHERE created_at > NOW() - INTERVAL '${days} days'
      GROUP BY DATE(created_at), role
      ORDER BY date DESC, role
    `);

    // Organisations en croissance
    const growingOrgs = await pool.query(`
      WITH org_comparison AS (
        SELECT 
          o.id,
          o.name,
          COUNT(DISTINCT CASE WHEN ord.created_at > NOW() - INTERVAL '7 days' THEN ord.id END) as recent_orders,
          COUNT(DISTINCT CASE WHEN ord.created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days' THEN ord.id END) as previous_orders
        FROM organizations o
        LEFT JOIN orders ord ON o.id = ord.organization_id
        WHERE o.active = true
        GROUP BY o.id, o.name
      )
      SELECT 
        id,
        name,
        recent_orders,
        previous_orders,
        CASE 
          WHEN previous_orders > 0 
          THEN ROUND(((recent_orders - previous_orders)::numeric / previous_orders * 100), 2)
          ELSE 0
        END as growth_rate
      FROM org_comparison
      WHERE recent_orders > 0
      ORDER BY growth_rate DESC
      LIMIT 10
    `);

    // Prédiction simple (moyenne mobile)
    const avgOrdersLast7Days = await pool.query(`
      SELECT ROUND(AVG(daily_count)) as avg
      FROM (
        SELECT COUNT(*) as daily_count
        FROM orders
        WHERE created_at > NOW() - INTERVAL '7 days'
        GROUP BY DATE(created_at)
      ) sub
    `);

    res.json({
      success: true,
      data: {
        period_days: days,
        orders_trend: ordersTrend.rows,
        revenue_trend: revenueTrend.rows,
        users_trend: usersTrend.rows,
        growing_organizations: growingOrgs.rows,
        predictions: {
          avg_daily_orders_next_week: parseInt(
            avgOrdersLast7Days.rows[0].avg || 0,
          ),
        },
      },
    });
  } catch (error) {
    logger.error("Trends analytics error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// POST /api/super-admin/alerts/create
// Créer une alerte personnalisée
router.post("/alerts/create", authenticateSuperAdmin, async (req, res) => {
  try {
    const {
      name,
      type,
      condition,
      threshold,
      enabled = true,
      notification_channels,
    } = req.body;

    if (!name || !type || !condition) {
      return res.status(400).json({ error: "Paramètres manquants" });
    }

    // Créer la table si elle n'existe pas
    await pool.query(`
      CREATE TABLE IF NOT EXISTS custom_alerts (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type VARCHAR(100) NOT NULL,
        condition VARCHAR(255) NOT NULL,
        threshold NUMERIC,
        enabled BOOLEAN DEFAULT true,
        notification_channels TEXT[],
        last_triggered TIMESTAMP,
        trigger_count INTEGER DEFAULT 0,
        created_by UUID REFERENCES users(id),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    const result = await pool.query(
      `INSERT INTO custom_alerts (name, type, condition, threshold, enabled, notification_channels, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        name,
        type,
        condition,
        threshold,
        enabled,
        notification_channels,
        req.user?.id,
      ],
    );

    await logAudit(
      "ALERT_CREATED",
      req.user?.id,
      null,
      { alert_name: name, type, condition },
      req,
    );

    res.json({
      success: true,
      message: "Alerte créée",
      data: result.rows[0],
    });
  } catch (error) {
    logger.error("Create alert error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/alerts/list
// Liste des alertes personnalisées
router.get("/alerts/list", authenticateSuperAdmin, async (req, res) => {
  try {
    const alerts = await pool.query(`
      SELECT 
        ca.*,
        u.name as created_by_name,
        u.email as created_by_email
      FROM custom_alerts ca
      LEFT JOIN users u ON ca.created_by = u.id
      ORDER BY ca.created_at DESC
    `);

    res.json({
      success: true,
      data: alerts.rows,
    });
  } catch (error) {
    // Table n'existe peut-être pas encore
    res.json({
      success: true,
      data: [],
    });
  }
});

// DELETE /api/super-admin/alerts/:id
// Supprimer une alerte
router.delete("/alerts/:id", authenticateSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    await pool.query("DELETE FROM custom_alerts WHERE id = $1", [id]);

    await logAudit("ALERT_DELETED", req.user?.id, null, { alert_id: id }, req);

    res.json({
      success: true,
      message: "Alerte supprimée",
    });
  } catch (error) {
    logger.error("Delete alert error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/errors/analysis
// Analyse des erreurs système
router.get("/errors/analysis", authenticateSuperAdmin, async (req, res) => {
  try {
    const { days = 7 } = req.query;

    // Erreurs par type
    const errorsByType = await pool.query(`
      SELECT 
        action,
        COUNT(*) as count,
        MAX(created_at) as last_occurrence
      FROM audit_logs
      WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
        AND created_at > NOW() - INTERVAL '${days} days'
      GROUP BY action
      ORDER BY count DESC
      LIMIT 20
    `);

    // Erreurs par organisation
    const errorsByOrg = await pool.query(`
      SELECT 
        o.id,
        o.name,
        COUNT(al.id) as error_count
      FROM organizations o
      LEFT JOIN audit_logs al ON o.id = al.organization_id
      WHERE (al.action LIKE '%ERROR%' OR al.action LIKE '%FAILED%')
        AND al.created_at > NOW() - INTERVAL '${days} days'
      GROUP BY o.id, o.name
      ORDER BY error_count DESC
      LIMIT 10
    `);

    // Erreurs récurrentes (même erreur plusieurs fois)
    const recurringErrors = await pool.query(`
      SELECT 
        action,
        details->>'error' as error_message,
        COUNT(*) as occurrences,
        MIN(created_at) as first_seen,
        MAX(created_at) as last_seen
      FROM audit_logs
      WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
        AND created_at > NOW() - INTERVAL '${days} days'
      GROUP BY action, details->>'error'
      HAVING COUNT(*) > 5
      ORDER BY occurrences DESC
      LIMIT 10
    `);

    // Taux de résolution (erreurs qui ne se reproduisent plus)
    const resolvedErrors = await pool.query(`
      SELECT 
        COUNT(DISTINCT action) as total_error_types,
        COUNT(DISTINCT action) FILTER (WHERE last_occurrence < NOW() - INTERVAL '24 hours') as resolved_count
      FROM (
        SELECT 
          action,
          MAX(created_at) as last_occurrence
        FROM audit_logs
        WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
          AND created_at > NOW() - INTERVAL '${days} days'
        GROUP BY action
      ) sub
    `);

    res.json({
      success: true,
      data: {
        period_days: days,
        errors_by_type: errorsByType.rows,
        errors_by_organization: errorsByOrg.rows,
        recurring_errors: recurringErrors.rows,
        resolution_stats: resolvedErrors.rows[0],
      },
    });
  } catch (error) {
    logger.error("Errors analysis error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/super-admin/recommendations
// Recommandations automatiques basées sur l'analyse
router.get("/recommendations", authenticateSuperAdmin, async (req, res) => {
  try {
    const recommendations = [];

    // Vérifier les organisations inactives
    const inactiveOrgs = await pool.query(`
      SELECT 
        o.id,
        o.name,
        MAX(ord.created_at) as last_order
      FROM organizations o
      LEFT JOIN orders ord ON o.id = ord.organization_id
      WHERE o.active = true
      GROUP BY o.id, o.name
      HAVING MAX(ord.created_at) < NOW() - INTERVAL '30 days' OR MAX(ord.created_at) IS NULL
    `);

    if (inactiveOrgs.rows.length > 0) {
      recommendations.push({
        type: "warning",
        category: "organizations",
        title: "Organisations inactives détectées",
        description: `${inactiveOrgs.rows.length} organisation(s) sans commande depuis 30 jours`,
        action: "Contacter ou archiver ces organisations",
        priority: "medium",
        affected_count: inactiveOrgs.rows.length,
      });
    }

    // Vérifier les erreurs récurrentes
    const recurringErrors = await pool.query(`
      SELECT COUNT(*) as count
      FROM (
        SELECT action
        FROM audit_logs
        WHERE (action LIKE '%ERROR%' OR action LIKE '%FAILED%')
          AND created_at > NOW() - INTERVAL '7 days'
        GROUP BY action
        HAVING COUNT(*) > 10
      ) sub
    `);

    if (parseInt(recurringErrors.rows[0].count) > 0) {
      recommendations.push({
        type: "error",
        category: "performance",
        title: "Erreurs récurrentes détectées",
        description: `${recurringErrors.rows[0].count} type(s) d'erreur se répètent fréquemment`,
        action: "Analyser et corriger les erreurs récurrentes",
        priority: "high",
        affected_count: parseInt(recurringErrors.rows[0].count),
      });
    }

    // Vérifier les utilisateurs inactifs
    const inactiveUsers = await pool.query(`
      SELECT COUNT(*) as count
      FROM users
      WHERE active = true
        AND updated_at < NOW() - INTERVAL '90 days'
    `);

    if (parseInt(inactiveUsers.rows[0].count) > 10) {
      recommendations.push({
        type: "info",
        category: "users",
        title: "Utilisateurs inactifs",
        description: `${inactiveUsers.rows[0].count} utilisateur(s) inactif(s) depuis 90 jours`,
        action: "Désactiver les comptes inutilisés",
        priority: "low",
        affected_count: parseInt(inactiveUsers.rows[0].count),
      });
    }

    // Vérifier la taille de la base de données
    const dbSize = await pool.query(`
      SELECT pg_database_size(current_database()) as size
    `);

    const sizeMB = parseInt(dbSize.rows[0].size) / 1024 / 1024;
    if (sizeMB > 1000) {
      recommendations.push({
        type: "warning",
        category: "database",
        title: "Base de données volumineuse",
        description: `Taille actuelle: ${Math.round(sizeMB)} MB`,
        action: "Purger les anciens logs et données inutiles",
        priority: "medium",
        affected_count: Math.round(sizeMB),
      });
    }

    // Vérifier les sessions expirées non nettoyées
    const expiredSessions = await pool.query(`
      SELECT COUNT(*) as count
      FROM refresh_tokens
      WHERE expires_at < NOW()
    `);

    if (parseInt(expiredSessions.rows[0].count) > 100) {
      recommendations.push({
        type: "info",
        category: "maintenance",
        title: "Sessions expirées à nettoyer",
        description: `${expiredSessions.rows[0].count} session(s) expirée(s)`,
        action: "Nettoyer les sessions expirées",
        priority: "low",
        affected_count: parseInt(expiredSessions.rows[0].count),
      });
    }

    res.json({
      success: true,
      data: {
        total: recommendations.length,
        high_priority: recommendations.filter((r) => r.priority === "high")
          .length,
        medium_priority: recommendations.filter((r) => r.priority === "medium")
          .length,
        low_priority: recommendations.filter((r) => r.priority === "low")
          .length,
        recommendations: recommendations.sort((a, b) => {
          const priorityOrder = { high: 0, medium: 1, low: 2 };
          return priorityOrder[a.priority] - priorityOrder[b.priority];
        }),
      },
    });
  } catch (error) {
    logger.error("Recommendations error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});
