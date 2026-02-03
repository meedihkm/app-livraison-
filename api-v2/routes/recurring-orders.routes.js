// =====================================================
// ROUTES : Commandes RÃ©currentes (RefactorisÃ©)
// Architecture propre avec logs et validation
// =====================================================

const express = require("express");
const router = express.Router();
const pool = require("../config/database");
const { authenticate, authorize } = require("../middleware/auth");
const { validateUUID } = require("../middleware/validate");
const { logAudit } = require("../services/audit.service");

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// HELPERS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Log une action avec contexte
 */
function logAction(action, details) {
  console.log(
    `[RECURRING_ORDERS] ${action}:`,
    JSON.stringify(details, null, 2),
  );
}

/**
 * Valide les donnÃ©es de commande rÃ©currente
 */
function validateRecurringOrderData(data) {
  const errors = [];

  if (
    !data.frequency ||
    !["daily", "weekly", "monthly"].includes(data.frequency)
  ) {
    errors.push("frequency doit Ãªtre daily, weekly ou monthly");
  }

  if (
    data.frequency === "weekly" &&
    (data.dayOfWeek < 0 || data.dayOfWeek > 6)
  ) {
    errors.push("dayOfWeek doit Ãªtre entre 0 (dimanche) et 6 (samedi)");
  }

  if (
    data.frequency === "monthly" &&
    (data.dayOfMonth < 1 || data.dayOfMonth > 31)
  ) {
    errors.push("dayOfMonth doit Ãªtre entre 1 et 31");
  }

  if (!data.items || !Array.isArray(data.items) || data.items.length === 0) {
    errors.push("items doit contenir au moins un produit");
  }

  return errors;
}

/**
 * Formate une commande rÃ©currente pour la rÃ©ponse
 */
