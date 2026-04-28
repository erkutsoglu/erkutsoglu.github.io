# CRT Terminal Experience — Design

**Date:** 2026-04-28
**Status:** Approved (pending implementation plan)
**Owner:** Erkut Süleymanoğlu

## Concept

The site presents itself as an old CRT terminal. Three coordinated effects deliver this:

1. **Boot sequence** — first-visit BBS-style boot before content reveals (power-on)
2. **CRT atmosphere** — whisper-level scanlines and vignette as ambient texture (screen surface)
3. **Glitch typography** — tab-change scramble + ambient wordmark interference (signal noise)

All three serve one frame: an inhabited, slightly broken CRT. Each effect is restrained on its own; the cohesion comes from their sharing a single conceptual world.

---

## 1. Boot Sequence

### Behavior

Runs once per session, gated by `sessionStorage["erkush34.booted"]`. Not seen on subsequent loads in the same tab.

### Phases

| Time     | Content                                                              |
|----------|----------------------------------------------------------------------|
| 0–0.3s   | Black screen, single line top-left: `system: erkush34 v0.2`          |
| 0.3–1.3s | Wordmark `erkush34` reveals via Bayer dither pattern (top→bottom)    |
| 1.3–2.8s | Status lines type sequentially (one every ~280ms)                    |
| 2.8–3.3s | Prompt: `> press [enter] to continue_` (cursor blinks)               |
| 3.3–4.0s | Bayer dither wipe bottom→top reveals the live site                   |

**Total:** ~4 seconds (skipped ~0.5s).

### Status lines

```
> checking memory........... 8mb ok    ← decorative (always ok after 200ms)
> loading projects[N]....... ok        ← real fetch; N from projects/_index.json
> loading bio............... ok        ← real fetch
> loading academics[M]...... ok        ← real fetch; M from content/academics.json
> loading contact........... ok        ← real fetch
```

The `ok` markers on the four real-fetch lines are wired to actual fetch outcomes:

