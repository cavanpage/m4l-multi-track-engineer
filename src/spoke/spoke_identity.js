// spoke_identity.js
// Max js object — uses LiveAPI for direct LOM access.
// Triggered by a bang from live.thisdevice on device load.
// Outputs JSON string: { name, color, category }
// Watches for live track renames and re-emits automatically.

autowatch = 1;
inlets = 1;
outlets = 1;

var trackApi = null;

var KEYWORD_MAP = {
  kick:   'kick',
  snare:  'snare',
  hat:    'hat',
  hihat:  'hat',
  bass:   'bass',
  vocal:  'vocal',
  vox:    'vocal',
  synth:  'synth',
  guitar: 'guitar',
  piano:  'piano',
  pad:    'pad'
};

function bang() {
  init();
}

function init() {
  try {
    var device = new LiveAPI('this_device');
    var parentResult = device.get('canonical_parent');

    if (!parentResult || parentResult[0] !== 'id') {
      error('spoke_identity: could not resolve canonical_parent\n');
      return;
    }

    trackApi = new LiveAPI(onTrackChange, 'id ' + parentResult[1]);
    trackApi.property = 'name';
    trackApi.propwatch = 1;

    emitMeta();
  } catch (e) {
    error('spoke_identity init error: ' + e.message + '\n');
  }
}

function onTrackChange() {
  emitMeta();
}

function emitMeta() {
  if (!trackApi) return;

  var name     = String(trackApi.get('name')[0]);
  var color    = parseInt(trackApi.get('color')[0]);
  var category = categorize(name);

  outlet(0, JSON.stringify({ name: name, color: color, category: category }));
}

function categorize(name) {
  var lower = name.toLowerCase();
  for (var keyword in KEYWORD_MAP) {
    if (KEYWORD_MAP.hasOwnProperty(keyword) && lower.indexOf(keyword) !== -1) {
      return KEYWORD_MAP[keyword];
    }
  }
  return 'unknown';
}
