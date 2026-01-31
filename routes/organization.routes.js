const express = require('express');
const router = express.Router();

const pool = require('../config/database');
const { authenticate, requireAdmin } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { logAudit } = require('../services/audit.service');
const { getAuditLogs } = require('../services/audit.service');
const cacheService = require('../services/cache.service');
const cacheMiddleware = require('../middleware/cache.middleware');
const { getPagination, getPagingData } = require('../utils/pagination.helper');

// GET /api/organization/settings
// GET /api/organization/settings
router.get('/settings', authenticate, cacheMiddleware(600), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, type, kitchen_mode FROM organizations WHERE id = $1',
      [req.user.organization_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Organisation non trouvÃ©e' });
    }

    const org = result.rows[0];
    res.json({
      success: true,
      data: {
        id: org.id,
        name: org.name,
        type: org.type,
        kitchenMode: org.kitchen_mode || false
      }
    });
  } catch (error) {
    console.error('Get org settings error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// PUT /api/organization/settings
router.put('/settings', authenticate, requireAdmin, validate('updateOrgSettings'), async (req, res) => {
  try {
    const { kitchenMode } = req.body;

    await pool.query(
      'UPDATE organizations SET kitchen_mode = $1 WHERE id = $2',
      [kitchenMode || false, req.user.organization_id]
    );

    await logAudit('ORG_SETTINGS_UPDATED', req.user.id, req.user.organization_id, { kitchenMode }, req);

    await cacheService.invalidate(`cache:organization:${req.user.organization_id}*`);



    res.json({ success: true });
  } catch (error) {
    console.error('Update org settings error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/financial/daily - RÃ©sumÃ© financier du jour
router.get('/daily', authenticate, async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    const result = await pool.query(
      `SELECT 
        COALESCE(SUM(total), 0) as total_orders, 
        COALESCE(SUM(amount_paid), 0) as total_collected, 
        COUNT(*) as order_count
       FROM orders 
       WHERE organization_id = $1 AND DATE(created_at) = $2`,
      [req.user.organization_id, today]
    );

    const data = result.rows[0];
    res.json({
      success: true,
      data: {
        total_orders: parseFloat(data.total_orders) || 0,
        total_collected: parseFloat(data.total_collected) || 0,
        order_count: parseInt(data.order_count) || 0
      }
    });
  } catch (error) {
    console.error('Daily financial error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/financial/debts - Liste des dettes par client
router.get('/debts', authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.email, 
              COALESCE(SUM(o.total - o.amount_paid), 0) as debt,
              COUNT(o.id) as order_count,
              MAX(o.created_at) as last_order
       FROM users u
       LEFT JOIN orders o ON u.id = o.customer_id AND o.total > o.amount_paid
       WHERE u.organization_id = $1 AND u.role = 'customer'
       GROUP BY u.id, u.name, u.email
       HAVING COALESCE(SUM(o.total - o.amount_paid), 0) > 0
       ORDER BY debt DESC`,
      [req.user.organization_id]
    );

    // Formater les donnÃ©es pour Ã©viter les problÃ¨mes de parsing
    const data = result.rows.map(row => ({
      id: row.id,
      name: row.name || '',
      email: row.email || '',
      debt: parseFloat(row.debt) || 0,
      order_count: parseInt(row.order_count) || 0,
      last_order: row.last_order
    }));

    res.json({ success: true, data });
  } catch (error) {
    console.error('Debts error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/audit-logs (montÃ© sur /api/audit-logs)
router.get('/', authenticate, requireAdmin, async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query, 50);
    const { action, userId } = req.query;

    const { data, total } = await getAuditLogs(req.user.organization_id, { limit, offset, action, userId });

    res.json(getPagingData(data, total, page, limit));
  } catch (error) {
    console.error('Audit logs error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
