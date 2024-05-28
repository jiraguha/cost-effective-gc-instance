const { Firestore } = require('@google-cloud/firestore');
const httpProxy = require('http-proxy');
const { google } = require('googleapis');
const compute = google.compute('v1');

const firestore = new Firestore();
const proxy = httpProxy.createProxyServer({});
let targetUrl = process.env.TARGET_URL;
const collectionId = process.env.COLLECTION_ID;
const projectId = process.env.PROJECT_ID;
const zone = process.env.ZONE;
const instanceName = process.env.INSTANCE_NAME;
const instanceStartDuration = parseInt(process.env.INSTANCE_START_DURATION,10);

if (!/^https?:\/\//i.test(targetUrl)) {
  targetUrl = `http://${targetUrl}`;
}

// Function to restart the GCE instance if it is stopped or terminated
async function restartInstanceIfNeeded() {
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
  
    if (instance.data.status === 'TERMINATED' || instance.data.status === 'STOPPED') {
      // Start the GCE instance if it is stopped or terminated
      const startResponse = await compute.instances.start({
        project: projectId,
        zone: zone,
        instance: instanceName
      });
  
      console.log(`Instance ${instanceName} started successfully`, startResponse.data);
  
      // Wait for the instance to start
      await new Promise(resolve => setTimeout(resolve, instanceStartDuration)); // wait for 1 minute
    }
  }

exports.handler = async (req, res) => {
  try {
    await restartInstanceIfNeeded();
    const docRef = firestore.collection(collectionId).doc();
    const timestamp = new Date().toISOString();
    const createdAt = new Date();
    const requestData = { timestamp: timestamp, created_at: createdAt };

    if (req.method) {
        requestData.method = req.method;
    }
    if (req.headers) {
        requestData.headers = req.headers;
    }
    if (req.url) {
        requestData.path = req.url;
    }

    docRef.set(requestData)
        .then(() => {
        proxy.web(req, res, { target: targetUrl }, (err) => {
            if (err) {
            res.status(500).send('Proxy error: ' + err.message);
            }
        });
        })
        .catch(err => {
        res.status(500).send('Firestore error: ' + err.message);
    });
  } catch (error) {
    console.error('Error restarting instance or proxying request:', error);
    res.status(500).send('Error restarting instance or proxying request');
  }
};
