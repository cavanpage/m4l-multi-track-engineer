# AI Multi-Track Engineer Assistant (M4L)

An Ableton Live toolset that identifies frequency masking and send space conflicts across multiple tracks using the Live Object Model (LOM) and provides AI-driven EQ, effects, and send suggestions to improve mix clarity.

---

## Table of Contents

- [Project Overview](#project-overview)
- [System Architecture](#system-architecture)
- [Component Specifications](#component-specifications)
- [Spoke-Owned State](#spoke-owned-state)
- [Hub Analysis Pipeline](#hub-analysis-pipeline)
- [Recommended Reference Gear](#recommended-reference-gear)
- [Development Timeline](#development-timeline)

---

## Project Overview

This toolset uses a **Hub & Spoke model** to overcome the isolation of standard DAW tracks.

- **Spoke Device (The Analyzer + Controller)** — placed on individual audio tracks; captures spectral data, track metadata, EQ/effects state, and send levels; applies Hub suggestions back to its own chain
- **Hub Device (The Brain)** — placed on the Master track or a dedicated Mix Bus; aggregates state from all Spokes, runs a multi-pass analysis pipeline, and emits per-Spoke correction payloads

Every Spoke is a **first-class state owner**. The Hub never writes blindly to a Spoke — it always works relative to what the Spoke already reports.

---

## System Architecture

```
                        ┌─────────────────────────────────────┐
                        │            HUB (Master)             │
                        │                                     │
Track A ──[Spoke]──────►│  GlobalMixRegistry                  │
Track B ──[Spoke]──────►│    ├─ spectral arrays               │──► Pass 1: Masking Detection
Track C ──[Spoke]──────►│    ├─ EQ / effects state            │──► Pass 2: Send Space Analysis
Track D ──[Spoke]──────►│    └─ send levels                   │──► Pass N: (extensible)
                        │                                     │
Return A ◄──────────────│  Coefficient Payloads               │
Return B ◄──────────────│    ├─ EQ reduction curves           │
                        │    ├─ effects param suggestions      │
                        │    └─ send level adjustments         │
                        └──────────────┬──────────────────────┘
                                       │
                        ┌──────────────▼──────────────────────┐
                        │     Per-Spoke Merge Layer           │
                        │  Hub suggestion + user state        │
                        │  → final applied value              │
                        └─────────────────────────────────────┘
```

---

## Component Specifications

### A. Metadata Extraction — The "Identity" Layer

Each Spoke automatically identifies its context to minimize manual user tagging.

| Property | Value |
|---|---|
| API Path | `live.path this_device canonical_parent` |
| Collected: name | `string` |
| Collected: color | `int` / RGB |

**Logic:** A JavaScript (Node for Max) script categorizes tracks based on name keywords (e.g., `"Kick"` → `low_frequency_priority`), later upgraded with AI classification in Phase 5.

---

### B. Spectral Analysis — The "Ear" Layer

| Parameter | Value | Rationale |
|---|---|---|
| Engine | `pfft~` (Phase Vocoder FFT) | Native Max object, low overhead |
| Window Size | 1024 or 2048 samples | Balances frequency resolution vs. latency |
| Data Reduction | 128 or 256 bins | Minimizes inter-device communication cost |

Raw magnitude buffers are downsampled before transmission to the Hub.

---

### C. Inter-Device Communication — The "Bridge" Layer

| Channel | Mechanism | Purpose |
|---|---|---|
| Registry | `GlobalMixRegistry` (global `dict`) | Spoke registration, metadata, and full state |
| Real-time stream | `s #0_spectral_data` | Per-instance spectral data to Hub |
| Feedback | Hub → Spoke coefficient payloads | EQ curves, effects params, send adjustments |

`#0` provides unique instance IDs so multiple Spokes never collide.

---

### D. AI & Logic Engine — The "Decision" Layer

**Runtime:** Node for Max (`n4m`)

| Task | Approach |
|---|---|
| Track classification | Pre-trained TensorFlow.js model (e.g., YAMNet) |
| Masking detection | Spectral Overlap Index between any two tracks |
| Send space analysis | Cross-track return bus load aggregation |

**Masking Threshold:** If Track A and Track B overlap > 40% in the 200 Hz–500 Hz range → trigger **"Muddy Mix"** alert.

**Send Threshold:** If cumulative send load to a single Return exceeds a configurable ceiling → trigger **"Crowded Return"** alert.

---

## Spoke-Owned State

Each Spoke owns, reports, and applies changes to three categories of state. The Hub never overwrites — it always works *relative* to what the Spoke currently reports.

### 1. EQ / Effects Chain

Each Spoke hosts its own EQ and effects parameters, read from and written to `live.remote~` / `live.object` bindings within the Spoke patch itself.

```js
// Spoke effects state shape (reported to Hub)
{
  eq: {
    bands: [
      { freq: number, gain: number, q: number, type: string }
    ]
  },
  effects: [
    { type: string, params: { [key: string]: number } }
  ]
}
```

### 2. Send Levels

Each Spoke reads its send knob values from the LOM and includes them in its registry entry.

```js
// LOM path
live_set tracks N mixer_device sends

// Spoke sends state shape (reported to Hub)
{
  sends: {
    [returnId: string]: {
      level: number,      // 0.0–1.0 current value
      returnName: string  // e.g. "Reverb A", "Delay B"
    }
  }
}
```

### 3. Merge Strategy

When the Hub sends a coefficient payload, the Spoke applies a **merge** rather than an override:

| Mode | Behavior |
|---|---|
| `relative` | Hub suggestion is added to the user's current value (default) |
| `absolute` | Hub suggestion replaces the current value (opt-in per parameter) |
| `advisory` | Hub suggestion is displayed in the UI only — no automation applied |

Merge mode is configurable per parameter type and per Spoke instance.

---

## Hub Analysis Pipeline

The Hub runs a **chain of composable analysis passes** over the shared registry. Each pass is an independent module that reads from the registry and emits suggestions — new passes plug in without touching existing ones.

```
Registry Snapshot
      │
      ▼
┌─────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Pass 1     │────►│  Pass 2          │────►│  Pass N          │
│  Masking    │     │  Send Space      │     │  (extensible)    │
│  Detection  │     │  Analysis        │     │                  │
└─────────────┘     └──────────────────┘     └──────────────────┘
      │                     │                        │
      └─────────────────────┴────────────────────────┘
                            │
                   Coefficient Aggregator
                            │
                  Per-Spoke Payloads emitted
```

### Pass 1 — Masking Detection

Compares spectral arrays pairwise. Emits EQ reduction curves targeting conflict bands.

### Pass 2 — Send Space Analysis

Aggregates send levels across all Spokes per Return track. Emits send level adjustments when a Return is overloaded, distributing reduction proportionally by track category priority.

### Adding a New Pass

Implement the pass interface and register it with the Hub — no other code changes required:

```js
// Pass interface contract
{
  name: string,
  analyze(registry: RegistrySnapshot): PassResult[],
}

// PassResult shape
{
  spokeId: string,
  suggestions: { [paramPath: string]: { value: number, mode: MergeMode } }
}
```

---

## Recommended Reference Gear

- **iZotope Mix & Master Bundle Advanced** — primary inspiration for inter-plugin communication; "Tonal Balance Control" uses a global listener to compare mixes against target curves
- **Sonible pure:unmask** — reference for side-chain intelligence; carves spectral space for a lead element by analyzing clash with a background element in real time

---

## Development Timeline

Each phase is self-contained and testable before the next begins. Interfaces between components are defined at the start of each phase to enforce modularity.

---

### Phase 1 — Identity Layer (Spoke Metadata)

**Goal:** A Spoke device reads its own track name and color from the LOM and logs them to the Max Console.

**Deliverables:**
- `spoke_identity.js` — Node for Max script exposing a `getTrackMeta()` function
- Max patch wiring `live.path` → JS → `print`

**Interface contract (frozen for downstream phases):**
```js
// TrackMeta shape
{
  name: string,
  color: number,    // Ableton RGB int
  category: string  // e.g. "kick", "vocal", "unknown"
}
```

**Tests:**
- [ ] Patch loads without errors on a fresh Ableton set
- [ ] Console prints correct name when device is on a renamed track
- [ ] Color int matches the track color swatch visually
- [ ] `category` field updates when track is renamed (hot-rename test)
- [ ] Keyword categorization returns `"unknown"` gracefully for unrecognized names

---

### Phase 2 — Bridge Layer (Spoke → Hub messaging)

**Goal:** Pass a single float (RMS level) from a Spoke on any track to a Hub on the Master, using `GlobalMixRegistry`.

**Deliverables:**
- `registry.js` — manages read/write to the shared `dict`
- Spoke patch: registers on load, writes RMS on each audio tick
- Hub patch: reads registry, prints all Spoke RMS values

**Interface contract (frozen for downstream phases):**
```js
// RegistryEntry shape — placeholders added now, filled in later phases
{
  id: string,          // #0 instance ID
  meta: TrackMeta,     // from Phase 1
  rms: number,         // 0.0–1.0
  spectral: null,      // filled Phase 3
  effects: null,       // filled Phase 6
  sends: null          // filled Phase 7
}
```

**Tests:**
- [ ] Hub receives RMS from a single Spoke
- [ ] Hub receives RMS from 4 simultaneous Spokes without collision
- [ ] Spoke deregisters cleanly when device is deleted (no stale entries)
- [ ] Hub continues functioning if a Spoke is added mid-session
- [ ] Registry survives a transport stop/start cycle

---

### Phase 3 — Ear Layer (FFT spectral data)

**Goal:** Each Spoke computes a downsampled magnitude array via `pfft~` and transmits it to the Hub.

**Deliverables:**
- `spoke_fft.maxpat` — `pfft~` subpatch producing 128-bin magnitude array
- `downsample.js` — reusable utility: full FFT buffer → N bins
- Hub patch: receives and stores spectral arrays per Spoke

**Interface contract:**
```js
// Spectral payload added to RegistryEntry
{
  spectral: Float32Array(128), // magnitude 0.0–1.0 per bin
  binHz: number                // Hz width per bin (sample-rate derived)
}
```

**Tests:**
- [ ] Sine wave at 440 Hz produces a clear peak in the expected bin
- [ ] White noise produces a roughly flat spectrum
- [ ] CPU usage with 8 simultaneous Spokes stays below 10% on target hardware
- [ ] Downsampler unit-tested independently with known input arrays
- [ ] Hub correctly maps each spectral array to its originating Spoke ID

---

### Phase 4 — Logic Layer (Masking detection — Pass 1)

**Goal:** Node for Max compares spectral arrays from two or more Spokes and emits masking alerts when Spectral Overlap Index exceeds threshold.

**Deliverables:**
- `masking_engine.js` — pure function `detectMasking(specA, specB, options)` (no Max dependencies)
- `alert_router.js` — maps engine output to Hub UI
- Hub patch: wires Pass 1 into the analysis pipeline

**Interface contract:**
```js
// detectMasking return shape
{
  overlapIndex: number,
  conflictBands: [
    { freqLow: number, freqHigh: number, severity: number }
  ],
  alert: boolean
}
```

**Tests:**
- [ ] `detectMasking` unit tests run in plain Node (no Ableton required)
- [ ] Two identical sine arrays → `overlapIndex` = 1.0
- [ ] Two non-overlapping arrays → `overlapIndex` ≈ 0.0
- [ ] 200–500 Hz overlap > 40% triggers `alert: true`
- [ ] Results are deterministic (same inputs → same output every run)
- [ ] Hub alerts fire in real time with a 2-track live session

---

### Phase 5 — Decision Layer (AI classification)

**Goal:** Integrate a TensorFlow.js model to validate track categories, reducing false positives in the masking engine.

**Deliverables:**
- `classifier.js` — wraps TF.js model, exposes `classify(audioBuffer): { category, confidence }`
- Spoke patch: runs classifier on load and after significant RMS changes
- Updated `spoke_identity.js`: classifier result replaces keyword-only categorization

**Extensibility hook:**
- Classifier injected as a dependency — swap models without touching the Spoke patch
- `confidence` score exposed so each pass can set its own threshold independently

**Tests:**
- [ ] Classifier loads without blocking the Max audio thread
- [ ] Vocal clip → `"vocal"` with confidence > 0.8
- [ ] Drum loop → `"kick"` or `"drums"`
- [ ] Silence → `"unknown"` with low confidence
- [ ] Masking engine adjusts thresholds when category changes
- [ ] 4-track session: zero false-positive masking alerts

---

### Phase 6 — Spoke Effects Layer (per-device EQ & effects ownership)

**Goal:** Each Spoke reads and owns its EQ and effects parameters. The Hub suggests changes; the Spoke applies them through a merge layer that always respects the user's current state.

**Deliverables:**
- `spoke_effects.js` — reads current EQ/effects state via `live.object`; exposes `getEffectsState()` and `applyCoefficients(payload, mergeMode)`
- `merge.js` — reusable utility implementing `relative`, `absolute`, and `advisory` merge modes
- Spoke patch: populates `effects` field in registry on each update tick
- Hub Pass 1 updated: masking output now includes EQ curve suggestions, not just alerts

**Interface contract:**
```js
// EffectsState shape (added to RegistryEntry)
{
  eq: {
    bands: [{ freq: number, gain: number, q: number, type: string }]
  },
  effects: [
    { type: string, params: { [key: string]: number } }
  ]
}

// Coefficient payload shape (Hub → Spoke)
{
  spokeId: string,
  suggestions: {
    [paramPath: string]: { value: number, mode: "relative" | "absolute" | "advisory" }
  }
}
```

**Tests:**
- [ ] `getEffectsState()` returns correct values for a device with a known EQ setting
- [ ] `merge.js` unit tests for all three merge modes with known inputs
- [ ] Hub suggestion in `relative` mode adds to — not replaces — the user's current gain
- [ ] `advisory` mode updates UI display but writes nothing to Ableton parameters
- [ ] EQ state in registry updates live as the user adjusts knobs
- [ ] Full round-trip: introduce frequency clash → Hub suggests EQ → Spoke applies via `relative` merge → clash resolved

---

### Phase 7 — Send Layer (per-device send ownership + Pass 2)

**Goal:** Each Spoke reads and reports its send levels. The Hub's Pass 2 analyzes cross-track send load on each Return and emits send adjustment suggestions.

**Deliverables:**
- `spoke_sends.js` — reads `live_set tracks N mixer_device sends` for all Return tracks; exposes `getSendsState()` and integrates with `applyCoefficients()` from Phase 6
- `send_analysis.js` — pure function `analyzeSends(registry, options)` (no Max dependencies); implements Pass 2
- Hub patch: registers Pass 2 in the analysis pipeline after Pass 1
- Return track names included in registry for human-readable alerts

**Interface contract:**
```js
// SendsState shape (added to RegistryEntry)
{
  sends: {
    [returnId: string]: {
      level: number,       // 0.0–1.0 current value
      returnName: string   // e.g. "Reverb A"
    }
  }
}

// analyzeSends return shape (Pass 2 result)
{
  returnId: string,
  totalLoad: number,       // sum of all Spoke send levels to this Return
  alert: boolean,
  suggestions: [
    { spokeId: string, adjustedLevel: number, mode: MergeMode }
  ]
}
```

**Tests:**
- [ ] `getSendsState()` returns correct levels matching Ableton's send knobs
- [ ] `analyzeSends` unit tests run in plain Node (no Ableton required)
- [ ] All Spokes at max send to a single Return → `alert: true`
- [ ] Suggestions distribute reduction proportionally by `category` priority
- [ ] Send adjustments applied via `relative` merge — user's baseline preserved
- [ ] Pass 2 runs independently of Pass 1 (disable masking, sends still analyzed)
- [ ] Full session: 6 tracks with varied reverb sends → Hub redistributes without user touching knobs

---

### Phase 8 — Hub UI & User Controls

**Goal:** Surface analysis results and per-Spoke suggestions in a coherent UI. Give the user controls to accept, reject, or tune suggestions globally and per-track.

**Deliverables:**
- Hub UI patch: per-Return load meters, per-Spoke masking indicators, global merge mode selector
- Spoke UI patch: active suggestions display, current merge mode, per-parameter override controls
- `preferences.js` — persists merge mode and threshold settings to `live.object` storage

**Tests:**
- [ ] UI updates in real time as spectral data changes
- [ ] Global merge mode change propagates to all active Spokes
- [ ] Per-Spoke merge mode override survives session save/reload
- [ ] Disabling a pass in Hub UI stops that pass's suggestions without affecting others
- [ ] No UI writes cause audio glitches (all parameter writes deferred off audio thread)

---

### Extensibility Checklist (applies across all phases)

Every component must satisfy these constraints before its phase is considered complete:

- [ ] No hardcoded track counts — all loops operate on dynamic registry entries
- [ ] No hardcoded sample rates or FFT sizes — derived from `live.properties` or constructor arguments
- [ ] No hardcoded Return track count — sends state built dynamically from LOM query
- [ ] Pure logic functions (`masking_engine`, `send_analysis`, `classifier`, `merge`) have zero Max dependencies and are unit-testable offline
- [ ] All inter-component interfaces are documented as explicit contracts (see each phase above)
- [ ] Hub analysis passes registered dynamically — a new pass requires no changes to existing passes or the Hub patch
- [ ] New Spoke state categories (e.g., MIDI velocity, sidechain input) can be added by extending `RegistryEntry` and implementing a new pass — no Hub or Spoke core changes required
- [ ] Merge mode configurable per parameter, per Spoke — Hub suggestions never silently override user intent
