/**
 * Pagination Helper
 * Standardise la gestion de la pagination pour l'API
 */

/**
 * Extrait les paramÃ¨tres de pagination de la requÃªte
 * @param {Object} query - req.query
 * @param {number} defaultLimit - Limite par dÃ©faut (def: 20)
 * @param {number} maxLimit - Limite maximum (def: 100)
 * @returns {Object} { page, limit, offset }
 */
const getPagination = (query, defaultLimit = 20, maxLimit = 100) => {
    const page = Math.max(1, parseInt(query.page, 10) || 1);
    const limit = Math.min(
        Math.max(1, parseInt(query.limit, 10) || defaultLimit),
        maxLimit
    );
    const offset = (page - 1) * limit;

    return { page, limit, offset };
};

/**
 * Formate la rÃ©ponse avec les donnÃ©es et les mÃ©tadonnÃ©es de pagination
 * @param {Array} data - Les donnÃ©es de la page courante
 * @param {number} total - Nombre total d'Ã©lÃ©ments
 * @param {number} page - NumÃ©ro de page courant
 * @param {number} limit - Limite par page
 * @returns {Object} { success: true, data, pagination: { ... } }
 */
const getPagingData = (data, total, page, limit) => {
    const totalItems = parseInt(total, 10);
    const totalPages = Math.max(1, Math.ceil(totalItems / limit));

    return {
        success: true,
        data,
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages,
            hasMore: page < totalPages,
            hasPrev: page > 1
        }
    };
};

module.exports = {
    getPagination,
    getPagingData
};
