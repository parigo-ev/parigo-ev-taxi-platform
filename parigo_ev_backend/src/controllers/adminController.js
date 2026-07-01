const admin = require('firebase-admin');
const db = require('../../db');

const reportCrash = async (req, res) => {
  try {
    const { role, phone, errorMessage, stackTrace } = req.body;
    
    // Find all admins
    const adminsResult = await db.query("SELECT uid FROM users WHERE role = 'admin' AND uid IS NOT NULL");
    
    const shortError = errorMessage ? errorMessage.substring(0, 100) : 'Unknown error';
    const message = `A crash occurred for a ${role || 'User'} (Phone: ${phone || 'Unknown'}). Error: ${shortError}`;
    
    const metadata = JSON.stringify({
      fullError: errorMessage,
      stackTrace: stackTrace
    });
    
    // Insert notification for each admin
    for (const adm of adminsResult.rows) {
      await db.query(
        'INSERT INTO notifications (uid, title, message, type, metadata) VALUES ($1, $2, $3, $4, $5)',
        [adm.uid, 'Critical App Crash 🚨', message, 'crash_alert', metadata]
      );
    }
    
    res.status(200).json({ success: true, message: 'Crash reported to admins' });
  } catch (error) {
    console.error('Error reporting crash:', error);
    res.status(500).json({ error: 'Failed to report crash' });
  }
};

const getPendingRides = async (req, res) => {
  try {
    const snapshot = await admin.firestore().collection('rides')
      .where('status', '==', 'SCHEDULED')
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching pending rides:', error);
    res.status(500).json({ error: 'Failed to fetch pending rides' });
  }
};

const allotRide = async (req, res) => {
  try {
    const { rideId, driverId } = req.body;
    if (!rideId || !driverId) {
      return res.status(400).json({ error: 'rideId and driverId are required' });
    }

    const etaTime = new Date();
    etaTime.setMinutes(etaTime.getMinutes() + 10); // Placeholder 10 min ETA

    await admin.firestore().collection('rides').doc(rideId).update({
      status: 'ALLOTTED',
      assignedDriverId: driverId,
      allottedAt: admin.firestore.FieldValue.serverTimestamp(),
      driverEtaTime: etaTime
    });

    res.status(200).json({ success: true, message: 'Ride allotted successfully' });
  } catch (error) {
    console.error('Error allotting ride:', error);
    res.status(500).json({ error: 'Failed to allot ride' });
  }
};

const getActiveRides = async (req, res) => {
  try {
    const snapshot = await admin.firestore().collection('rides')
      .where('status', 'in', ['ALLOTTED', 'IN_PROGRESS'])
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    for (let ride of rides) {
      if (ride.assignedDriverId) {
        try {
           const result = await db.query('SELECT name FROM drivers WHERE driver_uid = $1', [ride.assignedDriverId]);
           if (result.rows.length > 0) {
             ride.driverName = result.rows[0].name;
           }
        } catch (err) {
           console.error('Error fetching driver details for active ride:', err);
        }
      }
      if (ride.uid) {
        try {
           const result = await db.query('SELECT name, phone FROM users WHERE uid = $1', [ride.uid]);
           if (result.rows.length > 0) {
             ride.customerName = result.rows[0].name || result.rows[0].phone || 'Unknown';
           }
        } catch (err) {
           console.error('Error fetching customer details for active ride:', err);
        }
      }
    }

    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching active rides:', error);
    res.status(500).json({ error: 'Failed to fetch active rides' });
  }
};

const getCompletedRides = async (req, res) => {
  try {
    const snapshot = await admin.firestore().collection('rides')
      .where('status', '==', 'COMPLETED')
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    // Populate driver details
    for (let ride of rides) {
      if (ride.assignedDriverId) {
        try {
           const result = await db.query('SELECT name, vehicle_type, phone, profile_picture_url FROM drivers WHERE driver_uid = $1', [ride.assignedDriverId]);
           if (result.rows.length > 0) {
              ride.driverDetails = result.rows[0];
           }
        } catch (e) {
           console.error('Error fetching driver details for history ride:', e);
        }
      }
      
      // Populate customer details
      if (ride.uid && ride.uid !== 'anonymous') {
        try {
           const result = await db.query('SELECT name, phone FROM users WHERE uid = $1', [ride.uid]);
           if (result.rows.length > 0) {
              ride.customerDetails = result.rows[0];
           }
        } catch (e) {
           console.error('Error fetching customer details for history ride:', e);
        }
      }
    }

    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching completed rides:', error);
    res.status(500).json({ error: 'Failed to fetch completed rides' });
  }
};

