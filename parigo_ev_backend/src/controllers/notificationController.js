const db = require('../../db');
const { notifyUser } = require('../services/pushNotificationService');

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
    await notifyUser(uid, { title, message, type: type || 'general' });
    res.status(200).json({ success: true, message: 'Test notification sent' });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({ error: 'Failed to send test notification' });
  }
};

const registerDeviceToken = async (req, res) => {
  const { token, platform } = req.body;
  if (!token || !platform || !['android', 'ios'].includes(platform)) {
    return res.status(400).json({ error: 'A valid device token and platform are required' });
  }

  try {
    await db.query(
      `INSERT INTO device_tokens (uid, token, platform, updated_at)
       VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
       ON CONFLICT (token)
       DO UPDATE SET uid = EXCLUDED.uid, platform = EXCLUDED.platform, updated_at = CURRENT_TIMESTAMP`,
      [req.user.uid, token, platform]
    );
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error registering device token:', error);
    res.status(500).json({ error: 'Failed to register device token' });
  }
};

const unregisterDeviceToken = async (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'Device token required' });

  try {
    await db.query('DELETE FROM device_tokens WHERE uid = $1 AND token = $2', [req.user.uid, token]);
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error unregistering device token:', error);
    res.status(500).json({ error: 'Failed to unregister device token' });
  }
};

module.exports = {
  getNotifications,
  markAsRead,
  getUnreadCount,
  testNotification,
  registerDeviceToken,
  unregisterDeviceToken
};
