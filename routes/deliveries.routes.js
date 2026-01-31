const express = require("express");
const router = express.Router();

const pool = require("../config/database");
const { authenticate, requireAdmin } = require("../middleware/auth");
const { validate, validateUUID } = require("../middleware/validate");
const { logAudit } = require("../services/audit.service");
const { getOrderWithItems } = require("../services/order.service");
const { getPagination, getPagingData } = require("../utils/pagination.helper");

/**
 * @swagger
 * tags:
 *   name: Deliveries
 *   description: Gestion des livraisons et suivi livreurs
 */

/**
 * @swagger
 * components:
 *   schemas:
 *     Delivery:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         orderId:
 *           type: string
 *           format: uuid
 *         delivererId:
 *           type: string
 *           format: uuid
 *         status:
 *           type: string
 *           enum: [assigned, in_progress, delivered, failed, postponed]
 *         paymentStatus:
 *           type: string
 *           enum: [paid, unpaid]
 *         amountCollected:
 *           type: number
 *         failureReason:
 *           type: string
 *         comment:
 *           type: string
 *         createdAt:
 *           type: string
 *           format: date-time
 */

/**
 * @swagger
 * /deliveries:
 *   get:
 *     summary: Lister les livraisons (Admin)
 *     tags: [Deliveries]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *         description: Filtre par statut
 *     responses:
 *       200:
 *         description: Liste des livraisons
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
 *                     $ref: '#/components/schemas/Delivery'
 */
