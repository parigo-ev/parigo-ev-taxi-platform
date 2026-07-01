require('dotenv').config();
const { Pool } = require('pg');

// Initialize PostgreSQL connection pool
// For local development, assuming default postgres user and no password on localhost
const pool = new Pool({
  user: process.env.PG_USER || 'postgres',
  host: process.env.PG_HOST || 'localhost',
  database: process.env.PG_DATABASE || 'parigo_ev',
  password: process.env.PG_PASSWORD || 'postgres',
  port: process.env.PG_PORT || 5432,
});

// Test connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error acquiring client', err.stack);
  } else {
    console.log('PostgreSQL connected successfully!');
    release();
  }
});

// Helper function to create initial tables if they don't exist
const initDb = async () => {
  const createUsersTable = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      uid VARCHAR(255) UNIQUE NOT NULL,
      phone VARCHAR(50) UNIQUE NOT NULL,
      role VARCHAR(50) DEFAULT 'customer',
      pin VARCHAR(10),
      name VARCHAR(255),
      email VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  const createDriversTable = `
    CREATE TABLE IF NOT EXISTS drivers (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      driver_uid VARCHAR(255) UNIQUE NOT NULL,
      name VARCHAR(255),
      vehicle_type VARCHAR(100),
      is_online BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  const createRidesHistoryTable = `
    CREATE TABLE IF NOT EXISTS rides_history (
      id SERIAL PRIMARY KEY,
      ride_id VARCHAR(255) UNIQUE NOT NULL,
      customer_uid VARCHAR(255) NOT NULL,
      driver_uid VARCHAR(255),
      status VARCHAR(50) NOT NULL,
      fare DECIMAL(10, 2),
      pickup_lat DECIMAL(10, 8),
      pickup_lng DECIMAL(10, 8),
      dropoff_lat DECIMAL(10, 8),
      dropoff_lng DECIMAL(10, 8),
      scheduled_time TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      payment_method VARCHAR(50) DEFAULT 'CASH'
    );
  `;

  const createWalletsTable = `
    CREATE TABLE IF NOT EXISTS wallets (
      uid VARCHAR(255) PRIMARY KEY,
      balance DECIMAL(10, 2) DEFAULT 0.00,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  try {
    await pool.query(createUsersTable);
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS pin VARCHAR(10);');
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255);');
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);');
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;');
    
    await pool.query(createDriversTable);
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS aadhar_number VARCHAR(255);');
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS license_number VARCHAR(255);');
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS address TEXT;');
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS phone VARCHAR(50);');
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;');
    await pool.query('ALTER TABLE drivers ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3, 2) DEFAULT 5.0;');
    
    await pool.query(createRidesHistoryTable);
    
    // Add feedback columns
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS customer_rating INTEGER;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS customer_feedback TEXT;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS driver_rating INTEGER;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS driver_feedback TEXT;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS driver_eta_time TIMESTAMP;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS driver_arrival_time TIMESTAMP;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS ride_start_time TIMESTAMP;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS customer_wait_penalty DECIMAL(10, 2) DEFAULT 0.0;');
    await pool.query('ALTER TABLE rides_history ADD COLUMN IF NOT EXISTS driver_late_penalty DECIMAL(10, 2) DEFAULT 0.0;');

    await pool.query(createWalletsTable);

    console.log('PostgreSQL Tables initialized.');
  } catch (error) {
    console.error('Error initializing tables:', error);
  }
};

// Initialize DB on startup
initDb();

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
