const emailQueue = require('./email.queue');
const reportQueue = require('./report.queue');
const cleanupQueue = require('./cleanup.queue');

module.exports = {
    emailQueue,
    reportQueue,
    cleanupQueue,
    queues: [emailQueue, reportQueue, cleanupQueue]
};
