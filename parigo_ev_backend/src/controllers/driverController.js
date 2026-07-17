const admin = require('firebase-admin');
const db = require('../../db');
const fs = require('fs');
const path = require('path');

const getProfile = async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await db.query(`
      SELECT d.*, u.email 
      FROM drivers d 
      JOIN users u ON d.user_id = u.id 
      WHERE d.phone = $1
    `, [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    
    let profileData = result.rows[0];
    
    // Fetch average rating
    try {
       const ratingResult = await db.query(`
         SELECT AVG(customer_rating) as avg_rating
         FROM rides_history
         WHERE driver_uid = $1 AND customer_rating IS NOT NULL
       `, [profileData.driver_uid]);
       
       if (ratingResult.rows.length > 0 && ratingResult.rows[0].avg_rating) {
          profileData.average_rating = parseFloat(ratingResult.rows[0].avg_rating).toFixed(1);
       } else {
          profileData.average_rating = 'New';
       }
    } catch (e) {
       console.error('Error fetching rating:', e);
       profileData.average_rating = '4.9'; // Fallback
    }

    res.status(200).json(profileData);
  } catch (error) {
    console.error('Error fetching driver profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const updateLocation = async (req, res) => {
  const { driverId, lat, lng } = req.body;
  if (!driverId || lat == null || lng == null) {
    return res.status(400).json({ error: 'driverId, lat, and lng are required' });
  }

  try {
    await db.query(
      'UPDATE drivers SET lat = $1, lng = $2 WHERE driver_uid = $3',
      [lat, lng, driverId]
    );
    res.status(200).json({ success: true, message: 'Location updated successfully' });
  } catch (error) {
    console.error('Error updating driver location:', error);
    res.status(500).json({ error: 'Failed to update location' });
  }
};

const getLocation = async (req, res) => {
  try {
    const { driverId } = req.params;
    if (!driverId) {
      return res.status(400).json({ error: 'driverId required' });
    }
    const result = await db.query('SELECT lat, lng FROM drivers WHERE driver_uid = $1', [driverId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    res.status(200).json({ success: true, location: result.rows[0] });
  } catch (error) {
    console.error('Error fetching driver location:', error);
    res.status(500).json({ error: 'Failed to fetch location' });
  }
};

const uploadPhoto = async (req, res) => {
  try {
    const { driverId, image } = req.body;
    if (!driverId || !image) {
      return res.status(400).json({ error: 'driverId and image (base64) are required' });
    }

    // Decode base64 image
    const matches = image.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
    if (!matches || matches.length !== 3) {
      return res.status(400).json({ error: 'Invalid base64 image string' });
    }

    const type = matches[1];
    const data = Buffer.from(matches[2], 'base64');
    const extension = type.split('/')[1] || 'jpg';
    
    // Save image to file
    const filename = `driver_${driverId}_${Date.now()}.${extension}`;
    const filepath = path.join(__dirname, '../../uploads', filename);
    fs.writeFileSync(filepath, data);

    // Update database
    const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${filename}`;
    await db.query('UPDATE drivers SET profile_picture_url = $1 WHERE driver_uid = $2', [fileUrl, driverId]);

    res.status(200).json({ success: true, message: 'Photo uploaded successfully', url: fileUrl });
  } catch (error) {
    console.error('Error uploading photo:', error);
    res.status(500).json({ error: 'Failed to upload photo' });
  }
};

const getAssignedRides = async (req, res) => {
  try {
    const { driverId } = req.query;
    if (!driverId) {
      return res.status(400).json({ error: 'driverId is required' });
    }

    const snapshot = await admin.firestore().collection('rides')
      .where('assignedDriverId', '==', driverId)
      .where('status', 'in', ['ALLOTTED', 'ARRIVED', 'IN_PROGRESS'])
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    // Populate customer details for these rides
    for (let ride of rides) {
      if (ride.uid && ride.uid !== 'anonymous') {
        try {
           const result = await db.query('SELECT name, phone FROM users WHERE uid = $1', [ride.uid]);
           if (result.rows.length > 0) {
              ride.customerDetails = result.rows[0];
           }
        } catch (e) {
           console.error('Error fetching customer details for ride:', e);
        }
      }
    }

    // Sort locally
    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching assigned rides:', error);
    res.status(500).json({ error: 'Failed to fetch assigned rides' });
  }
};

const getHistoryRides = async (req, res) => {
  try {
    const { driverId } = req.query;
    if (!driverId) {
      return res.status(400).json({ error: 'driverId is required' });
    }

    const ridesRes = await db.query(
      `SELECT r.*, u.name as customer_name, u.phone as customer_phone
       FROM rides_history r
       LEFT JOIN users u ON r.customer_uid = u.uid
       WHERE r.driver_uid = $1 AND r.status IN ('COMPLETED', 'CANCELLED')
       ORDER BY r.created_at DESC`,
      [driverId]
    );

    const rides = ridesRes.rows.map(row => {
      return {
        id: row.ride_id,
        displayId: row.display_id,
        uid: row.customer_uid,
        assignedDriverId: row.driver_uid,
        status: row.status,
        finalFare: row.fare,
        estimatedFare: row.fare,
        pickup: {
          lat: row.pickup_lat,
          lng: row.pickup_lng,
          description: row.pickup_address || 'Unknown Pickup',
          address: row.pickup_address || 'Unknown Pickup'
        },
        destination: {
          lat: row.dropoff_lat,
          lng: row.dropoff_lng,
          description: row.dropoff_address || 'Unknown Dropoff',
          address: row.dropoff_address || 'Unknown Dropoff'
        },
        scheduledTime: row.scheduled_time,
        createdAt: row.created_at, 
        driverArrivalTime: row.driver_arrival_time,
        rideStartTime: row.ride_start_time,
        paymentMethod: row.payment_method,
        transactionId: row.transaction_id,
        distanceKm: row.distance_km,
        durationMins: row.duration_mins,
        gstAmount: row.gst_amount,
        baseFare: row.base_fare,
        customerWaitPenalty: row.customer_wait_penalty,
        driverLatePenalty: row.driver_late_penalty,
        customerRating: row.customer_rating,
        customerFeedback: row.customer_feedback,
        customerDetails: {
          name: row.customer_name,
          phone: row.customer_phone
        }
      };
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching driver history:', error);
    res.status(500).json({ error: 'Failed to fetch driver history' });
  }
};

const getEarnings = async (req, res) => {
  try {
    const { driverId } = req.query;
    if (!driverId) return res.status(400).json({ error: 'driverId required' });

    const result = await db.query(
      `SELECT fare, scheduled_time FROM rides_history 
       WHERE driver_uid = $1 AND status = 'COMPLETED' 
       ORDER BY scheduled_time DESC`,
      [driverId]
    );

    let totalFare = 0;
    result.rows.forEach(r => totalFare += parseFloat(r.fare || 0));

    res.status(200).json({
      success: true,
      total_balance: totalFare.toFixed(2),
      rides_today: result.rows.length,
      hours_online: 6.5, // Mock for now
      recent_trips: result.rows.map(r => ({
        title: 'Completed Ride',
        amount: `₹${r.fare}`,
        time: new Date(r.scheduled_time).toLocaleString(),
        isCredit: true
      }))
    });
  } catch (error) {
    console.error('Error fetching earnings:', error);
    res.status(500).json({ error: 'Failed to fetch earnings' });
  }
};

const updateRideStatus = async (req, res) => {
  try {
    const { rideId, status } = req.body;
    if (!rideId || !status) {
      return res.status(400).json({ error: 'rideId and status are required' });
    }

    const updateData = {
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (status === 'ARRIVED') {
      updateData.driverArrivalTime = admin.firestore.FieldValue.serverTimestamp();
    } else if (status === 'IN_PROGRESS') {
      updateData.rideStartTime = admin.firestore.FieldValue.serverTimestamp();
    }

    await admin.firestore().collection('rides').doc(rideId).update(updateData);

    if (status === 'COMPLETED' || status === 'PENDING_PAYMENT') {
      try {
        const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
        if (rideDoc.exists) {
          const r = rideDoc.data();
          let estimatedFare = r.estimatedFare || 0.0;
          let customerWaitPenalty = 0.0;
          let driverLatePenalty = 0.0;

          // Compute Penalties
          const arrivalTime = r.driverArrivalTime ? r.driverArrivalTime.toDate() : new Date();
          const startTime = r.rideStartTime ? r.rideStartTime.toDate() : new Date();
          const etaTime = r.driverEtaTime ? r.driverEtaTime.toDate() : new Date();

          // 1. Customer Wait Penalty (Wait > 3 mins)
          const waitMins = (startTime - arrivalTime) / 60000;
          if (waitMins > 3) {
             const penaltyBlocks = Math.floor((waitMins - 3) / 3);
             if (penaltyBlocks > 0) {
                customerWaitPenalty = penaltyBlocks * 3.0;
             }
          }

          // 2. Driver Late Penalty (Late > 3 mins)
          const lateMins = (arrivalTime - etaTime) / 60000;
          if (lateMins > 3) {
             const penaltyBlocks = Math.floor((lateMins - 3) / 3);
             if (penaltyBlocks > 0) {
                driverLatePenalty = penaltyBlocks * 3.0;
                // Cap at 30
                if (driverLatePenalty > 30.0) driverLatePenalty = 30.0;
             }
          }

          // Adjust Fare
          estimatedFare = estimatedFare + customerWaitPenalty - driverLatePenalty;
          if (estimatedFare < 0) estimatedFare = 0.0;

          // Save back to Firestore
          await admin.firestore().collection('rides').doc(rideId).update({
            finalFare: estimatedFare,
            customerWaitPenalty: customerWaitPenalty,
            driverLatePenalty: driverLatePenalty
          });

          await db.query(
            `INSERT INTO rides_history (ride_id, display_id, customer_uid, driver_uid, status, fare, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, scheduled_time, payment_method, driver_eta_time, driver_arrival_time, ride_start_time, customer_wait_penalty, driver_late_penalty) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
             ON CONFLICT (ride_id) DO UPDATE SET status = EXCLUDED.status, payment_method = EXCLUDED.payment_method`,
            [
              rideId, 
              r.displayId || null,
              r.uid || 'anonymous', 
              r.assignedDriverId || 'unknown', 
              status, 
              estimatedFare, 
              r.pickup?.lat || 0.0, 
              r.pickup?.lng || 0.0, 
              r.destination?.lat || 0.0, 
              r.destination?.lng || 0.0, 
              new Date(),
              r.paymentMethod || 'CASH',
              etaTime,
              arrivalTime,
              startTime,
              customerWaitPenalty,
              driverLatePenalty
            ]
          );

          // Deduct from Driver Wallet (50% of late penalty)
          if (driverLatePenalty > 0 && r.assignedDriverId) {
             const deduction = driverLatePenalty / 2;
             await db.query(
               `INSERT INTO wallets (uid, balance) VALUES ($1, -$2) 
                ON CONFLICT (uid) DO UPDATE SET balance = wallets.balance - $2`,
               [r.assignedDriverId, deduction]
             );
          }

          // Insert Ride Complete Notification for Customer
          if (status === 'COMPLETED') {
            try {
              // Fetch driver name for the notification
              const driverRes = await db.query('SELECT name FROM users u JOIN drivers d ON u.id = d.user_id WHERE d.driver_uid = $1', [r.assignedDriverId]);
              const driverName = driverRes.rows.length > 0 ? driverRes.rows[0].name : 'your driver';

              const metadata = JSON.stringify({
                rideId: rideId,
                otherPartyName: driverName
              });

              await db.query(
                'INSERT INTO notifications (uid, title, message, type, metadata) VALUES ($1, $2, $3, $4, $5)',
                [r.uid, 'Ride Completed', `Your trip was successfully completed. Please rate your experience with ${driverName}.`, 'ride_complete', metadata]
              );
            } catch (err) {
              console.error('Error inserting ride complete notification:', err);
            }
          }
        }
      } catch (err) {
        console.error('Error saving completed ride to PostgreSQL:', err);
      }
    }

    res.status(200).json({ success: true, message: `Ride status updated to ${status}` });
  } catch (error) {
    console.error('Error updating ride status:', error);
    res.status(500).json({ error: 'Failed to update ride status' });
  }
};

const updateStatus = async (req, res) => {
  const { driverId, isOnline } = req.body;
  if (!driverId || isOnline == null) {
    return res.status(400).json({ error: 'driverId and isOnline are required' });
  }
  try {
    await db.query(
      'UPDATE drivers SET is_online = $1 WHERE driver_uid = $2',
      [isOnline, driverId]
    );
    res.status(200).json({ success: true, is_online: isOnline });
  } catch (error) {
    console.error('Error updating driver status:', error);
    res.status(500).json({ error: 'Failed to update driver status' });
  }
};

const updateBattery = async (req, res) => {
  const { driverId, battery } = req.body;
  if (!driverId || battery == null) {
    return res.status(400).json({ error: 'driverId and battery are required' });
  }
  try {
    await db.query(
      'UPDATE drivers SET battery = $1 WHERE driver_uid = $2',
      [parseInt(battery), driverId]
    );
    res.status(200).json({ success: true, battery: battery });
  } catch (error) {
    console.error('Error updating driver battery:', error);
    res.status(500).json({ error: 'Failed to update battery' });
  }
};

const getDriverFeedback = async (req, res) => {
  try {
    const { driverId } = req.params;
    const query = `
      SELECT r.customer_rating, r.customer_feedback, r.created_at, u.name as customer_name
      FROM rides_history r
      LEFT JOIN users u ON r.customer_uid = u.uid
      WHERE r.driver_uid = $1 AND r.customer_rating IS NOT NULL
      ORDER BY r.created_at DESC
    `;
    const result = await db.query(query, [driverId]);
    res.status(200).json({ success: true, feedback: result.rows });
  } catch (error) {
    console.error('Error fetching driver feedback:', error);
    res.status(500).json({ error: 'Failed to fetch driver feedback' });
  }
};

module.exports = {
  getProfile,
  updateLocation,
  getLocation,
  uploadPhoto,
  getAssignedRides,
  getHistoryRides,
  getEarnings,
  updateRideStatus,
  updateStatus,
  updateBattery,
  getDriverFeedback
};