// GET /api/deliveries (avec pagination optionnelle)
router.get("/", authenticate, async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query, 50);
    const status = req.query.status;
    const delivererId = req.query.delivererId;
    const customerId = req.query.customerId;

    let whereClause = "WHERE d.organization_id = $1";
    const params = [req.user.organization_id];

    if (status && status !== "all") {
      params.push(status);
      whereClause += ` AND d.status = $${params.length}`;
    }

    if (delivererId) {
      params.push(delivererId);
      whereClause += ` AND d.deliverer_id = $${params.length}`;
    }

    if (customerId) {
      params.push(customerId);
      whereClause += ` AND o.customer_id = $${params.length}`;
    }

    // Compter le total
    // Si on filtre par cafeteria, il faut faire le JOIN
    const countQuery = customerId
      ? `SELECT COUNT(*) FROM deliveries d LEFT JOIN orders o ON d.order_id = o.id ${whereClause}`
      : `SELECT COUNT(*) FROM deliveries d ${whereClause}`;

    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].count);

    const result = await pool.query(
      `SELECT d.*,
              u.name as deliverer_name,
              to_jsonb(o.*) as order_data,
              ou.name as customer_name, ou.phone as customer_phone,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', oi.id,
                    'productId', oi.product_id,
                    'productName', oi.product_name,
                    'quantity', oi.quantity,
                    'price', oi.price
                  )
                ) FILTER (WHERE oi.id IS NOT NULL), 
                '[]'
              ) as order_items
       FROM deliveries d
       LEFT JOIN users u ON d.deliverer_id = u.id
       LEFT JOIN orders o ON d.order_id = o.id
       LEFT JOIN users ou ON o.customer_id = ou.id
       LEFT JOIN order_items oi ON o.id = oi.order_id
       ${whereClause}
       GROUP BY d.id, u.id, o.id, ou.id
       ORDER BY d.created_at DESC
       LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset],
    );

    const deliveries = result.rows.map((d) => {
      // Reconstituer l'objet order complet comme getOrderWithItems le ferait
      const order = d.order_data
        ? {
            ...d.order_data,
            items: d.order_items,
            customer: { name: d.customer_name, phone: d.customer_phone }, // UniformisÃ© avec customer
          }
        : null;

      return {
        id: d.id,
        orderId: d.order_id,
        delivererId: d.deliverer_id,
        status: d.status,
        paymentStatus: d.payment_status || "unpaid",
        amountCollected: parseFloat(d.amount_collected || 0),
        comment: d.comment,
        failureReason: d.failure_reason,
        failedAt: d.failed_at,
        postponedTo: d.postponed_to,
        attempts: d.attempts || 0,
        deliveredAt: d.delivered_at,
        createdAt: d.created_at,
        order,
        deliverer: d.deliverer_id
          ? { id: d.deliverer_id, name: d.deliverer_name }
          : null,
      };
    });

    res.json(getPagingData(deliveries, total, page, limit));
  } catch (error) {
    console.error("Deliveries error:", error);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

/**
 * @swagger
 * /deliveries/route:
 *   get:
 *     summary: Obtenir la feuille de route du livreur connectÃ©
 *     tags: [Deliveries]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des livraisons Ã  effectuer
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
 *                     $ref: '#/components/schemas/Delivery'
 */
// GET /api/deliveries/route
router.get("/route", authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.* FROM deliveries d
       WHERE d.deliverer_id = $1 AND d.status IN ('assigned', 'in_progress', 'postponed')
       ORDER BY CASE WHEN d.status = 'postponed' THEN 1 ELSE 0 END, d.created_at`,
      [req.user.id],
    );

    const deliveries = [];
    for (const d of result.rows) {
      const order = await getOrderWithItems(d.order_id);
      deliveries.push({
        id: d.id,
        orderId: d.order_id,
        delivererId: d.deliverer_id,
        status: d.status,
        paymentStatus: d.payment_status || "unpaid",
        amountCollected: parseFloat(d.amount_collected || 0),
        comment: d.comment,
        failureReason: d.failure_reason,
        failedAt: d.failed_at,
        postponedTo: d.postponed_to,
        attempts: d.attempts || 0,
        createdAt: d.created_at,
        order,
      });
    }

    res.json({ success: true, data: deliveries });
  } catch (error) {
    console.error("Route error:", error);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/deliveries/history
router.get("/history", authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.* FROM deliveries d
       WHERE d.deliverer_id = $1 AND d.status IN ('delivered', 'failed')
       ORDER BY d.delivered_at DESC NULLS LAST, d.created_at DESC
       LIMIT 100`,
      [req.user.id],
    );

    const deliveries = [];
    for (const d of result.rows) {
      const order = await getOrderWithItems(d.order_id);
      deliveries.push({
        id: d.id,
        orderId: d.order_id,
        delivererId: d.deliverer_id,
        status: d.status,
        paymentStatus: d.payment_status || "unpaid",
        amountCollected: parseFloat(d.amount_collected || 0),
        comment: d.comment,
        failureReason: d.failure_reason,
        deliveredAt: d.delivered_at,
        createdAt: d.created_at,
        order,
      });
    }

    res.json({ success: true, data: deliveries });
  } catch (error) {
    console.error("History error:", error);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/deliveries/:id
router.get("/:id", authenticate, validateUUID("id"), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.*, u.name as deliverer_name
       FROM deliveries d
       LEFT JOIN users u ON d.deliverer_id = u.id
       WHERE d.id = $1 AND d.organization_id = $2`,
      [req.params.id, req.user.organization_id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Livraison non trouvÃ©e" });
    }

    const d = result.rows[0];
    const order = await getOrderWithItems(d.order_id);

    res.json({
      success: true,
      data: {
        id: d.id,
        orderId: d.order_id,
        delivererId: d.deliverer_id,
        status: d.status,
        paymentStatus: d.payment_status || "unpaid",
        amountCollected: parseFloat(d.amount_collected || 0),
        comment: d.comment,
        deliveredAt: d.delivered_at,
        createdAt: d.created_at,
        order,
        deliverer: d.deliverer_id
          ? { id: d.deliverer_id, name: d.deliverer_name }
          : null,
      },
    });
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

/**
 * @swagger
 * /deliveries/{id}/status:
 *   put:
 *     summary: Mettre Ã  jour le statut d'une livraison (Livreur)
 *     tags: [Deliveries]
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
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [in_progress, delivered, failed, postponed]
 *               paymentStatus:
 *                 type: string
 *                 enum: [paid, unpaid]
 *               amountCollected:
 *                 type: number
 *               failureReason:
 *                 type: string
 *               comment:
 *                 type: string
 *     responses:
 *       200:
 *         description: Statut mis Ã  jour
 */
// PUT /api/deliveries/:id/status
router.put(
  "/:id/status",
  authenticate,
  validateUUID("id"),
  validate("updateDeliveryStatus"),
  async (req, res) => {
    try {
      const {
        status,
        paymentStatus,
        amountCollected,
        comment,
        failureReason,
        postponedTo,
      } = req.body;

      // VÃ©rifier que la livraison existe et appartient au livreur
      const checkDelivery = await pool.query(
        "SELECT id, deliverer_id FROM deliveries WHERE id = $1",
        [req.params.id],
      );

      if (checkDelivery.rows.length === 0) {
        return res.status(404).json({ error: "Livraison non trouvÃ©e" });
      }

      if (checkDelivery.rows[0].deliverer_id !== req.user.id) {
        return res
          .status(403)
          .json({ error: "Cette livraison ne vous est pas assignÃ©e" });
      }

      if (status === "delivered") {
        await pool.query(
          `UPDATE deliveries SET status = $1, payment_status = $2, amount_collected = $3, comment = $4, delivered_at = NOW() 
         WHERE id = $5 AND deliverer_id = $6`,
          [
            status,
            paymentStatus || "unpaid",
            amountCollected || 0,
            comment || null,
            req.params.id,
            req.user.id,
          ],
        );

        const delivery = await pool.query(
          "SELECT order_id FROM deliveries WHERE id = $1",
          [req.params.id],
        );
        if (delivery.rows.length > 0) {
          await pool.query(
            `UPDATE orders SET status = 'delivered', payment_status = $1, amount_paid = amount_paid + $2 
           WHERE id = $3`,
            [
              paymentStatus || "unpaid",
              amountCollected || 0,
              delivery.rows[0].order_id,
            ],
          );
        }

        await logAudit(
          "DELIVERY_COMPLETED",
          req.user.id,
          req.user.organization_id,
          { deliveryId: req.params.id, amountCollected },
          req,
        );
      } else if (status === "failed") {
        await pool.query(
          `UPDATE deliveries SET status = $1, comment = $2, failure_reason = $3, failed_at = NOW(), attempts = COALESCE(attempts, 0) + 1
         WHERE id = $4 AND deliverer_id = $5`,
          [
            status,
            comment || null,
            failureReason || "other",
            req.params.id,
            req.user.id,
          ],
        );

        const delivery = await pool.query(
          "SELECT order_id FROM deliveries WHERE id = $1",
          [req.params.id],
        );
        if (delivery.rows.length > 0) {
          await pool.query(
            `UPDATE orders SET status = 'locked' WHERE id = $1`,
            [delivery.rows[0].order_id],
          );
        }

        await logAudit(
          "DELIVERY_FAILED",
          req.user.id,
          req.user.organization_id,
          { deliveryId: req.params.id, failureReason },
          req,
        );
      } else if (status === "postponed") {
        await pool.query(
          `UPDATE deliveries SET status = $1, comment = $2, failure_reason = $3, postponed_to = $4, attempts = COALESCE(attempts, 0) + 1
         WHERE id = $5 AND deliverer_id = $6`,
          [
            status,
            comment || null,
            failureReason || "other",
            postponedTo || null,
            req.params.id,
            req.user.id,
          ],
        );

        await logAudit(
          "DELIVERY_POSTPONED",
          req.user.id,
          req.user.organization_id,
          { deliveryId: req.params.id, postponedTo },
          req,
        );
      } else {
        await pool.query(
          "UPDATE deliveries SET status = $1, comment = $2 WHERE id = $3 AND deliverer_id = $4",
          [status, comment || null, req.params.id, req.user.id],
        );
      }

      res.json({ success: true });
    } catch (error) {
      console.error("Delivery status error:", error);
      res.status(500).json({ error: "Erreur serveur: " + error.message });
    }
  },
);

/**
 * @swagger
 * /deliverers/location:
 *   post:
 *     summary: Mettre Ã  jour la gÃ©olocalisation du livreur
 *     tags: [Deliveries]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - latitude
 *               - longitude
 *             properties:
 *               latitude:
 *                 type: number
 *               longitude:
 *                 type: number
 *     responses:
 *       200:
 *         description: Position mise Ã  jour
 */
// POST /api/deliverers/location
router.post(
  "/location",
  authenticate,
  validate("updateLocation"),
  async (req, res) => {
    try {
      const { latitude, longitude } = req.body;

      await pool.query(
        `UPDATE users SET latitude = $1, longitude = $2, location_updated_at = NOW() 
       WHERE id = $3 AND role = 'deliverer'`,
        [latitude, longitude, req.user.id],
      );

      res.json({ success: true });
    } catch (error) {
      console.error("Location update error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// GET /api/deliverers/locations
router.get("/locations", authenticate, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, latitude, longitude, location_updated_at
       FROM users 
       WHERE organization_id = $1 AND role = 'deliverer' AND active = true
       AND latitude IS NOT NULL AND longitude IS NOT NULL`,
      [req.user.organization_id],
    );

    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error("Get locations error:", error);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/deliverers/:id/history (alias pour compatibilitÃ©)
// SECURITY: Filtrer par organization_id pour Ã©viter fuite de donnÃ©es inter-organisations
router.get(
  "/:id/history",
  authenticate,
  validateUUID("id"),
  async (req, res) => {
    try {
      const { date } = req.query;
      const delivererId = req.params.id;

      // VÃ©rifier que le livreur appartient Ã  l'organisation de l'utilisateur
      const delivererCheck = await pool.query(
        "SELECT id FROM users WHERE id = $1 AND organization_id = $2 AND role = $3",
        [delivererId, req.user.organization_id, "deliverer"],
      );

      if (delivererCheck.rows.length === 0) {
        return res
          .status(404)
          .json({ error: "Livreur non trouvÃ© dans votre organisation" });
      }

      const result = await pool.query(
        `SELECT latitude, longitude, recorded_at
       FROM location_history 
       WHERE deliverer_id = $1 AND DATE(recorded_at) = $2
       ORDER BY recorded_at`,
        [delivererId, date || new Date().toISOString().split("T")[0]],
      );

      res.json({ success: true, data: result.rows });
    } catch (error) {
      console.error("Get history error:", error);
      // Retourner tableau vide si table n'existe pas
      res.json({ success: true, data: [] });
    }
  },
);

module.exports = router;
