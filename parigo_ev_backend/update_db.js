require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PG_USER || 'postgres',
  host: process.env.PG_HOST || 'localhost',
  database: process.env.PG_DATABASE || 'parigo_ev',
  password: process.env.PG_PASSWORD || 'postgres',
  port: process.env.PG_PORT || 5432,
});

async function run() {
  try {
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255)');
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)');
    console.log('Successfully added name and email columns to users table.');
  } catch(e) {
    console.error('Error:', e);
  } finally {
    pool.end();
  }
}
run();
