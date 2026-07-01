const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

router.get('/:phone', notificationController.getNotifications);
router.post('/mark-read', notificationController.markAsRead);
router.get('/unread-count/:phone', notificationController.getUnreadCount);
router.post('/test', notificationController.testNotification);

module.exports = router;
