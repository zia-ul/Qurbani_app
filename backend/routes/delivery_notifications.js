const express = require('express');
const router = express.Router();
const { getMyNotifications, markAsRead } = require('../controllers/notification.controller');
const auth = require('../middlewares/auth');

// Get notifications for logged-in user
router.get('/my', auth, getMyNotifications);

// Mark notification as read
router.put('/:id/read', auth, markAsRead);

module.exports = router;
