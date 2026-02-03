const { Queue } = require('bullmq');
const { connection, defaultJobOptions } = require('../config/queue.config');

const cleanupQueue = new Queue('cleanup', {
    connection,
    defaultJobOptions,
});

// Ajouter les tÃ¢ches rÃ©currentes au dÃ©marrage
async function setupRecurringJobs() {
    // Purge logs every night at 3 AM
    await cleanupQueue.add('purge-logs', {}, {
        repeat: {
            pattern: '0 3 * * *',
        },
    });

    // Purge temp files every hour
    await cleanupQueue.add('purge-temp', {}, {
        repeat: {
            pattern: '0 * * * *',
        },
    });
}

// Initialiser les jobs rÃ©currents (Ã  appeler au dÃ©marrage du worker ou de l'app)
setupRecurringJobs().catch(console.error);

module.exports = cleanupQueue;