- Each line shows `....` placeholder until its underlying fetch resolves
- On success: `....... ok`
- On failure: `....... fail` (the word `fail` rendered with inverted background — black text on white background within the line, since the palette is B&W)
- Boot proceeds either way (failures don't block; the site uses its existing offline fallback messaging inside each panel)

### Skip

Any `keydown` or `click` during phases 1–4 jumps straight to phase 5 (dither wipe). Wipe itself is not skippable (~700ms).

### Implementation surface

A `<div id="boot">` rendered before main content, position fixed full-viewport, z-index `10001` (above cursor at `10000`). Removed from DOM after wipe completes.

During boot:

- `body` gets class `is-booting`: scroll lock (`overflow: hidden`), custom cursor hidden
- JSON loaders run in parallel; boot reads their state via shared promises

---

## 2. CRT Atmosphere (Whisper)

### Visual recipe

- **Scanlines:** `repeating-linear-gradient(0deg, transparent 0 2px, #000 2px 3px)` overlay, opacity `0.02`
- **Vignette:** `radial-gradient(ellipse at center, transparent 60%, rgba(0,0,0,0.06) 100%)` overlay
- Both fixed, full-viewport, `pointer-events: none`, `z-index: 9998` (just below noise overlay at 9999)
- Existing SVG newsprint noise stays — three textures stack, all whisper-level

### State

Always on after boot. No flicker, no transition triggers. Static ambient layer.

### Reduced motion

CRT layer is non-animated, so it remains active under `prefers-reduced-motion: reduce`. (Only boot and glitch are gated.)

---

## 3. Glitch Typography

### Tab scramble

Trigger: `click` on `.nav button`.

Target: the corresponding panel's `.panel-head h2` (e.g., `selected work`).

Algorithm:

- Total duration: 420ms over 14 ticks (one tick every 30ms)
- On each tick, the heading is rebuilt: each character position either shows its original character (if it has "settled") or a random char from `[A-Z0-9!@#%/\<>+*=]`
- Characters settle progressively left-to-right; for a heading of length L, the character at position `i` settles when `tick >= ceil((i+1) * 14 / L)`. The last character settles on the final tick.
- After the final tick: the original heading is rendered intact.

Suppressed if `prefers-reduced-motion: reduce` — heading swaps directly with no scramble.

### Ambient wordmark glitch

Trigger: `setTimeout` with random delay between 25 000ms and 40 000ms, repeating.

Target: a random character of `erkush34` in `.wordmark`.

Effect:

- Wrap the chosen character in a span with `clip-path: inset(50% 0 0 0)` and `transform: translateX(2.5px)` for 120ms — only the bottom half slices right ("bad signal" frame)
- Restore on next animation frame after 120ms

Suppressed under `prefers-reduced-motion: reduce`.

The wordmark is currently `<h1>erkush34</h1>`; on init, JS splits it into `<span>` per character to enable per-char styling. Visual layout unchanged — spans are inline.

---

## Architecture

Three new functions added to the existing IIFE in `index.html`:

```
initBoot()    — sessionStorage gate, render boot DOM, wire to fetch promises,
                handle skip, run wipe, remove boot DOM
initCRT()     — append scanline + vignette overlay <div>s once
initGlitch()  — splitWordmarkChars(), startAmbientLoop(),
                attachTabScramble() per nav button
```

### Coordination with existing systems

| Existing system           | Interaction                                                        |
|---------------------------|--------------------------------------------------------------------|
| JSON loaders (4)          | Boot reads their promises; loaders themselves unchanged            |
| Custom cursor             | Hidden via `.is-booting` body class during boot                    |
| Scroll-driven hero        | Effectively no-ops during boot (scroll locked); resumes after wipe |
| SVG noise overlay         | Stays; CRT scanlines layer below it                                |
| Sticky bar / hero         | Both hidden under boot div; reappear after wipe                    |

### Z-index map

```
10001  boot screen (during boot only)
10000  custom cursor
 9999  newsprint noise overlay
 9998  CRT scanlines + vignette
   50  top bar (sticky)
    5  hero (sticky)
   —  normal content
```

---

## Edge Cases

- **First-load with slow JSON:** Boot animates through phases on its timer; status lines stay at `....` until their fetch resolves, then flip to `ok`/`fail`. If a fetch takes longer than the boot's natural duration, the boot waits at the prompt phase until all are settled (max 8s ceiling, then proceeds anyway).
- **Fetch failure:** Line shows `fail`; site still loads (existing offline fallback in `loadProjects`/`loadBio`/etc. already shows error states inside panels).
- **`file://` protocol:** All fetches fail; boot completes with all `fail` lines; site shows existing offline fallbacks.
- **Reduced motion:** Boot skipped entirely (sessionStorage marked as if booted), tab scramble disabled, ambient wordmark glitch disabled. Scanlines + vignette + noise remain (static).
- **Page revisit in same tab:** sessionStorage flag set, no boot.
- **Page revisit in new tab/window:** sessionStorage is per-tab — boot plays again. Acceptable.
- **Mobile:** Same boot behavior (decided). Boot renders responsive (single-column status lines, smaller wordmark reveal).

---

## Out of Scope

- Audio (CRT hum, click clacks) — explicitly excluded
- Embedded mini-game (Snake, Pong) — covered as a separate idea (E), not part of this spec
- ASCII MODE toggle (idea C) — separate, not part of this spec
- Hidden terminal / Konami easter egg (idea E) — separate, not part of this spec
- Tab transition CRT flicker — design simplified to no-flicker per "whisper" choice
- Random body-text glyph swaps — explicitly rejected as too distracting

---

## Success Criteria

- First-time visitor sees a memorable, sub-5-second boot that reads as intentional craft, not loading delay
- Return visitor in same tab gets the site immediately
- Ambient CRT texture is visible enough to be felt but never interferes with reading
- Glitch effects feel like character, not bugs — predictable on tab change, surprising-but-rare on the wordmark
- All three effects respect `prefers-reduced-motion`
- No regression in existing scroll, cursor, content-loading behavior
