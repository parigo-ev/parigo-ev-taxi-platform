const admin = require('firebase-admin');
const db = require('../../db');

const getCustomerHistoryRides = async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'uid is required' });
    }

    // Fetch rides from Firestore where customer uid matches and status is COMPLETED or CANCELLED
    const snapshot = await admin.firestore().collection('rides')
      .where('uid', '==', uid)
      .where('status', 'in', ['COMPLETED', 'CANCELLED'])
      .get();
      
    const rides = [];
    snapshot.forEach(doc => {
      rides.push({ id: doc.id, ...doc.data() });
    });

    // Populate driverDetails and merge PostgreSQL history fields for each ride
    if (rides.length > 0) {
      try {
        const pgRides = await db.query('SELECT * FROM rides_history WHERE customer_uid = $1', [uid]);
        const pgMap = {};
        pgRides.rows.forEach(r => pgMap[r.ride_id] = r);

        for (let ride of rides) {
          // Merge from Postgres
          const pgRide = pgMap[ride.id];
          if (pgRide) {
             ride.displayId = pgRide.display_id || ride.displayId;
             ride.baseFare = pgRide.base_fare || ride.baseFare;
             ride.gstAmount = pgRide.gst_amount || ride.gstAmount;
             ride.distanceKm = pgRide.distance_km || ride.distanceKm;
             ride.durationMins = pgRide.duration_mins || ride.durationMins;
             ride.finalFare = pgRide.fare || ride.finalFare;
             ride.transactionId = pgRide.transaction_id || ride.transactionId;
          }

          // Fetch driver details
          if (ride.assignedDriverId) {
             const result = await db.query('SELECT name, phone, profile_picture_url FROM drivers WHERE driver_uid = $1', [ride.assignedDriverId]);
             if (result.rows.length > 0) {
                ride.driverDetails = {
                  name: result.rows[0].name,
                  phone: result.rows[0].phone,
                  profilePictureUrl: result.rows[0].profile_picture_url
                };
             }
          }
        }
      } catch (e) {
         console.error('Error fetching supplementary details for history ride:', e);
      }
    }

    // Sort by createdAt descending
    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      const timeA = typeof a.createdAt.toDate === 'function' ? a.createdAt.toDate().getTime() : new Date(a.createdAt).getTime();
      const timeB = typeof b.createdAt.toDate === 'function' ? b.createdAt.toDate().getTime() : new Date(b.createdAt).getTime();
      return timeB - timeA;
    });

    res.status(200).json({ success: true, rides });
  } catch (error) {
    console.error('Error fetching customer history:', error);
    res.status(500).json({ error: 'Failed to fetch customer history' });
  }
};

module.exports = {
  getCustomerHistoryRides
};
