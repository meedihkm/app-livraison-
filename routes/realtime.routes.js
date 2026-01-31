const express = require('express');
const router = express.Router();

const pool = require('../config/database');
const { authenticate, requireAdmin, requireDeliverer } = require('../middleware/auth');
const { validate, validateUUID } = require('../middleware/validate');

// POST /api/realtime/location - Livreur met Ã  jour sa position
router.post('/location', authenticate, requireDeliverer, validate('updateLocation'), async (req, res) => {
  try {
    const { latitude, longitude, accuracy } = req.body;
    
    // Mettre Ã  jour la position du livreur
    await pool.query(
      `UPDATE users 
       SET latitude = $1, longitude = $2, location_updated_at = NOW() 
       WHERE id = $3 AND role = 'deliverer'`,
      [latitude, longitude, req.user.id]
    );
    
    // Enregistrer dans l'historique
    try {
      await pool.query(
        `INSERT INTO location_history (deliverer_id, organization_id, latitude, longitude, accuracy, recorded_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [req.user.id, req.user.organization_id, latitude, longitude, accuracy || null]
      );
    } catch (historyError) {
      // Silently fail si table n'existe pas encore
      console.warn('Location history insert failed:', historyError.message);
    }
    
    res.json({ success: true });
  } catch (error) {
    console.error('Location update error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/realtime/deliverers - Admin rÃ©cupÃ¨re positions de tous les livreurs
router.get('/deliverers', authenticate, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, latitude, longitude, location_updated_at
       FROM users 
       WHERE organization_id = $1 AND role = 'deliverer' AND active = true
       AND latitude IS NOT NULL AND longitude IS NOT NULL`,
      [req.user.organization_id]
    );
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get deliverers locations error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/realtime/deliveries-map - Admin rÃ©cupÃ¨re toutes les livraisons avec positions
router.get('/deliveries-map', authenticate, requireAdmin, async (req, res) => {
  try {
    // RÃ©cupÃ©rer les livraisons en cours avec positions des clients et livreurs
    const result = await pool.query(
      `SELECT 
        d.id as delivery_id,
        d.status as delivery_status,
        o.id as order_id,
        o.order_number,
        o.total,
        c.id as client_id,
        c.name as client_name,
        c.phone as client_phone,
        c.address as client_address,
        c.address_lat as client_lat,
        c.address_lng as client_lng,
        u.id as deliverer_id,
        u.name as deliverer_name,
        u.latitude as deliverer_lat,
        u.longitude as deliverer_lng,
        u.location_updated_at as deliverer_location_updated
       FROM deliveries d
       JOIN orders o ON d.order_id = o.id
       JOIN users c ON o.customer_id = c.id
       LEFT JOIN users u ON d.deliverer_id = u.id
       WHERE d.organization_id = $1 
       AND d.status IN ('assigned', 'in_progress')
       ORDER BY d.created_at DESC`,
      [req.user.organization_id]
    );
    
    const deliveries = result.rows.map(row => ({
      deliveryId: row.delivery_id,
      deliveryStatus: row.delivery_status,
      order: {
        id: row.order_id,
        orderNumber: row.order_number,
        total: parseFloat(row.total || 0)
      },
      client: {
        id: row.client_id,
        name: row.client_name,
        phone: row.client_phone,
        address: row.client_address,
        latitude: row.client_lat ? parseFloat(row.client_lat) : null,
        longitude: row.client_lng ? parseFloat(row.client_lng) : null,
        hasLocation: row.client_lat != null && row.client_lng != null
      },
      deliverer: row.deliverer_id ? {
        id: row.deliverer_id,
        name: row.deliverer_name,
        latitude: row.deliverer_lat ? parseFloat(row.deliverer_lat) : null,
        longitude: row.deliverer_lng ? parseFloat(row.deliverer_lng) : null,
        locationUpdatedAt: row.deliverer_location_updated,
        hasLocation: row.deliverer_lat != null && row.deliverer_lng != null
      } : null
    }));
    
    res.json({ success: true, data: deliveries });
  } catch (error) {
    console.error('Get deliveries map error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/realtime/deliverer/:id/route - Admin rÃ©cupÃ¨re l'itinÃ©raire d'un livreur
router.get('/deliverer/:id/route', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
  try {
    // VÃ©rifier que le livreur appartient Ã  l'organisation
    const delivererCheck = await pool.query(
      'SELECT id FROM users WHERE id = $1 AND organization_id = $2 AND role = $3',
      [req.params.id, req.user.organization_id, 'deliverer']
    );
    
    if (delivererCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Livreur non trouvÃ©' });
    }
    
    // RÃ©cupÃ©rer les livraisons assignÃ©es Ã  ce livreur
    const result = await pool.query(
      `SELECT 
        d.id as delivery_id,
        d.status as delivery_status,
        o.id as order_id,
        o.order_number,
        o.total,
        c.id as client_id,
        c.name as client_name,
        c.phone as client_phone,
        c.address as client_address,
        c.address_lat as client_lat,
        c.address_lng as client_lng
       FROM deliveries d
       JOIN orders o ON d.order_id = o.id
       JOIN users c ON o.customer_id = c.id
       WHERE d.deliverer_id = $1 
       AND d.status IN ('assigned', 'in_progress', 'postponed')
       ORDER BY 
         CASE WHEN d.status = 'postponed' THEN 1 ELSE 0 END,
         d.created_at ASC`,
      [req.params.id]
    );
    
    const route = result.rows.map(row => ({
      deliveryId: row.delivery_id,
      deliveryStatus: row.delivery_status,
      order: {
        id: row.order_id,
        orderNumber: row.order_number,
        total: parseFloat(row.total || 0)
      },
      client: {
        id: row.client_id,
        name: row.client_name,
        phone: row.client_phone,
        address: row.client_address,
        latitude: row.client_lat ? parseFloat(row.client_lat) : null,
        longitude: row.client_lng ? parseFloat(row.client_lng) : null,
        hasLocation: row.client_lat != null && row.client_lng != null
      }
    }));
    
    res.json({ success: true, data: route });
  } catch (error) {
    console.error('Get deliverer route error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// GET /api/realtime/deliverer/:id/history - Historique GPS d'un livreur
router.get('/deliverer/:id/history', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
  try {
    const { date } = req.query;
    
    // VÃ©rifier que le livreur appartient Ã  l'organisation
    const delivererCheck = await pool.query(
      'SELECT id FROM users WHERE id = $1 AND organization_id = $2 AND role = $3',
      [req.params.id, req.user.organization_id, 'deliverer']
    );
    
    if (delivererCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Livreur non trouvÃ©' });
    }
    
    const result = await pool.query(
      `SELECT latitude, longitude, accuracy, recorded_at
       FROM location_history 
       WHERE deliverer_id = $1 AND DATE(recorded_at) = $2
       ORDER BY recorded_at`,
      [req.params.id, date || new Date().toISOString().split('T')[0]]
    );
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get deliverer history error:', error);
    // Retourner tableau vide si table n'existe pas
    res.json({ success: true, data: [] });
  }
});

// GET /api/realtime/deliverer/:id/stats - Statistiques de localisation d'un livreur
router.get('/deliverer/:id/stats', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    // VÃ©rifier que le livreur appartient Ã  l'organisation
    const delivererCheck = await pool.query(
      'SELECT id FROM users WHERE id = $1 AND organization_id = $2 AND role = $3',
      [req.params.id, req.user.organization_id, 'deliverer']
    );
    
    if (delivererCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Livreur non trouvÃ©' });
    }
    
    const result = await pool.query(
      `SELECT * FROM get_deliverer_location_stats($1, $2, $3)`,
      [
        req.params.id,
        startDate || new Date().toISOString().split('T')[0],
        endDate || new Date().toISOString().split('T')[0]
      ]
    );
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get deliverer stats error:', error);
    res.json({ success: true, data: [] });
  }
});

// POST /api/realtime/cleanup-history - Nettoyer l'historique GPS ancien (Admin)
router.post('/cleanup-history', authenticate, requireAdmin, async (req, res) => {
  try {
    const { daysToKeep = 90 } = req.body;
    
    const result = await pool.query(
      'SELECT cleanup_old_location_history($1)',
      [daysToKeep]
    );
    
    const deletedCount = result.rows[0].cleanup_old_location_history;
    
    res.json({ 
      success: true, 
      message: `${deletedCount} enregistrements supprimÃ©s`,
      deletedCount 
    });
  } catch (error) {
    console.error('Cleanup history error:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
