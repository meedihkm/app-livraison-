/**
 * Packaging Service
 * Gestion des consignes (emballages retournables)
 */

const pool = require('../config/database');
const logger = require('../config/logger');

/**
 * RÃ©cupÃ¨re tous les types de consignes actifs
 */
async function getPackagingTypes(organizationId, includeInactive = false) {
    const query = includeInactive
        ? `SELECT * FROM packaging_types WHERE organization_id = $1 ORDER BY name`
        : `SELECT * FROM packaging_types WHERE organization_id = $1 AND active = true ORDER BY name`;

    const result = await pool.query(query, [organizationId]);
    return result.rows.map(formatPackagingType);
}

/**
 * RÃ©cupÃ¨re un type de consigne par ID
 */
async function getPackagingTypeById(id, organizationId) {
    const result = await pool.query(
        `SELECT * FROM packaging_types WHERE id = $1 AND organization_id = $2`,
        [id, organizationId]
    );
    return result.rows[0] ? formatPackagingType(result.rows[0]) : null;
}

/**
 * CrÃ©e un nouveau type de consigne
 */
async function createPackagingType(data) {
    const { organizationId, name, description, depositValue } = data;

    const result = await pool.query(
        `INSERT INTO packaging_types (organization_id, name, description, deposit_value)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
        [organizationId, name, description || null, depositValue || 0]
    );

    logger.info(`Packaging type created: ${name} for org ${organizationId}`);
    return formatPackagingType(result.rows[0]);
}

/**
 * Met Ã  jour un type de consigne
 */
async function updatePackagingType(id, organizationId, data) {
    const { name, description, depositValue, active } = data;

    const result = await pool.query(
        `UPDATE packaging_types 
     SET name = COALESCE($3, name),
         description = COALESCE($4, description),
         deposit_value = COALESCE($5, deposit_value),
         active = COALESCE($6, active),
         updated_at = NOW()
     WHERE id = $1 AND organization_id = $2
     RETURNING *`,
        [id, organizationId, name, description, depositValue, active]
    );

    return result.rows[0] ? formatPackagingType(result.rows[0]) : null;
}

/**
 * Enregistre une transaction de consigne
 * @param {Object} data - { organizationId, customerId, packagingTypeId, quantity, deliveryId?, recordedBy, note? }
 */
async function recordDeposit(data) {
    const { organizationId, customerId, packagingTypeId, quantity, deliveryId, recordedBy, note } = data;

    // VÃ©rifier que le type existe
    const typeCheck = await pool.query(
        `SELECT id, name FROM packaging_types WHERE id = $1 AND organization_id = $2`,
        [packagingTypeId, organizationId]
    );

    if (typeCheck.rows.length === 0) {
        throw new Error('Type de consigne invalide');
    }

    const result = await pool.query(
        `INSERT INTO packaging_deposits 
     (organization_id, customer_id, packaging_type_id, delivery_id, quantity, recorded_by, note)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
        [organizationId, customerId, packagingTypeId, deliveryId || null, quantity, recordedBy, note || null]
    );

    const action = quantity > 0 ? 'given' : 'returned';
    logger.info(`Packaging ${action}: ${Math.abs(quantity)} x ${typeCheck.rows[0].name} for customer ${customerId}`);

    return {
        ...formatDeposit(result.rows[0]),
        typeName: typeCheck.rows[0].name
    };
}

/**
 * RÃ©cupÃ¨re le solde des consignes pour un client
 */
async function getCustomerBalance(customerId, organizationId) {
    const result = await pool.query(
        `SELECT 
       cpb.packaging_type_id,
       cpb.type_name,
       cpb.deposit_value,
       cpb.total_given,
       cpb.total_returned,
       cpb.outstanding
     FROM customer_packaging_balance cpb
     WHERE cpb.customer_id = $1 AND cpb.organization_id = $2
     ORDER BY cpb.type_name`,
        [customerId, organizationId]
    );

    return result.rows.map(row => ({
        packagingTypeId: row.packaging_type_id,
        typeName: row.type_name,
        depositValue: parseFloat(row.deposit_value) || 0,
        totalGiven: parseInt(row.total_given) || 0,
        totalReturned: parseInt(row.total_returned) || 0,
        outstanding: parseInt(row.outstanding) || 0
    }));
}

/**
 * RÃ©cupÃ¨re l'historique des transactions pour un client
 */
async function getDepositHistory(customerId, organizationId, options = {}) {
    const { limit = 50, offset = 0, packagingTypeId } = options;

    let query = `
    SELECT pd.*, pt.name as type_name, u.name as recorded_by_name
    FROM packaging_deposits pd
    JOIN packaging_types pt ON pd.packaging_type_id = pt.id
    LEFT JOIN users u ON pd.recorded_by = u.id::text
    WHERE pd.customer_id = $1 AND pd.organization_id = $2
  `;
    const params = [customerId, organizationId];

    if (packagingTypeId) {
        params.push(packagingTypeId);
        query += ` AND pd.packaging_type_id = $${params.length}`;
    }

    query += ` ORDER BY pd.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    return result.rows.map(row => ({
        ...formatDeposit(row),
        typeName: row.type_name,
        recordedByName: row.recorded_by_name
    }));
}

/**
 * RÃ©sumÃ© des consignes pour toute l'organisation
 */
async function getOrganizationSummary(organizationId) {
    const result = await pool.query(
        `SELECT 
       pt.id as packaging_type_id,
       pt.name as type_name,
       pt.deposit_value,
       COALESCE(SUM(CASE WHEN pd.quantity > 0 THEN pd.quantity ELSE 0 END), 0) as total_given,
       COALESCE(SUM(CASE WHEN pd.quantity < 0 THEN ABS(pd.quantity) ELSE 0 END), 0) as total_returned,
       COALESCE(SUM(pd.quantity), 0) as total_outstanding,
       COUNT(DISTINCT pd.customer_id) as customers_count
     FROM packaging_types pt
     LEFT JOIN packaging_deposits pd ON pt.id = pd.packaging_type_id
     WHERE pt.organization_id = $1 AND pt.active = true
     GROUP BY pt.id, pt.name, pt.deposit_value
     ORDER BY pt.name`,
        [organizationId]
    );

    return result.rows.map(row => ({
        packagingTypeId: row.packaging_type_id,
        typeName: row.type_name,
        depositValue: parseFloat(row.deposit_value) || 0,
        totalGiven: parseInt(row.total_given) || 0,
        totalReturned: parseInt(row.total_returned) || 0,
        totalOutstanding: parseInt(row.total_outstanding) || 0,
        customersCount: parseInt(row.customers_count) || 0
    }));
}

// ===== Helpers =====

function formatPackagingType(row) {
    return {
        id: row.id,
        organizationId: row.organization_id,
        name: row.name,
        description: row.description,
        depositValue: parseFloat(row.deposit_value) || 0,
        active: row.active,
        createdAt: row.created_at,
        updatedAt: row.updated_at
    };
}

function formatDeposit(row) {
    return {
        id: row.id,
        organizationId: row.organization_id,
        customerId: row.customer_id,
        packagingTypeId: row.packaging_type_id,
        deliveryId: row.delivery_id,
        quantity: row.quantity,
        recordedBy: row.recorded_by,
        note: row.note,
        createdAt: row.created_at
    };
}

module.exports = {
    getPackagingTypes,
    getPackagingTypeById,
    createPackagingType,
    updatePackagingType,
    recordDeposit,
    getCustomerBalance,
    getDepositHistory,
    getOrganizationSummary
};
