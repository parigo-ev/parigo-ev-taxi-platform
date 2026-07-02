const admin = require('firebase-admin');
const db = require('../../db');

const getProfile = async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await db.query('SELECT name, email, phone, role, profile_picture_url FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const updateProfilePicture = async (req, res) => {
  const { phone, imageBase64 } = req.body;
  if (!phone || !imageBase64) {
    return res.status(400).json({ error: 'Phone and imageBase64 are required' });
  }

  try {
    await db.query(
      'UPDATE users SET profile_picture_url = $1 WHERE phone = $2',
      [imageBase64, phone]
    );
    // Sync with drivers table if they are a driver
    await db.query(
      'UPDATE drivers SET profile_picture_url = $1 WHERE user_id = (SELECT id FROM users WHERE phone = $2)',
      [imageBase64, phone]
    );
    res.status(200).json({ success: true, message: 'Profile picture updated successfully' });
  } catch (error) {
    console.error('Error updating profile picture:', error);
    res.status(500).json({ error: 'Failed to update profile picture' });
  }
};

const deleteAccount = async (req, res) => {
  const { phone } = req.params;
  try {
    // 1. Get user uid
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const uid = result.rows[0].uid;

    // 2. Delete from Firebase Auth
    try {
      if (admin.apps.length > 0) {
        await admin.auth().deleteUser(uid);
      }
    } catch (fbError) {
      console.warn('Firebase user deletion failed or user did not exist:', fbError.message);
    }

    // 3. Delete from wallets
    await db.query('DELETE FROM wallets WHERE uid = $1', [uid]);

    // 4. Delete from users (will cascade to drivers if any)
    await db.query('DELETE FROM users WHERE uid = $1', [uid]);

    res.status(200).json({ success: true, message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
};

const updateProfile = async (req, res) => {
  const { phone, name, email } = req.body;
  if (!phone) return res.status(400).json({ error: 'Phone is required' });

  try {
    await db.query(
      'UPDATE users SET name = $1, email = $2 WHERE phone = $3',
      [name, email, phone]
    );
    // Sync with drivers table if they are a driver
    await db.query(
      'UPDATE drivers SET name = $1, phone = $2 WHERE user_id = (SELECT id FROM users WHERE phone = $3)',
      [name, phone, phone]
    );
    res.status(200).json({ success: true, message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  getProfile,
  updateProfilePicture,
  deleteAccount,
  updateProfile
};
