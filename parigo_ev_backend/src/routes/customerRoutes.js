const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');

router.get('/rides/history', customerController.getCustomerHistoryRides);

module.exports = router;
