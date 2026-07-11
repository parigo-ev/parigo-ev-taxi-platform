const db = require('../../db');
const Razorpay = require('razorpay');
const crypto = require('crypto');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

function normalizePhone(phone) {
  if (!phone) return phone;
  let normalized = phone.toString().trim();
  if (!normalized.startsWith('+')) {
    if (normalized.length === 10) {
      normalized = '+91' + normalized;
    } else {
      normalized = '+' + normalized;
    }
  }
  return normalized;
}

const getBalance = async (req, res) => {
  const { phone } = req.params;
  try {
    const normalizedPhone = normalizePhone(phone);
    const result = await db.query('SELECT uid FROM users WHERE phone = $1', [normalizedPhone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    
    const uid = result.rows[0].uid;
    const walletRes = await db.query('SELECT balance FROM wallets WHERE uid = $1', [uid]);
    const balance = walletRes.rows.length > 0 ? walletRes.rows[0].balance : 0;
    res.status(200).json({ success: true, balance: parseFloat(balance) });
  } catch (error) {
    console.error('Error fetching balance:', error);
    res.status(500).json({ error: 'Failed to fetch balance' });
  }
};

const getTransactions = async (req, res) => {
  const { phone } = req.params;
  try {
    const normalizedPhone = normalizePhone(phone);
    const result = await db.query('SELECT id FROM users WHERE phone = $1', [normalizedPhone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    
    const userId = result.rows[0].id;
    const transRes = await db.query(
      `SELECT id, user_id, UPPER(type) as type, amount, balance_after, reference_type, reference_id, description, created_at 
       FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC`, 
      [userId]
    );
    res.status(200).json({ success: true, transactions: transRes.rows });
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
};

const addFunds = async (req, res) => {
  const { phone, amount } = req.body;
  const paymentMethod = req.body.paymentMethod || 'Payment Gateway';
  if (!phone || !amount) return res.status(400).json({ error: 'Phone and amount required' });

  try {
    const normalizedPhone = normalizePhone(phone);
    const result = await db.query('SELECT id, uid FROM users WHERE phone = $1', [normalizedPhone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    const { id: userId, uid } = result.rows[0];

    const walletRes = await db.query(
      `INSERT INTO wallets (uid, balance) VALUES ($1, $2) 
       ON CONFLICT (uid) DO UPDATE SET balance = wallets.balance + $2
       RETURNING balance`,
      [uid, amount]
    );
    const newBalance = walletRes.rows[0].balance;

    await db.query(
      `INSERT INTO wallet_transactions (user_id, amount, type, balance_after, description) VALUES ($1, $2, 'credit', $3, $4)`,
      [userId, amount, newBalance, `Added via ${paymentMethod}`]
    );

    // Insert wallet topup notification
    try {
      await db.query(
        'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
        [uid, 'Welcome to Parigo EV!', `₹${amount} has been added to your Parigo EV wallet.`, 'wallet_topup']
      );
    } catch (err) {
      console.error('Error inserting wallet topup notification:', err);
    }

    res.status(200).json({ success: true, message: 'Funds added successfully' });
  } catch (error) {
    console.error('Error adding funds:', error);
    res.status(500).json({ error: 'Failed to add funds' });
  }
};

const createRazorpayOrder = async (req, res) => {
  const { amount } = req.body;
  if (!amount) return res.status(400).json({ error: 'Amount required' });

  try {
    const options = {
      amount: amount * 100, // amount in the smallest currency unit (paise)
      currency: 'INR',
      receipt: `receipt_order_${Date.now()}`
    };
    
    const order = await razorpay.orders.create(options);
    if (!order) return res.status(500).json({ error: 'Failed to create order' });
    
    res.status(200).json({ success: true, order });
  } catch (error) {
    console.error('Error creating razorpay order:', error);
    res.status(500).json({ error: 'Failed to create razorpay order' });
  }
};

const verifyPayment = async (req, res) => {
  const { phone, amount, razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;
  
  if (!phone || !amount || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ error: 'Missing payment verification details' });
  }

  try {
    const shasum = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET);
    shasum.update(`${razorpay_order_id}|${razorpay_payment_id}`);
    const digest = shasum.digest('hex');

    if (digest !== razorpay_signature) {
      return res.status(400).json({ error: 'Transaction not legit!' });
    }

    // Payment is successful, add funds
    const normalizedPhone = normalizePhone(phone);
    const result = await db.query('SELECT id, uid FROM users WHERE phone = $1', [normalizedPhone]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    const { id: userId, uid } = result.rows[0];

    const walletRes = await db.query(
      `INSERT INTO wallets (uid, balance) VALUES ($1, $2) 
       ON CONFLICT (uid) DO UPDATE SET balance = wallets.balance + $2
       RETURNING balance`,
      [uid, amount]
    );
    const newBalance = walletRes.rows[0].balance;

    await db.query(
      `INSERT INTO wallet_transactions (user_id, amount, type, balance_after, description) VALUES ($1, $2, 'credit', $3, $4)`,
      [userId, amount, newBalance, 'Added via Razorpay']
    );

    try {
      await db.query(
        'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
        [uid, 'Wallet Top-up Successful', `₹${amount} has been added to your Parigo EV wallet.`, 'wallet_topup']
      );
    } catch (err) {
      console.error('Error inserting wallet topup notification:', err);
    }

    res.status(200).json({ success: true, message: 'Payment verified and funds added successfully' });
  } catch (error) {
    console.error('Error verifying payment:', error);
    res.status(500).json({ error: 'Failed to verify payment' });
  }
};

const razorpayWebhook = async (req, res) => {
  const secret = process.env.RAZORPAY_KEY_SECRET;
  const signature = req.headers['x-razorpay-signature'];
  
  if (!signature) {
    return res.status(400).send('No signature');
  }

  try {
    const isValid = Razorpay.validateWebhookSignature(req.rawBody.toString(), signature, secret);
    if (!isValid) {
      return res.status(400).send('Invalid signature');
    }

    const event = req.body.event;
    if (event === 'payment.captured' || event === 'payment.authorized') {
      const payment = req.body.payload.payment.entity;
      const amount = payment.amount / 100;
      const phone = payment.contact;
      const order_id = payment.order_id;
      
      const normalizedPhone = normalizePhone(phone);
      const result = await db.query('SELECT id, uid FROM users WHERE phone = $1', [normalizedPhone]);
      if (result.rows.length > 0) {
        const { id: userId, uid } = result.rows[0];
        
        // Prevent double funding by checking if order ID was already processed
        const checkRes = await db.query('SELECT id FROM wallet_transactions WHERE description LIKE $1', [`%${order_id}%`]);
        if (checkRes.rows.length === 0) {
          const walletRes = await db.query(
            `INSERT INTO wallets (uid, balance) VALUES ($1, $2) 
             ON CONFLICT (uid) DO UPDATE SET balance = wallets.balance + $2
             RETURNING balance`,
            [uid, amount]
          );
          const newBalance = walletRes.rows[0].balance;

          await db.query(
            `INSERT INTO wallet_transactions (user_id, amount, type, balance_after, description) VALUES ($1, $2, 'credit', $3, $4)`,
            [userId, amount, newBalance, `Added via Razorpay Webhook Order: ${order_id}`]
          );

          try {
            await db.query(
              'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
              [uid, 'Wallet Top-up Successful', `₹${amount} has been added to your Parigo EV wallet.`, 'wallet_topup']
            );
          } catch (err) {
            console.error('Error inserting webhook notification:', err);
          }
        }
      }
    }
    
    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Server Error');
  }
};

const phonepeCreateOrder = async (req, res) => {
  const { amount, phone } = req.body;
  if (!amount || !phone) return res.status(400).json({ error: 'Amount and phone required' });

  try {
    const merchantTransactionId = `T${Date.now()}`;
    const data = {
      merchantId: process.env.PHONEPE_MERCHANT_ID,
      merchantTransactionId: merchantTransactionId,
      merchantUserId: phone,
      amount: amount * 100,
      redirectUrl: "https://parigo.example.com/payment/success",
      redirectMode: "REDIRECT",
      mobileNumber: phone,
      paymentInstrument: {
        type: "PAY_PAGE"
      }
    };

    const base64Payload = Buffer.from(JSON.stringify(data)).toString('base64');
    const endpoint = '/pg/v1/pay';
    const saltKey = process.env.PHONEPE_SALT_KEY;
    const saltIndex = process.env.PHONEPE_SALT_INDEX;
    
    const stringToHash = base64Payload + endpoint + saltKey;
    const sha256 = crypto.createHash('sha256').update(stringToHash).digest('hex');
    const checksum = `${sha256}###${saltIndex}`;

    const phonepeHost = process.env.PHONEPE_ENV === 'PROD' 
      ? 'https://api.phonepe.com/apis/hermes' 
      : 'https://api-preprod.phonepe.com/apis/pg-sandbox';
      
    const response = await fetch(`${phonepeHost}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-VERIFY': checksum
      },
      body: JSON.stringify({ request: base64Payload })
    });

    const responseData = await response.json();

    if (responseData.success) {
      const url = responseData.data.instrumentResponse.redirectInfo.url;
      res.status(200).json({ success: true, url, merchantTransactionId });
    } else {
      res.status(400).json({ error: responseData.message || 'PhonePe init failed' });
    }
  } catch (error) {
    console.error('PhonePe Create Order Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

const phonepeVerifyPayment = async (req, res) => {
  const { merchantTransactionId, phone, amount } = req.body;
  if (!merchantTransactionId || !phone || !amount) return res.status(400).json({ error: 'Missing details' });

  try {
    const merchantId = process.env.PHONEPE_MERCHANT_ID;
    const saltKey = process.env.PHONEPE_SALT_KEY;
    const saltIndex = process.env.PHONEPE_SALT_INDEX;
    
    const endpoint = `/pg/v1/status/${merchantId}/${merchantTransactionId}`;
    const stringToHash = endpoint + saltKey;
    const sha256 = crypto.createHash('sha256').update(stringToHash).digest('hex');
    const checksum = `${sha256}###${saltIndex}`;

    const phonepeHost = process.env.PHONEPE_ENV === 'PROD' 
      ? 'https://api.phonepe.com/apis/hermes' 
      : 'https://api-preprod.phonepe.com/apis/pg-sandbox';

    const response = await fetch(`${phonepeHost}${endpoint}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-VERIFY': checksum,
        'X-MERCHANT-ID': merchantId
      }
    });

    const responseData = await response.json();

    if (responseData.success && responseData.data.state === 'COMPLETED') {
      const normalizedPhone = normalizePhone(phone);
      const result = await db.query('SELECT id, uid FROM users WHERE phone = $1', [normalizedPhone]);
      if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
      const { id: userId, uid } = result.rows[0];

      const checkRes = await db.query('SELECT id FROM wallet_transactions WHERE description LIKE $1', [`%${merchantTransactionId}%`]);
      if (checkRes.rows.length === 0) {
        const walletRes = await db.query(
          `INSERT INTO wallets (uid, balance) VALUES ($1, $2) 
           ON CONFLICT (uid) DO UPDATE SET balance = wallets.balance + $2
           RETURNING balance`,
          [uid, amount]
        );
        const newBalance = walletRes.rows[0].balance;

        await db.query(
          `INSERT INTO wallet_transactions (user_id, amount, type, balance_after, description) VALUES ($1, $2, 'credit', $3, $4)`,
          [userId, amount, newBalance, `Added via PhonePe Order: ${merchantTransactionId}`]
        );

        try {
          await db.query(
            'INSERT INTO notifications (uid, title, message, type) VALUES ($1, $2, $3, $4)',
            [uid, 'Wallet Top-up Successful', `₹${amount} has been added to your Parigo EV wallet.`, 'wallet_topup']
          );
        } catch (err) {}
      }

      res.status(200).json({ success: true, message: 'Payment verified successfully' });
    } else {
      res.status(400).json({ error: 'Payment not successful', state: responseData.data?.state });
    }
  } catch (error) {
    console.error('PhonePe Verify Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

const getBalanceByIdentifier = async (req, res) => {
  const { identifier } = req.params;
  try {
    let result;
    // Check if identifier is a phone number (e.g. contains only digits and possibly starting with +)
    if (/^\+?[0-9]+$/.test(identifier)) {
      const normalizedPhone = normalizePhone(identifier);
      result = await db.query('SELECT uid FROM users WHERE phone = $1', [normalizedPhone]);
    } else {
      result = await db.query('SELECT uid FROM users WHERE uid = $1', [identifier]);
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const uid = result.rows[0].uid;
    const walletRes = await db.query('SELECT balance FROM wallets WHERE uid = $1', [uid]);
    const balance = walletRes.rows.length > 0 ? walletRes.rows[0].balance : 0;
    res.status(200).json({ success: true, balance: parseFloat(balance) });
  } catch (error) {
    console.error('Error fetching balance by identifier:', error);
    res.status(500).json({ error: 'Failed to fetch balance' });
  }
};

module.exports = {
  getBalance,
  getTransactions,
  addFunds,
  createRazorpayOrder,
  verifyPayment,
  razorpayWebhook,
  phonepeCreateOrder,
  phonepeVerifyPayment,
  getBalanceByIdentifier
};
