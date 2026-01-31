const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const db = require('../config/database');

// ============================================
// 1. GET /api/notifications
// ============================================
// RÃ©cupÃ¨re les notifications de l'utilisateur

router.get('/', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 50, unreadOnly = false } = req.query;
    
    const result = await db.query(
      'SELECT * FROM get_user_notifications($1, $2, $3)',
      [userId, parseInt(limit), unreadOnly === 'true']
    );
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des notifications',
      error: error.message
    });
  }
});

// ============================================
// 2. GET /api/notifications/unread-count
// ============================================
// Compte les notifications non lues

router.get('/unread-count', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const result = await db.query(
      'SELECT get_unread_count($1) as count',
      [userId]
    );
    
    res.json({
      success: true,
      data: { count: result.rows[0].count }
    });
  } catch (error) {
    console.error('Error counting unread notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors du comptage',
      error: error.message
    });
  }
});

// ============================================
// 3. PUT /api/notifications/:id/read
// ============================================
// Marque une notification comme lue

router.put('/:id/read', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    
    const result = await db.query(
      'SELECT mark_notification_read($1, $2) as success',
      [id, userId]
    );
    
    if (result.rows[0].success) {
      res.json({
        success: true,
        message: 'Notification marquÃ©e comme lue'
      });
    } else {
      res.status(404).json({
        success: false,
        message: 'Notification non trouvÃ©e ou dÃ©jÃ  lue'
      });
    }
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise Ã  jour',
      error: error.message
    });
  }
});

// ============================================
// 4. PUT /api/notifications/read-all
// ============================================
// Marque toutes les notifications comme lues

router.put('/read-all', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const result = await db.query(
      'SELECT mark_all_notifications_read($1) as count',
      [userId]
    );
    
    res.json({
      success: true,
      message: `${result.rows[0].count} notification(s) marquÃ©e(s) comme lue(s)`,
      data: { count: result.rows[0].count }
    });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise Ã  jour',
      error: error.message
    });
  }
});

// ============================================
// 5. DELETE /api/notifications/:id
// ============================================
// Supprime une notification

router.delete('/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    
    const result = await db.query(
      'DELETE FROM notifications WHERE id = $1 AND user_id = $2 RETURNING id',
      [id, userId]
    );
    
    if (result.rows.length > 0) {
      res.json({
        success: true,
        message: 'Notification supprimÃ©e'
      });
    } else {
      res.status(404).json({
        success: false,
        message: 'Notification non trouvÃ©e'
      });
    }
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression',
      error: error.message
    });
  }
});

// ============================================
// 6. GET /api/notifications/preferences
// ============================================
// RÃ©cupÃ¨re les prÃ©fÃ©rences de notification

router.get('/preferences', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    let result = await db.query(
      'SELECT * FROM notification_preferences WHERE user_id = $1',
      [userId]
    );
    
    // Si pas de prÃ©fÃ©rences, crÃ©er avec valeurs par dÃ©faut
    if (result.rows.length === 0) {
      result = await db.query(
        `INSERT INTO notification_preferences (user_id)
         VALUES ($1)
         RETURNING *`,
        [userId]
      );
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching notification preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des prÃ©fÃ©rences',
      error: error.message
    });
  }
});

// ============================================
// 7. PUT /api/notifications/preferences
// ============================================
// Met Ã  jour les prÃ©fÃ©rences de notification

