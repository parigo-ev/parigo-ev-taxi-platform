const db = require('./db');

async function createSupportTable() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS support_tickets (
        id SERIAL PRIMARY KEY,
        uid VARCHAR(255) NOT NULL,
        ride_id VARCHAR(255),
        issue_type VARCHAR(100) NOT NULL,
        description TEXT NOT NULL,
        status VARCHAR(50) DEFAULT 'OPEN',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Support tickets table created successfully.');
  } catch (error) {
    console.error('Error creating support tickets table:', error);
  } finally {
    process.exit();
  }
}

createSupportTable();
