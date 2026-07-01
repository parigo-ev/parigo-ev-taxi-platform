const db = require('../../db');

const getNotifications = async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    
    const uid = result.rows[0].uid;
    const notifRes = await db.query('SELECT * FROM notifications WHERE uid = $1 ORDER BY created_at DESC LIMIT 50', [uid]);
    res.status(200).json({ success: true, notifications: notifRes.rows });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
};

const markAsRead = async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'Notification ID required' });
  try {
    await db.query('UPDATE notifications SET is_read = TRUE WHERE id = $1', [id]);
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error marking notification read:', error);
    res.status(500).json({ error: 'Internal error' });
  }
};

const getUnreadCount = async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    
    const uid = result.rows[0].uid;
    const countRes = await db.query('SELECT COUNT(*) FROM notifications WHERE uid = $1 AND is_read = FALSE', [uid]);
    const unreadCount = parseInt(countRes.rows[0].count, 10);
    
    res.status(200).json({ success: true, count: unreadCount });
  } catch (error) {
    console.error('Error fetching unread count:', error);
    res.status(500).json({ error: 'Failed to fetch unread count' });
  }
};

const testNotification = async (req, res) => {
  const { phone, title, message, type } = req.body;
  if (!phone || !title || !message) return res.status(400).json({ error: 'Missing required fields' });
  try {
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    
    const uid = result.rows[0].uid;
    await db.query(
      'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
      [uid, title, message, type || 'general']
    );
    res.status(200).json({ success: true, message: 'Test notification sent' });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({ error: 'Failed to send test notification' });
  }
};

module.exports = {
  getNotifications,
  markAsRead,
  getUnreadCount,
  testNotification
};
