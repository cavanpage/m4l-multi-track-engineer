// bridge.js
// Node for Max (n4m) — WebSocket client.
// Forwards Spoke metadata to the Python server and emits responses back to Max.
// Reconnects automatically if the Python server is not yet running.

const MaxAPI = require('max-api');
const WebSocket = require('ws');

const SERVER_URL = 'ws://localhost:8765';
const RETRY_MS   = 2000;

let ws = null;
let ready = false;

function connect() {
  ws = new WebSocket(SERVER_URL);

  ws.on('open', () => {
    ready = true;
    MaxAPI.post('bridge: connected to Python server at ' + SERVER_URL);
  });

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      MaxAPI.outlet(msg);
    } catch (e) {
      MaxAPI.post('bridge: bad message from server — ' + e.message);
    }
  });

  ws.on('close', () => {
    ready = false;
    MaxAPI.post('bridge: disconnected — retrying in ' + RETRY_MS + 'ms');
    setTimeout(connect, RETRY_MS);
  });

  ws.on('error', (err) => {
    // suppress ECONNREFUSED noise while Python server is starting up
    if (err.code !== 'ECONNREFUSED') {
      MaxAPI.post('bridge: error — ' + err.message);
    }
  });
}

// Receives JSON string from spoke_identity.js via "prepend meta" in the patch
MaxAPI.addHandler('meta', (jsonStr) => {
  if (!ready) return;
  try {
    const meta = typeof jsonStr === 'string' ? JSON.parse(jsonStr) : jsonStr;
    ws.send(JSON.stringify({ type: 'meta', payload: meta }));
  } catch (e) {
    MaxAPI.post('bridge: send error — ' + e.message);
  }
});

connect();