function formatRecurringOrder(row) {
  return {
    id: row.id,
    organizationId: row.organization_id,
    customerId: row.customer_id,
    name: row.name,
    frequency: row.frequency,
    dayOfWeek: row.day_of_week,
    dayOfMonth: row.day_of_month,
    timeOfDay: row.time_of_day,
    active: row.active,
    lastExecuted: row.last_executed,
    nextExecution: row.next_execution,
    createdAt: row.created_at,
    items: row.items || [],
  };
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/recurring-orders
// Liste les commandes rÃ©currentes du client connectÃ©
// Accessible par : customer
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get("/", authenticate, authorize(["customer"]), async (req, res) => {
  logAction("GET_RECURRING_ORDERS", {
    userId: req.user.id,
    role: req.user.role,
  });

  try {
    const result = await pool.query(
      `SELECT ro.*, 
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      WHERE ro.customer_id = $1::uuid 
        AND ro.organization_id = $2::uuid
      ORDER BY ro.created_at DESC`,
      [req.user.id, req.user.organization_id],
    );

    logAction("GET_RECURRING_ORDERS_SUCCESS", {
      count: result.rows.length,
    });

    res.json({
      success: true,
      data: result.rows.map(formatRecurringOrder),
    });
  } catch (error) {
    logAction("GET_RECURRING_ORDERS_ERROR", { error: error.message });
    console.error("[RECURRING_ORDERS] Error:", error);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/recurring-orders/:id
// RÃ©cupÃ¨re une commande rÃ©currente par ID
// Accessible par : customer, admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/:id",
  authenticate,
  authorize(["customer", "admin"]),
  validateUUID("id"),
  async (req, res) => {
    logAction("GET_RECURRING_ORDER", {
      orderId: req.params.id,
      userId: req.user.id,
    });

    try {
      const result = await pool.query(
        `SELECT ro.*, 
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      WHERE ro.id = $1::uuid 
        AND ro.organization_id = $2::uuid`,
        [req.params.id, req.user.organization_id],
      );

      if (result.rows.length === 0) {
        logAction("GET_RECURRING_ORDER_NOT_FOUND", { orderId: req.params.id });
        return res
          .status(404)
          .json({ error: "Commande rÃ©currente non trouvÃ©e" });
      }

      const order = result.rows[0];

      // VÃ©rifier l'accÃ¨s
      if (req.user.role !== "admin" && order.customer_id !== req.user.id) {
        logAction("GET_RECURRING_ORDER_FORBIDDEN", {
          orderId: req.params.id,
          userId: req.user.id,
        });
        return res.status(403).json({ error: "AccÃ¨s non autorisÃ©" });
      }

      logAction("GET_RECURRING_ORDER_SUCCESS", { orderId: req.params.id });

      res.json({
        success: true,
        data: formatRecurringOrder(order),
      });
    } catch (error) {
      logAction("GET_RECURRING_ORDER_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/recurring-orders
// CrÃ©e une nouvelle commande rÃ©currente
// Accessible par : customer, admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post(
  "/",
  authenticate,
  authorize(["customer", "admin"]),
  async (req, res) => {
    const startTime = Date.now();
    logAction("CREATE_RECURRING_ORDER", {
      userId: req.user.id,
      role: req.user.role,
      body: req.body,
    });

    try {
      const {
        name,
        frequency,
        dayOfWeek,
        dayOfMonth,
        timeOfDay,
        items,
        customerId,
      } = req.body;

      // Validation
      const validationErrors = validateRecurringOrderData({
        frequency,
        dayOfWeek,
        dayOfMonth,
        items,
      });
      if (validationErrors.length > 0) {
        logAction("CREATE_RECURRING_ORDER_VALIDATION_ERROR", {
          errors: validationErrors,
        });
        return res.status(400).json({ error: validationErrors.join(", ") });
      }

      // DÃ©terminer le customerId
      const targetCustomerId =
        req.user.role === "admin" && customerId ? customerId : req.user.id;

      // VÃ©rifier que le client existe
      if (req.user.role === "admin" && customerId) {
        const customerCheck = await pool.query(
          "SELECT id FROM users WHERE id = $1::uuid AND organization_id = $2::uuid AND role = $3",
          [customerId, req.user.organization_id, "customer"],
        );

        if (customerCheck.rows.length === 0) {
          logAction("CREATE_RECURRING_ORDER_CUSTOMER_NOT_FOUND", {
            customerId,
          });
          return res.status(404).json({ error: "Client non trouvÃ©" });
        }
      }

      // CrÃ©er la commande rÃ©currente
      const orderResult = await pool.query(
        `INSERT INTO recurring_orders (
        organization_id, customer_id, name, frequency, 
        day_of_week, day_of_month, time_of_day, active
      ) VALUES ($1::text, $2::text, $3, $4, $5, $6, $7, true)
      RETURNING id, created_at`,
        [
          req.user.organization_id,
          targetCustomerId,
          name || `Commande ${frequency}`,
          frequency,
          dayOfWeek || null,
          dayOfMonth || null,
          timeOfDay || "08:00",
        ],
      );

      const orderId = orderResult.rows[0].id;

      // Ajouter les items
      for (const item of items) {
        await pool.query(
          `INSERT INTO recurring_order_items (
          recurring_order_id, product_id, quantity
        ) VALUES ($1::text, $2::text, $3)`,
          [orderId, item.productId, item.quantity],
        );
      }

      // RÃ©cupÃ©rer la commande complÃ¨te
      const completeOrder = await pool.query(
        `SELECT ro.*, 
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      WHERE ro.id = $1::uuid`,
        [orderId],
      );

      // Logger l'audit
      await logAudit({
        action: "CREATE_RECURRING_ORDER",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "recurring_order",
        targetId: orderId,
        details: {
          name,
          frequency,
          itemsCount: items.length,
          customerId: targetCustomerId,
        },
      });

      const duration = Date.now() - startTime;
      logAction("CREATE_RECURRING_ORDER_SUCCESS", {
        orderId,
        duration: `${duration}ms`,
      });

      res.status(201).json({
        success: true,
        data: formatRecurringOrder(completeOrder.rows[0]),
      });
    } catch (error) {
      logAction("CREATE_RECURRING_ORDER_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PUT /api/recurring-orders/:id
// Met Ã  jour une commande rÃ©currente
// Accessible par : customer, admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.put(
  "/:id",
  authenticate,
  authorize(["customer", "admin"]),
  validateUUID("id"),
  async (req, res) => {
    logAction("UPDATE_RECURRING_ORDER", {
      orderId: req.params.id,
      userId: req.user.id,
      body: req.body,
    });

    try {
      // VÃ©rifier que la commande existe et l'accÃ¨s
      const existing = await pool.query(
        "SELECT * FROM recurring_orders WHERE id = $1::uuid AND organization_id = $2::uuid",
        [req.params.id, req.user.organization_id],
      );

      if (existing.rows.length === 0) {
        logAction("UPDATE_RECURRING_ORDER_NOT_FOUND", {
          orderId: req.params.id,
        });
        return res
          .status(404)
          .json({ error: "Commande rÃ©currente non trouvÃ©e" });
      }

      const order = existing.rows[0];

      if (req.user.role !== "admin" && order.customer_id !== req.user.id) {
        logAction("UPDATE_RECURRING_ORDER_FORBIDDEN", {
          orderId: req.params.id,
          userId: req.user.id,
        });
        return res.status(403).json({ error: "AccÃ¨s non autorisÃ©" });
      }

      const { name, frequency, dayOfWeek, dayOfMonth, timeOfDay, items } =
        req.body;

      // Validation si frequency est modifiÃ©e
      if (frequency) {
        const validationErrors = validateRecurringOrderData({
          frequency,
          dayOfWeek,
          dayOfMonth,
          items: items || [{}],
        });
        if (
          validationErrors.length > 0 &&
          validationErrors.some((e) => e.includes("frequency"))
        ) {
          logAction("UPDATE_RECURRING_ORDER_VALIDATION_ERROR", {
            errors: validationErrors,
          });
          return res.status(400).json({ error: validationErrors.join(", ") });
        }
      }

      // Mettre Ã  jour la commande
      await pool.query(
        `UPDATE recurring_orders 
       SET name = COALESCE($1, name),
           frequency = COALESCE($2, frequency),
           day_of_week = COALESCE($3, day_of_week),
           day_of_month = COALESCE($4, day_of_month),
           time_of_day = COALESCE($5, time_of_day),
           updated_at = NOW()
       WHERE id = $6::uuid`,
        [name, frequency, dayOfWeek, dayOfMonth, timeOfDay, req.params.id],
      );

      // Mettre Ã  jour les items si fournis
      if (items && items.length > 0) {
        // Supprimer les anciens items
        await pool.query(
          "DELETE FROM recurring_order_items WHERE recurring_order_id = $1::uuid",
          [req.params.id],
        );

        // Ajouter les nouveaux items
        for (const item of items) {
          await pool.query(
            `INSERT INTO recurring_order_items (
            recurring_order_id, product_id, quantity
          ) VALUES ($1::text, $2::text, $3)`,
            [req.params.id, item.productId, item.quantity],
          );
        }
      }

      // RÃ©cupÃ©rer la commande mise Ã  jour
      const updated = await pool.query(
        `SELECT ro.*, 
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      WHERE ro.id = $1::uuid`,
        [req.params.id],
      );

      // Logger l'audit
      await logAudit({
        action: "UPDATE_RECURRING_ORDER",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "recurring_order",
        targetId: req.params.id,
        details: req.body,
      });

      logAction("UPDATE_RECURRING_ORDER_SUCCESS", { orderId: req.params.id });

      res.json({
        success: true,
        data: formatRecurringOrder(updated.rows[0]),
      });
    } catch (error) {
      logAction("UPDATE_RECURRING_ORDER_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// DELETE /api/recurring-orders/:id
// Supprime une commande rÃ©currente
// Accessible par : customer, admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.delete(
  "/:id",
  authenticate,
  authorize(["customer", "admin"]),
  validateUUID("id"),
  async (req, res) => {
    logAction("DELETE_RECURRING_ORDER", {
      orderId: req.params.id,
      userId: req.user.id,
    });

    try {
      // VÃ©rifier que la commande existe et l'accÃ¨s
      const existing = await pool.query(
        "SELECT * FROM recurring_orders WHERE id = $1::uuid AND organization_id = $2::uuid",
        [req.params.id, req.user.organization_id],
      );

      if (existing.rows.length === 0) {
        logAction("DELETE_RECURRING_ORDER_NOT_FOUND", {
          orderId: req.params.id,
        });
        return res
          .status(404)
          .json({ error: "Commande rÃ©currente non trouvÃ©e" });
      }

      const order = existing.rows[0];

      if (req.user.role !== "admin" && order.customer_id !== req.user.id) {
        logAction("DELETE_RECURRING_ORDER_FORBIDDEN", {
          orderId: req.params.id,
          userId: req.user.id,
        });
        return res.status(403).json({ error: "AccÃ¨s non autorisÃ©" });
      }

      // Supprimer les items
      await pool.query(
        "DELETE FROM recurring_order_items WHERE recurring_order_id = $1::uuid",
        [req.params.id],
      );

      // Supprimer la commande
      await pool.query("DELETE FROM recurring_orders WHERE id = $1::uuid", [
        req.params.id,
      ]);

      // Logger l'audit
      await logAudit({
        action: "DELETE_RECURRING_ORDER",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "recurring_order",
        targetId: req.params.id,
      });

      logAction("DELETE_RECURRING_ORDER_SUCCESS", { orderId: req.params.id });

      res.json({
        success: true,
        message: "Commande rÃ©currente supprimÃ©e",
      });
    } catch (error) {
      logAction("DELETE_RECURRING_ORDER_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/recurring-orders/:id/toggle
// Active/dÃ©sactive une commande rÃ©currente
// Accessible par : customer, admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post(
  "/:id/toggle",
  authenticate,
  authorize(["customer", "admin"]),
  validateUUID("id"),
  async (req, res) => {
    logAction("TOGGLE_RECURRING_ORDER", {
      orderId: req.params.id,
      userId: req.user.id,
    });

    try {
      // VÃ©rifier que la commande existe et l'accÃ¨s
      const existing = await pool.query(
        "SELECT * FROM recurring_orders WHERE id = $1::uuid AND organization_id = $2::uuid",
        [req.params.id, req.user.organization_id],
      );

      if (existing.rows.length === 0) {
        logAction("TOGGLE_RECURRING_ORDER_NOT_FOUND", {
          orderId: req.params.id,
        });
        return res
          .status(404)
          .json({ error: "Commande rÃ©currente non trouvÃ©e" });
      }

      const order = existing.rows[0];

      if (req.user.role !== "admin" && order.customer_id !== req.user.id) {
        logAction("TOGGLE_RECURRING_ORDER_FORBIDDEN", {
          orderId: req.params.id,
          userId: req.user.id,
        });
        return res.status(403).json({ error: "AccÃ¨s non autorisÃ©" });
      }

      // Toggle active
      const newActive = !order.active;
      await pool.query(
        "UPDATE recurring_orders SET active = $1, updated_at = NOW() WHERE id = $2::uuid",
        [newActive, req.params.id],
      );

      // RÃ©cupÃ©rer la commande mise Ã  jour
      const updated = await pool.query(
        `SELECT ro.*, 
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      WHERE ro.id = $1::uuid`,
        [req.params.id],
      );

      // Logger l'audit
      await logAudit({
        action: newActive ? "RESUME_RECURRING_ORDER" : "PAUSE_RECURRING_ORDER",
        performedBy: req.user.id,
        organizationId: req.user.organization_id,
        targetType: "recurring_order",
        targetId: req.params.id,
      });

      logAction("TOGGLE_RECURRING_ORDER_SUCCESS", {
        orderId: req.params.id,
        newActive,
      });

      res.json({
        success: true,
        data: formatRecurringOrder(updated.rows[0]),
      });
    } catch (error) {
      logAction("TOGGLE_RECURRING_ORDER_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/recurring-orders/admin/all
// Admin: Liste toutes les commandes rÃ©currentes
// Accessible par : admin
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/admin/all",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    logAction("GET_ALL_RECURRING_ORDERS", {
      userId: req.user.id,
      query: req.query,
    });

    try {
      const active = req.query.active;
      let whereClause = "WHERE ro.organization_id = $1::uuid";
      const params = [req.user.organization_id];

      if (active !== undefined) {
        params.push(active === "true");
        whereClause += " AND ro.active = $2";
      }

      const result = await pool.query(
        `SELECT ro.*, 
        u.name as customer_name,
        (SELECT json_agg(json_build_object(
          'id', roi.id,
          'productId', roi.product_id,
          'productName', p.name,
          'quantity', roi.quantity
        )) FROM recurring_order_items roi 
        JOIN products p ON roi.product_id = p.id
        WHERE roi.recurring_order_id = ro.id) as items
      FROM recurring_orders ro
      JOIN users u ON ro.customer_id = u.id
      ${whereClause}
      ORDER BY ro.created_at DESC`,
        params,
      );

      logAction("GET_ALL_RECURRING_ORDERS_SUCCESS", {
        count: result.rows.length,
      });

      res.json({
        success: true,
        data: result.rows.map((row) => ({
          ...formatRecurringOrder(row),
          customerName: row.customer_name,
        })),
      });
    } catch (error) {
      logAction("GET_ALL_RECURRING_ORDERS_ERROR", { error: error.message });
      console.error("[RECURRING_ORDERS] Error:", error);
      res.status(500).json({ error: "Erreur serveur" });
    }
  },
);

module.exports = router;
