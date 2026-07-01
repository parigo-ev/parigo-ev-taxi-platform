const db = require('./db');

async function createNotificationsTable() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        uid VARCHAR(255) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50) NOT NULL,
        is_read BOOLEAN DEFAULT false,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Notifications table created successfully.');
  } catch (error) {
    console.error('Error creating notifications table:', error);
  } finally {
    process.exit();
  }
}

createNotificationsTable();
