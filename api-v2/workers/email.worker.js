const { Worker } = require('bullmq');
const { connection } = require('../config/queue.config');
const logger = require('../config/logger');

const emailWorker = new Worker('email', async (job) => {
    logger.info(`[Email] Processing job ${job.id}: ${job.name}`);

    // Simuler l'envoi d'email
    await new Promise(resolve => setTimeout(resolve, 500));

    if (job.name === 'fail-test') {
        throw new Error('Test d\'Ã©chec d\'envoi d\'email');
    }

    logger.info(`[Email] Job ${job.id} completed`);
    return { sent: true, recipient: job.data.to };
}, { connection });

emailWorker.on('failed', (job, err) => {
    logger.error(`[Email] Job ${job.id} failed: ${err.message}`);
});

module.exports = emailWorker;
