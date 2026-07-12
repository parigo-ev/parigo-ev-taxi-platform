const db = require('./db');

async function updateRideHistoryCols() {
  try {
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS transaction_id VARCHAR(255);');
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS pickup_address TEXT;');
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS dropoff_address TEXT;');
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS distance_km DECIMAL(10, 2);');
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS duration_mins INTEGER;');
    
    // Also store gst and subtotal if needed, or we can just calculate them on the fly based on fare.
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS gst_amount DECIMAL(10, 2);');
    await db.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS base_fare DECIMAL(10, 2);');

    console.log('Successfully updated rides_history columns.');
  } catch (error) {
    console.error('Error updating rides_history columns:', error);
  } finally {
    process.exit();
  }
}

updateRideHistoryCols();
