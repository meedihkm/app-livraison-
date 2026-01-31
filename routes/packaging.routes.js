/**
 * Packaging Routes
 * API endpoints pour la gestion des consignes
 */

const express = require('express');
const router = express.Router();

const { authenticate, requireAdmin, authorize } = require('../middleware/auth');
const { validate, validateUUID } = require('../middleware/validate');
const { logAudit } = require('../services/audit.service');
const packagingService = require('../services/packaging.service');

// ===== TYPES DE CONSIGNES =====

/**
 * GET /api/packaging/types
 * Liste tous les types de consignes
 */
router.get('/types', authenticate, async (req, res) => {
    try {
        const includeInactive = req.query.all === 'true' && req.user.role === 'admin';
        const types = await packagingService.getPackagingTypes(req.user.organization_id, includeInactive);

        res.json({ success: true, data: types });
    } catch (error) {
        console.error('Error fetching packaging types:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /api/packaging/types
 * CrÃ©er un nouveau type de consigne (Admin)
 */
router.post('/types', authenticate, requireAdmin, async (req, res) => {
    try {
        const { name, description, depositValue } = req.body;

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ error: 'Nom requis' });
        }

        const type = await packagingService.createPackagingType({
            organizationId: req.user.organization_id,
            name: name.trim(),
            description,
            depositValue
        });

        await logAudit({
            action: 'CREATE_PACKAGING_TYPE',
            performedBy: req.user.id,
            organizationId: req.user.organization_id,
            targetType: 'packaging_type',
            targetId: type.id,
            details: { name: type.name }
        });

        res.status(201).json({ success: true, data: type });
    } catch (error) {
        console.error('Error creating packaging type:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PUT /api/packaging/types/:id
 * Modifier un type de consigne (Admin)
 */
router.put('/types/:id', authenticate, requireAdmin, validateUUID('id'), async (req, res) => {
    try {
        const { name, description, depositValue, active } = req.body;

        const type = await packagingService.updatePackagingType(
            req.params.id,
            req.user.organization_id,
            { name, description, depositValue, active }
        );

        if (!type) {
            return res.status(404).json({ error: 'Type non trouvÃ©' });
        }

        await logAudit({
            action: 'UPDATE_PACKAGING_TYPE',
            performedBy: req.user.id,
            organizationId: req.user.organization_id,
            targetType: 'packaging_type',
            targetId: type.id,
            details: req.body
        });

        res.json({ success: true, data: type });
    } catch (error) {
        console.error('Error updating packaging type:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ===== TRANSACTIONS =====

/**
 * POST /api/packaging/deposits
 * Enregistrer une transaction (donner/retourner)
 */
router.post('/deposits', authenticate, authorize(['admin', 'deliverer']), async (req, res) => {
    try {
        const { customerId, packagingTypeId, quantity, deliveryId, note } = req.body;

        if (!customerId || !packagingTypeId || !quantity) {
            return res.status(400).json({ error: 'customerId, packagingTypeId et quantity requis' });
        }

        if (typeof quantity !== 'number' || quantity === 0) {
            return res.status(400).json({ error: 'QuantitÃ© invalide (doit Ãªtre non-zÃ©ro)' });
        }

        const deposit = await packagingService.recordDeposit({
            organizationId: req.user.organization_id,
            customerId,
            packagingTypeId,
            quantity,
            deliveryId,
            recordedBy: req.user.id,
            note
        });

        await logAudit({
            action: quantity > 0 ? 'PACKAGING_GIVEN' : 'PACKAGING_RETURNED',
            performedBy: req.user.id,
            organizationId: req.user.organization_id,
            targetType: 'packaging_deposit',
            targetId: deposit.id,
            details: { customerId, packagingTypeId, quantity, typeName: deposit.typeName }
        });

        res.status(201).json({ success: true, data: deposit });
    } catch (error) {
        console.error('Error recording deposit:', error);
        res.status(error.message === 'Type de consigne invalide' ? 400 : 500)
            .json({ error: error.message || 'Erreur serveur' });
    }
});

// ===== SOLDES & HISTORIQUE =====

/**
 * GET /api/packaging/customers/:id/balance
 * Solde des consignes pour un client
 */
router.get('/customers/:id/balance', authenticate, validateUUID('id'), async (req, res) => {
    try {
        const balance = await packagingService.getCustomerBalance(
            req.params.id,
            req.user.organization_id
        );

        res.json({ success: true, data: balance });
    } catch (error) {
        console.error('Error fetching customer balance:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /api/packaging/customers/:id/history
 * Historique des transactions pour un client
 */
router.get('/customers/:id/history', authenticate, validateUUID('id'), async (req, res) => {
    try {
        const { limit = 50, offset = 0, type } = req.query;

        const history = await packagingService.getDepositHistory(
            req.params.id,
            req.user.organization_id,
            { limit: parseInt(limit), offset: parseInt(offset), packagingTypeId: type }
        );

        res.json({ success: true, data: history });
    } catch (error) {
        console.error('Error fetching deposit history:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /api/packaging/summary
 * RÃ©sumÃ© des consignes pour l'organisation (Admin)
 */
router.get('/summary', authenticate, requireAdmin, async (req, res) => {
    try {
        const summary = await packagingService.getOrganizationSummary(req.user.organization_id);

        res.json({ success: true, data: summary });
    } catch (error) {
        console.error('Error fetching organization summary:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
