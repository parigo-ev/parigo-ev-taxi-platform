const admin = require('firebase-admin');
const db = require('../../db');

const createRide = async (req, res) => {
  const { uid, pickup, destination, scheduledTime, scheduledDate, estimatedFare, estimatedDistance, estimatedDuration, isScheduled, paymentMethod } = req.body;
  if (!uid || !pickup || !destination) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const rideRef = admin.firestore().collection('rides').doc();
    
    // Default to 'CASH' if paymentMethod is undefined or null
    const finalPaymentMethod = paymentMethod || 'CASH';

    await rideRef.set({
      uid: uid,
      pickup: pickup,
      destination: destination,
      scheduledTime: scheduledTime || null,
      scheduledDate: scheduledDate || null,
      estimatedFare: estimatedFare || 0.0,
      estimatedDistance: estimatedDistance || 0.0,
      estimatedDuration: estimatedDuration || 0.0,
      isScheduled: isScheduled || false,
      status: 'SCHEDULED',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: finalPaymentMethod
    });

    res.status(200).json({ success: true, rideId: rideRef.id });
  } catch (error) {
    console.error('Error creating ride:', error);
    res.status(500).json({ error: 'Failed to create ride' });
  }
};

const getActiveRide = async (req, res) => {
  try {
    const uid = req.query.uid;
    if (!uid) return res.status(400).json({ error: 'uid required' });

    const snapshot = await admin.firestore().collection('rides')
      .where('uid', '==', uid)
      .where('status', 'in', ['SCHEDULED', 'ALLOTTED', 'ARRIVED', 'IN_PROGRESS', 'PENDING_PAYMENT'])
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
      
    if (snapshot.empty) {
      return res.status(200).json({ success: true, ride: null });
    }
    
    const ride = snapshot.docs[0].data();
    ride.id = snapshot.docs[0].id;

    // Fetch driver details if assigned
    if (ride.assignedDriverId) {
      try {
        const dRes = await db.query('SELECT name, phone, vehicle_type, profile_picture_url FROM drivers WHERE driver_uid = $1', [ride.assignedDriverId]);
        if (dRes.rows.length > 0) {
          ride.driverDetails = dRes.rows[0];
        }
      } catch (err) {
        console.error('Failed to get driver details:', err);
      }
    }

    res.status(200).json({ success: true, ride });
  } catch (error) {
    console.error('Error fetching active ride:', error);
    res.status(500).json({ error: 'Failed to fetch active ride' });
  }
};

const getHistory = async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const uid = result.rows[0].uid;
    
    const ridesRes = await db.query(
      `SELECT r.*, d.name as driver_name, d.phone as driver_phone, d.profile_picture_url as driver_pic
       FROM rides_history r
       LEFT JOIN drivers d ON r.driver_uid = d.driver_uid
       WHERE r.customer_uid = $1 
       ORDER BY r.scheduled_time DESC`,
      [uid]
    );

    res.status(200).json({ success: true, rides: ridesRes.rows });
  } catch (error) {
    console.error('Error fetching ride history:', error);
    res.status(500).json({ error: 'Failed to fetch ride history' });
  }
};

const submitFeedback = async (req, res) => {
  const { rideId, rating, feedback, role } = req.body;
  if (!rideId || rating == null) {
    return res.status(400).json({ error: 'rideId and rating are required' });
  }

  try {
    if (role === 'Customer') {
      await db.query(
        'UPDATE rides_history SET customer_rating = $1, customer_feedback = $2 WHERE ride_id = $3',
        [rating, feedback, rideId]
      );
    } else if (role === 'Driver') {
      await db.query(
        'UPDATE rides_history SET driver_rating = $1, driver_feedback = $2 WHERE ride_id = $3',
        [rating, feedback, rideId]
      );
    } else {
      return res.status(400).json({ error: 'Invalid role for feedback' });
    }
    res.status(200).json({ success: true, message: 'Feedback submitted successfully' });
  } catch (error) {
    console.error('Error submitting feedback:', error);
    res.status(500).json({ error: 'Failed to submit feedback' });
  }
};