router.put('/preferences', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      payment_notifications,
      debt_notifications,
      favorite_notifications,
      debt_reminders_enabled,
      debt_reminder_frequency,
      quiet_hours_start,
      quiet_hours_end
    } = req.body;
    
    const result = await db.query(
      `INSERT INTO notification_preferences (
        user_id,
        payment_notifications,
        debt_notifications,
        favorite_notifications,
        debt_reminders_enabled,
        debt_reminder_frequency,
        quiet_hours_start,
        quiet_hours_end
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (user_id)
      DO UPDATE SET
        payment_notifications = EXCLUDED.payment_notifications,
        debt_notifications = EXCLUDED.debt_notifications,
        favorite_notifications = EXCLUDED.favorite_notifications,
        debt_reminders_enabled = EXCLUDED.debt_reminders_enabled,
        debt_reminder_frequency = EXCLUDED.debt_reminder_frequency,
        quiet_hours_start = EXCLUDED.quiet_hours_start,
        quiet_hours_end = EXCLUDED.quiet_hours_end,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        userId,
        payment_notifications,
        debt_notifications,
        favorite_notifications,
        debt_reminders_enabled,
        debt_reminder_frequency,
        quiet_hours_start,
        quiet_hours_end
      ]
    );
    
    res.json({
      success: true,
      message: 'PrÃ©fÃ©rences mises Ã  jour',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise Ã  jour',
      error: error.message
    });
  }
});

// ============================================
// 8. POST /api/notifications/send-debt-reminders (Admin/Cron)
// ============================================
// Envoie les rappels de dette

router.post('/send-debt-reminders', authenticate, requireAdmin, async (req, res) => {
  try {
    const organizationId = req.user.organization_id;
    
    // RÃ©cupÃ©rer clients avec dettes et prÃ©fÃ©rences activÃ©es
    const clientsResult = await db.query(
      `SELECT
        u.id,
        u.name,
        u.organization_id,
        cd.debt,
        cd.order_count,
        np.debt_reminders_enabled,
        np.debt_reminder_frequency,
        MAX(n.created_at) as last_reminder
       FROM users u
       INNER JOIN client_debts_view cd ON cd.client_id = u.id
       LEFT JOIN notification_preferences np ON np.user_id = u.id
       LEFT JOIN notifications n ON n.user_id = u.id AND n.type = 'debt_reminder'
       WHERE u.organization_id = $1
         AND u.role = 'customer'
         AND cd.debt > 0
         AND COALESCE(np.debt_reminders_enabled, false) = true
       GROUP BY u.id, u.name, u.organization_id, cd.debt, cd.order_count, np.debt_reminders_enabled, np.debt_reminder_frequency`,
      [organizationId]
    );
    
    let sentCount = 0;
    
    for (const client of clientsResult.rows) {
      const frequency = client.debt_reminder_frequency || 7;
      const lastReminder = client.last_reminder ? new Date(client.last_reminder) : null;
      const daysSinceLastReminder = lastReminder
        ? Math.floor((Date.now() - lastReminder.getTime()) / (1000 * 60 * 60 * 24))
        : 999;
      
      // Envoyer si pas de rappel ou si frÃ©quence dÃ©passÃ©e
      if (daysSinceLastReminder >= frequency) {
        await db.query(
          'SELECT notify_debt_reminder($1, $2, $3, $4)',
          [client.id, client.organization_id, client.debt, client.order_count]
        );
        sentCount++;
      }
    }
    
    res.json({
      success: true,
      message: `${sentCount} rappel(s) envoyÃ©(s)`,
      data: { sent: sentCount, total: clientsResult.rows.length }
    });
  } catch (error) {
    console.error('Error sending debt reminders:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'envoi des rappels',
      error: error.message
    });
  }
});

// ============================================
// 9. GET /api/notifications/stats (Admin)
// ============================================
// Statistiques sur les notifications

router.get('/stats', authenticate, requireAdmin, async (req, res) => {
  try {
    const organizationId = req.user.organization_id;
    
    const result = await db.query(
      `SELECT
        COUNT(*) as total_notifications,
        COUNT(CASE WHEN is_read = false THEN 1 END) as unread_count,
        COUNT(CASE WHEN type = 'payment_recorded' THEN 1 END) as payment_notifications,
        COUNT(CASE WHEN type = 'debt_cleared' THEN 1 END) as debt_cleared_notifications,
        COUNT(CASE WHEN type = 'favorite_suggested' THEN 1 END) as favorite_notifications,
        COUNT(CASE WHEN type = 'debt_reminder' THEN 1 END) as debt_reminders,
        COUNT(DISTINCT user_id) as users_with_notifications
       FROM notifications
       WHERE organization_id = $1
         AND created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'`,
      [organizationId]
    );
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching notification stats:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la rÃ©cupÃ©ration des statistiques',
      error: error.message
    });
  }
});

module.exports = router;
