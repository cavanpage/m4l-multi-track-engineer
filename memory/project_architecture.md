---
name: project_architecture
description: Core architectural decisions for m4l-multi-track-engineer plugin
type: project
---

Hub & Spoke M4L plugin for cross-track frequency masking analysis and AI-driven EQ/send suggestions.

**Why:** Overcome DAW track isolation to enable cross-track spectral analysis with automated correction.

**How to apply:** All suggestions should respect this layered architecture — don't collapse layers or bypass the merge strategy.

## Runtime split (intentional, do not consolidate)

| Layer | Runtime | Why locked here |
|---|---|---|
| LOM reads/writes | Max `js` (ES5) | Only runtime with `LiveAPI` |
| Visual panels | Max `js` (ES5) | Only runtime with `mgraphics` |
| WebSocket bridge | Node for Max (n4m) | Needs npm (`ws` package) |
| Analysis / AI | Python | numpy, librosa, PyTorch ecosystem |

## Key design decisions

- Each Spoke is a **first-class state owner** — owns EQ/effects state AND send levels
- Hub uses a **composable pass pipeline** — Pass 1: masking, Pass 2: send space, Pass N: extensible
- **Merge strategy** per parameter: `relative` (default), `absolute`, `advisory` — Hub never silently overwrites user state
- `pfft~` stays in Max (audio thread, C speed) — Python only receives pre-digested 128-bin float arrays
- Python server runs as a **separate process** — n4m bridge auto-reconnects on restart
- Pure logic functions (masking engine, send analysis, classifier) have **zero Max dependencies** — testable offline

## Phase status
- Phase 1 (Identity): code written, not yet tested in Ableton
- Phases 2–8: designed in README, not yet implemented
