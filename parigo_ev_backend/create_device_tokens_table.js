const db = require('./db');

async function createDeviceTokensTable() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        id SERIAL PRIMARY KEY,
        uid VARCHAR(255) NOT NULL,
        token TEXT UNIQUE NOT NULL,
        platform VARCHAR(20) NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await db.query('CREATE INDEX IF NOT EXISTS device_tokens_uid_idx ON device_tokens(uid);');
    console.log('Device tokens table created successfully.');
  } catch (error) {
    console.error('Error creating device tokens table:', error);
    process.exitCode = 1;
  } finally {
    await db.pool.end();
  }
}

createDeviceTokensTable();
