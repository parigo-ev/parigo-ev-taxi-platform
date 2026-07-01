const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');

router.get('/profile/:phone', userController.getProfile);
router.post('/update-profile-picture', userController.updateProfilePicture);
router.delete('/delete/:phone', userController.deleteAccount);
router.post('/update-profile', userController.updateProfile);

module.exports = router;
