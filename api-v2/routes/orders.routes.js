const express = require("express");
const router = express.Router();

const pool = require("../config/database");
const logger = require("../config/logger");
const cacheMiddleware = require("../middleware/cache.middleware");
const {
  authenticate,
  requireAdmin,
  requireKitchen,
} = require("../middleware/auth");
const { validate, validateUUID } = require("../middleware/validate");
const { logAudit } = require("../services/audit.service");
const {
  getOrderItems,
  getOrderWithItems,
  formatOrder,
} = require("../services/order.service");
const { getPagination, getPagingData } = require("../utils/pagination.helper");

/**
 * @swagger
 * tags:
 *   name: Orders
 *   description: Gestion des commandes (crÃ©ation, suivi, cuisine)
 */

/**
 * @swagger
 * components:
 *   schemas:
 *     OrderItem:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         productId:
 *           type: string
 *           format: uuid
 *         productName:
 *           type: string
 *         quantity:
 *           type: integer
 *         price:
 *           type: number
 *           format: float
 *     Order:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         orderNumber:
 *           type: integer
 *         status:
 *           type: string
 *           enum: [pending, validated, locked, preparing, ready, in_delivery, delivered, cancelled]
 *         total:
 *           type: number
 *           format: float
 *         date:
 *           type: string
 *           format: date-time
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/OrderItem'
 *         customer:
 *           type: object
 *           properties:
 *             name:
 *               type: string
 *             phone:
 *               type: string
 */

/**
 * @swagger
 * /orders:
 *   get:
 *     summary: Lister les commandes (Admin/Manager)
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: NumÃ©ro de page (dÃ©faut 1)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Nombre d'Ã©lÃ©ments par page (dÃ©faut 50)
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *         description: Filtrer par statut
 *     responses:
 *       200:
 *         description: Liste des commandes paginÃ©e
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
 *                     $ref: '#/components/schemas/Order'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     total:
 *                       type: integer
 */
// GET /api/orders (avec pagination optionnelle)
router.get("/", authenticate, cacheMiddleware(60), async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query, 50);
    const status = req.query.status; // Filtre optionnel par statut
    const customerId = req.query.customerId; // Filtre optionnel par client (cafÃ©tÃ©ria)

    // Construire la requÃªte avec filtres
    let whereClause = "WHERE o.organization_id = $1";
    const params = [req.user.organization_id];

    if (status && status !== "all") {
      params.push(status);
      whereClause += ` AND o.status = $${params.length}`;
    }

    if (customerId) {
      params.push(customerId);
      whereClause += ` AND o.customer_id = $${params.length}`;
    }

    // Compter le total
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM orders o ${whereClause}`,
      params,
    );
    const total = parseInt(countResult.rows[0].count);

    // RÃ©cupÃ©rer les commandes avec pagination et items en une seule requÃªte (Optimisation N+1)
    const result = await pool.query(
      `SELECT o.*, 
              u.name as customer_name, u.phone as customer_phone,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', oi.id,
                    'productId', oi.product_id,
                    'productName', p.name,
                    'quantity', oi.quantity,
                    'unitPrice', oi.price
                  ) ORDER BY oi.created_at
                ) FILTER (WHERE oi.id IS NOT NULL), 
                '[]'
              ) as items
       FROM orders o 
       JOIN users u ON o.customer_id = u.id 
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       ${whereClause}
       GROUP BY o.id, u.id
       ORDER BY o.created_at DESC
       LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset],
    );

    const orders = result.rows.map((order) =>
      formatOrder(order, order.items, {
        id: order.customer_id,
        name: order.customer_name,
        phone: order.customer_phone,
      }),
    );

    res.json(getPagingData(orders, total, page, limit));
  } catch (error) {
    logger.error("Orders error:", { error: error.message, stack: error.stack });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/orders/my
router.get("/my", authenticate, cacheMiddleware(60), async (req, res) => {
  try {
    // Optimisé : 1 requête au lieu de N+1
    const result = await pool.query(
      `SELECT o.*, 
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', oi.id,
                    'productId', oi.product_id,
                    'productName', p.name,
                    'quantity', oi.quantity,
                    'unitPrice', oi.price
                  ) ORDER BY oi.created_at
                ) FILTER (WHERE oi.id IS NOT NULL), 
                '[]'
              ) as items
       FROM orders o 
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.customer_id = $1 AND o.organization_id = $2 
       GROUP BY o.id
       ORDER BY o.created_at DESC`,
      [req.user.id, req.user.organization_id],
    );

    const orders = result.rows.map((order) => formatOrder(order, order.items));

    res.json({ success: true, data: orders });
  } catch (error) {
    logger.error("My orders error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur" });
  }
});

