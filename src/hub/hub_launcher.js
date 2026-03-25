// hub_launcher.js
// Node for Max (n4m) — uses built-in child_process, no npm needed.
// Spawns and manages the spoke_server binary alongside this file.
// Receives 'start' from live.thisdevice left outlet (device loaded).
// Receives 'stop'  from live.thisdevice right outlet (device removed).

const MaxAPI      = require('max-api');
const { spawn }   = require('child_process');
const path        = require('path');
const fs          = require('fs');

const BINARY_NAME = process.platform === 'win32' ? 'spoke_server.exe' : 'spoke_server';
const BINARY_PATH = path.join(__dirname, BINARY_NAME);

let serverProcess = null;

function emitStatus(s) {
  MaxAPI.outlet(s);
  MaxAPI.post('hub_launcher: ' + s);
}

MaxAPI.addHandler('start', () => {
  if (serverProcess) {
    emitStatus('already running');
    return;
  }

  if (!fs.existsSync(BINARY_PATH)) {
    emitStatus('error: binary not found — run build.sh first');
    return;
  }

  // PYTHONUNBUFFERED ensures stdout is line-buffered even in a PyInstaller binary
  const env = Object.assign({}, process.env, { PYTHONUNBUFFERED: '1' });
  serverProcess = spawn(BINARY_PATH, [], { detached: false, env: env });

  serverProcess.stdout.on('data', (data) => {
    const line = data.toString().trim();
    MaxAPI.post('[python] ' + line);
    // Emit 'running' only once the server confirms it is listening
    if (line.includes('listening')) {
      emitStatus('running');
    }
  });

  serverProcess.stderr.on('data', (data) => {
    MaxAPI.post('[python err] ' + data.toString().trim());
  });

  // Emit 'stopped' exactly once — from the close event, not the stop handler
  serverProcess.on('close', (code) => {
    MaxAPI.post('hub_launcher: server exited (code ' + code + ')');
    serverProcess = null;
    emitStatus('stopped');
  });
});

MaxAPI.addHandler('stop', () => {
  if (serverProcess) {
    serverProcess.kill();
    serverProcess = null;
    emitStatus('stopped');
  }
});
