const express = require("express");
const bcrypt = require("bcryptjs");
const router = express.Router();

const pool = require("../config/database");
const { authenticate, requireAdmin } = require("../middleware/auth");
const { validate, validateUUID } = require("../middleware/validate");
const { logAudit } = require("../services/audit.service");
const cacheService = require("../services/cache.service");
const cacheMiddleware = require("../middleware/cache.middleware");
const { getPagination, getPagingData } = require("../utils/pagination.helper");

/**
 * @swagger
 * tags:
 *   name: Users
 *   description: Gestion des utilisateurs (EmployÃ©s, CafÃ©tÃ©rias, Livreurs)
 */

/**
 * @swagger
 * /users:
 *   get:
 *     summary: Lister tous les utilisateurs (hors admin)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des utilisateurs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 */
// GET /api/users
router.get("/", authenticate, cacheMiddleware(300), async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query, 50);

    // Count
    const countResult = await pool.query(
      "SELECT COUNT(*) FROM users WHERE organization_id = $1 AND role != $2",
      [req.user.organization_id, "admin"],
    );
    const total = parseInt(countResult.rows[0].count);

    const result = await pool.query(
      "SELECT id, email, name, phone, role, active, created_at, address, address_lat, address_lng FROM users WHERE organization_id = $1 AND role != $2 LIMIT $3 OFFSET $4",
      [req.user.organization_id, "admin", limit, offset],
    );

    res.json(getPagingData(result.rows, total, page, limit));
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/users/deliverers
router.get(
  "/deliverers",
  authenticate,
  cacheMiddleware(300),
  async (req, res) => {
    try {
      const result = await pool.query(
        "SELECT id, email, name, phone, active FROM users WHERE organization_id = $1 AND role = $2 AND active = true",
        [req.user.organization_id, "deliverer"],
      );
      res.json({ success: true, data: result.rows });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/users/clients-locations
router.get(
  "/clients-locations",
  authenticate,
  cacheMiddleware(300),
  async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT u.id, u.name, u.phone, u.address, u.address_lat as latitude, u.address_lng as longitude,
              (SELECT COUNT(*) FROM orders o WHERE o.customer_id = u.id AND o.status IN ('pending', 'validated', 'preparing', 'ready', 'in_delivery'))::int as active_orders_count,
              (SELECT COALESCE(SUM(total), 0) FROM orders o WHERE o.customer_id = u.id AND o.status IN ('pending', 'validated', 'preparing', 'ready', 'in_delivery'))::float as active_orders_total
       FROM users u
       WHERE u.organization_id = $1 AND u.role = 'customer' AND u.active = true
       AND u.address_lat IS NOT NULL AND u.address_lng IS NOT NULL`,
        [req.user.organization_id],
      );
      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error("Get clients locations error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

/**
 * @swagger
 * /users:
 *   post:
 *     summary: CrÃ©er un nouvel utilisateur (Admin)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - name
 *               - role
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 6
 *               name:
 *                 type: string
 *               phone:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [deliverer, customer]
 *     responses:
 *       200:
 *         description: Utilisateur crÃ©Ã©
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Email existant ou donnÃ©es invalides
 */
// POST /api/users
router.post(
  "/",
  authenticate,
  requireAdmin,
  validate("createUser"),
  async (req, res) => {
    try {
      const { email, password, name, phone, role } = req.body;

      const existingUser = await pool.query(
        "SELECT id FROM users WHERE LOWER(email) = LOWER($1)",
        [email.trim()],
      );
      if (existingUser.rows.length > 0) {
        return res.status(400).json({ error: "Email dÃ©jÃ  utilisÃ©" });
      }

      const hashedPassword = await bcrypt.hash(password, 12);
      const sanitizedPhone = phone
        ? phone.replace(/[^0-9+\-\s]/g, "").substring(0, 20)
        : "";

      const result = await pool.query(
        "INSERT INTO users (organization_id, email, password, name, phone, role) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, email, name, phone, role",
        [
          req.user.organization_id,
          email.trim().toLowerCase(),
          hashedPassword,
          name.trim(),
          sanitizedPhone,
          role,
        ],
      );

      await logAudit(
        "USER_CREATED",
        req.user.id,
        req.user.organization_id,
        { newUserId: result.rows[0].id, email, role },
        req,
      );

      await cacheService.invalidate(`cache:users:${req.user.organization_id}*`);

      res.json({ success: true, data: result.rows[0] });
    } catch (error) {
      console.error("Create user error:", error.message);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// DELETE /api/users/:id
router.delete(
  "/:id",
  authenticate,
  requireAdmin,
  validateUUID("id"),
  async (req, res) => {
    try {
      const userId = req.params.id;

      const userCheck = await pool.query(
        "SELECT id, role FROM users WHERE id = $1 AND organization_id = $2",
        [userId, req.user.organization_id],
      );

      if (userCheck.rows.length === 0) {
        return res.status(404).json({ error: "Utilisateur non trouvÃ©" });
      }

      if (userCheck.rows[0].role === "admin") {
        return res
          .status(403)
          .json({ error: "Impossible de supprimer un admin" });
      }

      const ordersCheck = await pool.query(
        "SELECT COUNT(*) as count FROM orders WHERE customer_id = $1",
        [userId],
      );

      if (parseInt(ordersCheck.rows[0].count) > 0) {
        await pool.query("UPDATE users SET active = false WHERE id = $1", [
          userId,
        ]);
        await logAudit(
          "USER_DEACTIVATED",
          req.user.id,
          req.user.organization_id,
          { targetUserId: userId, reason: "has_orders" },
          req,
        );
        return res.json({
          success: true,
          message: "Utilisateur dÃ©sactivÃ© (commandes existantes)",
          deactivated: true,
        });
      }

      await pool.query(
        "UPDATE deliveries SET deliverer_id = NULL WHERE deliverer_id = $1",
        [userId],
      );
      await pool.query("DELETE FROM users WHERE id = $1", [userId]);

      await logAudit(
        "USER_DELETED",
        req.user.id,
        req.user.organization_id,
        { targetUserId: userId },
        req,
      );

      await cacheService.invalidate(`cache:users:${req.user.organization_id}*`);

      res.json({ success: true });
    } catch (error) {
      console.error("Delete user error:", error.message);
      res.status(500).json({ error: "Erreur serveur: " + error.message });
    }
  },
);

// PUT /api/users/:id/toggle
router.put(
  "/:id/toggle",
  authenticate,
  requireAdmin,
  validateUUID("id"),
  async (req, res) => {
    try {
      await pool.query(
        "UPDATE users SET active = NOT active WHERE id = $1 AND organization_id = $2",
        [req.params.id, req.user.organization_id],
      );

      await logAudit(
        "USER_TOGGLED",
        req.user.id,
        req.user.organization_id,
        { targetUserId: req.params.id },
        req,
      );

      await cacheService.invalidate(`cache:users:${req.user.organization_id}*`);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

/**
 * @swagger
 * /users/{id}/address:
 *   put:
 *     summary: Mettre Ã  jour l'adresse d'un utilisateur (Geocoding)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               address:
 *                 type: string
 *               latitude:
 *                 type: number
 *                 format: float
 *               longitude:
 *                 type: number
 *                 format: float
 *     responses:
 *       200:
 *         description: Adresse mise Ã  jour avec coordonnÃ©es
 */
// PUT /api/users/:id/address - Mettre Ã  jour l'adresse d'un client (avec gÃ©ocodage OSM)
router.put(
  "/:id/address",
  authenticate,
  validateUUID("id"),
  async (req, res) => {
    try {
      const { address, latitude, longitude } = req.body;
      const userId = req.params.id;

      // VÃ©rifier que l'utilisateur appartient Ã  la mÃªme organisation
      const userCheck = await pool.query(
        "SELECT id FROM users WHERE id = $1 AND organization_id = $2",
        [userId, req.user.organization_id],
      );

      if (userCheck.rows.length === 0) {
        return res.status(404).json({ error: "Utilisateur non trouvÃ©" });
      }

      let lat = latitude;
      let lng = longitude;

      // Si pas de coordonnÃ©es fournies, gÃ©ocoder l'adresse via Nominatim (OSM)
      if (address && (!lat || !lng)) {
        try {
          const response = await fetch(
            `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}&limit=1`,
            { headers: { "User-Agent": "Awid-Delivery-App/1.0" } },
          );
          const data = await response.json();
          if (data && data.length > 0) {
            lat = parseFloat(data[0].lat);
            lng = parseFloat(data[0].lon);
          }
        } catch (geoError) {
          console.error("Geocoding error:", geoError.message);
        }
      }

      await pool.query(
        "UPDATE users SET address = $1, address_lat = $2, address_lng = $3 WHERE id = $4",
        [address || null, lat || null, lng || null, userId],
      );

      await logAudit(
        "USER_ADDRESS_UPDATED",
        req.user.id,
        req.user.organization_id,
        { targetUserId: userId, address },
        req,
      );

      await cacheService.invalidate(`cache:users:${req.user.organization_id}*`);

      res.json({
        success: true,
        data: { address, latitude: lat, longitude: lng },
      });
    } catch (error) {
      console.error("Update address error:", error.message);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// PUT /api/users/:id/credit-limit
router.put(
  "/:id/credit-limit",
  authenticate,
  requireAdmin,
  validateUUID("id"),
  async (req, res) => {
    try {
      const { creditLimit } = req.body; // Can be null or number
      const userId = req.params.id;

      // Validation basic
      if (creditLimit !== null && (isNaN(creditLimit) || creditLimit < 0)) {
        return res
          .status(400)
          .json({ error: "Limite invalide (doit Ãªtre positive ou null)" });
      }

      const result = await pool.query(
        "UPDATE users SET credit_limit = $1 WHERE id = $2 AND organization_id = $3 RETURNING credit_limit",
        [creditLimit, userId, req.user.organization_id],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ error: "Utilisateur non trouvÃ©" });
      }

      await logAudit(
        "CREDIT_LIMIT_UPDATED",
        req.user.id,
        req.user.organization_id,
        { targetUserId: userId, creditLimit },
        req,
      );

      // Invalider cache user
      await cacheService.invalidate(`cache:users:${req.user.organization_id}*`);

      res.json({
        success: true,
        data: { creditLimit: result.rows[0].credit_limit },
      });
    } catch (error) {
      console.error("Update credit limit error:", error.message);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

module.exports = router;
