const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');

router.get('/balance/:phone', walletController.getBalance);
router.get('/transactions/:phone', walletController.getTransactions);
router.post('/add-funds', walletController.addFunds);
router.post('/create-order', walletController.createRazorpayOrder);
router.post('/verify-payment', walletController.verifyPayment);
router.post('/phonepe/create-order', walletController.phonepeCreateOrder);
router.post('/phonepe/verify', walletController.phonepeVerifyPayment);

module.exports = router;
