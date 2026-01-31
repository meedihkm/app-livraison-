const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const pool = require('../config/database');

// ============================================
// ROUTES SPÃ‰CIFIQUES (AVANT LES ROUTES AVEC :id)
// ============================================

// 1. GET /api/favorites/my-favorites
router.get('/my-favorites', authenticate, async (req, res) => {
  try {
    const clientId = req.user.id;
    
    const result = await pool.query(
      'SELECT * FROM get_client_favorites($1)',
      [clientId]
    );
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching favorites:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des favoris',
      error: error.message
    });
  }
});

// 2. GET /api/favorites/preferences
router.get('/preferences', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    let result = await pool.query(
      'SELECT * FROM user_preferences WHERE user_id = $1',
      [userId]
    );
    
    // Si pas de prÃ©fÃ©rences, crÃ©er avec valeurs par dÃ©faut
    if (result.rows.length === 0) {
      result = await pool.query(
        `INSERT INTO user_preferences (user_id, favorite_orders_enabled, auto_suggest_enabled, min_pattern_count)
         VALUES ($1, true, true, 3)
         RETURNING *`,
        [userId]
      );
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des prÃ©fÃ©rences',
      error: error.message
    });
  }
});

// 3. PUT /api/favorites/preferences
router.put('/preferences', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { favorite_orders_enabled, auto_suggest_enabled, min_pattern_count } = req.body;
    
    const result = await pool.query(
      `INSERT INTO user_preferences (user_id, favorite_orders_enabled, auto_suggest_enabled, min_pattern_count)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id)
       DO UPDATE SET
         favorite_orders_enabled = EXCLUDED.favorite_orders_enabled,
         auto_suggest_enabled = EXCLUDED.auto_suggest_enabled,
         min_pattern_count = EXCLUDED.min_pattern_count,
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [userId, favorite_orders_enabled, auto_suggest_enabled, min_pattern_count]
    );
    
    res.json({
      success: true,
      message: 'PrÃ©fÃ©rences mises Ã  jour',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise Ã  jour',
      error: error.message
    });
  }
});

// 4. POST /api/favorites/detect-pattern
router.post('/detect-pattern', authenticate, async (req, res) => {
  try {
    const { items } = req.body;
    const clientId = req.user.id;
    const organizationId = req.user.organizationId;
    
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Items requis'
      });
    }
    
    // DÃ©tecter le pattern
    const result = await pool.query(
      'SELECT * FROM detect_order_pattern($1, $2, $3)',
      [clientId, organizationId, JSON.stringify(items)]
    );
    
    const patternData = result.rows[0].detect_order_pattern;
    
    res.json({
      success: true,
      data: patternData
    });
  } catch (error) {
    console.error('Error detecting pattern:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la dÃ©tection',
      error: error.message
    });
  }
});

// 5. GET /api/favorites/stats (Admin)
router.get('/stats', authenticate, async (req, res) => {
  try {
    // VÃ©rifier que c'est un admin
    if (req.user.role !== 'admin' && req.user.role !== 'superadmin') {
      return res.status(403).json({
        success: false,
        message: 'AccÃ¨s non autorisÃ©'
      });
    }
    
    const organizationId = req.user.organizationId;
    
    const result = await pool.query(
      `SELECT
        COUNT(DISTINCT f.client_id) AS clients_with_favorites,
        COUNT(f.id) AS total_favorites,
        SUM(f.order_count) AS total_favorite_orders,
        AVG(f.order_count) AS avg_orders_per_favorite,
        COUNT(CASE WHEN f.is_auto_detected THEN 1 END) AS auto_detected_count,
        COUNT(CASE WHEN NOT f.is_auto_detected THEN 1 END) AS manual_count
       FROM favorite_orders f
       WHERE f.organization_id = $1 AND f.is_active = true`,
      [organizationId]
    );
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des statistiques',
      error: error.message
    });
  }
});

// 6. POST /api/favorites/create
router.post('/create', authenticate, async (req, res) => {
  try {
    const { name, items, fromPattern } = req.body;
    const clientId = req.user.id;
    const organizationId = req.user.organizationId;
    
    // Calculer le total
    let total = 0;
    for (const item of items) {
      total += item.quantity * item.unitPrice;
    }
    
    // CrÃ©er le favori
    const result = await pool.query(
      `INSERT INTO favorite_orders (
        client_id, organization_id, name, items, total, is_auto_detected
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
      [clientId, organizationId, name, JSON.stringify(items), total, fromPattern || false]
    );
    
    res.json({
      success: true,
      message: 'Favori crÃ©Ã© avec succÃ¨s',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating favorite:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la crÃ©ation du favori',
      error: error.message
    });
  }
});

// ============================================
// ROUTES AVEC PARAMÃˆTRES :id (APRÃˆS LES ROUTES SPÃ‰CIFIQUES)
// ============================================

// 7. POST /api/favorites/:id/use
router.post('/:id/use', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.id;
    
    // VÃ©rifier que le favori appartient au client
    const checkResult = await pool.query(
      'SELECT id FROM favorite_orders WHERE id = $1 AND client_id = $2 AND is_active = true',
      [id, clientId]
    );
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Favori non trouvÃ©'
      });
    }
    
    // Mettre Ã  jour les stats
    await pool.query('SELECT update_favorite_usage($1)', [id]);
    
    res.json({
      success: true,
      message: 'Utilisation enregistrÃ©e'
    });
  } catch (error) {
    console.error('Error recording favorite usage:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'enregistrement',
      error: error.message
    });
  }
});

// 8. PUT /api/favorites/:id
router.put('/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, items } = req.body;
    const clientId = req.user.id;
    
    // VÃ©rifier que le favori appartient au client
    const checkResult = await pool.query(
      'SELECT id FROM favorite_orders WHERE id = $1 AND client_id = $2',
      [id, clientId]
    );
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Favori non trouvÃ©'
      });
    }
    
    // Calculer le nouveau total
    let total = 0;
    for (const item of items) {
      total += item.quantity * item.unitPrice;
    }
    
    // Mettre Ã  jour
    const result = await pool.query(
      `UPDATE favorite_orders
       SET name = $1, items = $2, total = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4 AND client_id = $5
       RETURNING *`,
      [name, JSON.stringify(items), total, id, clientId]
    );
    
    res.json({
      success: true,
      message: 'Favori mis Ã  jour',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating favorite:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise Ã  jour',
      error: error.message
    });
  }
});

// 9. DELETE /api/favorites/:id
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.id;
    
    const result = await pool.query(
      `UPDATE favorite_orders
       SET is_active = false, updated_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND client_id = $2
       RETURNING id`,
      [id, clientId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Favori non trouvÃ©'
      });
    }
    
    res.json({
      success: true,
      message: 'Favori supprimÃ©'
    });
  } catch (error) {
    console.error('Error deleting favorite:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression',
      error: error.message
    });
  }
});

module.exports = router;
