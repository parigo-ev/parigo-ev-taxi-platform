const admin = require('firebase-admin');
const db = require('../../db');

const getCustomerHistoryRides = async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'uid is required' });
    }

    const ridesRes = await db.query(
      `SELECT r.*, d.name as driver_name, d.phone as driver_phone, d.profile_picture_url as driver_pic, d.vehicle_type
       FROM rides_history r
       LEFT JOIN drivers d ON r.driver_uid = d.driver_uid
       WHERE r.customer_uid = $1 AND r.status IN ('COMPLETED', 'CANCELLED')
       ORDER BY r.created_at DESC`,
      [uid]
    );

    const rides = ridesRes.rows.map(row => {
      return {
        id: row.ride_id,
        displayId: row.display_id,
        uid: row.customer_uid,
        assignedDriverId: row.driver_uid,
        status: row.status,
        finalFare: row.fare, // Using fare as finalFare
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
        driverDetails: {
          name: row.driver_name,
          phone: row.driver_phone,
          vehicle_type: row.vehicle_type,
          profilePictureUrl: row.driver_pic
        }
      };
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
