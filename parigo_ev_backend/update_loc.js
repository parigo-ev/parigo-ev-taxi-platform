require('dotenv').config({path: '../.env'});
const db = require('./db');

async function checkAndUpdate() {
  try {
    console.log('Checking drivers table columns...');
    // Add columns if they don't exist
    await db.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS lat DECIMAL(10, 8);');
    await db.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS lng DECIMAL(10, 8);');
    console.log('Columns lat/lng ensured.');

    // Update Abhishek Gole's location to Gwalior (lat: 26.2183, lng: 78.1828)
    const res = await db.query(
      "UPDATE drivers SET lat = 26.2183, lng = 78.1828 WHERE name = 'Abhishek Gole' RETURNING *"
    );
    
    console.log('Update result:', res.rows);
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

checkAndUpdate();
