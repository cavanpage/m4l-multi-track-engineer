# Phase 1 — Identity Layer: Build & Test Guide

**Goal:** Each Spoke device reads its own track name and color from the LOM, renders a visual panel, and registers itself with the Python server.

**Prerequisites:**
- Ableton Live 11+ with Max for Live
- Node.js 18+ (for n4m)
- Python 3.11+

**Source files:**

| File | Role |
|---|---|
| [`src/spoke/spoke_identity.js`](../src/spoke/spoke_identity.js) | LOM reads via LiveAPI |
| [`src/spoke/spoke_ui.js`](../src/spoke/spoke_ui.js) | jsui visual panel |
| [`src/spoke/bridge.js`](../src/spoke/bridge.js) | n4m WebSocket client → Python |
| [`src/spoke/spoke_identity.maxpat`](../src/spoke/spoke_identity.maxpat) | Pre-wired Max patch |
| [`src/python/server.py`](../src/python/server.py) | Python WebSocket server |
| [`src/python/requirements.txt`](../src/python/requirements.txt) | Python dependencies |

---

## Signal flow

```
[live.thisdevice] → bang on load
        │
[js spoke_identity.js] ← reads LOM via LiveAPI (name, color, category)
        │                  watches track name for live renames
        ├──[prepend parse]──► [jsui spoke_ui.js]     visual panel in device
        ├──[prepend meta]───► [node.script bridge.js] → WebSocket → Python
        └──[print spoke_meta]                         Max Console debug
```

---

## Why two JS environments?

| Object | Environment | Why |
|---|---|---|
| `js spoke_identity.js` | Max `js` (ES5) | Only environment with native `LiveAPI` for LOM access |
| `jsui spoke_ui.js` | Max `js` (ES5) | Only environment with `mgraphics` for drawing in a device panel |
| `node.script bridge.js` | Node for Max (n4m) | Needs `ws` npm package for WebSocket |

`LiveAPI` and `mgraphics` are not available in n4m. n4m's npm access is not available in the `js` object. Each piece uses the right environment for the job.

---

## Step 1: Install dependencies

**Node (n4m bridge):**
```bash
cd src/spoke
npm install
```

**Python server:**
```bash
cd src/python
pip install -r requirements.txt
```

---

## Step 2: Start the Python server

```bash
cd src/python
python server.py
```

You should see:
```
[server] listening on ws://localhost:8765
```

Leave this running in a terminal.

---

## Step 3: Load the device into Ableton

1. Create a new **Audio Track** and rename it `Kick Drum`
2. In the Ableton browser, navigate to `src/spoke/`
3. Drag `spoke_identity.maxpat` onto the track
4. When prompted, save as `spoke_identity.amxd` in `src/spoke/`
5. Open the Max Console: **Window → Max Console** (`Cmd+Shift+M`)

---

## Step 4: Run the tests

### Test 1 — Device loads, visual panel appears

- Re-drag the device onto the track
- The device panel should show:
  ```
  ████ Kick Drum
       kick
  ```
  (colored swatch on the left, track name, category badge)
- Max Console prints: `spoke_meta: {"name":"Kick Drum","color":...,"category":"kick"}`
- Python terminal prints: `[spoke] Kick Drum           category=kick       color=...`
- = **pass**

---

### Test 2 — Correct name on renamed track

- Rename the track to `Snare Top`, delete and re-add the device
- Panel updates to show `Snare Top` / `snare`
- Python terminal shows the updated name
- = **pass**

---

### Test 3 — Color swatch matches track color

- Right-click the track → change to bright red
- Re-add the device
- Left strip in the panel should render red
- Python terminal shows the updated color int
- = **pass**

---

### Test 4 — Hot-rename updates panel without reload

- With the device loaded, rename the track while Ableton is running
- Panel should update within ~1 second automatically
- Python terminal shows the new name
- No device reload required = **pass**

---

### Test 5 — Category keywords

Rename the track to each of the following and re-add the device:

| Track name | Expected category |
|---|---|
| `Pad Lead` | `pad` |
| `Vocal Chop` | `vocal` |
| `Kick 808` | `kick` |
| `Bus Group 1` | `unknown` |

All four correct in the panel and Python terminal = **pass**

> To add keywords: edit `KEYWORD_MAP` in `spoke_identity.js` and save. `autowatch = 1` reloads it immediately.

---

### Test 6 — Python ack returns to Max

- With the device loaded and Python running
- Max Console should show a `python_ack` line alongside each `spoke_meta` line:
  ```
  python_ack: { type: 'ack', spoke: 'Kick Drum', registered: 1 }
  ```
- = **pass**

---

### Test 7 — Bridge reconnects when Python restarts

- Stop the Python server (`Ctrl+C`)
- Max Console should show: `bridge: disconnected — retrying in 2000ms`
- Restart `python server.py`
- Max Console should show: `bridge: connected to Python server at ws://localhost:8765`
- Re-add the device — Python receives it normally
- = **pass**

---

## Phase 1 Test Checklist

```
[ ] Visual panel renders color swatch, track name, and category on load
[ ] Panel shows correct name after track rename + device reload
[ ] Color swatch matches the Ableton track color swatch
[ ] Hot-rename updates the panel automatically without reloading
[ ] Known keywords return the correct category in the panel
[ ] Unrecognized name shows category: unknown
[ ] Python terminal receives and logs each registration
[ ] python_ack appears in Max Console for each registration
[ ] Bridge reconnects automatically when Python server restarts
```

All nine green → **Phase 1 complete. Safe to start [Phase 2](./phase-2-bridge-layer.md).**

---

## Interface contract (frozen for Phase 2+)

```js
// TrackMeta — output of spoke_identity.js, received by Python as msg.payload
{
  name: string,     // e.g. "Kick Drum"
  color: number,    // Ableton RGB int, e.g. 16711680
  category: string  // e.g. "kick" | "vocal" | "unknown"
}
```

```python
# WebSocket message shape — bridge.js → server.py
{
  "type": "meta",
  "payload": TrackMeta
}
```

---

← [Back to README](../README.md)
