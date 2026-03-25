# Phase 1 — Identity Layer: Build & Test Guide

**Goal:** A Spoke device reads its own track name and color from the LOM and logs them to the Max Console.

**Prerequisite:** Ableton Live 11+ with Max for Live installed.

---

## Step 1: Create the M4L Device File

1. In Ableton, create a new **Audio Track** and rename it `Kick Drum`
2. In the browser sidebar: **Max for Live → Max Audio Effect** — drag a blank one onto the track
3. Click the **pencil icon** on the device to open the Max patcher
4. In Max, go **File → Save As** → save as `spoke_identity.amxd` in your project folder

---

## Step 2: Build the Patch

Switch to **patching mode** (`Cmd+E`) and place these objects, connected top to bottom:

```
[live.thisdevice]
       |
  (outlet 1 = device id on load)
       |
[prepend set]
       |
[live.object]          ←── points to this Spoke device
       |
[get canonical_parent] ←── requests the parent track's id
       |
[route id]             ←── extracts the id number from "id 42"-style message
       |
[prepend set]
       |
[live.object]          ←── points to the track
       |
[get name color]       ←── requests both properties in one shot
       |
[print track_info]     ←── outputs to Max Console
```

**Wiring notes:**
- `live.thisdevice` left outlet → `prepend set` → first `live.object`
- First `live.object` left outlet → `get canonical_parent`
- `get canonical_parent` outlet → `route id`
- `route id` outlet → `prepend set` → second `live.object`
- Second `live.object` left outlet → `get name color` → `print track_info`

Lock the patch (`Cmd+E`) and save (`Cmd+S`).

---

## Step 3: Open the Max Console

In Max: **Window → Max Console** (`Cmd+Shift+M`)

Keep this open — it is your test output for all Phase 1 tests.

---

## Step 4: Run the Tests

### Test 1 — Patch loads without errors

- Delete the device from the track and re-drag it on
- Console should show:
  ```
  track_info: name Kick Drum
  track_info: color 16711680
  ```
- No red error messages = **pass**

---

### Test 2 — Correct name when track is renamed

- Rename the Ableton track to `Snare`
- Delete and re-add the device (or add a `[bang]` button wired to `live.thisdevice` to re-trigger manually)
- Console should print `name Snare` = **pass**

---

### Test 3 — Color int matches the track swatch

- Right-click the track name in Ableton → change the color to bright red
- Re-trigger the device
- Console prints a number — e.g. `16711680`
- Convert to hex: `16711680` → `#FF0000` = red = **pass**

> Use any decimal-to-hex color converter to verify other colors.

---

### Test 4 — Hot-rename fires a live update

The tests above re-trigger manually. To watch for live renames, extend the patch with a `[live.observer]`:

```
[live.object]  (the track live.object from Step 2)
       |
[live.observer @property name]
       |
[print name_changed]
```

- Rename the track while Ableton is running
- Console should print `name_changed: <new name>` within ~1 second = **pass**

---

### Test 5 — JS categorization returns correct category or `"unknown"`

Create `spoke_identity.js` in the **same folder** as your `.amxd` file:

```js
// spoke_identity.js
const MaxAPI = require('max-api');

const KEYWORD_MAP = {
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
  pad:    'pad',
};

function categorize(name) {
  const lower = name.toLowerCase();
  for (const [keyword, category] of Object.entries(KEYWORD_MAP)) {
    if (lower.includes(keyword)) return category;
  }
  return 'unknown';
}

MaxAPI.addHandler('name', (trackName) => {
  const category = categorize(trackName);
  MaxAPI.outlet({ name: trackName, category });
});
```

In the Max patch, replace `[print track_info]` with:

```
[js spoke_identity.js]
       |
[print spoke_meta]
```

Wire the `get name` outlet into the `[js spoke_identity.js]` inlet.

**Run these cases:**

| Track name | Expected category |
|---|---|
| `Pad Lead` | `pad` |
| `Vocal Chop` | `vocal` |
| `Kick 808` | `kick` |
| `Bus Group 1` | `unknown` |

All four correct = **pass**

---

## Phase 1 Test Checklist

Copy this into your notes and tick each off before starting Phase 2:

```
[ ] Patch loads — name + color print to console on device load
[ ] Console shows correct name after track rename + re-trigger
[ ] Color decimal converts to the correct hex swatch color
[ ] live.observer fires name_changed on hot-rename without re-loading device
[ ] Known keywords (kick, vocal, pad) return the correct category
[ ] Unrecognized name returns category: unknown
```

All six green → **Phase 1 complete. Safe to start [Phase 2](./phase-2-bridge-layer.md).**

---

## Interface Contract (frozen for Phase 2+)

The shape below is the output of `spoke_identity.js`. Downstream phases depend on this — do not change property names.

```js
// TrackMeta
{
  name: string,     // e.g. "Kick Drum"
  color: number,    // Ableton RGB int, e.g. 16711680
  category: string  // e.g. "kick" | "vocal" | "unknown"
}
```

---

← [Back to README](../README.md)
