# Phase 1 — Identity Layer: Build & Test Guide

**Goal:** Each Spoke device reads its own track name and color from the LOM, renders a visual panel, and registers itself with the Python server. The Hub device auto-launches and manages the Python server binary — no manual Python required.

**Prerequisites:**
- Ableton Live 11+ with Max for Live
- Node.js 18+ (for n4m in Hub)
- Python 3.11+ (build-time only — end users do not need Python)

**Source files:**

| File | Role |
|---|---|
| [`src/spoke/spoke_identity.js`](../src/spoke/spoke_identity.js) | LOM reads via LiveAPI |
| [`src/spoke/spoke_ui.js`](../src/spoke/spoke_ui.js) | jsui visual panel |
| [`src/spoke/spoke_identity.maxpat`](../src/spoke/spoke_identity.maxpat) | Spoke Max patch |
| [`src/hub/hub_launcher.js`](../src/hub/hub_launcher.js) | n4m binary lifecycle manager |
| [`src/hub/hub.maxpat`](../src/hub/hub.maxpat) | Hub Max patch (place on Master) |
| [`src/python/server.py`](../src/python/server.py) | Python OSC/UDP server |
| [`src/python/requirements.txt`](../src/python/requirements.txt) | Python dependencies |
| [`build.sh`](../build.sh) | Compiles server.py → standalone binary |

---

## Signal flow

```
HUB (Master track)
  [live.thisdevice] ──load──► [start] ──► [node.script hub_launcher.js]
                    ──free──► [stop]  ──►        │
                                          spawns spoke_server binary
                                          (no Python install needed by user)

SPOKE (any audio track)
  [live.thisdevice] → bang on load
          │
  [js spoke_identity.js] ← reads LOM via LiveAPI (name, color, category)
          │                  watches track name for live renames
          ├──[prepend parse]──────► [jsui spoke_ui.js]        visual panel
          ├──[prepend /spoke/meta]─► [udpsend 127.0.0.1 8765] → binary
          └──[print spoke_meta]                                Max Console debug

  [udpreceive 8766] ──► [print python_ack]   ← acks from binary
```

No npm. No manual Python. Hub auto-starts the binary; Spoke communicates via native `udpsend`/`udpreceive`.

---

## Why two JS environments?

| Object | Environment | Why |
|---|---|---|
| `js spoke_identity.js` | Max `js` (ES5) | Only environment with native `LiveAPI` for LOM access |
| `jsui spoke_ui.js` | Max `js` (ES5) | Only environment with `mgraphics` for drawing in a device panel |

n4m is not needed until Phase 4 when TensorFlow.js requires npm packages.

---

## Step 1: Set up the Python environment (build-time only)

```bash
# Run once from the repo root
python3 -m venv .venv
source .venv/bin/activate
pip install -r src/python/requirements.txt
```

---

## Step 2: Build the server binary

```bash
./build.sh
```

Output: `src/hub/spoke_server`

This is the file that ships with the plugin. End users never need Python installed.

---

## Step 3: Load the devices into Ableton

1. Create a new **Audio Track** and rename it `Kick Drum`
2. Create a **Master** or dedicated **Mix Bus** track
3. In the Ableton browser, navigate to `src/hub/` → drag `hub.maxpat` onto the Master track → save as `hub.amxd`
4. Navigate to `src/spoke/` → drag `spoke_identity.maxpat` onto the Kick Drum track → save as `spoke_identity.amxd`
5. Open the Max Console: **Window → Max Console** (`Cmd+Shift+M`)

---

## Step 4: Run the tests

### Test 1 — Device loads, visual panel appears

- Re-drag the Spoke device onto the track
- The device panel should show:
  ```
  ████ Kick Drum
       kick
  ```
  (colored swatch on the left, track name, category badge)
- Max Console prints: `spoke_meta: {"name":"Kick Drum","color":...,"category":"kick"}`
- Max Console prints: `[python] [spoke]  Kick Drum           category=kick ...`
- = **pass**

---

### Test 2 — Correct name on renamed track

- Rename the track to `Snare Top`, delete and re-add the Spoke device
- Panel updates to show `Snare Top` / `snare`
- Max Console shows `[python] [spoke]  Snare Top ...`
- = **pass**

---

### Test 3 — Color swatch matches track color

- Right-click the track → change to bright red
- Re-add the Spoke device
- Left strip in the panel renders red
- Max Console shows updated color int in `[python]` line
- = **pass**

---

### Test 4 — Hot-rename updates panel without reload

- With the Spoke device loaded, rename the track while Ableton is running
- Panel should update within ~1 second automatically
- Max Console shows new name in `[python]` line
- No device reload required = **pass**

---

### Test 5 — Category keywords

Rename the track to each of the following and re-add the Spoke device:

| Track name | Expected category |
|---|---|
| `Pad Lead` | `pad` |
| `Vocal Chop` | `vocal` |
| `Kick 808` | `kick` |
| `Bus Group 1` | `unknown` |

All four correct in both the panel and the `[python]` Max Console line = **pass**

> To add keywords: edit `KEYWORD_MAP` in `spoke_identity.js` and save. `autowatch = 1` reloads it immediately.

---

### Test 6 — Ack returns from binary to Max

- With Hub and Spoke loaded, Max Console should show a `python_ack` line for each registration:
  ```
  python_ack: /ack {"spoke": "Kick Drum", "registered": 1}
  ```
- = **pass**

---

## Phase 1 Test Checklist

**Identity (Spoke):**
```
[ ] Visual panel renders color swatch, track name, and category on load
[ ] Panel shows correct name after track rename + device reload
[ ] Color swatch matches the Ableton track color swatch
[ ] Hot-rename updates the panel automatically without reloading
[ ] Known keywords return the correct category in the panel
[ ] Unrecognized name shows category: unknown
```

**Communication:**
```
[ ] python_ack appears in Max Console for each Spoke registration
[ ] Ack includes correct spoke name and registered count
```

**Packaging (as shipped):**
```
[ ] build.sh runs without errors and produces src/hub/spoke_server
[ ] Hub device loaded → Max Console shows "hub_launcher: running" (no terminal open)
[ ] Spoke registers successfully with the auto-launched binary
[ ] Hub device removed → Max Console shows "hub_launcher: stopped"
[ ] Binary re-launched after Hub device is re-added to the session
[ ] No Python installation on PATH required for any of the above
```

All thirteen green → **Phase 1 complete. Safe to start [Phase 2](./phase-2-bridge-layer.md).**

---

## Interface contract (frozen for Phase 2+)

```js
// TrackMeta — output of spoke_identity.js outlet 0 (JSON symbol)
{
  name: string,     // e.g. "Kick Drum"
  color: number,    // Ableton RGB int, e.g. 16711680
  category: string  // e.g. "kick" | "vocal" | "unknown"
}
```

```
// OSC message — udpsend → server.py
address:  /spoke/meta
argument: TrackMeta as JSON string

// OSC ack — server.py → udpreceive
address:  /ack
argument: {"spoke": string, "registered": number}
```

---

← [Back to README](../README.md)
