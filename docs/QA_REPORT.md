# Doodle Rescue 3D — QA report

Date: 2026-11-09
Engine: Godot 4.7.2 stable (Compatibility renderer, no threads)
Report scope: the 0.2.0 build committed for the Little Joy Arcade launch.

This report separates what was **executed** from what was **not tested**.
Every win below came from the shipping physics, not a scripted success.

---

## 1. Level data and solvability

`godot --headless --path . Scenes/Tests.tscn` builds all 20 levels, validates
their data, draws each stored solution through the real `BeamBuilder`, starts
the real simulation and requires `phase == "won"` before the test process exits
zero.

Result: **20/20 won, ALL TESTS PASSED (21 levels simulated)**. The extra run is
the structural doorway test below.

| # | Level | Mode | Result | Time | Pen used |
|---|---|---|---|---|---|
| 1 | The Round Doorway | Bee | WON | 10.0 s | 3.2 / 5.2 m |
| 2 | Two Little Hives | Bee | WON | 10.0 s | 3.4 / 5.6 m |
| 3 | The Side Door | Bee | WON | 10.0 s | 2.9 / 4.4 m |
| 4 | High Hive, Low Ink | Bee | WON | 10.0 s | 3.1 / 4.6 m |
| 5 | Three Ways In | Bee | WON | 10.0 s | 3.8 / 6.2 m |
| 6 | First Crossing | Bridge | WON | 5.4 s | 6.8 / 9.5 m |
| 7 | Down the Rapids | Bridge | WON | 5.6 s | 7.7 / 11.0 m |
| 8 | Narrow Ledges | Bridge | WON | 5.8 s | 7.8 / 12.0 m |
| 9 | Up and Over | Bridge | WON | 5.8 s | 7.5 / 10.5 m |
| 10 | The Last Plank | Bridge | WON | 5.4 s | 7.0 / 8.8 m |
| 11 | Rolling Rock | Dodge | WON | 8.0 s | 3.0 / 8.0 m |
| 12 | Crate Rain | Dodge | WON | 8.0 s | 4.0 / 9.0 m |
| 13 | Two Boulders | Dodge | WON | 9.0 s | 10.2 / 12.0 m |
| 14 | The Chute | Dodge | WON | 8.0 s | 2.9 / 7.5 m |
| 15 | Pinball Alley | Dodge | WON | 9.0 s | 8.8 / 12.0 m |
| 16 | Ball in the Box | Contraption | WON | 1.5 s | 7.0 / 10.0 m |
| 17 | Bounce Bucket | Contraption | WON | 1.5 s | 4.4 / 9.0 m |
| 18 | Over the Wall | Contraption | WON | 1.7 s | 6.2 / 11.0 m |
| 19 | The Basket | Contraption | WON | 1.5 s | 6.6 / 10.0 m |
| 20 | Wonder Workshop | Contraption | WON | 1.6 s | 6.7 / 11.0 m |

The levels are checked as a set too: 20 levels, 4 worlds, ids 1–20, unique
titles, valid modes, every solution inside its drawing bounds and budget, and
every mode's required data present (`hives` and a round `door`, `bridge`,
`hazards`, `target`).

### The structural doorway

The suite also builds level 1 with a deliberate loose doodle — a small stroke in
the middle of the opening that never touches the frame — and runs the bees.
Result: **PASS, shoved after 163 frames**, phase `lost`. The doodle becomes a
full plug, the swarm pushes it, it shakes out, and the bees reach Biscuit. This
is the exact behaviour that makes a floating doodle different from a wedged one,
tested against the shipping code.

### Bugs found and fixed during validation

- **Bridge walker fell off every long deck.** Biscuit walked at z = 0.4 on a
  0.64 m-deep plank. The step-hop nudged him sideways and he slid off. He is now
  centred on the deck and his depth is locked; levels 6–10 all pass.
- **Bounce Bucket ball rolled the wrong way.** It spawned on the ramp's rounded
  tip. A 1 m/s nudge onto the slope sends it down the ramp into the basket.
- **Win card only opened when a trophy unlocked.** The result card and star
  animation were inside the achievement branch. They now open on every win.
- **Camera aim error on first frame.** `look_at` ran before the camera entered
  the tree. Reordered, and the browser console is clean.
- **Bee shelters were invincible.** Any scribble that crossed the flight lane
  stopped every bee because drawn beams were static and bees gave up on
  contact. Bee Defence now has a kennel with a round doorway; only a doodle
  that catches the wide frame in two places is secure.
- **A line across a round hole did not seal it, and the kennel roof blocked the
  swarm before the doorway.** A doodle at the doorway now fills the opening
  with a plug disc, and the roof was moved behind the flight lane.

---

## 2. Exported browser build

