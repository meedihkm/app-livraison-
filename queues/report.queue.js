const { Queue } = require('bullmq');
const { connection, defaultJobOptions } = require('../config/queue.config');

const reportQueue = new Queue('report', {
    connection,
    defaultJobOptions,
});

module.exports = reportQueue;
