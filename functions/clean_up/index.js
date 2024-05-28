const { Firestore } = require('@google-cloud/firestore');

const firestore = new Firestore();

exports.cleanUpRequests = async (req, res) => {
  try {
    const requestsCollection = firestore.collection('requests');

    // Get all documents in the collection, ordered by the timestamp
    const snapshot = await requestsCollection.orderBy('created_at', 'desc').get();

    if (snapshot.empty) {
      console.log('No request logs found');
      res.status(200).send('No request logs found');
      return;
    }

    const docs = snapshot.docs;

    // Keep the most recent document and delete all others
    const batch = firestore.batch();
    for (let i = 1; i < docs.length; i++) {
      batch.delete(docs[i].ref);
    }

    await batch.commit();
    console.log(`Deleted ${docs.length - 1} old request logs`);
    res.status(200).send(`Deleted ${docs.length - 1} old request logs`);
  } catch (error) {
    console.error('Error cleaning up request logs:', error);
    res.status(500).send('Error cleaning up request logs');
  }
};
