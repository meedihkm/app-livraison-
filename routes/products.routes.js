const express = require('express');
const router = express.Router();

const pool = require('../config/database');
const { authenticate, requireAdmin } = require('../middleware/auth');
const { validate, validateUUID } = require('../middleware/validate');
const { logAudit } = require('../services/audit.service');
const cacheService = require('../services/cache.service');
const cacheMiddleware = require('../middleware/cache.middleware');
const { getPagination, getPagingData } = require('../utils/pagination.helper');

// GET /api/products
router.get('/', authenticate, cacheMiddleware(300), async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query, 100);

    // Count total
    const countResult = await pool.query(
      'SELECT COUNT(*) FROM products WHERE organization_id = $1',
      [req.user.organization_id]
    );
    const total = parseInt(countResult.rows[0].count);

    const result = await pool.query(
      'SELECT * FROM products WHERE organization_id = $1 ORDER BY COALESCE(sort_order, 999999), name LIMIT $2 OFFSET $3',
      [req.user.organization_id, limit, offset]
    );

    res.json(getPagingData(result.rows, total, page, limit));
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/products/categories
router.get('/categories', authenticate, cacheMiddleware(1800), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT category FROM products WHERE organization_id = $1 AND category IS NOT NULL ORDER BY category',
      [req.user.organization_id]
    );
    res.json({ success: true, data: result.rows.map(r => r.category) });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// POST /api/products
router.post('/', authenticate, requireAdmin, validate('createProduct'), async (req, res) => {
  try {
    const { name, price, imageUrl, category, isNew, isPromo, promoPrice } = req.body;

    const maxOrder = await pool.query(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM products WHERE organization_id = $1',
      [req.user.organization_id]
    );
    const sortOrder = maxOrder.rows[0].next_order;

    const result = await pool.query(
      'INSERT INTO products (organization_id, name, price, image_url, category, sort_order, is_new, is_promo, promo_price) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *',
      [req.user.organization_id, name, price, imageUrl || null, category || null, sortOrder, isNew || false, isPromo || false, promoPrice || null]
    );

    await logAudit('PRODUCT_CREATED', req.user.id, req.user.organization_id, { productId: result.rows[0].id, name, price }, req);

    // Invalider le cache produits
    await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);

    res.json({ success: true, data: result.rows[0] });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// PUT /api/products/:id
router.put('/:id', authenticate, requireAdmin, validateUUID('id'), validate('updateProduct'), async (req, res) => {
  try {
    const { name, price, imageUrl, category, isNew, isPromo, promoPrice } = req.body;
    const result = await pool.query(
      'UPDATE products SET name = $1, price = $2, image_url = $3, category = $4, is_new = $5, is_promo = $6, promo_price = $7, updated_at = NOW() WHERE id = $8 AND organization_id = $9 RETURNING *',
      [name, price, imageUrl || null, category || null, isNew || false, isPromo || false, promoPrice || null, req.params.id, req.user.organization_id]
    );

    await logAudit('PRODUCT_UPDATED', req.user.id, req.user.organization_id, { productId: req.params.id, name, price }, req);

    await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);

    res.json({ success: true, data: result.rows[0] });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// PUT /api/products/:id/reorder
router.put('/:id/reorder', authenticate, requireAdmin, validateUUID('id'), validate('reorderProduct'), async (req, res) => {
  try {
    const { direction } = req.body;
    const productId = req.params.id;

    const current = await pool.query(
      'SELECT id, sort_order FROM products WHERE id = $1 AND organization_id = $2',
      [productId, req.user.organization_id]
    );
    if (current.rows.length === 0) {
      return res.status(404).json({ error: 'Produit non trouvÃ©' });
    }

    const currentOrder = current.rows[0].sort_order || 0;

    let neighbor;
    if (direction === 'up') {
      neighbor = await pool.query(
        'SELECT id, sort_order FROM products WHERE organization_id = $1 AND COALESCE(sort_order, 999999) < $2 ORDER BY COALESCE(sort_order, 999999) DESC LIMIT 1',
        [req.user.organization_id, currentOrder]
      );
    } else {
      neighbor = await pool.query(
        'SELECT id, sort_order FROM products WHERE organization_id = $1 AND COALESCE(sort_order, 999999) > $2 ORDER BY COALESCE(sort_order, 999999) ASC LIMIT 1',
        [req.user.organization_id, currentOrder]
      );
    }

    if (neighbor.rows.length === 0) {
      return res.json({ success: true, message: 'DÃ©jÃ  en position extrÃªme' });
    }

    const neighborOrder = neighbor.rows[0].sort_order || 0;
    const neighborId = neighbor.rows[0].id;

    await pool.query('UPDATE products SET sort_order = $1 WHERE id = $2', [neighborOrder, productId]);
    await pool.query('UPDATE products SET sort_order = $1 WHERE id = $2', [currentOrder, neighborId]);

    await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);

    res.json({ success: true });
  } catch (error) {
    console.error('Reorder error:', error.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// PUT /api/products/:id/toggle
router.put('/:id/toggle', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
  try {
    await pool.query(
      'UPDATE products SET active = NOT active WHERE id = $1 AND organization_id = $2',
      [req.params.id, req.user.organization_id]
    );

    await logAudit('PRODUCT_TOGGLED', req.user.id, req.user.organization_id, { productId: req.params.id }, req);

    await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// DELETE /api/products/:id (Hard Delete)
router.delete('/:id', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
  try {
    // VÃ©rifier si le produit est utilisÃ© dans des commandes
    const usageCheck = await pool.query(
      'SELECT COUNT(*) as count FROM order_items WHERE product_id = $1',
      [req.params.id]
    );
    
    const isUsed = parseInt(usageCheck.rows[0].count) > 0;
    
    if (isUsed) {
      // Si le produit est utilisÃ©, on le dÃ©sactive au lieu de le supprimer
      await pool.query(
        'UPDATE products SET active = false WHERE id = $1 AND organization_id = $2',
        [req.params.id, req.user.organization_id]
      );
      
      await logAudit('PRODUCT_ARCHIVED', req.user.id, req.user.organization_id, { 
        productId: req.params.id, 
        reason: 'used_in_orders' 
      }, req);
      
      await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);
      
      return res.json({ 
        success: true, 
        message: 'Produit archivÃ© (utilisÃ© dans des commandes)',
        archived: true 
      });
    }
    
    // Sinon, suppression physique
    await pool.query(
      'DELETE FROM products WHERE id = $1 AND organization_id = $2',
      [req.params.id, req.user.organization_id]
    );

    await logAudit('PRODUCT_DELETED', req.user.id, req.user.organization_id, { 
      productId: req.params.id, 
      type: 'hard_delete' 
    }, req);

    await cacheService.invalidate(`cache:products:${req.user.organization_id}*`);

    res.json({ success: true, message: 'Produit supprimÃ© dÃ©finitivement' });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