const getAvailableDrivers = async (req, res) => {
  try {
    const result = await db.query('SELECT driver_uid as id, name, lat, lng FROM drivers');
    res.status(200).json({ success: true, drivers: result.rows });
  } catch (error) {
    console.error('Error fetching available drivers:', error);
    res.status(500).json({ error: 'Failed to fetch drivers' });
  }
};

const getDriversForSlot = async (req, res) => {
  try {
    const { date, time } = req.query;
    if (!date || !time) {
      return res.status(400).json({ error: 'date and time are required' });
    }

    const result = await db.query('SELECT driver_uid as id, name, lat, lng FROM drivers');
    const drivers = result.rows;

    const snapshot = await admin.firestore().collection('rides')
      .where('scheduledDate', '==', date)
      .where('scheduledTime', '==', time)
      .where('status', 'in', ['ALLOTTED', 'ARRIVED', 'IN_PROGRESS'])
      .get();
      
    const bookedDriverIds = new Set();
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.assignedDriverId) {
        bookedDriverIds.add(data.assignedDriverId);
      }
    });

    const enhancedDrivers = drivers.map(d => ({
      ...d,
      isBooked: bookedDriverIds.has(d.id)
    }));

    res.status(200).json({ success: true, drivers: enhancedDrivers });
  } catch (error) {
    console.error('Error fetching drivers for slot:', error);
    res.status(500).json({ error: 'Failed to fetch drivers for slot' });
  }
};

const addDriver = async (req, res) => {
  try {
    const { name, phone, email, pin, vehicleType, aadharNumber, licenseNumber, address } = req.body;
    
    if (!phone || !name || !pin || !vehicleType) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if phone already exists
    const existing = await db.query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Phone number already registered' });
    }

    const driverUid = 'driver_' + Date.now();

    // Insert into users
    const userResult = await db.query(`
      INSERT INTO users (uid, phone, role, pin, name, email) 
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, uid;
    `, [driverUid, phone, 'driver', pin, name, email]);

    const dId = userResult.rows[0].id;
    const dUid = userResult.rows[0].uid;

    // Insert into drivers
    await db.query(`
      INSERT INTO drivers (user_id, driver_uid, name, vehicle_type, aadhar_number, license_number, address, phone)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    `, [dId, dUid, name, vehicleType, aadharNumber, licenseNumber, address, phone]);

    res.status(200).json({ success: true, message: 'Driver added successfully' });
  } catch (error) {
    console.error('Error adding driver:', error);
    res.status(500).json({ error: 'Failed to add driver' });
  }
};

const addAdmin = async (req, res) => {
  try {
    const { name, phone, email, pin } = req.body;
    
    if (!phone || !name || !pin) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if phone already exists
    const existing = await db.query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Phone number already registered' });
    }

    const adminUid = 'admin_' + Date.now();

    // Insert into users
    await db.query(`
      INSERT INTO users (uid, phone, role, pin, name, email) 
      VALUES ($1, $2, $3, $4, $5, $6)
    `, [adminUid, phone, 'admin', pin, name, email]);

    res.status(200).json({ success: true, message: 'Admin added successfully' });
  } catch (error) {
    console.error('Error adding admin:', error);
    res.status(500).json({ error: 'Failed to add admin' });
  }
};

const getFleet = async (req, res) => {
  try {
    const result = await db.query('SELECT driver_uid as id, name, vehicle_type as vehicle, profile_picture_url, is_online FROM drivers');
    const fleet = result.rows.map(d => ({
      id: d.id,
      name: d.name || 'Unknown',
      vehicle: d.vehicle || 'Unknown EV',
      battery: Math.floor(Math.random() * 40) + 60, // Mocking battery between 60-100
      status: d.is_online ? 'ONLINE' : 'OFFLINE',
      range: '210 km', // Mocking range
      profile_picture_url: d.profile_picture_url
    }));
    res.status(200).json({ success: true, fleet });
  } catch (error) {
    console.error('Error fetching fleet:', error);
    res.status(500).json({ error: 'Failed to fetch fleet' });
  }
};

