const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
if (admin.apps.length === 0) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

async function run() {
  const snapshot = await admin.firestore().collection('rides').where('status', '==', 'SCHEDULED').get();
  const rides = [];
  snapshot.forEach(doc => rides.push({id: doc.id, ...doc.data()}));
  
  try {
    rides.sort((a, b) => {
      if (!a.createdAt || !b.createdAt) return 0;
      return b.createdAt.toDate().getTime() - a.createdAt.toDate().getTime();
    });
    console.log("Sort succeeded", rides.length);
  } catch (e) {
    console.log("Sort crashed", e.message);
  }
}
run();
