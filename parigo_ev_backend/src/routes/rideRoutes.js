const express = require('express');
const router = express.Router();
const rideController = require('../controllers/rideController');

router.post('/create', rideController.createRide);
router.get('/active', rideController.getActiveRide);
router.get('/customer', rideController.getCustomerRides);
router.get('/history/:phone', rideController.getHistory);
router.post('/feedback', rideController.submitFeedback);
router.post('/cancel', rideController.cancelRide);

router.post('/estimate', rideController.estimateFare);
router.get('/slot-availability', rideController.checkSlotAvailability);
router.post('/schedule', rideController.scheduleRide);
router.post('/pay', rideController.payRide);
router.get('/:rideId/messages', rideController.getMessages);
router.post('/:rideId/messages', rideController.sendMessage);

module.exports = router;