/**
 * @swagger
 * /orders/kitchen:
 *   get:
 *     summary: Liste des commandes en cours pour la cuisine
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     description: Retourne les commandes aux statuts 'validated' et 'preparing', triÃ©es par prioritÃ©.
 *     responses:
 *       200:
 *         description: Liste des commandes cuisine
 */
// GET /api/orders/kitchen
router.get(
  "/kitchen",
  authenticate,
  requireKitchen,
  cacheMiddleware(30),
  async (req, res) => {
    try {
      // Optimisé : 1 requête au lieu de N+1
      const result = await pool.query(
        `SELECT o.*, 
              u.name as customer_name, 
              u.phone as customer_phone,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', oi.id,
                    'productId', oi.product_id,
                    'productName', p.name,
                    'quantity', oi.quantity,
                    'unitPrice', oi.price
                  ) ORDER BY oi.created_at
                ) FILTER (WHERE oi.id IS NOT NULL), 
                '[]'
              ) as items
       FROM orders o 
       JOIN users u ON o.customer_id = u.id 
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.organization_id = $1 AND o.status IN ('validated', 'preparing')
       GROUP BY o.id, u.name, u.phone
       ORDER BY 
         CASE WHEN o.status = 'validated' THEN 0 ELSE 1 END,
         o.created_at ASC`,
        [req.user.organization_id],
      );

      const orders = result.rows.map((order) => ({
        id: order.id,
        organizationId: order.organization_id,
        customerId: order.customer_id,
        date: order.date,
        total: parseFloat(order.total),
        status: order.status,
        createdAt: order.created_at,
        items: order.items,
        customer: {
          id: order.customer_id,
          name: order.customer_name,
          phone: order.customer_phone,
        },
      }));

      res.json({ success: true, data: orders });
    } catch (error) {
      logger.error("Kitchen orders error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

/**
 * @swagger
 * /orders:
 *   post:
 *     summary: CrÃ©er une nouvelle commande (CafÃ©tÃ©ria)
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - items
 *             properties:
 *               items:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     productId:
 *                       type: string
 *                       format: uuid
 *                     quantity:
 *                       type: integer
 *                       minimum: 1
 *     responses:
 *       200:
 *         description: Commande crÃ©Ã©e
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/Order'
 *       400:
 *         description: Stock insuffisant ou donnÃ©es invalides
 */
// POST /api/orders
router.post("/", authenticate, validate("createOrder"), async (req, res) => {
  try {
    const { items } = req.body;
    const clientId = req.user.id;

    let total = 0;
    for (const item of items) {
      const product = await pool.query(
        "SELECT price FROM products WHERE id = $1 AND organization_id = $2",
        [item.productId, req.user.organization_id],
      );
      if (product.rows.length > 0) {
        total += product.rows[0].price * item.quantity;
      }
    }

    if (total === 0) {
      return res.status(400).json({ error: "Aucun produit valide trouvÃ©" });
    }

    // GÃ©nÃ©rer numÃ©ro de commande sÃ©quentiel
    const seqResult = await pool.query(
      `INSERT INTO order_sequences(organization_id, last_number) 
       VALUES($1, 1) 
       ON CONFLICT(organization_id) 
       DO UPDATE SET last_number = order_sequences.last_number + 1 
       RETURNING last_number`,
      [req.user.organization_id],
    );
    const orderNumber = seqResult.rows[0].last_number;

    const orderResult = await pool.query(
      `INSERT INTO orders(organization_id, customer_id, date, total, status, payment_status, amount_paid, order_number) 
       VALUES($1, $2, NOW(), $3, 'pending', 'unpaid', 0, $4) RETURNING * `,
      [req.user.organization_id, clientId, total, orderNumber],
    );

    const order = orderResult.rows[0];

    for (const item of items) {
      const product = await pool.query(
        "SELECT price FROM products WHERE id = $1 AND organization_id = $2",
        [item.productId, req.user.organization_id],
      );
      if (product.rows.length > 0) {
        await pool.query(
          "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)",
          [order.id, item.productId, item.quantity, product.rows[0].price],
        );
      }
    }

    await logAudit(
      "ORDER_CREATED",
      req.user.id,
      req.user.organization_id,
      { orderId: order.id, total },
      req,
    );

    // VÃ©rifier limite de crÃ©dit (appel interne simplifiÃ©)
    try {
      const creditCheck = await pool.query(
        `SELECT u.credit_limit, COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) as debt
         FROM users u
         LEFT JOIN orders o ON u.id = o.customer_id AND o.organization_id = $2 AND o.total > o.amount_paid
         WHERE u.id = $1 GROUP BY u.id, u.credit_limit`,
        [req.user.id, req.user.organization_id],
      );

      if (creditCheck.rows.length > 0) {
        const { credit_limit, debt } = creditCheck.rows[0];
        const limit = parseFloat(credit_limit) || 0;
        const currentDebt = parseFloat(debt) || 0;

        if (limit > 0 && currentDebt >= limit * 0.8) {
          // Notification admin via service (ne bloque pas la commande)
          const ratio = Math.round((currentDebt / limit) * 100);
          logger.warn(
            `[CREDIT_ALERT] Customer ${req.user.id} at ${ratio}% of credit limit`,
            { customerId: req.user.id, ratio, debt: currentDebt, limit },
          );
        }
      }
    } catch (err) {
      logger.error("[CREDIT_CHECK] Error:", {
        error: err.message,
        stack: err.stack,
      });
    }

    const orderItems = await getOrderItems(order.id);
    res.json({ success: true, data: { ...order, items: orderItems } });
  } catch (error) {
    logger.error("Create order error:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: "Erreur serveur: " + error.message });
  }
});

// PUT /api/orders/:id
router.put(
  "/:id",
  authenticate,
  validateUUID("id"),
  validate("updateOrder"),
  async (req, res) => {
    try {
      const { items } = req.body;

      const orderCheck = await pool.query(
        `SELECT * FROM orders WHERE id = $1 AND customer_id = $2 AND organization_id = $3 AND status = 'pending'`,
        [req.params.id, req.user.id, req.user.organization_id],
      );

      if (orderCheck.rows.length === 0) {
        return res.status(403).json({ error: "Commande non modifiable" });
      }

      await pool.query("DELETE FROM order_items WHERE order_id = $1", [
        req.params.id,
      ]);

      let total = 0;
      for (const item of items) {
        const product = await pool.query(
          "SELECT price FROM products WHERE id = $1 AND organization_id = $2",
          [item.productId, req.user.organization_id],
        );
        if (product.rows.length > 0) {
          const price = product.rows[0].price;
          total += price * item.quantity;
          await pool.query(
            "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)",
            [req.params.id, item.productId, item.quantity, price],
          );
        }
      }

      await pool.query(
        "UPDATE orders SET total = $1, updated_at = NOW() WHERE id = $2",
        [total, req.params.id],
      );

      await logAudit(
        "ORDER_UPDATED",
        req.user.id,
        req.user.organization_id,
        { orderId: req.params.id, total },
        req,
      );

      // VÃ©rifier limite de crÃ©dit (appel interne simplifiÃ©)
      try {
        const creditCheck = await pool.query(
          `SELECT u.credit_limit, COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) as debt
           FROM users u
           LEFT JOIN orders o ON u.id = o.customer_id AND o.organization_id = $2 AND o.total > o.amount_paid
           WHERE u.id = $1 GROUP BY u.id, u.credit_limit`,
          [req.user.id, req.user.organization_id],
        );

        if (creditCheck.rows.length > 0) {
          const { credit_limit, debt } = creditCheck.rows[0];
          const limit = parseFloat(credit_limit) || 0;
          const currentDebt = parseFloat(debt) || 0;

          if (limit > 0 && currentDebt >= limit * 0.8) {
            const ratio = Math.round((currentDebt / limit) * 100);
            logger.warn(
              `[CREDIT_ALERT] Customer ${req.user.id} at ${ratio}% of credit limit`,
              {
                customerId: req.user.id,
                ratio,
                debt: currentDebt,
                limit,
              },
            );
          }
        }
      } catch (err) {
        logger.error("[CREDIT_CHECK] Error:", {
          error: err.message,
          stack: err.stack,
        });
      }

      const updatedItems = await getOrderItems(req.params.id);
      res.json({
        success: true,
        data: { id: req.params.id, total, items: updatedItems },
      });
    } catch (error) {
      logger.error("Update order error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// PUT /api/orders/:id/lock
router.put(
  "/:id/lock",
  authenticate,
  requireAdmin,
  validateUUID("id"),
  async (req, res) => {
    try {
      const orgResult = await pool.query(
        "SELECT kitchen_mode FROM organizations WHERE id = $1",
        [req.user.organization_id],
      );

      const kitchenMode = orgResult.rows[0]?.kitchen_mode || false;
      const newStatus = kitchenMode ? "validated" : "locked";

      await pool.query(
        `UPDATE orders SET status = $1, locked_at = NOW() 
       WHERE id = $2 AND organization_id = $3 AND status = 'pending'`,
        [newStatus, req.params.id, req.user.organization_id],
      );

      await logAudit(
        "ORDER_LOCKED",
        req.user.id,
        req.user.organization_id,
        { orderId: req.params.id, newStatus },
        req,
      );

      res.json({ success: true, status: newStatus });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// POST /api/orders/:id/assign
router.post(
  "/:id/assign",
  authenticate,
  requireAdmin,
  validateUUID("id"),
  validate("assignDeliverer"),
  async (req, res) => {
    try {
      const { delivererId } = req.body;

      const orderCheck = await pool.query(
        `SELECT * FROM orders WHERE id = $1 AND organization_id = $2 AND status IN('locked', 'ready')`,
        [req.params.id, req.user.organization_id],
      );

      if (orderCheck.rows.length === 0) {
        return res
          .status(400)
          .json({ error: "Commande non prÃªte pour assignation" });
      }

      const deliveryResult = await pool.query(
        `INSERT INTO deliveries(organization_id, order_id, deliverer_id, status) 
       VALUES($1, $2, $3, 'assigned') RETURNING * `,
        [req.user.organization_id, req.params.id, delivererId],
      );

      await pool.query(
        `UPDATE orders SET status = 'in_delivery' WHERE id = $1`,
        [req.params.id],
      );

      await logAudit(
        "ORDER_ASSIGNED",
        req.user.id,
        req.user.organization_id,
        { orderId: req.params.id, delivererId },
        req,
      );

      res.json({ success: true, data: deliveryResult.rows[0] });
    } catch (error) {
      logger.error("Assign error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// PUT /api/orders/:id/kitchen-status
router.put(
  "/:id/kitchen-status",
  authenticate,
  requireKitchen,
  validateUUID("id"),
  validate("kitchenStatus"),
  async (req, res) => {
    try {
      const { status } = req.body;

      const orderCheck = await pool.query(
        `SELECT status FROM orders WHERE id = $1 AND organization_id = $2`,
        [req.params.id, req.user.organization_id],
      );

      if (orderCheck.rows.length === 0) {
        return res.status(404).json({ error: "Commande non trouvÃ©e" });
      }

      const currentStatus = orderCheck.rows[0].status;

      if (status === "preparing" && currentStatus !== "validated") {
        return res.status(400).json({
          error:
            "La commande doit Ãªtre validÃ©e pour commencer la prÃ©paration",
        });
      }
      if (status === "ready" && currentStatus !== "preparing") {
        return res.status(400).json({
          error:
            "La commande doit Ãªtre en prÃ©paration pour Ãªtre marquÃ©e prÃªte",
        });
      }

      await pool.query(
        `UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2 AND organization_id = $3`,
        [status, req.params.id, req.user.organization_id],
      );

      await logAudit(
        "ORDER_KITCHEN_STATUS",
        req.user.id,
        req.user.organization_id,
        { orderId: req.params.id, status },
        req,
      );

      res.json({ success: true });
    } catch (error) {
      logger.error("Kitchen status error:", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

module.exports = router;
