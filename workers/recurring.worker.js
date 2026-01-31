/**
 * Recurring Orders Worker
 * Traite les commandes rÃ©currentes automatiquement selon leur planification
 */

const { Worker } = require('bullmq');
const { connection } = require('../config/queue.config');
const logger = require('../config/logger');
const recurringService = require('../services/recurring.service');

const recurringWorker = new Worker('recurring', async (job) => {
    logger.info(`[Recurring] Processing job ${job.id}: ${job.name}`);

    if (job.name === 'process-recurring-orders') {
        try {
            const generatedOrders = await recurringService.processRecurringOrders();
            logger.info(`[Recurring] Generated ${generatedOrders.length} orders`);
            return {
                status: 'completed',
                ordersGenerated: generatedOrders.length,
                orders: generatedOrders
            };
        } catch (error) {
            logger.error(`[Recurring] Error processing recurring orders:`, error);
            throw error;
        }
    }

    return { status: 'unknown job' };
}, { connection });

recurringWorker.on('completed', (job, result) => {
    if (result.ordersGenerated > 0) {
        logger.info(`[Recurring] Job ${job.id} completed: ${result.ordersGenerated} orders generated`);
    }
});

recurringWorker.on('failed', (job, err) => {
    logger.error(`[Recurring] Job ${job?.id} failed: ${err.message}`);
});

module.exports = recurringWorker;
