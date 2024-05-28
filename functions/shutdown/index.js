const { Firestore } = require('@google-cloud/firestore');
const { google } = require('googleapis');
const compute = google.compute('v1');

const firestore = new Firestore();
const projectId = process.env.PROJECT_ID;
const zone = process.env.ZONE;
const instanceName = process.env.INSTANCE_NAME;
const maxIdleDuration = parseInt(process.env.INSTANCE_MAX_IDLE_DURATION, 10);

exports.checkAndShutdown = async (req, res) => {
  try {
    // Get the latest request log from Firestore
    const snapshot = await firestore.collection('requests')
      .orderBy('created_at', 'desc')
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('No request logs found');
      res.status(200).send('No request logs found');
      return;
    }

    const doc = snapshot.docs[0];
    const lastRequestTime = doc.data().created_at.toDate();
    const currentTime = new Date();

    const timeDifference = (currentTime - lastRequestTime) / 1000; // in seconds

    if (timeDifference > maxIdleDuration) {
      // Authorize the client with application default credentials
      const authClient = await google.auth.getClient({
        scopes: ['https://www.googleapis.com/auth/cloud-platform']
      });
      google.options({ auth: authClient });

      // Check the status of the instance
      const instance = await compute.instances.get({
        project: projectId,
        zone: zone,
        instance: instanceName
      });

      if (instance.data.status !== 'TERMINATED' && instance.data.status !== 'STOPPED') {
        // Shutdown the GCE instance if it is running
        const response = await compute.instances.stop({
          project: projectId,
          zone: zone,
          instance: instanceName
        });

        console.log(`Instance ${instanceName} stopped successfully`, response.data);
        res.status(200).send(`Instance ${instanceName} stopped successfully`);
      } else {
        console.log(`Instance ${instanceName} is already stopped`);
        res.status(200).send(`Instance ${instanceName} is already stopped`);
      }
    } else {
      console.log('Instance does not need to be stopped');
      res.status(200).send('Instance does not need to be stopped');
    }
  } catch (error) {
    console.error('Error checking logs or stopping instance:', error);
    res.status(500).send('Error checking logs or stopping instance');
  }
};