const getCustomers = async (req, res) => {
  try {
    const result = await db.query("SELECT id, uid, name, phone, email, created_at FROM users WHERE role = 'customer' ORDER BY created_at DESC");
    res.status(200).json({ success: true, customers: result.rows });
  } catch (error) {
    console.error('Error fetching customers:', error);
    res.status(500).json({ error: 'Failed to fetch customers' });
  }
};

const getAnalytics = async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        COUNT(*) as total_rides,
        COALESCE(SUM(fare), 0) as total_revenue
      FROM rides_history 
      WHERE status = 'COMPLETED'
    `);
    
    const stats = result.rows[0];
    res.status(200).json({
      totalRides: parseInt(stats.total_rides) || 0,
      totalRevenue: parseFloat(stats.total_revenue) || 0
    });
  } catch (error) {
    console.error('Error fetching admin analytics:', error);
    res.status(500).json({ error: 'Failed to fetch analytics' });
  }
};

const updateSlotCapacity = async (req, res) => {
  try {
    const { maxBookingsPerSlot } = req.body;
    if (maxBookingsPerSlot === undefined) {
      return res.status(400).json({ error: 'maxBookingsPerSlot is required' });
    }

    await admin.firestore().collection('settings').doc('global').set({
      maxBookingsPerSlot: parseInt(maxBookingsPerSlot)
    }, { merge: true });

    res.status(200).json({ success: true, message: 'Slot capacity updated' });
  } catch (error) {
    console.error('Error updating slot capacity:', error);
    res.status(500).json({ error: 'Failed to update slot capacity' });
  }
};

const getSlotCapacity = async (req, res) => {
  try {
    const doc = await admin.firestore().collection('settings').doc('global').get();
    let maxBookingsPerSlot = 5; // Default fallback
    if (doc.exists && doc.data().maxBookingsPerSlot !== undefined) {
      maxBookingsPerSlot = doc.data().maxBookingsPerSlot;
    }
    res.status(200).json({ success: true, maxBookingsPerSlot });
  } catch (error) {
    console.error('Error fetching slot capacity:', error);
    res.status(500).json({ error: 'Failed to fetch slot capacity' });
  }
};

const getFeedback = async (req, res) => {
  try {
    const query = `
      SELECT 
        r.id, 
        r.ride_id, 
        r.customer_rating, 
        r.customer_feedback, 
        r.created_at, 
        COALESCE(u.name, u.phone, 'Unknown Customer') AS customer_name, 
        COALESCE(d.name, d.phone, 'Unknown Driver') AS driver_name 
      FROM rides_history r 
      LEFT JOIN users u ON r.customer_uid = u.uid 
      LEFT JOIN drivers d ON r.driver_uid = d.driver_uid 
      WHERE r.customer_rating IS NOT NULL 
      ORDER BY r.created_at DESC
    `;
    const result = await db.query(query);
    res.status(200).json({ success: true, feedback: result.rows });
  } catch (error) {
    console.error('Error fetching admin feedback:', error);
    res.status(500).json({ error: 'Failed to fetch feedback' });
  }
};

const sendPromo = async (req, res) => {
  const { title, message, targetUid } = req.body; // if targetUid is null, send to all customers
  if (!title || !message) return res.status(400).json({ error: 'Title and message required' });
  
  try {
    if (targetUid) {
      await db.query(
        'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
        [targetUid, title, message, 'promo']
      );
    } else {
      // Send to all customers
      await db.query(`
        INSERT INTO notifications (uid, title, message, type)
        SELECT uid, $1, $2, $3 FROM users WHERE role = 'customer'
      `, [title, message, 'promo']);
    }
    res.status(200).json({ success: true, message: 'Promo sent successfully' });
  } catch (error) {
    console.error('Error sending promo:', error);
    res.status(500).json({ error: 'Failed to send promo' });
  }
};

module.exports = {
  reportCrash,
  getPendingRides,
  allotRide,
  getActiveRides,
  getCompletedRides,
  getAvailableDrivers,
  getDriversForSlot,
  addDriver,
  addAdmin,
  getFleet,
  getCustomers,
  getAnalytics,
  updateSlotCapacity,
  getSlotCapacity,
  getFeedback,
  sendPromo
};
