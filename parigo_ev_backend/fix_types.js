const fs = require('fs');

function fixFile(filePath) {
    let content = fs.readFileSync(filePath, 'utf-8');

    // Helper for formatting date
    const dateHelper = `
    const formatDate = (dateObj) => {
      if (!dateObj) return null;
      return { _seconds: Math.floor(new Date(dateObj).getTime() / 1000) };
    };
    `;

    if (!content.includes('const formatDate =')) {
        content = content.replace('const ridesRes = await db.query(', dateHelper + '\n    const ridesRes = await db.query(');
    }

    // Fix map function
    content = content.replace(/scheduledTime: row\.scheduled_time,/g, 'scheduledTime: formatDate(row.scheduled_time),');
    content = content.replace(/createdAt: row\.created_at,/g, 'createdAt: formatDate(row.created_at),');
    content = content.replace(/driverArrivalTime: row\.driver_arrival_time,/g, 'driverArrivalTime: formatDate(row.driver_arrival_time),');
    content = content.replace(/rideStartTime: row\.ride_start_time,/g, 'rideStartTime: formatDate(row.ride_start_time),');

    content = content.replace(/customerWaitPenalty: row\.customer_wait_penalty,/g, 'customerWaitPenalty: parseFloat(row.customer_wait_penalty || 0),');
    content = content.replace(/driverLatePenalty: row\.driver_late_penalty,/g, 'driverLatePenalty: parseFloat(row.driver_late_penalty || 0),');

    fs.writeFileSync(filePath, content, 'utf-8');
    console.log("Fixed", filePath);
}

fixFile('c:/Users/abhim/Downloads/stitch_parigo_ev_taxi_platform/parigo_ev_backend/src/controllers/customerController.js');
fixFile('c:/Users/abhim/Downloads/stitch_parigo_ev_taxi_platform/parigo_ev_backend/src/controllers/driverController.js');