Command chain: import → `--export-release "Web"` → `Tools/patch_web.py`.
Output: `index.wasm` 37.7 MiB, `index.pck` 0.86 MiB, no threads.

`Tools/smoke.mjs` in Playwright Chromium, 390×844 phone viewport, real pointer
input on the canvas:

- Canvas fills the window exactly (390×844; desktop 1280×800).
- Title boots, 20 levels loaded, arcade bridge and client both present.
- Level 1 starts in `bee` draw mode with the 5.2 m budget and the doorway
  **OPEN**.
- A real mouse drag along the projected solution built **3.21 m** of beam and
  snapped both ends to the doorway frame.
- Play started the simulation and the level **won with three stars**.
- Journey map opened; desktop canvas fills 1280×800.
- **No page errors or console errors.**
- Screenshots: `/tmp/doodle-shots/{loading,title,draw,stroke,win,worlds,desktop}.png`.

The 0.2.0 build was deployed to
<https://jd4rider.github.io/doodle-rescue-3d/> (GitHub Pages, `gh-pages`
branch). The public URL returned **200**, and the smoke test was repeated
against it: a real **3.21 m** drag, Play, **won with three stars**, journey map,
desktop layout, **zero console errors**. The game state reported the new
`budget = 5.2` and `door = open`, confirming the new build rather than the
cached 0.1.0. The loading overlay still shows the pencil, "Loading Doodle
Rescue 3D…" and a centred progress bar (the first version hid the progress bar
and looked blank for several seconds — fixed and redeployed).

Frame rate, measured from the game's own `Engine.get_frames_per_second()` in
headed Chrome (hardware GPU), median of five one-second samples:

| View | Median |
|---|---|
| Phone, Bee Defence draw | 55 fps |
| Phone, Bridge draw | 60 fps |
| Desktop, Bee Defence draw | 49 fps |
| Desktop, title (first samples) | 2 fps cold → 48 fps after warm-up |

**Honest reading:** in-level performance is smooth on the phone viewport and
playable at 46–58 fps at 1280×800 after warm-up on this machine. The first
seconds of a cold load are dominated by shader compilation (1–2 fps), which is
why the loader has a visible progress bar and message. Desktop 60 fps in the
bee level is not demonstrated; 46–58 fps is what was measured. Headless
Chromium uses software rendering and runs the 10 s level timer at roughly half
real time, so it is suitable for correctness only, not performance.

---

## 3. Arcade catalogue and database

- `src/data/games.ts` contains the hand-written Doodle Rescue 3D entry, and
  `supabase/migrations/0019_doodle_rescue_3d.sql` is the reproducible schema
  seed for a fresh database.
- The littlejoyarcade CI and Pages workflows completed successfully; the
  deployed bundle at <https://littlejoyarcade.site/> contains
  "Doodle Rescue 3D".
- The live Supabase row was upserted through the service-role REST path:
  `status = live`, `version = 0.2.0`, `sort_order = 16`, play URL pointing at
  the Pages build. Verified by reading the row back.
- **18 achievements** (`doodle-rescue-3d.first_rescue` … `.pens_all`) were
  inserted and counted back from `public.achievements`.

---

## 4. What was not verified

- **300 levels are not in this build.** 20 hand-built levels are committed and
  all 20 were replayed by the physics. The remaining 280 were not generated,
  and inventing unvalidated layouts was deliberately avoided.
- **No ads and no purchases.** No ad provider is configured;
  `DoodleRescue.adsAllowed()` returns `false`. There is no rewarded-ad button
  and therefore no ad-removal entitlement to test.
- **No Blender assets.** All models are procedural GDScript meshes.
- **One drawing plane** (z = 0). Depth- and surface-constrained drawing are not
  implemented; structures still have real 3D volume and collision.
- **Loose plugs are shoved with a hand-authored shake-and-slide**, not a
  rigid-body simulation of the whole plug; the doodle is a real collider while
  it holds.
- **Physical iOS/Android devices were not exercised.** Chromium at phone and
  desktop sizes is the only browser tested. Safari and Android Chrome use the
  same WebGL 2 path but were not run here.
- **Cloud save round-trip** was not tested with a signed-in real account; the
  local save path is exercised by the game, and the JS bridge is present and
  guarded.
- **Sound** is synthesised and wired, but was not audited on device speakers.

---

## 5. Reproduce

```bash
cd doodle-rescue-3d
godot --headless --path . Scenes/Tests.tscn          # ~3 min, 20/20 + loose plug
godot --headless --path . --export-release "Web" web/play/index.html
python3 Tools/patch_web.py
python3 -m http.server 4291 --directory web/play
node Tools/smoke.mjs http://127.0.0.1:4291/
node Tools/perf.mjs http://127.0.0.1:4291/ --headed
```
