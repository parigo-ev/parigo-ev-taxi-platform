const express = require('express');
const router = express.Router();
const driverController = require('../controllers/driverController');

router.get('/profile/:phone', driverController.getProfile);
router.post('/update-location', driverController.updateLocation);
router.get('/location/:driverId', driverController.getLocation);
router.post('/location/update', driverController.updateLocation); // Alias mapping based on existing index.js logic
router.post('/upload-photo', driverController.uploadPhoto);
router.get('/rides/assigned', driverController.getAssignedRides);
router.get('/rides/history', driverController.getHistoryRides);
router.post('/rides/update-status', driverController.updateRideStatus);
router.get('/earnings', driverController.getEarnings);
router.post('/status', driverController.updateStatus);

module.exports = router;
