require('dotenv').config();
const db = require('./db');

async function seedDatabase() {
  try {
    console.log('Connecting to database...');

    // ==========================================
    // 1. HARDCODE YOUR ADMIN DETAILS HERE
    // ==========================================
    const adminPhone = '+918878587615'; // Admin Phone (Must match what you type in app)
    const adminPin = '8878'; // 4-digit PIN
    const adminName = 'Abhimanyu Singh Parihar';
    const adminEmail = 'abhimanyusingh16111998@gmail.com';
    const adminUid = 'admin_' + Date.now();

    // ==========================================
    // 2. HARDCODE YOUR DRIVER DETAILS HERE
    // ==========================================
    const driverPhone = '+919171494595'; // Driver Phone (Must match what you type in app)
    const driverPin = '9171'; // 4-digit PIN
    const driverName = 'Abhishek Gole';
    const driverEmail = 'goleabhishek0505@gmail.com';
    const driverUid = 'driver_' + Date.now();
    const vehicleType = 'Tata Nexon EV';
    const aadharNumber = '1234 5678 9012';
    const licenseNumber = 'DL-14-20230123456';
    const address = '123 Main Street, New Delhi';

    // Insert Admin
    console.log('Inserting Admin...');
    const adminResult = await db.query(`
      INSERT INTO users (uid, phone, role, pin, name, email) 
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (phone) DO UPDATE SET pin = EXCLUDED.pin, role = EXCLUDED.role, name = EXCLUDED.name, email = EXCLUDED.email
      RETURNING id, uid;
    `, [adminUid, adminPhone, 'admin', adminPin, adminName, adminEmail]);

    console.log('Inserting Admin into drivers table so they can also act as a driver...');
    let aId, aUid;
    if (adminResult.rows.length > 0) {
      aId = adminResult.rows[0].id;
      aUid = adminResult.rows[0].uid;
    } else {
      const existingAdmin = await db.query('SELECT id, uid FROM users WHERE phone = $1', [adminPhone]);
      aId = existingAdmin.rows[0].id;
      aUid = existingAdmin.rows[0].uid;
    }

    await db.query(`
      INSERT INTO drivers (user_id, driver_uid, name, vehicle_type, aadhar_number, license_number, address, phone)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT ON CONSTRAINT drivers_user_id_unique DO UPDATE SET
        name = EXCLUDED.name,
        vehicle_type = EXCLUDED.vehicle_type,
        aadhar_number = EXCLUDED.aadhar_number,
        license_number = EXCLUDED.license_number,
        address = EXCLUDED.address,
        phone = EXCLUDED.phone;
    `, [aId, aUid, adminName, 'Admin Vehicle', '0000 0000 0000', 'DL-ADMIN-000', 'Admin HQ', adminPhone]);

    // Insert Driver into Users table
    console.log('Inserting Driver into users table...');
    const userResult = await db.query(`
      INSERT INTO users (uid, phone, role, pin, name, email) 
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (phone) DO UPDATE SET pin = EXCLUDED.pin, role = EXCLUDED.role, name = EXCLUDED.name, email = EXCLUDED.email
      RETURNING id, uid;
    `, [driverUid, driverPhone, 'driver', driverPin, driverName, driverEmail]);

    // Insert Driver into Drivers table
    console.log('Inserting Driver into drivers table...');
    
    // We need the internal user id and uid. If it already existed, we fetch it.
    let dId, dUid;
    if (userResult.rows.length > 0) {
      dId = userResult.rows[0].id;
      dUid = userResult.rows[0].uid;
    } else {
      const existing = await db.query('SELECT id, uid FROM users WHERE phone = $1', [driverPhone]);
      dId = existing.rows[0].id;
      dUid = existing.rows[0].uid;
    }

    await db.query(`
      INSERT INTO drivers (user_id, driver_uid, name, vehicle_type, aadhar_number, license_number, address, phone)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT ON CONSTRAINT drivers_user_id_unique DO UPDATE SET
        name = EXCLUDED.name,
        vehicle_type = EXCLUDED.vehicle_type,
        aadhar_number = EXCLUDED.aadhar_number,
        license_number = EXCLUDED.license_number,
        address = EXCLUDED.address,
        phone = EXCLUDED.phone;
    `, [dId, dUid, driverName, vehicleType, aadharNumber, licenseNumber, address, driverPhone]);

    console.log('--------------------------------------------------');
    console.log('SUCCESS! Database seeded with hardcoded details.');
    console.log(`Admin Phone: ${adminPhone} | PIN: ${adminPin}`);
    console.log(`Driver Phone: ${driverPhone} | PIN: ${driverPin}`);
    console.log('You can now log into the app using these exact numbers and PINs.');
    console.log('Drivers cannot change their details from the app. They must contact the Admin.');
    console.log('--------------------------------------------------');

    process.exit(0);
  } catch (error) {
    console.error('Error seeding database:', error);
    process.exit(1);
  }
}

seedDatabase();
