# AI Multi-Track Engineer Assistant (M4L)

An Ableton Live toolset that identifies frequency masking across multiple tracks using the Live Object Model (LOM) and provides AI-driven EQ suggestions to improve mix clarity.

---

## Table of Contents

- [Project Overview](#project-overview)
- [System Architecture](#system-architecture)
- [Component Specifications](#component-specifications)
- [Recommended Reference Gear](#recommended-reference-gear)
- [Development Timeline](#development-timeline)

---

## Project Overview

This toolset uses a **Hub & Spoke model** to overcome the isolation of standard DAW tracks:

- **Spoke Device (The Analyzer)** — placed on individual audio tracks; captures spectral data and track metadata
- **Hub Device (The Brain)** — placed on the Master track or a dedicated Mix Bus; aggregates data from all Spokes to perform cross-track analysis

---

## System Architecture

```
Track A ──[Spoke]──┐
Track B ──[Spoke]──┤──► [Hub / Master] ──► AI Engine ──► EQ Suggestions
Track C ──[Spoke]──┘         │
                              └──► Feedback (reduction coefficients) ──► Spokes
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

**Logic:** A JavaScript (Node for Max) script categorizes tracks based on name keywords (e.g., `"Kick"` → `low_frequency_priority`).

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
| Registry | `GlobalMixRegistry` (global `dict`) | Spoke registration and metadata |
| Real-time stream | `s #0_spectral_data` | Per-instance spectral data to Hub |
| Feedback | Hub → Spoke coefficients | Automate EQ reduction curves |

`#0` provides unique instance IDs so multiple Spokes never collide.

---

### D. AI & Logic Engine — The "Decision" Layer

**Runtime:** Node for Max (`n4m`)

| Task | Approach |
|---|---|
| Track classification | Pre-trained TensorFlow.js model (e.g., YAMNet) — confirms if "Vocal" tracks contain vocal energy |
| Masking detection | Spectral Overlap Index algorithm between any two tracks |

**Masking Threshold:** If Track A and Track B overlap > 40% in the 200 Hz–500 Hz range → trigger **"Muddy Mix"** alert.

---

## Recommended Reference Gear

### Intelligent Mixing Plugins

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

**Interface contract defined here:**
```js
// spoke_identity.js — exported shape (frozen for downstream phases)
{
  name: string,
  color: number,   // Ableton RGB int
  category: string // e.g. "kick", "vocal", "unknown"
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

**Interface contract defined here:**
```js
// GlobalMixRegistry entry shape (frozen for downstream phases)
{
  id: string,       // #0 instance ID
  meta: TrackMeta,  // shape from Phase 1
  rms: number,      // 0.0–1.0
  spectral: null    // placeholder, filled in Phase 3
}
```

**Tests:**
- [ ] Hub receives RMS from a single Spoke
- [ ] Hub receives RMS from 4 simultaneous Spokes without collision
- [ ] Spoke deregisters cleanly when its device is deleted (no stale entries)
- [ ] Hub continues functioning if a Spoke is added mid-session
- [ ] Registry survives an Ableton transport stop/start cycle

---

### Phase 3 — Ear Layer (FFT spectral data)

**Goal:** Each Spoke computes a downsampled magnitude array via `pfft~` and transmits it to the Hub through the bridge established in Phase 2.

**Deliverables:**
- `spoke_fft.maxpat` — `pfft~` subpatch producing 128-bin magnitude array
- `downsample.js` — reusable utility: full FFT buffer → N bins
- Hub patch: receives and stores spectral arrays per Spoke

**Interface contract defined here:**
```js
// spectral payload added to registry entry
{
  spectral: Float32Array(128), // magnitude 0.0–1.0 per bin
  binHz: number               // Hz width per bin (depends on sample rate)
}
```

**Tests:**
- [ ] Sine wave at 440 Hz produces a clear peak in the expected bin
- [ ] White noise produces a roughly flat spectrum
- [ ] CPU usage with 8 simultaneous Spokes stays below 10% on target hardware
- [ ] Downsampler is tested independently with known input arrays
- [ ] Hub correctly maps each spectral array to its originating Spoke ID

---

### Phase 4 — Logic Layer (Masking detection)

**Goal:** Node for Max compares spectral arrays from two or more Spokes and emits a masking alert when Spectral Overlap Index exceeds the threshold.

**Deliverables:**
- `masking_engine.js` — pure function `detectMasking(specA, specB, options)` (no Max dependencies, unit-testable in Node)
- `alert_router.js` — maps masking results to UI output and Hub → Spoke feedback coefficients
- Hub patch: wires engine output to console alerts and visual indicators

**Interface contract defined here:**
```js
// detectMasking return shape
{
  overlapIndex: number,    // 0.0–1.0
  conflictBands: [         // bands exceeding threshold
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

**Goal:** Integrate a TensorFlow.js model (YAMNet or equivalent) to validate that tracks tagged "Vocal" actually contain vocal energy, reducing false positives in the masking engine.

**Deliverables:**
- `classifier.js` — wraps TF.js model, exposes `classify(audioBuffer): TrackCategory`
- Spoke patch: runs classifier on load and after significant RMS changes
- Updated `spoke_identity.js`: replaces keyword-only categorization with classifier output

**Extensibility hook defined here:**
- Classifier is injected as a dependency into `spoke_identity.js` — swap models without touching the Spoke patch
- `classify()` returns a confidence score so callers can set their own thresholds

**Tests:**
- [ ] Classifier loads model without blocking Max audio thread
- [ ] Vocal audio clip → `"vocal"` category with confidence > 0.8
- [ ] Drum loop → `"kick"` or `"drums"` category
- [ ] Silence / noise → `"unknown"` with low confidence
- [ ] Masking engine receives updated categories and adjusts thresholds accordingly
- [ ] Full session test: 4 tracks with mixed content, verify zero false-positive alerts

---

### Phase 6 — Feedback Layer (Automated EQ)

**Goal:** Hub sends reduction coefficients back to Spokes; Spokes apply them as automated EQ curves to resolve detected masking.

**Deliverables:**
- `coefficient_calculator.js` — converts `conflictBands` into per-Spoke gain reduction curves
- Spoke patch: receives coefficients and drives a `live.remote~` EQ automation lane
- Hub UI: toggle to enable/disable auto-correction per track pair

**Extensibility hook defined here:**
- Coefficient calculator is a pure function — replaceable with a more sophisticated ML model in a future phase
- Auto-correction is opt-in per track so manual mixing always takes precedence

**Tests:**
- [ ] Coefficient calculator unit tests (known conflict → expected gain curves)
- [ ] EQ dip appears at the correct frequency in Ableton's clip view
- [ ] Disabling auto-correct on Hub immediately stops Spoke EQ changes
- [ ] No coefficient feedback occurs when `alert: false`
- [ ] Full round-trip test: introduce frequency clash → verify automated EQ resolves it

---

### Extensibility Checklist (applies across all phases)

Every component should satisfy these constraints before the phase is considered complete:

- [ ] No hardcoded track counts — all loops operate on dynamic registry entries
- [ ] No hardcoded sample rates or FFT sizes — derived from `live.properties` or constructor arguments
- [ ] Pure logic functions (`masking_engine`, `classifier`, `coefficient_calculator`) have zero Max dependencies and are unit-testable offline
- [ ] All inter-component interfaces are documented as explicit contracts (see each phase above)
- [ ] New Spoke types (MIDI, sidechain, return tracks) can be added by implementing the Phase 1 interface without modifying the Hub
