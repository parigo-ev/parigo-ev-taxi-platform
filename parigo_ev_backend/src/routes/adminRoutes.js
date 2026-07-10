const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');

router.post('/report-crash', adminController.reportCrash);
router.get('/rides/pending', adminController.getPendingRides);
router.post('/allot-ride', adminController.allotRide);
router.get('/rides/active', adminController.getActiveRides);
router.get('/rides/completed', adminController.getCompletedRides);
router.get('/drivers/available', adminController.getAvailableDrivers);
router.get('/drivers/for-slot', adminController.getDriversForSlot);
router.post('/drivers/add', adminController.addDriver);
router.post('/admins/add', adminController.addAdmin);
router.get('/fleet', adminController.getFleet);
router.get('/customers', adminController.getCustomers);
router.get('/analytics', adminController.getAnalytics);
router.post('/settings/slot-capacity', adminController.updateSlotCapacity);
router.get('/settings/slot-capacity', adminController.getSlotCapacity);
router.get('/feedback', adminController.getFeedback);
router.post('/send-promo', adminController.sendPromo);
router.post('/coupon/create', adminController.createCoupon);

module.exports = router;
