const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

router.post('/verify-otp', authController.verifyOtp);
router.post('/check-user', authController.checkUser);
router.post('/set-pin', authController.setPin);
router.post('/verify-pin', authController.verifyPin);

module.exports = router;
