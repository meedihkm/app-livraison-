const { Worker } = require('bullmq');
const { connection } = require('../config/queue.config');
const logger = require('../config/logger');

const reportWorker = new Worker('report', async (job) => {
    logger.info(`[Report] Processing job ${job.id}: ${job.name}`);

    // Simulation gÃ©nÃ©ration lourde
    await new Promise(resolve => setTimeout(resolve, 2000));

    logger.info(`[Report] Job ${job.id} completed`);
    return { url: 'https://example.com/report.pdf', size: '1.2MB' };
}, { connection });

reportWorker.on('failed', (job, err) => {
    logger.error(`[Report] Job ${job.id} failed: ${err.message}`);
});

module.exports = reportWorker;
