const axios = require('axios');
const logger = require('../config/logger');

class NotificationService {
    constructor() {
        this.apiUrl = 'https://onesignal.com/api/v1/notifications';
        this.appId = process.env.ONESIGNAL_APP_ID;
        this.apiKey = process.env.ONESIGNAL_REST_API_KEY;
    }

    /**
     * Envoie une notification Ã  un utilisateur spÃ©cifique
     * @param {string} userId - ID de l'utilisateur (external_user_id)
     * @param {string} title - Titre de la notification
     * @param {string} message - Corps du message
     * @param {Object} data - DonnÃ©es additionnelles pour deep link { type: 'order', id: '...' }
     */
    async sendToUser(userId, title, message, data = {}) {
        if (!this.appId || !this.apiKey) {
            logger.warn('[Notification] OneSignal credentials missing');
            return false;
        }

        try {
            const payload = {
                app_id: this.appId,
                include_aliases: {
                    external_id: [userId]
                },
                target_channel: "push",
                headings: { fr: title, en: title },
                contents: { fr: message, en: message },
                data: data,
                // Android specific
                android_accent_color: 'FF2E7D32', // Green
                small_icon: 'ic_stat_onesignal_default',
            };

            const response = await axios.post(this.apiUrl, payload, {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${this.apiKey}`
                }
            });

            logger.info(`[Notification] Sent to ${userId}: ${response.data.id}`);
            return true;
        } catch (error) {
            logger.error(`[Notification] Failed to send to ${userId}: ${error.response?.data?.errors?.[0] || error.message}`);
            return false;
        }
    }

    /**
     * Envoie une notification Ã  plusieurs utilisateurs
     */
    async sendToUsers(userIds, title, message, data = {}) {
        if (!this.appId || !this.apiKey) return false;

        try {
            // Note: OneSignal recommande des batchs si > 2000 users, mais ici c'est B2B
            const payload = {
                app_id: this.appId,
                include_aliases: {
                    external_id: userIds
                },
                target_channel: "push",
                headings: { fr: title, en: title },
                contents: { fr: message, en: message },
                data: data,
                android_accent_color: 'FF2E7D32',
            };

            const response = await axios.post(this.apiUrl, payload, {
                headers: { 'Authorization': `Basic ${this.apiKey}` }
            });

            return true;
        } catch (error) {
            logger.error(`[Notification] Batch failed: ${error.message}`);
            return false;
        }
    }
}

module.exports = new NotificationService();
