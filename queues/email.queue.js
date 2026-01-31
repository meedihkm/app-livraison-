const { Queue } = require('bullmq');
const { connection, defaultJobOptions } = require('../config/queue.config');

const emailQueue = new Queue('email', {
    connection,
    defaultJobOptions,
});

module.exports = emailQueue;
