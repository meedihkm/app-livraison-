/**
 * Routes de diagnostic et santÃ© (Health Checks)
 * UtilisÃ©es par K8s, Docker Swarm ou Load Balancers
 */

const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { testConnection } = require('../config/database');

// Liveness probe (/health)
// Simple retour 200 pour dire "le processus nodejs tourne"
router.get('/', (req, res) => {
    res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Liveness alias
router.get('/live', (req, res) => {
    res.status(200).json({ status: 'alive' });
});

// Readiness probe (/health/ready)
// VÃ©rifie les dÃ©pendances critiques (DB, etc.)
router.get('/ready', async (req, res) => {
    const health = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        dependencies: {
            database: 'unknown'
        }
    };

    try {
        // Check DB
        const dbStart = Date.now();
        await pool.query('SELECT 1');
        health.dependencies.database = {
            status: 'up',
            latency: `${Date.now() - dbStart}ms`
        };

        // Check Redis (si ajoutÃ© plus tard)

        res.status(200).json(health);
    } catch (error) {
        health.status = 'error';
        health.dependencies.database = {
            status: 'down',
            error: error.message
        };

        // Retourner 503 Service Unavailable si une dÃ©pendence critique est down
        res.status(503).json(health);
    }
});

module.exports = router;
