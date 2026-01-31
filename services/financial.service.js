// =====================================================
// SERVICE: Financial Service - Gestion FinanciÃ¨re UnifiÃ©e
// Centralise toute la logique mÃ©tier finance/dette/statistiques
// Version: 1.0.0 - Production Ready
// =====================================================

const pool = require("../config/database");
const { logAudit } = require("./audit.service");

// Helper pour parsing sÃ©curisÃ©
const safeParseNumber = (value, defaultValue = 0) => {
  const parsed = parseFloat(value);
  return isNaN(parsed) ? defaultValue : parsed;
};

/**
 * Calcule le statut de crÃ©dit basÃ© sur le ratio dette/limite
 * @param {number} debt - Dette actuelle
 * @param {number} limit - Limite de crÃ©dit
 * @returns {Object} Statut et niveau d'alerte
 */
function calculateCreditStatus(debt, limit) {
  if (limit <= 0) {
    return { status: "no_limit", level: null, ratio: 0 };
  }

  const ratio = Math.round((debt / limit) * 100);

  if (ratio >= 120) {
    return { status: "critical", level: "urgent", ratio };
  } else if (ratio >= 100) {
    return { status: "over_limit", level: "warning", ratio };
  } else if (ratio >= 80) {
    return { status: "approaching", level: "info", ratio };
  }

  return { status: "ok", level: null, ratio };
}

/**
 * Service financier - OpÃ©rations de haut niveau
 */
class FinancialService {
  /**
   * RÃ©cupÃ¨re la vue d'ensemble financiÃ¨re (dashboard)
   * @param {string} organizationId - ID de l'organisation
   * @param {Object} filters - Filtres optionnels (dateFrom, dateTo)
   */
  async getOverview(organizationId, { dateFrom, dateTo } = {}) {
    const params = [organizationId];
    let paramIndex = 2;
    let dateFilter = "";

    if (dateFrom) {
      params.push(dateFrom);
      dateFilter += ` AND o.created_at >= $${paramIndex++}`;
    }

    if (dateTo) {
      params.push(dateTo);
      dateFilter += ` AND o.created_at <= $${paramIndex++}`;
    }

    // RequÃªte unique optimisÃ©e avec CTE (Common Table Expressions)
    const query = `
      WITH order_stats AS (
        SELECT 
          COALESCE(SUM(o.total), 0) as total_revenue,
          COALESCE(SUM(o.amount_paid), 0) as total_collected,
          COALESCE(SUM(o.total - o.amount_paid), 0) as total_unpaid,
          COUNT(*) as total_orders,
          COUNT(*) FILTER (WHERE o.status = 'delivered') as delivered_orders,
          COUNT(*) FILTER (WHERE o.payment_status = 'paid') as paid_orders,
          COUNT(*) FILTER (WHERE o.payment_status = 'unpaid') as unpaid_orders,
          COUNT(*) FILTER (WHERE o.payment_status = 'partial') as partial_orders,
          COUNT(DISTINCT o.customer_id) as total_customers,
          COUNT(DISTINCT o.customer_id) FILTER (WHERE o.total > o.amount_paid) as customers_with_debt
        FROM orders o
        WHERE o.organization_id = $1
          AND o.status != 'cancelled'
          ${dateFilter}
      ),
      top_clients AS (
        SELECT 
          u.id,
          u.name,
          u.phone,
          COALESCE(SUM(o.total), 0) as total_revenue,
          COALESCE(SUM(o.amount_paid), 0) as total_paid,
          COALESCE(SUM(o.total - o.amount_paid), 0) as total_debt,
          COUNT(*) as order_count
        FROM users u
        JOIN orders o ON u.id = o.customer_id
        WHERE o.organization_id = $1
          AND o.status != 'cancelled'
          ${dateFilter}
        GROUP BY u.id, u.name, u.phone
        ORDER BY total_revenue DESC
        LIMIT 5
      ),
      deliverer_stats AS (
        SELECT 
          u.id,
          u.name,
          COUNT(d.id) as total_deliveries,
          COUNT(*) FILTER (WHERE d.status = 'delivered') as delivered_count,
          COALESCE(SUM(o.amount_paid) FILTER (WHERE d.status = 'delivered'), 0) as amount_collected
        FROM users u
        LEFT JOIN deliveries d ON u.id = d.deliverer_id AND d.organization_id = $1
        LEFT JOIN orders o ON d.order_id = o.id
        WHERE u.role = 'deliverer'
          AND u.organization_id = $1
          AND u.active = true
        GROUP BY u.id, u.name
        ORDER BY delivered_count DESC
      )
      SELECT 
        (SELECT json_build_object(
          'totalRevenue', total_revenue,
          'totalCollected', total_collected,
          'totalUnpaid', total_unpaid,
          'totalOrders', total_orders,
          'deliveredOrders', delivered_orders,
          'paidOrders', paid_orders,
          'unpaidOrders', unpaid_orders,
          'partialOrders', partial_orders,
          'totalCustomers', total_customers,
          'customersWithDebt', customers_with_debt
        ) FROM order_stats) as summary,
        (SELECT json_agg(top_clients) FROM top_clients) as top_clients,
        (SELECT json_agg(deliverer_stats) FROM deliverer_stats) as deliverer_stats
    `;

    const result = await pool.query(query, params);
    const row = result.rows[0];

    return {
      summary: row.summary,
      topClients: row.top_clients || [],
      delivererStats: row.deliverer_stats || [],
    };
  }

