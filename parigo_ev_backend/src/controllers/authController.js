const admin = require('firebase-admin');
const db = require('../../db');

const verifyOtp = async (req, res) => {
  const { idToken, mockPhone, role: requestedRole } = req.body;
  if (!idToken) {
    return res.status(400).json({ error: 'ID Token is required' });
  }

  try {
    let uid, phone;

    if (idToken === 'mock_token') {
      uid = 'mock_uid_' + (mockPhone || '12345');
      phone = mockPhone || '+910000000000';
    } else {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      uid = decodedToken.uid;
      phone = decodedToken.phone_number || '+910000000000';
    }

    // Check if user exists
    const result = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
    const userExists = result.rows.length > 0;
    
    if (!userExists) {
      if (requestedRole === 'Driver' || requestedRole === 'Admin') {
         return res.status(403).json({ error: `Unauthorized access for ${requestedRole}` });
      }
      
      // Auto-create Customer
      try {
        await db.query(
          `INSERT INTO users (uid, phone, role) 
           VALUES ($1, $2, $3) 
           ON CONFLICT (uid) DO UPDATE SET role = EXCLUDED.role`,
          [uid, phone, 'customer']
        );
      } catch(err) {
        console.error('PostgreSQL Error:', err);
      }
      
      // Insert Welcome Notification
      try {
        await db.query(
          'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
          [uid, 'Welcome to Parigo EV!', 'Thanks for joining our eco-friendly fleet. Book your first ride today.', 'welcome']
        );
      } catch (err) {
        console.error('Error inserting welcome notification:', err);
      }

      return res.status(200).json({ success: true, uid: uid, message: 'OTP Verified Successfully', role: 'Customer', isNewUser: true });
    } else {
      const user = result.rows[0];
      const requestedRoleLower = requestedRole ? requestedRole.toLowerCase() : 'customer';
      const dbRoleLower = user.role.toLowerCase();

      if (requestedRoleLower === 'customer') {
        if (dbRoleLower !== 'customer') {
          return res.status(403).json({ error: `Unauthorized. This phone number is registered as an ${user.role}.` });
        }
      } else if (requestedRoleLower === 'driver' || requestedRoleLower === 'admin') {
        if (dbRoleLower !== requestedRoleLower) {
          if (!(requestedRoleLower === 'driver' && dbRoleLower === 'admin')) {
            return res.status(403).json({ error: `Unauthorized access. Role mismatch.` });
          }
        }
      }
      
      await db.query('UPDATE users SET uid = $1 WHERE phone = $2', [uid, phone]);
      await db.query('UPDATE drivers SET driver_uid = $1 WHERE user_id = (SELECT id FROM users WHERE phone = $2)', [uid, phone]);
      return res.status(200).json({ success: true, uid: uid, message: 'OTP Verified Successfully', role: user.role });
    }
  } catch (error) {
    console.error('Error verifying token:', error);
    res.status(401).json({ error: 'Invalid or expired token' });
  }
};

const checkUser = async (req, res) => {
  const { phone, role } = req.body;
  if (!phone) return res.status(400).json({ error: 'Phone number is required' });

  try {
    const result = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      if (role === 'Driver' || role === 'Admin') {
        return res.status(403).json({ error: `Unauthorized. You are not registered as a ${role}.` });
      }
      return res.status(200).json({ userExists: false, hasPin: false });
    }
    const user = result.rows[0];
    
    const requestedRoleLower = role ? role.toLowerCase() : 'customer';
    const dbRoleLower = user.role.toLowerCase();

    if (requestedRoleLower === 'customer') {
      if (dbRoleLower !== 'customer') {
        return res.status(403).json({ 
          error: `Unauthorized. This phone number is registered as an ${user.role}. Please use the correct app or a different phone number for your Customer account.` 
        });
      }
    } else if (requestedRoleLower === 'driver' || requestedRoleLower === 'admin') {
      if (dbRoleLower !== requestedRoleLower) {
        if (!(requestedRoleLower === 'driver' && dbRoleLower === 'admin')) {
          return res.status(403).json({ error: `Unauthorized. Role mismatch.` });
        }
      }
    }

    return res.status(200).json({ userExists: true, hasPin: !!user.pin });
  } catch (error) {
    console.error('Error checking user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const setPin = async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: 'Phone and PIN are required' });

  try {
    await db.query('UPDATE users SET pin = $1 WHERE phone = $2', [pin, phone]);
    res.status(200).json({ success: true, message: 'PIN set successfully' });
  } catch (error) {
    console.error('Error setting PIN:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const verifyPin = async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: 'Phone and PIN are required' });

  try {
    const result = await db.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];
    if (user.pin !== pin) {
      return res.status(401).json({ error: 'Incorrect PIN' });
    }

    // PIN is correct. Generate a Firebase custom token so client can sign in.
    let customToken;
    try {
      customToken = await admin.auth().createCustomToken(user.uid);
    } catch (firebaseErr) {
      console.error('Error creating custom token:', firebaseErr);
      return res.status(500).json({ error: 'Could not generate session token' });
    }

    res.status(200).json({
      success: true,
      customToken: customToken,
      uid: user.uid,
      role: user.role
    });

  } catch (error) {
    console.error('Error verifying PIN:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  verifyOtp,
  checkUser,
  setPin,
  verifyPin
};