const cancelRide = async (req, res) => {
  try {
    const { rideId, canceledBy } = req.body;
    if (!rideId || !canceledBy) {
      return res.status(400).json({ error: 'rideId and canceledBy are required' });
    }

    await admin.firestore().collection('rides').doc(rideId).update({
      status: 'CANCELLED',
      canceledBy: canceledBy,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({ success: true, message: 'Ride cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling ride:', error);
    res.status(500).json({ error: 'Failed to cancel ride' });
  }
};

// Helper for distance calculation (Haversine)
function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  var R = 6371; // Radius of the earth in km
  var dLat = deg2rad(lat2 - lat1);
  var dLon = deg2rad(lon2 - lon1); 
  var a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2); 
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  return R * c; // Distance in km
}

function deg2rad(deg) {
  return deg * (Math.PI/180);
}

const estimateFare = async (req, res) => {
  try {
    const { pickup, destination } = req.body;
    if (!pickup || !destination) {
      return res.status(400).json({ error: 'Pickup and destination are required' });
    }

    const distanceKm = getDistanceFromLatLonInKm(pickup.lat, pickup.lng, destination.lat, destination.lng);
    
    // Base fare: 50 for up to 2km, then 18.99/km
    const baseFare = 50;
    const perKmRate = 18.99;
    
    let fare = baseFare;
    if (distanceKm > 2) {
      fare += (distanceKm - 2) * perKmRate;
    }

    // Add 5% GST
    const fareWithGst = fare + (fare * 0.05);

    res.status(200).json({
      success: true,
      distance_km: distanceKm.toFixed(2),
      estimated_fare: Math.round(fareWithGst)
    });
  } catch (error) {
    console.error('Error estimating fare:', error);
    res.status(500).json({ error: 'Failed to estimate fare' });
  }
};

const checkSlotAvailability = async (req, res) => {
  try {
    const { date } = req.query; 
    if (!date) {
      return res.status(400).json({ error: 'Date is required' });
    }
    
    const snapshot = await admin.firestore().collection('rides')
      .where('isScheduled', '==', true)
      .where('scheduledDateStr', '==', date)
      .where('status', 'in', ['SCHEDULED', 'ALLOTTED'])
      .get();

    const bookedSlots = {};
    snapshot.forEach(doc => {
      const data = doc.data();
      const timeSlot = data.scheduledTime;
      if (timeSlot) {
        bookedSlots[timeSlot] = (bookedSlots[timeSlot] || 0) + 1;
      }
    });

    res.status(200).json({
      success: true,
      maxCapacity: 5,
      bookedSlots: bookedSlots
    });
  } catch (error) {
    console.error('Error checking availability:', error);
    res.status(500).json({ error: 'Failed to check slot availability' });
  }
};

const scheduleRide = async (req, res) => {
  try {
    const { pickup, destination, scheduledDate, scheduledTime, exactTime, estimatedFare, distanceKm, uid, paymentMethod, isPrepaid } = req.body;
    
    if (!uid || !pickup || !destination || !scheduledDate || !scheduledTime) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const dateObj = new Date(scheduledDate);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    // In JS getDay() returns 0 for Sun, 1 for Mon. 
    // Wait, the Dart code uses: `weekdays[d.weekday - 1]`. Dart DateTime.weekday is 1 (Mon) to 7 (Sun).
    // So Dart 'Mon' is Mon. JS getDay() 1 is Mon.
    let jsDay = dateObj.getDay() - 1;
    if (jsDay < 0) jsDay = 6; // Sun is 6
    const dartWeekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const scheduledDateStr = `${dartWeekdays[jsDay]}, ${months[dateObj.getMonth()]} ${dateObj.getDate()}`;

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const rideRef = admin.firestore().collection('rides').doc();

    await rideRef.set({
      uid: uid,
      pickup: pickup,
      destination: destination,
      scheduledTime: scheduledTime,
      exactTime: exactTime || null,
      scheduledDate: scheduledDate,
      scheduledDateStr: scheduledDateStr,
      estimatedFare: parseFloat(estimatedFare) || 0.0,
      estimatedDistance: parseFloat(distanceKm) || 0.0,
      isScheduled: true,
      status: 'SCHEDULED',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: paymentMethod || 'CASH',
      isPrepaid: isPrepaid || false,
      otp: otp
    });

    res.status(201).json({ success: true, rideId: rideRef.id, otp: otp });
  } catch (error) {
    console.error('Error scheduling ride:', error);
    res.status(500).json({ error: 'Failed to schedule ride' });
  }
};

const getCustomerRides = async (req, res) => {
  try {
    // URL decoding converts '+' to ' '. If passed via query, restore it.
    let uid = req.user?.uid || req.query.uid;
    if (uid && uid.includes(' ')) uid = uid.replace(/ /g, '+');
    
    console.log('Fetching customer rides for uid:', uid);
    if (!uid) return res.status(400).json({ error: 'uid required' });

    const snapshot = await admin.firestore().collection('rides')
      .where('uid', '==', uid)
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    // Sort in memory to avoid needing a composite index in Firestore
    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching customer rides:', error);
    res.status(500).json({ error: 'Failed to fetch customer rides' });
  }
};

const payRide = async (req, res) => {
  const { rideId, uid, paymentMethod, fare } = req.body;
  if (!rideId || !uid || !paymentMethod || fare == null) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();
    if (!rideDoc.exists) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    const ride = rideDoc.data();

    // 1. If payment method is WALLET, deduct balance
    if (paymentMethod === 'WALLET') {
      const walletRes = await db.query('SELECT balance FROM wallets WHERE uid = $1', [uid]);
      const currentBalance = walletRes.rows.length > 0 ? parseFloat(walletRes.rows[0].balance) : 0.0;

      if (currentBalance < fare) {
        return res.status(400).json({ error: 'Insufficient wallet balance' });
      }

      await db.query(
        'UPDATE wallets SET balance = balance - $1 WHERE uid = $2',
        [fare, uid]
      );

      await db.query(
        "INSERT INTO wallet_transactions (uid, amount, type, description) VALUES ($1, $2, 'DEBIT', $3)",
        [uid, fare, `Paid for Ride ID: ${rideId}`]
      );
    }

    // 2. Update ride status in Firestore to COMPLETED
    await rideRef.update({
      status: 'COMPLETED',
      paymentMethod: paymentMethod,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Update PostgreSQL rides_history status to COMPLETED and update payment method
    await db.query(
      "UPDATE rides_history SET status = 'COMPLETED', payment_method = $1 WHERE ride_id = $2",
      [paymentMethod, rideId]
    );

    // 4. Create Notification for Customer
    try {
      const driverRes = await db.query(
        'SELECT u.name FROM users u JOIN drivers d ON u.id = d.user_id WHERE d.driver_uid = $1',
        [ride.assignedDriverId]
      );
      const driverName = driverRes.rows.length > 0 ? driverRes.rows[0].name : 'your driver';

      const metadata = JSON.stringify({
        rideId: rideId,
        otherPartyName: driverName
      });

      await db.query(
        'INSERT INTO notifications (uid, title, message, type, metadata) VALUES ($1, $2, $3, $4, $5)',
        [uid, 'Ride Completed', `Your trip was successfully completed. Please rate your experience with ${driverName}.`, 'ride_complete', metadata]
      );
    } catch (err) {
      console.error('Error inserting ride complete notification:', err);
    }

    res.status(200).json({ success: true, message: 'Payment processed and ride completed successfully' });
  } catch (error) {
    console.error('Error processing ride payment:', error);
    try {
      const fs = require('fs');
      const path = require('path');
      const logMsg = `[${new Date().toISOString()}] RideId: ${rideId || 'N/A'}, UID: ${uid || 'N/A'}, Error: ${error.message}\nStack: ${error.stack}\n\n`;
      fs.appendFileSync(path.join(__dirname, '../../uploads/error_log.txt'), logMsg);
    } catch (logErr) {
      console.error('Failed to write to error log file:', logErr);
    }
    res.status(500).json({ error: 'Failed to process payment', details: error.message });
  }
};

const getMessages = async (req, res) => {
  const { rideId } = req.params;
  try {
    const messagesRef = admin.firestore().collection('rides').doc(rideId).collection('messages');
    const snapshot = await messagesRef.orderBy('createdAt', 'asc').get();
    
    const messages = [];
    snapshot.forEach(doc => {
      messages.push({ id: doc.id, ...doc.data() });
    });
    
    res.status(200).json({ success: true, messages });
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
};

const sendMessage = async (req, res) => {
  const { rideId } = req.params;
  const { senderRole, text } = req.body;
  if (!senderRole || !text) {
    return res.status(400).json({ error: 'senderRole and text are required' });
  }

  try {
    const messagesRef = admin.firestore().collection('rides').doc(rideId).collection('messages');
    const newMessageRef = await messagesRef.add({
      senderRole,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(201).json({ success: true, messageId: newMessageRef.id });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
};

module.exports = {
  createRide,
  getActiveRide,
  getCustomerRides,
  getHistory,
  submitFeedback,
  cancelRide,
  estimateFare,
  checkSlotAvailability,
  scheduleRide,
  payRide,
  getMessages,
  sendMessage
};