  /**
   * RÃ©cupÃ¨re la liste des clients avec dette
   * @param {string} organizationId - ID de l'organisation
   * @param {Object} options - Options de pagination et filtres
   */
  async getDebts(organizationId, { page = 1, limit = 50, minDebt = 0, customerId = null, delivererId = null } = {}) {
    const offset = (page - 1) * limit;
    const params = [organizationId];
    let paramIndex = 2;

    let whereClause =
      "WHERE o.organization_id = $1 AND o.total > o.amount_paid AND o.status != 'cancelled'";

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

    // RequÃªte de comptage optimisÃ©e
    const countQuery = `
      SELECT COUNT(DISTINCT o.customer_id) as count
      FROM orders o
      ${whereClause}
    `;

    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].count);

    // RequÃªte principale
    const dataQuery = `
      SELECT 
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
      LIMIT $${paramIndex + 1} OFFSET $${paramIndex + 2}
    `;

    const dataParams = [...params, minDebt, limit, offset];
    const result = await pool.query(dataQuery, dataParams);

    return {
      data: result.rows.map((row) => ({
        customerId: row.customer_id,
        name: row.name,
        email: row.email,
        phone: row.phone,
        unpaidOrders: parseInt(row.unpaid_orders),
        totalDebt: safeParseNumber(row.total_debt),
        lastOrderDate: row.last_order_date,
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * RÃ©cupÃ¨re le dÃ©tail de la dette d'un client spÃ©cifique
   * @param {string} customerId - ID du client
   * @param {string} organizationId - ID de l'organisation
   */
  async getCustomerDebt(customerId, organizationId) {
    // VÃ©rifier que le client existe
    const customerCheck = await pool.query(
      "SELECT id, name, email, phone, credit_limit FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
      [customerId, organizationId]
    );

    if (customerCheck.rows.length === 0) {
      throw new Error("Client non trouvÃ©");
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
      [customerId, organizationId]
    );

    const unpaidOrders = ordersResult.rows.map((order) => ({
      id: order.id,
      orderNumber: order.order_number,
      date: order.created_at,
      total: safeParseNumber(order.total),
      amountPaid: safeParseNumber(order.amount_paid),
      remaining: safeParseNumber(order.remaining),
      status: order.status,
      paymentStatus: order.payment_status,
    }));

    const totalDebt = unpaidOrders.reduce((sum, order) => sum + order.remaining, 0);

    // Calculer le statut crÃ©dit
    const creditLimit = safeParseNumber(customer.credit_limit);
    const creditStatus = calculateCreditStatus(totalDebt, creditLimit);

    return {
      customer: {
        id: customer.id,
        name: customer.name,
        email: customer.email,
        phone: customer.phone,
      },
      totalDebt,
      creditLimit: creditLimit > 0 ? creditLimit : null,
      credit: {
        limit: creditLimit,
        used: totalDebt,
        available: Math.max(0, creditLimit - totalDebt),
        ...creditStatus,
      },
      unpaidOrders,
    };
  }

  /**
   * Enregistre un paiement et met Ã  jour les commandes (FIFO)
   * @param {Object} paymentData - DonnÃ©es du paiement
   * @param {string} performedBy - ID de l'utilisateur qui enregistre
   * @param {string} organizationId - ID de l'organisation
   */
  async recordPayment(
    { customerId, amount, mode = "cash", notes, targetOrders },
    performedBy,
    organizationId
  ) {
    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      // 1. VÃ©rifier le client
      const customerCheck = await client.query(
        "SELECT id, name FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
        [customerId, organizationId]
      );

      if (customerCheck.rows.length === 0) {
        throw new Error("Client non trouvÃ©");
      }

      const customer = customerCheck.rows[0];

      // 2. Calculer la dette actuelle (avec row lock)
      const debtResult = await client.query(
        `SELECT COALESCE(SUM(total - amount_paid), 0) as current_debt
         FROM orders
         WHERE customer_id = $1 
           AND organization_id = $2 
           AND total > amount_paid 
           AND status != 'cancelled'
         FOR UPDATE`,
        [customerId, organizationId]
      );

      const currentDebt = safeParseNumber(debtResult.rows[0].current_debt);

      if (currentDebt === 0) {
        throw new Error("Ce client n'a pas de dette");
      }

      if (amount > currentDebt) {
        throw new Error(
          `Le montant (${amount} DA) est supÃ©rieur Ã  la dette (${currentDebt} DA)`
        );
      }

      // 3. InsÃ©rer le paiement dans la table dÃ©diÃ©e
      const paymentResult = await client.query(
        `INSERT INTO payments (organization_id, customer_id, amount, mode, recorded_by, notes)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, created_at`,
        [organizationId, customerId, amount, mode, performedBy, notes]
      );

      const paymentId = paymentResult.rows[0].id;

      // 4. Appliquer le paiement aux commandes (FIFO)
      let remainingAmount = amount;
      const affectedOrders = [];

      const ordersQuery = targetOrders?.length > 0
        ? `SELECT id, total, amount_paid, (total - amount_paid) as remaining
            FROM orders
            WHERE id = ANY($1::text[]) 
              AND customer_id = $2 
              AND organization_id = $3 
              AND total > amount_paid
            ORDER BY created_at ASC`
        : `SELECT id, total, amount_paid, (total - amount_paid) as remaining
            FROM orders
            WHERE customer_id = $1 
              AND organization_id = $2 
              AND total > amount_paid 
              AND status != 'cancelled'
            ORDER BY created_at ASC`;

      const ordersParams = targetOrders?.length > 0
        ? [targetOrders, customerId, organizationId]
        : [customerId, organizationId];

      const ordersToUpdate = await client.query(ordersQuery, ordersParams);

      for (const order of ordersToUpdate.rows) {
        if (remainingAmount <= 0) break;

        const orderRemaining = safeParseNumber(order.remaining);
        const paymentForOrder = Math.min(remainingAmount, orderRemaining);
        const newAmountPaid = safeParseNumber(order.amount_paid) + paymentForOrder;
        const newPaymentStatus = newAmountPaid >= safeParseNumber(order.total) ? "paid" : "partial";

        await client.query(
          `UPDATE orders 
           SET amount_paid = $1, payment_status = $2, updated_at = NOW()
           WHERE id = $3`,
          [newAmountPaid, newPaymentStatus, order.id]
        );

        // Lier le paiement Ã  la commande
        await client.query(
          `INSERT INTO payment_orders (payment_id, order_id, amount_applied)
           VALUES ($1, $2, $3)`,
          [paymentId, order.id, paymentForOrder]
        );

        affectedOrders.push({
          orderId: order.id,
          amountApplied: paymentForOrder,
          newStatus: newPaymentStatus,
        });

        remainingAmount -= paymentForOrder;
      }

      // 5. Logger l'audit
      await logAudit({
        action: "PAYMENT_RECORDED",
        performedBy,
        organizationId,
        targetType: "payment",
        targetId: paymentId,
        details: {
          customerId,
          customerName: customer.name,
          amount,
          mode,
          debtBefore: currentDebt,
          debtAfter: currentDebt - amount,
          ordersAffected: affectedOrders.length,
          paymentId,
        },
      });

      await client.query("COMMIT");

      return {
        paymentId,
        customerId,
        customerName: customer.name,
        amount,
        mode,
        debtBefore: currentDebt,
        debtAfter: currentDebt - amount,
        ordersAffected: affectedOrders,
        createdAt: paymentResult.rows[0].created_at,
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * RÃ©cupÃ¨re les alertes crÃ©dit (clients proches de leur limite)
   * @param {string} organizationId - ID de l'organisation
   */
  async getCreditAlerts(organizationId) {
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
      [organizationId]
    );

    return result.rows.map((row) => {
      const debt = safeParseNumber(row.current_debt);
      const limit = safeParseNumber(row.credit_limit);
      const creditStatus = calculateCreditStatus(debt, limit);

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
          ratio: parseInt(row.ratio) || 0,
          ...creditStatus,
        },
      };
    });
  }

  /**
   * RÃ©cupÃ¨re l'historique des paiements d'un livreur
   * @param {string} delivererId - ID du livreur
   * @param {string} organizationId - ID de l'organisation
   * @param {Object} options - Options (date)
   */
  async getDelivererCollections(delivererId, organizationId, { date = new Date() } = {}) {
    const result = await pool.query(
      `SELECT 
        p.id,
        p.amount,
        p.mode,
        p.notes,
        p.created_at,
        u.id as customer_id,
        u.name as customer_name
      FROM payments p
      JOIN users u ON p.customer_id = u.id
      WHERE p.recorded_by = $1
        AND p.organization_id = $2
        AND DATE(p.created_at) = DATE($3)
      ORDER BY p.created_at DESC`,
      [delivererId, organizationId, date]
    );

    return result.rows.map((row) => ({
      id: row.id,
      amount: safeParseNumber(row.amount),
      mode: row.mode,
      notes: row.notes,
      createdAt: row.created_at,
      customerId: row.customer_id,
      customerName: row.customer_name,
    }));
  }

  /**
   * Met Ã  jour la limite de crÃ©dit d'un client
   * @param {string} customerId - ID du client
   * @param {number} limit - Nouvelle limite (null pour illimitÃ©)
   * @param {string} performedBy - ID de l'admin qui modifie
   * @param {string} organizationId - ID de l'organisation
   */
  async updateCreditLimit(customerId, limit, performedBy, organizationId) {
    // VÃ©rifier que le client existe
    const customerCheck = await pool.query(
      "SELECT id, name FROM users WHERE id = $1 AND organization_id = $2 AND role = 'customer'",
      [customerId, organizationId]
    );

    if (customerCheck.rows.length === 0) {
      throw new Error("Client non trouvÃ©");
    }

    const customer = customerCheck.rows[0];

    // Mettre Ã  jour la limite
    await pool.query(
      "UPDATE users SET credit_limit = $1, updated_at = NOW() WHERE id = $2",
      [limit === null ? 0 : limit, customerId]
    );

    // Logger
    await logAudit({
      action: "CREDIT_LIMIT_UPDATED",
      performedBy,
      organizationId,
      targetType: "customer",
      targetId: customerId,
      details: { newLimit: limit, customerName: customer.name },
    });

    return {
      customerId,
      customerName: customer.name,
      newLimit: limit,
    };
  }
}

// Export singleton
module.exports = new FinancialService();
