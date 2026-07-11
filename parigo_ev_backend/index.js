require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const db = require('./db');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin — supports both local file and Railway env var
try {
  let serviceAccount;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    // Railway / Production: decode from base64 environment variable
    const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
    serviceAccount = JSON.parse(decoded);
    console.log('Firebase credentials loaded from environment variable.');
  } else {
    // Local development: load from file
    serviceAccount = require('./serviceAccountKey.json');
    console.log('Firebase credentials loaded from serviceAccountKey.json.');
  }

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
  console.log('Firebase Admin Initialized successfully.');
} catch (error) {
  console.warn('Warning: Firebase Admin is NOT initialized.', error.message);
}

const app = express();
app.use(cors());
app.use(express.json({ 
  limit: '10mb', 
  verify: (req, res, buf) => { req.rawBody = buf; } 
}));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Trust proxy if behind a load balancer
app.set('trust proxy', 1);

// Rate limiters
const apiLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 1500, standardHeaders: true, legacyHeaders: false });
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 500, standardHeaders: true, legacyHeaders: false, message: { error: 'Too many auth requests from this IP' } });

app.use('/api/', apiLimiter);
app.use('/api/auth/', authLimiter);

// Ensure uploads dir
if (!fs.existsSync(path.join(__dirname, 'uploads'))) {
  fs.mkdirSync(path.join(__dirname, 'uploads'));
}

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Parigo EV Backend is running.' });
});

// Mount routers
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const driverRoutes = require('./src/routes/driverRoutes');
const adminRoutes = require('./src/routes/adminRoutes');
const rideRoutes = require('./src/routes/rideRoutes');
const walletRoutes = require('./src/routes/walletRoutes');
const notificationRoutes = require('./src/routes/notificationRoutes');
const customerRoutes = require('./src/routes/customerRoutes');
const { verifyToken } = require('./src/middleware/authMiddleware');

app.use('/api/auth', authRoutes); // Public endpoints

const walletController = require('./src/controllers/walletController');
app.post('/api/webhook/razorpay', walletController.razorpayWebhook);

app.use('/api/user/notifications', verifyToken, notificationRoutes); 
app.use('/api/user', verifyToken, userRoutes);
app.use('/api/customer', verifyToken, customerRoutes);
app.use('/api/driver', verifyToken, driverRoutes);
app.use('/api/admin', verifyToken, adminRoutes);
app.use('/api/ride', verifyToken, rideRoutes);
app.use('/api/rides', verifyToken, rideRoutes);
app.use('/api/wallet', verifyToken, walletRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on port ${PORT}`);
});

