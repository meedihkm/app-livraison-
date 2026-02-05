// =====================================================
// ROUTES : Gestion FinanciÃ¨re UnifiÃ©e
// Paiements + Dettes + Statistiques
// =====================================================

const express = require("express");
const router = express.Router();
const pool = require("../config/database");
const logger = require("../config/logger");
const { authenticate, authorize } = require("../middleware/auth");
const { validate, validateUUID } = require("../middleware/validate");
const { logAudit } = require("../services/audit.service");

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// HELPERS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function parseNumber(value, defaultValue = 0) {
  const parsed = parseFloat(value);
  return isNaN(parsed) ? defaultValue : parsed;
}

function logAction(action, details) {
  logger.info(`[FINANCIAL] ${action}`, details);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/overview
// Vue d'ensemble financiÃ¨re (Admin)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/overview",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    logAction("GET_OVERVIEW", { userId: req.user.id });

    try {
      const { dateFrom, dateTo } = req.query;
      const orgId = req.user.organization_id;

      // Construire les filtres de date
      let dateFilter = "";
      const params = [orgId];
      let paramIndex = 2;

      if (dateFrom) {
        params.push(dateFrom);
        dateFilter += ` AND o.created_at >= $${paramIndex++}`;
      }

      if (dateTo) {
        params.push(dateTo);
        dateFilter += ` AND o.created_at <= $${paramIndex++}`;
      }

      // Statistiques globales
      const statsResult = await pool.query(
        `SELECT 
        -- Revenus
        COALESCE(SUM(o.total), 0) as total_revenue,
        COALESCE(SUM(o.amount_paid), 0) as total_collected,
        COALESCE(SUM(o.total - o.amount_paid), 0) as total_unpaid,
        
        -- Compteurs de commandes
        COUNT(*) as total_orders,
        COUNT(*) FILTER (WHERE o.status = 'delivered') as delivered_orders,
        COUNT(*) FILTER (WHERE o.payment_status = 'paid') as paid_orders,
        COUNT(*) FILTER (WHERE o.payment_status = 'unpaid') as unpaid_orders,
        COUNT(*) FILTER (WHERE o.payment_status = 'partial') as partial_orders,
        
        -- Clients
        COUNT(DISTINCT o.customer_id) as total_customers,
        COUNT(DISTINCT o.customer_id) FILTER (WHERE o.total > o.amount_paid) as customers_with_debt
      FROM orders o
      WHERE o.organization_id = $1
        AND o.status != 'cancelled'
        ${dateFilter}`,
        params,
      );

      const stats = statsResult.rows[0];

      // Top 5 clients par CA
      const topClientsResult = await pool.query(
        `SELECT 
        u.id,
        u.name,
        u.phone,
        COALESCE(SUM(o.total), 0) as total_revenue,
        COALESCE(SUM(o.amount_paid), 0) as total_paid,
        COALESCE(SUM(o.total - o.amount_paid), 0) as total_debt,
        COUNT(o.id) as order_count
      FROM users u
      LEFT JOIN orders o ON u.id = o.customer_id 
        AND o.organization_id = $1
        AND o.status != 'cancelled'
        ${dateFilter}
      WHERE u.organization_id = $1
        AND u.role = 'customer'
        AND u.active = true
      GROUP BY u.id, u.name, u.phone
      HAVING COUNT(o.id) > 0
      ORDER BY total_revenue DESC
      LIMIT 5`,
        params,
      );

      // Stats par livreur
      const delivererStatsResult = await pool.query(
        `SELECT 
        u.id,
        u.name,
        COUNT(d.id) as total_deliveries,
        COUNT(d.id) FILTER (WHERE d.status = 'delivered') as delivered_count,
        COALESCE(SUM(o.amount_paid) FILTER (WHERE d.status = 'delivered'), 0) as amount_collected
      FROM users u
      LEFT JOIN deliveries d ON u.id = d.deliverer_id 
        AND d.organization_id = $1
        ${dateFrom ? `AND d.created_at >= $${paramIndex}` : ""}
        ${dateTo ? `AND d.created_at <= $${paramIndex + (dateFrom ? 1 : 0)}` : ""}
      LEFT JOIN orders o ON d.order_id = o.id
      WHERE u.role = 'deliverer'
        AND u.organization_id = $1
        AND u.active = true
      GROUP BY u.id, u.name
      ORDER BY delivered_count DESC`,
        params,
      );

      logAction("GET_OVERVIEW_SUCCESS", { stats });

      res.json({
        success: true,
        data: {
          summary: {
            totalRevenue: parseNumber(stats.total_revenue),
            totalCollected: parseNumber(stats.total_collected),
            totalUnpaid: parseNumber(stats.total_unpaid),
            totalOrders: parseInt(stats.total_orders),
            deliveredOrders: parseInt(stats.delivered_orders),
            paidOrders: parseInt(stats.paid_orders),
            unpaidOrders: parseInt(stats.unpaid_orders),
            partialOrders: parseInt(stats.partial_orders),
            totalCustomers: parseInt(stats.total_customers),
            customersWithDebt: parseInt(stats.customers_with_debt),
          },
          topClients: topClientsResult.rows.map((row) => ({
            id: row.id,
            name: row.name,
            phone: row.phone,
            totalRevenue: parseNumber(row.total_revenue),
            totalPaid: parseNumber(row.total_paid),
            totalDebt: parseNumber(row.total_debt),
            orderCount: parseInt(row.order_count),
          })),
          delivererStats: delivererStatsResult.rows.map((row) => ({
            id: row.id,
            name: row.name,
            totalDeliveries: parseInt(row.total_deliveries),
            deliveredCount: parseInt(row.delivered_count),
            amountCollected: parseNumber(row.amount_collected),
          })),
        },
      });
    } catch (error) {
      logAction("GET_OVERVIEW_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/debts
// Liste des clients avec dette
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/debts",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    logAction("GET_DEBTS", { userId: req.user.id, query: req.query });

    try {
      const page = parseInt(req.query.page) || 1;
      const limit = Math.min(parseInt(req.query.limit) || 50, 100);
      const offset = (page - 1) * limit;
      const minDebt = parseNumber(req.query.minDebt, 0);
      const customerId = req.query.customerId || null;
      const delivererId =
        req.user.role === "deliverer"
          ? req.user.id
          : req.query.delivererId || null;

      // Construction de la requÃªte
      let whereClause =
        "WHERE o.organization_id = $1 AND o.total > o.amount_paid AND o.status != 'cancelled'";
      const params = [req.user.organization_id];
      let paramIndex = 2;

      if (customerId) {
        params.push(customerId);
        whereClause += ` AND o.customer_id = $${paramIndex++}`;
      }

      if (delivererId) {
        params.push(delivererId);
        whereClause += ` AND EXISTS (
        SELECT 1 FROM deliveries d 
        WHERE d.order_id = o.id AND d.deliverer_id = $${paramIndex++}
      )`;
      }

      // Compter le total
      const countResult = await pool.query(
        `SELECT COUNT(DISTINCT o.customer_id) as count
      FROM orders o
      ${whereClause}`,
        params,
      );
      const total = parseInt(countResult.rows[0].count);

      // RÃ©cupÃ©rer les dettes
      const result = await pool.query(
        `SELECT 
        u.id as customer_id,
        u.name,
        u.email,
        u.phone,
        COUNT(o.id) as unpaid_orders,
        COALESCE(SUM(o.total - o.amount_paid), 0) as total_debt,
        MAX(o.created_at) as last_order_date
      FROM orders o
      JOIN users u ON o.customer_id = u.id
      ${whereClause}
      GROUP BY u.id, u.name, u.email, u.phone
      HAVING COALESCE(SUM(o.total - o.amount_paid), 0) >= $${paramIndex}
      ORDER BY total_debt DESC
      LIMIT $${paramIndex + 1} OFFSET $${paramIndex + 2}`,
        [...params, minDebt, limit, offset],
      );

      logAction("GET_DEBTS_SUCCESS", { count: result.rows.length, total });

      res.json({
        success: true,
        data: result.rows.map((row) => ({
          id: row.customer_id, // Ajouté pour compatibilité mobile
          customerId: row.customer_id,
          name: row.name || "", // Garantir non-null
          email: row.email || "", // Garantir non-null
          phone: row.phone || "", // Garantir non-null
          unpaidOrders: parseInt(row.unpaid_orders),
          totalDebt: parseNumber(row.total_debt),
          lastOrderDate: row.last_order_date,
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      logAction("GET_DEBTS_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/debts/:customerId
// DÃ©tail de la dette d'un client
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/debts/:customerId",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    logAction("GET_CUSTOMER_DEBT", { customerId: req.params.customerId });

    try {
      const { customerId } = req.params;

      // VÃ©rifier que le client existe
      const customerCheck = await pool.query(
        "SELECT id, name, email, phone FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
        [customerId, req.user.organization_id],
      );

      if (customerCheck.rows.length === 0) {
        return res.status(404).json({ error: "Client non trouvÃ©" });
      }

      const customer = customerCheck.rows[0];

      // RÃ©cupÃ©rer les commandes impayÃ©es
      const ordersResult = await pool.query(
        `SELECT 
        o.id,
        o.order_number,
        o.created_at,
        o.total,
        o.amount_paid,
        (o.total - o.amount_paid) as remaining,
        o.status,
        o.payment_status
      FROM orders o
      WHERE o.customer_id = $1 
        AND o.organization_id = $2 
        AND o.total > o.amount_paid
        AND o.status != 'cancelled'
      ORDER BY o.created_at ASC`,
        [customerId, req.user.organization_id],
      );

      const totalDebt = ordersResult.rows.reduce(
        (sum, order) => sum + parseNumber(order.remaining),
        0,
      );

      logAction("GET_CUSTOMER_DEBT_SUCCESS", { customerId, totalDebt });

      res.json({
        success: true,
        data: {
          customer: {
            id: customer.id,
            name: customer.name,
            email: customer.email,
            phone: customer.phone,
          },
          totalDebt,
          unpaidOrders: ordersResult.rows.map((order) => ({
            id: order.id,
            orderNumber: order.order_number,
            date: order.created_at,
            total: parseNumber(order.total),
            amountPaid: parseNumber(order.amount_paid),
            remaining: parseNumber(order.remaining),
            status: order.status,
            paymentStatus: order.payment_status,
          })),
        },
      });
    } catch (error) {
      logAction("GET_CUSTOMER_DEBT_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/financial/payments
// Enregistrer un paiement
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post(
  "/payments",
  authenticate,
  authorize(["admin", "deliverer"]),
  validate("recordPayment"),
  async (req, res) => {
    logAction("RECORD_PAYMENT", { userId: req.user.id, body: req.body });

    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      const {
        customerId,
        amount,
        mode = "cash",
        notes,
        targetOrders,
      } = req.body;

      // Validation
      if (!customerId || !amount || amount <= 0) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "DonnÃ©es invalides" });
      }

      // VÃ©rifier le client
      const customerCheck = await client.query(
        "SELECT id, name FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
        [customerId, req.user.organization_id],
      );

      if (customerCheck.rows.length === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ error: "Client non trouvÃ©" });
      }

      const customer = customerCheck.rows[0];

      // Calculer la dette actuelle
      const debtResult = await client.query(
        `SELECT COALESCE(SUM(total - amount_paid), 0) as current_debt
       FROM orders
       WHERE customer_id = $1 AND organization_id = $2 AND total > amount_paid AND status != 'cancelled'`,
        [customerId, req.user.organization_id],
      );

      const currentDebt = parseNumber(debtResult.rows[0].current_debt);

      if (currentDebt === 0) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "Ce client n'a pas de dette" });
      }

      if (amount > currentDebt) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          error: `Le montant (${amount} DA) est supÃ©rieur Ã  la dette (${currentDebt} DA)`,
        });
      }

      // Appliquer le paiement aux commandes (FIFO)
      let remainingAmount = amount;
      const affectedOrders = [];

      const ordersToUpdate =
        targetOrders && targetOrders.length > 0
          ? await client.query(
              `SELECT id, total, amount_paid, (total - amount_paid) as remaining
           FROM orders
           WHERE id = ANY($1) AND customer_id = $2 AND organization_id = $3 AND total > amount_paid
           ORDER BY created_at ASC`,
              [targetOrders, customerId, req.user.organization_id],
            )
          : await client.query(
              `SELECT id, total, amount_paid, (total - amount_paid) as remaining
           FROM orders
           WHERE customer_id = $1 AND organization_id = $2 AND total > amount_paid AND status != 'cancelled'
           ORDER BY created_at ASC`,
              [customerId, req.user.organization_id],
            );

      for (const order of ordersToUpdate.rows) {
        if (remainingAmount <= 0) break;

        const orderRemaining = parseNumber(order.remaining);
        const paymentForOrder = Math.min(remainingAmount, orderRemaining);
        const newAmountPaid = parseNumber(order.amount_paid) + paymentForOrder;
        const newPaymentStatus =
          newAmountPaid >= parseNumber(order.total) ? "paid" : "partial";

        await client.query(
          `UPDATE orders 
         SET amount_paid = $1, payment_status = $2, updated_at = NOW()
         WHERE id = $3`,
          [newAmountPaid, newPaymentStatus, order.id],
        );

        affectedOrders.push({
          orderId: order.id,
          amountApplied: paymentForOrder,
          newStatus: newPaymentStatus,
        });

        remainingAmount -= paymentForOrder;
      }

      // Enregistrer dans l'audit
      await logAudit({
        action: "PAYMENT_RECORDED",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "payment",
        targetId: customerId,
        details: {
          customerId,
          customerName: customer.name,
          amount,
          mode,
          debtBefore: currentDebt,
          debtAfter: currentDebt - amount,
          ordersAffected: affectedOrders.length,
        },
      });

      await client.query("COMMIT");

      const newDebt = currentDebt - amount;

      logAction("RECORD_PAYMENT_SUCCESS", {
        customerId,
        amount,
        ordersAffected: affectedOrders.length,
      });

      res.status(201).json({
        success: true,
        data: {
          customerId,
          customerName: customer.name,
          amount,
          mode,
          debtBefore: currentDebt,
          debtAfter: newDebt,
          ordersAffected: affectedOrders,
        },
      });
    } catch (error) {
      await client.query("ROLLBACK");
      logAction("RECORD_PAYMENT_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur: " + error.message });
    } finally {
      client.release();
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/credit/:customerId
// Statut crÃ©dit d'un client
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/credit/:customerId",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    logAction("GET_CREDIT_STATUS", { customerId: req.params.customerId });

    try {
      const { customerId } = req.params;

      // RÃ©cupÃ©rer limite et dette
      const result = await pool.query(
        `SELECT 
        u.id,
        u.name,
        u.email,
        u.phone,
        u.credit_limit,
        COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) as current_debt
      FROM users u
      LEFT JOIN orders o ON u.id = o.customer_id 
        AND o.organization_id = $2 
        AND o.total > o.amount_paid
        AND o.status != 'cancelled'
      WHERE u.id = $1 AND u.organization_id = $2
      GROUP BY u.id, u.name, u.email, u.phone, u.credit_limit`,
        [customerId, req.user.organization_id],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: "Client non trouvÃ©" });
      }

      const row = result.rows[0];
      const debt = parseNumber(row.current_debt);
      const limit = parseNumber(row.credit_limit);

      let status = "ok";
      let level = null;
      let ratio = 0;

      if (limit > 0) {
        ratio = Math.round((debt / limit) * 100);

        if (ratio >= 120) {
          status = "critical";
          level = "urgent";
        } else if (ratio >= 100) {
          status = "over_limit";
          level = "warning";
        } else if (ratio >= 80) {
          status = "approaching";
          level = "info";
        }
      } else {
        status = "no_limit";
      }

      logAction("GET_CREDIT_STATUS_SUCCESS", { customerId, status, ratio });

      res.json({
        success: true,
        data: {
          customer: {
            id: row.id,
            name: row.name,
            email: row.email,
            phone: row.phone,
          },
          credit: {
            limit,
            used: debt,
            available: Math.max(0, limit - debt),
            ratio,
            status,
            level,
          },
        },
      });
    } catch (error) {
      logAction("GET_CREDIT_STATUS_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PUT /api/financial/credit/:customerId/limit
// Modifier la limite de crÃ©dit
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.put(
  "/credit/:customerId/limit",
  authenticate,
  authorize(["admin"]),
  validateUUID("customerId"),
  validate("updateCreditLimit"),
  async (req, res) => {
    logAction("UPDATE_CREDIT_LIMIT", {
      customerId: req.params.customerId,
      body: req.body,
    });

    try {
      const { customerId } = req.params;
      const { limit } = req.body;

      if (limit === undefined || limit < 0) {
        return res.status(400).json({ error: "Limite invalide" });
      }

      // VÃ©rifier que le client existe
      const customerCheck = await pool.query(
        "SELECT id, name FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
        [customerId, req.user.organization_id],
      );

      if (customerCheck.rows.length === 0) {
        return res.status(404).json({ error: "Client non trouvÃ©" });
      }

      // Mettre Ã  jour la limite
      await pool.query(
        "UPDATE users SET credit_limit = $1, updated_at = NOW() WHERE id = $2",
        [limit, customerId],
      );

      // Logger l'audit
      await logAudit({
        action: "CREDIT_LIMIT_UPDATED",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "customer",
        targetId: customerId,
        details: { newLimit: limit },
      });

      logAction("UPDATE_CREDIT_LIMIT_SUCCESS", { customerId, limit });

      res.json({
        success: true,
        data: {
          customerId,
          customerName: customerCheck.rows[0].name,
          newLimit: limit,
        },
      });
    } catch (error) {
      logAction("UPDATE_CREDIT_LIMIT_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/credit/alerts
// Liste des clients en alerte crÃ©dit
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/credit/alerts",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    logAction("GET_CREDIT_ALERTS", { userId: req.user.id });

    try {
      const result = await pool.query(
        `SELECT 
        u.id,
        u.name,
        u.email,
        u.phone,
        u.credit_limit,
        COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) as current_debt,
        ROUND((COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) / NULLIF(u.credit_limit, 0)) * 100) as ratio
      FROM users u
      LEFT JOIN orders o ON u.id = o.customer_id 
        AND o.organization_id = $1 
        AND o.total > o.amount_paid
        AND o.status != 'cancelled'
      WHERE u.organization_id = $1 
        AND u.role = 'customer'
        AND u.credit_limit > 0
      GROUP BY u.id, u.name, u.email, u.phone, u.credit_limit
      HAVING COALESCE(SUM(o.total) - SUM(o.amount_paid), 0) >= (u.credit_limit * 0.8)
      ORDER BY ratio DESC`,
        [req.user.organization_id],
      );

      const alerts = result.rows.map((row) => {
        const debt = parseNumber(row.current_debt);
        const limit = parseNumber(row.credit_limit);
        const ratio = parseInt(row.ratio) || 0;

        let status = "approaching";
        let level = "info";

        if (ratio >= 120) {
          status = "critical";
          level = "urgent";
        } else if (ratio >= 100) {
          status = "over_limit";
          level = "warning";
        }

        return {
          customer: {
            id: row.id,
            name: row.name,
            email: row.email,
            phone: row.phone,
          },
          credit: {
            limit,
            used: debt,
            available: Math.max(0, limit - debt),
            ratio,
            status,
            level,
          },
        };
      });

      logAction("GET_CREDIT_ALERTS_SUCCESS", { count: alerts.length });

      res.json({
        success: true,
        data: alerts,
      });
    } catch (error) {
      logAction("GET_CREDIT_ALERTS_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/payments/my-collections
// RÃ©cupÃ¨re les paiements collectÃ©s par le livreur connectÃ©
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/payments/my-collections",
  authenticate,
  authorize(["deliverer"]),
  async (req, res) => {
    logAction("GET_MY_COLLECTIONS", { userId: req.user.id });

    try {
      // RÃ©cupÃ©rer les paiements enregistrÃ©s par ce livreur via l'audit
      const result = await pool.query(
        `SELECT 
          al.created_at,
          al.details->>'customerId' as customer_id,
          al.details->>'customerName' as client_name,
          (al.details->>'amount')::numeric as amount,
          al.details->>'mode' as mode
        FROM audit_logs al
        WHERE al.action = 'PAYMENT_RECORDED'
          AND al.user_id = $1
          AND al.organization_id = $2
          AND DATE(al.created_at) = CURRENT_DATE
        ORDER BY al.created_at DESC`,
        [req.user.id, req.user.organization_id],
      );

      logAction("GET_MY_COLLECTIONS_SUCCESS", { count: result.rows.length });

      res.json({
        success: true,
        data: result.rows.map((row) => ({
          created_at: row.created_at, // Format snake_case pour mobile
          createdAt: row.created_at,
          customerId: row.customer_id || "",
          client_name: row.client_name || "", // Format snake_case pour mobile
          clientName: row.client_name || "",
          amount: parseNumber(row.amount),
          mode: row.mode || "cash",
        })),
      });
    } catch (error) {
      logAction("GET_MY_COLLECTIONS_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// ====================================================================
// GET /api/financial/payments/history
// Historique complet des paiements (Admin)
// ====================================================================
router.get(
  "/payments/history",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    logAction("GET_PAYMENTS_HISTORY", {
      userId: req.user.id,
      query: req.query,
    });

    try {
      const page = parseInt(req.query.page) || 1;
      const limit = Math.min(parseInt(req.query.limit) || 50, 100);
      const offset = (page - 1) * limit;
      const { dateFrom, dateTo, customerId, delivererId } = req.query;

      // Construction des filtres
      let whereClause =
        "WHERE al.action = 'PAYMENT_RECORDED' AND al.organization_id = $1";
      const params = [req.user.organization_id];
      let paramIndex = 2;

      if (dateFrom) {
        params.push(dateFrom);
        whereClause += ` AND DATE(al.created_at) >= $${paramIndex++}`;
      }

      if (dateTo) {
        params.push(dateTo);
        whereClause += ` AND DATE(al.created_at) <= $${paramIndex++}`;
      }

      if (customerId) {
        params.push(customerId);
        whereClause += ` AND al.details->>'customerId' = $${paramIndex++}`;
      }

      if (delivererId) {
        params.push(delivererId);
        whereClause += ` AND al.user_id = $${paramIndex++}`;
      }

      // Compter le total
      const countResult = await pool.query(
        `SELECT COUNT(*) as count FROM audit_logs al ${whereClause}`,
        params,
      );
      const total = parseInt(countResult.rows[0].count);

      // Récupérer les paiements
      const result = await pool.query(
        `SELECT 
          al.id,
          al.created_at,
          al.user_id,
          u.name as recorded_by,
          al.details->>'customerId' as customer_id,
          al.details->>'customerName' as customer_name,
          (al.details->>'amount')::numeric as amount,
          al.details->>'mode' as mode,
          (al.details->>'debtBefore')::numeric as debt_before,
          (al.details->>'debtAfter')::numeric as debt_after,
          (al.details->>'ordersAffected')::int as orders_affected
        FROM audit_logs al
        LEFT JOIN users u ON al.user_id = u.id
        ${whereClause}
        ORDER BY al.created_at DESC
        LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
        [...params, limit, offset],
      );

      logAction("GET_PAYMENTS_HISTORY_SUCCESS", {
        count: result.rows.length,
        total,
      });

      res.json({
        success: true,
        data: result.rows.map((row) => ({
          id: row.id,
          createdAt: row.created_at,
          recordedBy: {
            id: row.user_id,
            name: row.recorded_by || "Inconnu",
          },
          customer: {
            id: row.customer_id || "",
            name: row.customer_name || "",
          },
          amount: parseNumber(row.amount),
          mode: row.mode || "cash",
          debtBefore: parseNumber(row.debt_before),
          debtAfter: parseNumber(row.debt_after),
          ordersAffected: parseInt(row.orders_affected) || 0,
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      logAction("GET_PAYMENTS_HISTORY_ERROR", {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

module.exports = router;
