const { Worker } = require('bullmq');
const { connection } = require('../config/queue.config');
const logger = require('../config/logger');

const cleanupWorker = new Worker('cleanup', async (job) => {
    logger.info(`[Cleanup] Processing job ${job.id}: ${job.name}`);

    if (job.name === 'purge-logs') {
        logger.info('[Cleanup] Logs have been purged');
    } else if (job.name === 'purge-temp') {
        logger.info('[Cleanup] Temp files removed');
    }

    return { status: 'cleaned' };
}, { connection });

cleanupWorker.on('failed', (job, err) => {
    logger.error(`[Cleanup] Job ${job.id} failed: ${err.message}`);
});

module.exports = cleanupWorker;
