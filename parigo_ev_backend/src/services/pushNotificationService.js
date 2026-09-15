const admin = require('firebase-admin');
const db = require('../../db');

const invalidTokenErrors = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

function serializeMetadata(metadata) {
  if (!metadata) return {};
  if (typeof metadata === 'string') {
    try {
      return JSON.parse(metadata);
    } catch (_) {
      return {};
    }
  }
  return metadata;
}

function notificationData({ notificationId, type, metadata }) {
  return {
    notificationId: notificationId ? String(notificationId) : '',
    type: type || 'general',
    metadata: JSON.stringify(serializeMetadata(metadata)),
  };
}

async function sendPushToUsers(uids, notification) {
  const uniqueUids = [...new Set(uids.filter(Boolean))];
  if (!uniqueUids.length || admin.apps.length === 0) {
    return { sent: 0, skipped: true };
  }

  const tokenResult = await db.query(
    'SELECT token FROM device_tokens WHERE uid = ANY($1::varchar[])',
    [uniqueUids]
  );
  const tokens = [...new Set(tokenResult.rows.map((row) => row.token).filter(Boolean))];
  if (!tokens.length) return { sent: 0, skipped: true };

  let sent = 0;
  const staleTokens = [];

  for (let index = 0; index < tokens.length; index += 500) {
    const chunk = tokens.slice(index, index + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: {
        title: notification.title,
        body: notification.message,
      },
      data: notificationData(notification),
      android: {
        priority: 'high',
        notification: {
          channelId: 'parigo_notifications',
          sound: 'default',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    });

    sent += response.successCount;
    response.responses.forEach((result, responseIndex) => {
      if (!result.success && invalidTokenErrors.has(result.error?.code)) {
        staleTokens.push(chunk[responseIndex]);
      } else if (!result.success) {
        console.error('FCM delivery failed:', result.error?.code || result.error);
      }
    });
  }

  if (staleTokens.length) {
    await db.query('DELETE FROM device_tokens WHERE token = ANY($1::text[])', [staleTokens]);
  }

  return { sent, skipped: false };
}

async function notifyUser(uid, { title, message, type = 'general', metadata = null }) {
  const metadataJson = metadata ? JSON.stringify(serializeMetadata(metadata)) : null;
  const result = await db.query(
    `INSERT INTO notifications (uid, title, message, type, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id`,
    [uid, title, message, type, metadataJson]
  );

  const notification = {
    notificationId: result.rows[0].id,
    title,
    message,
    type,
    metadata,
  };
  sendPushToUsers([uid], notification).catch((error) => {
    console.error('Unable to send FCM notification:', error);
  });
  return notification;
}

async function notifyUsers(uids, notification) {
  const uniqueUids = [...new Set(uids.filter(Boolean))];
  await Promise.all(uniqueUids.map((uid) => notifyUser(uid, notification)));
  return uniqueUids.length;
}

module.exports = {
  notifyUser,
  notifyUsers,
  sendPushToUsers,
};
