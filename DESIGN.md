# Sailor Man — Game Design Document

> Hand-off document for the implementation session. It fixes the concept, the
> rules, the architecture and the order of work. Numbers marked *(tune)* are
> starting points, not contracts. Read the repository's `AGENTS.md` first — the
> framework/game boundary there overrides anything here that seems to conflict.
> Cultural statements marked *(verify)* must be checked with a practising
> salomero/salomera before they reach player-facing copy (§12).

| | |
| --- | --- |
| Game ID | `sailor_man` |
| Title | Sailor Man *(confirmed by the owner)* |
| Folder | `godot-base/games/sailor_man/` (initialized Git submodule) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Players | Solo vs CPU crews; two-human hot-seat duel (`max_local_players = 2`) |
| Menu order | `10` (after Dolce's Adventure's `9`) |
| Feature tag | `sailor_man` |
| Input reference | `games/dead_metal_jam/input/` (microphone + pitch detection) |
| Look-and-feel reference | `games/chicken_pit/` (3D world in a `SubViewport` under the 2D shell) |
| Renderer | `gl_compatibility` — unchanged |

**Current delivery:** a complete grey-box best-of-three duel against one
explicitly synthetic practice skiff, with judges, an isolated 3D lock,
opt-in microphone input and Remo. Practice retains the full scorer workbench.
The source manifest exposes this single-player prototype, not the target
campaign or multiplayer described below. English-first
copy keeps Spanish saloma terms; v1 hot seat is two humans, and grito stays
within Remate. No performer recordings or cultural partner are available yet,
so Milestone 1's authentic-recording exit remains unverified. The owner
authorized continuing with Remo and the grey-box duel assuming validation works,
not as a claim that recordings or review were completed. See `README.md` for
what actually runs and `TODO.md` for verified progress.

---

## 1. Concept

The **saloma** is a traditional Panamanian vocal call from the rural interior,
especially the Azuero peninsula. It is a long, carrying cry that breaks between
chest voice and falsetto. Farm workers have used it to call across fields, to
keep rhythm while working and to express joy or sorrow. The verb is **salomar**.
Its shorter, sharper relative is the **grito**. At festivals, singers trade gritos
and salomas in **contrapunto**, a call-and-response duel judged by the crowd and
a panel. *(verify wording, regional terms and festival names)*

**Sailor Man** takes that contest down the **Panama Canal**. You captain a
small boat from Azuero on its way to the great saloma festival on the Pacific
shore. The canal is crowded with other crews: fishermen, tug crews, a tourist
ship and a container ship whose crew has just learned what a quiebre is. Each
crew challenges you as it passes or waits beside you in a lock chamber. You
win each duel by answering their saloma with your own, out loud into a
microphone or with buttons. Win, and they let you go first. Win through every
lock and you reach the Pacific and the champion.

The title is a pun: *salo-**mar*** — *mar* is "sea" — and
"Sailor Man" sounds close to *salomar* when said aloud.

### Locked pillars

1. **Your real voice is the controller.** The microphone path is the headline
   and the scoring is designed around what a saloma actually is: breath, the
   break, the glide and the finish. It is not a volume meter.
2. **Nobody is excluded.** Every duel is fully winnable with buttons, keys,
   gamepad or touch. The button path produces the **same pitch track** as
   the microphone and is scored by the **same** judge (§4.1), so it is a
   genuine second input source, not a separate minigame.
3. **Your voice, not an absolute pitch.** Scores are relative to each player's
   own calibrated range. A deep voice and a high voice, an adult and a child,
   score alike for the same shape.
4. **Respect for the tradition.** The humour comes from the characters and the
   canal, never from the saloma itself. Rival voices are **recordings of real
   salomeros**, credited and paid. No synthesized caricature ships (§11).
5. **Never reward hurting yourself.** Loudness is capped. Quiet Mode removes it
   from scoring entirely, and the game encourages rest between duels (§4.6).
6. **Same studio look as Chicken Pit.** A real, toy-like 3D canal in an
   isolated viewport, driven by node-free models, under the shared HUD.

### Look and tone

Warm, sunlit and a little miniature: a tabletop canal of painted wood and
clay. Boats bob, the jungle crowds the banks, and the lock "mules" (electric
towing locomotives) creep along their rails. Rivals are characters with
pride, quirks and a soft spot. The **container-ship crew is an affectionate
running joke**, not a punchline about outsiders. They are learners, and when they
finally land a clean quiebre, the whole canal cheers for them.

### Story (for the intro cards and `instructions_rules`)

Five short cards, using the same intro shape as the other games:

1. In a village in Azuero, your grandmother's saloma could reach the next hill.
2. This year the great saloma festival is on the Pacific shore, across the isthmus.
3. Your little boat, the *Quiebre*, enters the canal at Colón with the dawn.
4. Every crew on the water has heard about the festival, and none of them
   plan to let you pass quietly.
5. Fill your lungs. **¡Salomea!** *(verify imperative form)*

---

## 2. Core loop

```
Title ─► Play ─► Mode select (Solo / Duel · level · captain on the plinth)
     ─► Instructions ─► Soundcheck (mic: calibrate · buttons: one practice call)
     ─► Level: cruise ─► a rival boat hails you ─► DUEL:
            tanda 1: rival calls ─► you answer ─► the judges score both
            tanda 2: you call  ─► rival answers ─► the judges score both
            tanda 3: decider (only if 1–1)
        ─► win: rival yields the lane · lose: retry the duel (no lives lost)
        ─► next rival … ─► LOCK BOSS: the chamber fills while you duel
     ─► level complete ─► results (tandas won, best call, judges' notes)
     ─► Balboas payout ─► next level unlocks
     ─► Store (hats, flags, boat paint) / Gallery / Share card
```

A level is **4–7 minutes**: two or three duels with short cruise segments
between them. A single duel lasts about **60–90 seconds**. The cruise is
non-interactive in v1. It is a breather for the voice and the moment for the
next rival's intro card.

---

## 3. The duel — contrapunto

### 3.1 Structure

A duel is **best of three tandas** *(tune)*. Each tanda has two turns:

| Turn | Who | What the judges want |
| --- | --- | --- |
| **Call** (*llamada*) | The tanda's leader | Their own saloma, scored on its merits |
| **Answer** (*respuesta*) | The other singer | Scored on its merits **plus Eco**: does it echo the call's shape and then top it? |

The lead alternates: the rival calls in tanda 1, you call in tanda 2, and in
tanda 3 the singer who **lost the closer tanda** leads. Answering is easier to
judge but harder to win. Calling is free but cannot earn Eco. That asymmetry
is the strategic heart of contrapunto.
Closeness is the absolute judge-point margin; when both margins are equal,
the loser of tanda 2 leads the decider *(confirmed by the owner)*.

Each turn is a **listening window** of 6 s *(tune)* that opens on a visible and
audible cue, the conch-shell **¡Ya!**. The window closes early after 1.2 s of
silence once the singer has started *(tune)*. Before the cue, the mic is muted
for scoring, so the rival's recording cannot leak into your score (§4.3).

### 3.2 The five marks

Three judges sit on the lock wall or a moored launch. Each judge raises a
paddle showing a **1–10 score** for each turn. The score is the weighted sum
of five marks, each normalized to 0–1:

| Mark | Spanish | What it measures (§4.4 for the maths) | Base weight *(tune)* |
| --- | --- | --- | --- |
| Breath | **Aliento** | Longest continuously voiced segment, saturating at 5 s | 0.25 |
| Break | **Quiebre** | Clean chest⇄falsetto jumps: count (up to 3) × cleanness | 0.30 |
| Range | **Altura** | Span between the turn's 10th and 90th pitch percentiles, relative to the calibrated range | 0.15 |
| Finish | **Remate** | A confident ending: a falling glide or a short cut-off, not a fade | 0.15 |
| Echo | **Eco** | *Answers only.* How closely the answer's contour matches the call's | 0.15 (0 on calls; the others rescale) |

**Fuerza (power)** is *not* a mark. It is a gate: a turn whose voiced frames
mostly sit below the calibrated "carrying" level loses 20 % *(tune)*. Being
louder earns nothing more, and clipping earns nothing either. Quiet Mode
removes the gate (§4.6).

**Judges have tastes.** Each judge multiplies one or two weights, shown on their
card before the duel: "Doña Mire listens for Quiebre ×1.5". The card shows text
and an icon, so it never relies on colour alone. Tastes give the level variety and teach the
marks one at a time (§6.3).

### 3.3 Winning a tanda, a duel, a level

- A **tanda** goes to the singer with the higher **sum of the three judges'
  paddles** for that tanda's two turns. Ties go to the answerer, because topping
  the call is the harder job.
- A **duel** is the first to two tandas.
- **Losing** a duel costs nothing but time: retry immediately, or continue
  from the cruise. There are no lives. The canal is the progression, and
  voice fatigue is the real limit (§4.6).
- A **level** is complete when its lock boss is beaten. Duels already won stay
  won within that attempt of the level.

### 3.4 The lock bosses — the chamber fills

Each level ends in a lock chamber, where you and the boss are tied up side by
side. While you duel, the **chamber fills or empties**. It is the visible clock
of a boss duel: three tandas must finish before the gates open, or the boss
"wins on time". Use a generous 4 minutes *(tune)* so the clock creates
tension without punishing a slow player. The time counts **between** turns
only, never inside a listening window. Water level is purely presentation in
the model (§7.3); the rule is the clock.

### 3.5 Hot-seat duel (two humans)

Two players, one device. P1 and P2 take the call and answer turns with the
same tanda rules, scored by the same judges. A **"Pass the mic"** card sits
between turns, showing the next singer's name, colour **and** P1/P2 label. Each
player has their **own calibration profile** (§4.2), chosen on that card, so
two different voices share one microphone fairly. Either player may use
buttons instead. The duel uses the free-play setting from any unlocked level.
Mobile builds stay single-player, as the shell already enforces
(`GameSession.multiplayer_available()`).

### 3.6 CPU rivals

A rival's turn is an **authored performance**: a real recording plus its
pre-analysed pitch track (§11.2), and a **target mark profile** with a
variance band per difficulty. The CPU does not "sing live". It plays the
recording, and the judges score it with the **same scorer** run over its
stored track. The difficulty tunable scales which take of the rival is
chosen (a cleaner or a rougher one), not the scoring. This keeps the judge honest and
lets tests check that each rival is beatable with a reachable score (§13).

---

## 4. Voice input

### 4.1 Architecture — one track, many sources

```
MicVoiceSource ─┐
KeyVoiceSource ─┼─► VoiceFrame stream ─► SalomaScorer ─► marks ─► Judges
TouchVoiceSource┘     (t, cents, voiced, level)          (pure, node-free)
                      ↑ also: recorded rival tracks, test fixtures
```

`VoiceFrame` is `{t: float, cents: float, voiced: bool, level: float}`.
`cents` is relative to the singer's calibrated **chest centre** (§4.2) and
`level` is relative to their calibrated carrying level. Every source emits
frames at **100 Hz** *(tune)*. The scorer never knows where frames came from.
That is how buttons, the CPU and tests become first-class: each produces the
same kind of track as a voice.

The microphone spike treats missing/unanalyzable PCM as a recording failure,
not a silent performance. Four seconds without new buffers aborts the call;
actual captured silence may still score zero. A cancelled call cannot replace
a scored reference. These checks do not establish that physical microphone
permissions or real saloma scoring have been validated.

`tools/analyse_takes.gd` now supports read-only local WAV comparisons through
the same PCM pipeline, including optional reference-based Eco. It reports
provisional scores/evidence without saving tracks or profiles, and preserves
recording gain and silence. This prepares the authentic-recording gate; it
does not pass it or implement the later rival `.track` baking workflow.

Copy and adapt Dead Metal Jam's microphone stack into this folder, **not**
import it. There must be no game-to-game dependency:

| Dead Metal Jam | Sailor Man | Change |
| --- | --- | --- |
| `input/mic_capture.gd` | `voice/mic_capture.gd` | Same runtime-created muted capture bus ("Saloma"), same dead-mic silence test |
| `input/pitch_detector.gd` (MPM/NSDF) | `voice/pitch_detector.gd` | Widen range to ~70–1100 Hz to cover falsetto; output continuous cents, not quantised notes |
| `input/pitch_analysis.gd` | `voice/voice_track.gd` | Smoothing, voicing hysteresis and octave-error guard, but **keep real jumps** (§4.4) |
| `input/latency_calibration.gd` | `voice/voice_calibration.gd` | Calibrates range and level, not latency: turns are judged after the fact, so latency only matters for the live ribbon |

`audio/driver/enable_input=true` is already the project default. Keep it
on for the `sailor_man` feature tag.

### 4.2 Calibration — "Prueba de voz"

A short optional overlay, opened by the game-owned **Soundcheck** button on a
pre-duel/next-turn card. The owner selected this entry rather than adding a
generic Settings action API. Remo works immediately without it.

1. **Room** — 2 s silence. Measures the noise floor. Exact digital silence
   means a dead or denied microphone. Say so plainly and offer buttons.
2. **Speak** — "Say a short phrase at your normal speaking level."
3. **Low** — "Hold a comfortable low *ooo*." This gives the chest centre, `0` cents.
4. **High** — "Now go up into your light, high voice — *eee*." This gives the falsetto
   band. If no break is found, the band is set from a default **+700 cents**
   *(tune)* and Quiebre uses the softer rule (§4.4).
5. **Call** — "Give us one saloma, any way you like." This is not scored. It is
   played back as a ribbon so the player sees what the game hears.

The scoring profile is `{chest_hz, falsetto_low, falsetto_high,
falsetto_calibrated, carry_level}`. `chest_hz` is an absolute frequency;
falsetto bounds are relative cents. `falsetto_calibrated` distinguishes a
measured band from the softer fallback rule. The development workbench still
accepts temporary manual references when no saved profile is loaded.

Full calibration adds `noise_floor`, `speak_level` and `device`, names profiles
(default "P1", with other names supported) and stores only validated scalar
measurements plus selection in `user://sailor_man_voice.cfg`. That is
calibration, so it is deliberately **not** a declared `save_files` entry
(`AGENTS.md`: saves are progress only).

Opening the overlay or selecting a saved profile does not activate capture.
**Enable microphone** is the gesture boundary. Speak/Low/High allow three
seconds each, Call six, with an earlier Stop and at least 0.6 seconds of clear
voice per measurement. Low must be steady; High needs an observed register
break or keeps an explicitly unmeasured +700-1300-cent fallback. It can also
be skipped. **Save and use mic** alone saves a completed profile; cancellation
or failure never replaces a prior one. Saved profiles merge by name;
damaged/newer files fail explicitly without overwrite.

The overlay suspends duel stepping and releases input on Back, pause/focus loss
or failure. Saving hands the checked capture reference to gameplay without
reparenting/restarting its live audio node. Later Enable actions perform a
fresh room check with the saved vocal range/levels. No PCM or tracks persist.

### 4.3 Bleed and the speakers

The rival's recording plays from the same speakers the mic can hear. Three
defences, in order:

1. **Turn gating** — the scorer only consumes frames inside the player's own
   listening window. The rival never sings during it.
2. **Tail guard** — the window opens 250 ms *(tune)* after the rival's last
   sample plus the measured reverb tail. The cue sound is short and pitched
   outside the scored band.
3. **Never monitor the mic** — the capture bus stays at −80 dB, as in Dead
   Metal Jam. Headphones are suggested on the Soundcheck card, never required.

### 4.4 The scorer — `saloma_scorer.gd`

`RefCounted`, node-free and autoload-free, so headless tests can import it.
Input: an array of `VoiceFrame`s and a profile. Output: the five marks, the
power-gate flag and **evidence** (where each break happened, the longest breath
segment). The judges' notes and the results ribbon draw from that evidence.

- **Voiced segments** — voicing with 40 ms hysteresis; gaps ≤ 60 ms *(tune)*
  are bridged, since a saloma's break often has a tiny gap.
- **Aliento** — `min(longest_segment_s / 5.0, 1.0)`.
- **Quiebre** — a jump of **≥ 500 cents within ≤ 90 ms** *(tune)*, either
  direction, that lands inside or leaves the calibrated falsetto band. Each
  break's *cleanness* is 1.0 minus a penalty for wobble in the 120 ms after
  landing. Mark = `min(sum(cleanness), 3) / 3`. **Softer rule** when no falsetto
  was calibrated: a jump ≥ 400 cents anywhere counts at 0.8. **Octave guard** —
  an exactly-1200-cent jump lasting ≤ 2 frames is a detector error, not a break.
- **Altura** — `(p90 − p10) / (falsetto_high − 0)`, clamped to 0–1.
- **Remate** — the last 400 ms: a falling glide of ≥ 300 cents, or a crisp stop
  (level falls 20 dB in ≤ 80 ms). A slow fade scores half. A glide must be a
  progressive descent, not one register drop followed by an unfinished hold.
- **Eco** — both contours are made **relative to each singer's own median**
  and resampled to 64 points. Score with **dynamic time warping** with a
  band of ±12 % *(tune)*. Map the distance to 0–1 with a curve tuned so a
  sincere attempt at the shape gets ~0.6 and a near copy gets ~0.9. Exact
  mimicry is not the goal. The answer is meant to echo, then top.

Every threshold is a constant at the top of the file, so the tests and the
tunables can quote them.

### 4.5 Buttons, keys and touch — "Remo" mode

A **voice ribbon** scrolls across the lower third: the call's contour (for
answers) or an empty lane (for calls). The player draws their saloma onto it:

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| **Voice** (hold to sing) | Space | A / right trigger | Hold anywhere on the ribbon |
| **Pitch** (glide up/down) | W/S or ↑/↓ | Left stick Y / D-pad | Drag vertically while holding |
| **Quiebre** (snap to falsetto and back) | J | X / right bumper | Quick flick up (or the Break button) |
| **Remate** (finish) | K | B | Flick down to release |
| Pause | Escape (shell) | Start | Pause icon |

`KeyVoiceSource` turns those inputs into `VoiceFrame`s using a **virtual
profile**: chest at 0, falsetto band +700…+1300. A quiebre press is a jump
of 700 cents over 40 ms. The pitch stick glides at 1800 cents/s *(tune)*. While
Voice is held, the player hears their **captain's recorded voice** pitch-
shifted along the track. These are real takes, so a button saloma still
sounds like a saloma.

**Current workbench:** key/gamepad and independent touch sources now feed the
same scorer and reference ribbon, with rebindable keyboard hints. Start Remo
or hold the ribbon; Remo disconnects microphone capture and uses a clearly
labelled, original synthetic tone on the SFX bus. Real captain recordings
remain Milestone 6. Explicit Remate leaves 120 ms of silent frames before
judging, while Stop/timeout do not fabricate an ending. Pause, focus loss and
rebinding cancel unfinished turns without losing a kept reference.
The virtual band is authored/known, not a measured microphone calibration.

Because the same scorer judges it, Remo mode cannot be strictly easier or
harder by accident. The tests pin that an ideal Remo performance and an ideal
sung performance of the same contour score within 5 % *(tune)*.

### 4.6 Voice health and Quiet Mode

- **Quiet Mode** (tunable): no power gate, and the mic gain is normalized to
  speaking level. It is for night play, shared rooms or a tired voice. Hummed or
  half-voiced salomas score normally.
- After **6 sung turns in 10 minutes** *(tune)*, the cruise card suggests a
  sip of water and offers Remo mode for the next duel. It never forces it.
  In the grey-box version this is an optional between-duel card and saved
  reminder toggle. Only completed voiced microphone turns count, including
  practice, not silent/failed/cancelled takes, Remo or synthetic examples.
  Dismissal acknowledges that group; counts are gameplay-session-local across
  replays, never stored in calibration.
- Copy never says "louder". It says "carry", "hold", "break" and "finish".
- No achievement rewards loudness or session length.

### 4.7 Platforms

| Platform | Microphone | Notes |
| --- | --- | --- |
| Desktop | Native | Primary target. Device picker in Soundcheck (`AudioServer.input_device`). |
| Mobile | Native after runtime permission | Record permission in the export preset. Single-player only (shell rule). Touch Remo fully supported. |
| Web | HTTPS + permission + a user gesture | Soundcheck is the gesture gate. Live analysis yields after eight detector windows per update; Stop queues/drains its last PCM over updates. No worker thread is required. |

Saved Auto/Microphone/Remo selection is a manifest-declared integer choice.
Auto prefers an available calibrated device, otherwise Remo; no preference or
profile silently opens hardware. Capture failure selects usable Remo for Auto
without changing that saved preference. Desktop/offline analysis remains
unlimited. Synthetic equivalence tests exercise the budget, not real browser
permissions, acoustic behavior or device performance.

No gameplay script may branch on platform. Differences are resolved where
sources are built, as in Dead Metal Jam §4.7.

---

## 5. The canal — campaign and levels

### 5.1 Geography *(verify details with current ACP material; no ACP logos)*

The real canal runs about 80 km from Colón on the Caribbean to Balboa on the
Pacific. Ships climb about 26 m through the **Gatún Locks** into **Gatún
Lake**, a reservoir made by damming the Chagres River. They cross the lake past
**Barro Colorado Island**, pass **Gamboa** where the Chagres comes in, and cut
through the Continental Divide in the **Culebra (Gaillard) Cut** under the
**Centennial Bridge**. They step down at **Pedro Miguel**, cross little
**Miraflores Lake**, and drop to the sea at **Miraflores**, then pass under the
**Bridge of the Americas**. Electric locomotives called **mulas** guide ships through the
original locks. The 2016 Neopanamax locks (Agua Clara, Cocolí) are
background set dressing only.

The game compresses the canal freely. It is a toy-model canal, not a simulator.

### 5.2 Levels (shared level selector)

Use the manifest's `levels` with achievement gates, like Cube Trials. Each level
has an `icon` captured from the real scene by `tools/capture_art.gd`.

| # | Level | Duels | Boss (in the lock) | Mechanic introduced | Unlocked by |
| --- | --- | --- | --- | --- | --- |
| 1 | **Bahía Limón & Gatún** | Tutorial: the old fisherman; a pilot launch | **Las Mulas** — the lock's locomotive crew | Calls, answers, Aliento; the chamber fills | always |
| 2 | **Lago Gatún** | A cayuco from Coclé; the howler monkeys of Barro Colorado (interlude, §6.2) | **The Dredge** *Tío Chagres* | Quiebre; judges' tastes | `sailor_man_passed_gatun` |
| 3 | **Corte Culebra** | The tourist ship; the container ship | **The Cut itself** — an echo duel (§5.3) | Eco, Remate | `sailor_man_passed_lake` |
| 4 | **Pedro Miguel** | Night tug; a fishing panga from Herrera | **Los Gallos de Ocú** *(name: verify)* | Full contrapunto; decider tandas | `sailor_man_passed_cut` |
| 5 | **Miraflores & the Pacific** | The visitor-centre crowd's favourite | **La Maestra**, on the festival boat under the Bridge of the Americas | Everything; judges with two tastes | `sailor_man_passed_pedro_miguel` |

Completing level 5 unlocks `sailor_man_champion` and **free play**: any rival,
any arena, and the hot-seat duel at every arena (not only level 1).

### 5.3 Arena modifiers

Each arena changes the duel's **presentation and one rule**, never the scorer:

- **Locks** — the chamber clock (§3.4).
- **Lake** — open water: the rival's boat drifts in and out of the shot. The
  call is replayed once on request (the **Repeat** button) at no cost.
- **Culebra Cut** — echo: your call returns from the cut walls 600 ms later
  *(tune)* as a quiet, delayed copy. The boss duel is **you against your own
  echo**. Answer *your own* call with a better one. The scorer is unchanged;
  only who calls changes.
- **Pacific** — a festival panel of five judges, not three. The two extra
  paddles widen the spread, so a perfect turn reads as a perfect turn.

---

## 6. Characters

### 6.1 The player's captains (`characters`)

Shared mode select places the chosen captain on the plinth. Captains differ
in **look and recorded voice** (for Remo mode and the share card), never in
stats. Starting roster *(cast real voices, §11)*:

| Id | Name | From | Voice for Remo |
| --- | --- | --- | --- |
| `capt_tito` | Tito | Las Tablas, Los Santos | Male salomero |
| `capt_yari` | Yari | Ocú, Herrera | Female salomera |
| `capt_abuela` | Abuela Chela | Pedasí, Los Santos | Elder salomera (unlocked by `sailor_man_champion`) |

In hot seat, P2 picks too. Two captains in one duel wear their seat's colour on
the boat's pennant **and** carry a P1/P2 plaque.

### 6.2 Rivals

Rivals are original characters, not real festival winners or their likenesses.
Each rival card gives a name, boat, home, a one-line personality and the judges'
taste for that duel.

| Rival | Boat | Personality | Duel note |
| --- | --- | --- | --- |
| **Don Fermín** | Dugout *(cayuco)* at the breakwater | Retired fisherman, patient teacher | Tutorial: will happily lose the first tanda |
| **The Pilot** | Pilot launch | Brisk, professional, secretly a great salomero | Short, clean calls |
| **Las Mulas** | Lock locomotives (crew on the wall) | Three brothers who salomar in turns | Boss: the call passes between three voices |
| **Los de Penonomé** | Cayuco from Coclé | Cheerful family crew | Long Aliento |
| **The Howlers** | Barro Colorado trees | Howler monkeys answering anything loud | Comic interlude: they "judge" by howling back. Unscored practice for Quiebre |
| **Tío Chagres** | An old dredge | Grumpy, then proud of you | Boss: low, slow, enormous Aliento |
| **Captain Marguerite** | Tourist ship | Learned saloma from a TV documentary | Enthusiastic, off-shape. Good for practising Eco |
| **The MV Long Haul crew** | Container ship (fictional, no real line's livery) | A multinational crew who have practised for months | Running gag: they improve every time you meet them |
| **Los Gallos de Ocú** | Festival panga | Rival festival favourites | Boss: break-heavy, two-voice calls |
| **La Maestra** | Festival boat under the Bridge of the Americas | Your grandmother's old rival | Final boss: every mark, two judges' tastes |

### 6.3 Judges

Recurring judges with clear tastes teach the marks. Each judge appears as a
toy figure with a paddle and a name card:

- **Doña Mire** — Quiebre ×1.5
- **Profe Abdiel** — Aliento ×1.5
- **Nena** — Eco ×1.5, and she laughs warmly at a good answer
- **El Capitán del Puerto** — Remate ×1.5, a stickler for a clean finish

---

## 7. Architecture

### 7.1 File layout

```
game.gd                       # GameManifest — copy, theme, achievements, credits
sailor_man_options.gd         # constants-only: tunables, bindings, levels,
                              #   characters, store, gallery (loaded by path)
gameplay.gd / .tscn           # extends GameShell; inherited scene of game_shell.tscn
intro.tscn                    # five story cards (§1)
duel/duel_state.gd            # node-free tanda/turn state machine, chamber clock
duel/saloma_scorer.gd         # node-free marks from a VoiceFrame track (§4.4)
duel/judges.gd                # tastes, paddles, notes from scorer evidence
duel/rival_book.gd            # rivals, their takes and difficulty variants
campaign/voyage.gd            # node-free level → duels → boss sequence
voice/voice_frame.gd          # the shared frame shape
voice/mic_capture.gd          # adapted from dead_metal_jam (muted bus, dead-mic test)
voice/pitch_detector.gd       # adapted MPM detector, continuous cents
voice/voice_track.gd          # smoothing, voicing hysteresis, octave guard
voice/voice_calibration.gd    # Prueba de voz (§4.2), profile load/save
voice/mic_voice_source.gd
voice/key_voice_source.gd     # Remo mode, keyboard + gamepad
voice/touch_voice_source.gd   # Remo mode, multitouch
world/canal_view.gd           # isolated SubViewport, cameras, water level
world/boat_rig.gd             # boats from one rig: hull, paint, flag, hat slots
world/lock_set.gd             # walls, gates, mulas, filling water
world/scenery.gd              # jungle banks, lake islands, cut terraces, bridges
world/crowd.gd                # batched spectators on walls and banks
world/voice_ribbon.gd         # the ribbon drawn over the water as a voice carries
world/mesh_builder.gd         # copied from cube_trials/world/, adapted
ui/duel_hud.gd                # turn banner, listening window, judges' paddles
ui/soundcheck.gd / .tscn      # calibration overlay, device picker
ui/remo_ribbon.gd             # the Remo-mode drawing lane
audio/sailor_audio.gd         # cues: conch, crowd, water, lock horn
assets/voices/                # licensed recordings + pre-analysed .track files
assets/models/ assets/levels/ assets/icons/ assets/video/
share_art.gd / .tscn          # captain on the bow, mid-saloma
store_preview.gd / .tscn      # boat or captain wearing one item
gallery_stage.gd / .tscn      # turntable
character_preview.gd / .tscn  # captain on the setup plinth
tests/                        # §13
tools/                        # capture_art.gd, analyse_takes.gd, tutorial_driver.gd
README.md · DESIGN.md · AGENTS.md
```

### 7.2 Model / view split

`duel_state.gd`, `saloma_scorer.gd`, `judges.gd`, `rival_book.gd`,
`voyage.gd` and the voice sources' frame logic are `RefCounted`. They touch
**no autoload and no node** and are what the headless tests exercise.
`gameplay.gd` steps the duel, routes frames from the active source to the
scorer, and hands state to `canal_view.gd`. The view may add bobbing,
crowd waves and ribbon flourishes, but it never feeds back into the model.

### 7.3 `GameShell` hooks used

`game_id`, `_prepare_session`, `_build_playfield`, `_load_round_settings`
(`super()`), `_reset_round_state`, `_activate_round`, `_update_round`,
`_handle_gameplay_input`, `_finish_round`, `_round_totals`, `_player_stats`,
`_describe_round_outcome`, `_round_highlight_summary`,
`_award_round_achievements`, `_round_points_earned`, `_configure_mode_ui`
(`super()`), `_on_game_setting_changed`, `_set_reduced_motion_enabled`
(**`super(value)`**), `_set_intense_effects_enabled` (**`super(value)`**).
Copy the signatures exactly from `AGENTS.md`.

A shell **round is one level** in solo play and one duel in hot seat.
`uses_shell_round_rules = false`. The level ends when the boss falls or the
player quits to the results. Gameplay then calls the shell's normal end-of-round
path, as Cube Trials does. `_round_totals` reports total judges' points.
`_player_stats` reports tandas won, best turn score, quiebres landed, longest
Aliento and the input source used.

### 7.4 Manifest sketch

This is the target manifest. The scorer spike deliberately leaves opponents,
multiplayer, levels, captains, progress files, store and gallery undeclared.

```gdscript
game.id = Options.GAME_ID                       # "sailor_man"
game.title = "Sailor Man"
game.tagline = "Win the canal one saloma at a time."
game.menu_order = 10
game.gameplay_scene_path = "res://games/sailor_man/gameplay.tscn"
game.intro_scene_path = "res://games/sailor_man/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = true                # hot-seat duel
game.supports_cpu_opponent = true               # the campaign
game.max_local_players = 2
game.local_multiplayer_turns = true
game.levels = Options.LEVELS                    # §5.2, achievement-gated
game.characters = Options.CAPTAINS              # §6.1
game.character_preview_scene_path = ".../character_preview.tscn"
game.save_files = [{"path": "user://sailor_man.cfg", "title": "Voyage",
		"description": "Levels passed, rivals beaten and best calls."}]
game.tunables / control_bindings / store_* / gallery_* = Options.*
game.tutorial_video_path / tutorial_poster_path
game.stats_url = "https://deskcansaw.com"       # ≤ 42 bytes
game.theme = theme                              # §8.3
```

---

## 8. Art direction

### 8.1 Pipeline

Follow Chicken Pit's lead: a real `Node3D` world in an isolated `SubViewport`,
original vertex-coloured low-poly meshes, scenery batched through
`mesh_builder.gd`, a warm key light with compatibility shadows and no SSAO
or glow. Budget: **below 60 draw calls** in a duel shot, enforced by
`canal_view_test.gd` as Chicken Pit does.

### 8.2 Scenes

- **Duel framing** — a two-shot across the water. On each turn the camera eases
  toward the singer, and the **voice ribbon** unrolls from their mouth across
  the water as they sing. Its height follows the pitch track, and each quiebre
  shows as a visible step with a spark. Reduced motion holds a fixed two-shot
  and draws the ribbon without easing.
- **Locks** — tall concrete walls, miter gates, mulas on their rails and a
  crowd on the walls. The water rises or falls with the chamber clock.
- **Lake** — jungle islands, distant generic ships, and howler monkeys in the
  canopy.
- **Culebra Cut** — terraced red-earth slopes and the cable-stayed bridge
  overhead.
- **Pacific** — the arched bridge, a hazy city skyline, the causeway and the
  festival boats dressed in bunting.

### 8.3 Palette and theme

Drawn from the interior's festival colours and the canal's water *(tune)*:

```gdscript
const INK := Color("1f2a36")
const CANAL := Color("2f7f86")       # water
const JUNGLE := Color("3f7d3a")
const SUN := Color("f4b941")         # accent: festival bunting, the ribbon
const POLLERA_RED := Color("c8413b")
const CREAM := Color("fbf2df")
```

`GameTheme`: accent `SUN`, light `CREAM`, plaque `INK`, background a
dawn-to-teal gradient, `style_share_card = true`, logo `assets/game-icon.png`
(the *Quiebre*'s bow with a ribbon of voice, captured from the model).
Player identities keep the shared blue/red colours. The theme must not tint
them.

Traditional dress (pollera, montuno, sombrero pintao) appears on festival
characters and in the store **as worn with pride, never as a costume gag**,
and only after the cultural review (§12).

---

## 9. Shell features

### 9.1 Achievements (keys are stable forever)

| Key | Title | Badge | Condition |
| --- | --- | --- | --- |
| `sailor_man_first_duel` | First Call | LLAMADA | Win any duel |
| `sailor_man_passed_gatun` | Up the Steps | GATÚN | Beat Las Mulas |
| `sailor_man_passed_lake` | Across the Lake | LAGO | Beat Tío Chagres |
| `sailor_man_passed_cut` | Through the Divide | CULEBRA | Beat your own echo |
| `sailor_man_passed_pedro_miguel` | One Step Down | P. MIGUEL | Beat Los Gallos |
| `sailor_man_champion` | Rey / Reina del Canal | CAMPEÓN | Beat La Maestra |
| `sailor_man_triple_break` | Tres Quiebres | QUIEBRE | Three clean quiebres in one turn |
| `sailor_man_long_breath` | Aliento de Pescador | ALIENTO | A 5-second unbroken Aliento |
| `sailor_man_perfect_echo` | Eco Perfecto | ECO | Eco ≥ 0.9 on an answer |
| `sailor_man_clean_sweep` | Sin Discusión | 2–0 | Win a boss duel 2–0 |
| `sailor_man_hot_seat` | Pásame el Micrófono | DUO | Finish a hot-seat duel |

The five `passed_*`/`champion` keys gate levels (§5.2) and Abuela Chela (§6.1).
Every achievement is reachable in Remo mode *and* Quiet Mode, and assists never
block one.

### 9.2 Store — currency "Balboas"

Named after Panama's currency. `store_currency` pays about one Balboa per 10 judges'
points, plus a win bonus against a CPU rival *(tune)*. Slots are **hat**
(captain), **pennant** (boat flag), **paint** (hull) and **bow** (figurehead).
Starter items: a straw hat (default), a sombrero pintao (gated behind
`sailor_man_champion` and cultural review), a fisherman's cap, festival bunting,
a red-and-white hull, a mola-pattern pennant *(verify with Guna design guidance — or cut)*,
a conch-shell bow and a carved fish bow. Cosmetic only.

### 9.3 Gallery

`GALLERY_EXHIBITS`: the *Quiebre*, each rival's boat, a mula on its rail,
a lock gate, the howler monkey, the dredge, the festival boat and the
"whole canal" diorama. Later items are gated by their level achievement. The
stage implements `configure`, `set_view` and `set_auto_spin`.

### 9.4 Share card

The captain on the bow mid-saloma, with the ribbon of their **best turn**
drawn across the card from real scorer evidence. The headline is the level reached,
with the judges' best paddles, quiebres and Aliento below. The QR code points
to `stats_url`.

### 9.5 Accessibility (non-negotiable)

- **Remo mode** everywhere (§4.5); the input source is a tunable, and
  Soundcheck offers it whenever the mic fails.
- **Captions** for every sound that carries meaning: the rival's call ("Don
  Fermín salomas — long, two breaks, falling finish"), the ¡Ya! cue, judges'
  verdicts, the chamber horn and crowd reactions. A call's caption describes its
  **shape** in words, so a deaf or hard-of-hearing player can answer from the
  ribbon and the caption alone.
- **Visual ribbon** of the call (toggle, on by default) is the same contour Eco
  measures.
- **Never colour-only**: P1/P2 labels on pennants and HUD; judges' paddles show
  numbers; marks have icons.
- **Reduced motion**: fixed camera, no bobbing, no crowd waves, no water
  shimmer, opacity-only transitions; the water level still changes, since it is
  the clock.
- **Intense effects off**: no flash on a quiebre spark, no camera punch on a
  win.
- **Longer windows** tunable (6 s → 9 s) and **Repeat call** everywhere.

### 9.6 Audio — `sailor_audio.gd`

Real recordings for every voice (§11). Synthesized or recorded cues for
the conch ¡Ya!, the lock horn, the water roar of filling, the crowd, the
judges' paddle clack and the mula bell. There is an optional music bed in the
cruise only, never under a listening window. That would bleed into the mic and
would compete with the singer.

---

## 10. Tunables and bindings

| Key | Type | Default |
| --- | --- | --- |
| `game/sailor_man_input_source` | choice: Auto / Microphone / Remo | Auto (mic if calibrated, else Remo) |
| `game/sailor_man_quiet_mode` | toggle | false |
| `game/sailor_man_rival_difficulty` | choice: Relaxed / Festival / Maestro | Festival |
| `game/sailor_man_show_call_ribbon` | toggle | true |
| `game/sailor_man_long_windows` | toggle | false |
| `game/sailor_man_mic_sensitivity` | slider 50–150 % | 100 % |

Bindings are listed in §4.5, with every action and key prefixed
`sailor_man_`. Source, Quiet Mode and reminder preferences are ordinary
manifest-declared tunables. Recalibration opens through the game-owned
pre-duel Soundcheck button; no framework action-row API or game-name branch
is needed.

---

## 11. Voices and cultural authenticity

### 11.1 Recordings

- Cast **real salomeros and salomeras**, ideally through a festival or
  cultural institution in Azuero, with **written consent, fair payment and
  credit** in `GameManifest.credits`. Record each rival's calls in several takes
  (clean / rough) for the difficulty variants. Record each captain's sustained
  vowels and breaks for Remo resynthesis.
- Store the source recordings outside export, and ship processed OGG plus a
  `.track` (pre-analysed `VoiceFrame`s) generated by `tools/analyse_takes.gd`.
  Shipping the track means the CPU's scores are reproducible and testable.
  The current tool only analyzes WAVs read-only; track baking remains a later
  milestone, and no performer recordings are currently supplied.
- Placeholder voices during development may be synthesized. **No synthesized
  rival may ship.**

### 11.2 Cultural review

Before content lock, a consultant reviews the intro cards, rival names and
personalities, judges, glossary, traditional dress, store items and every
*(verify)* line here. They also review the scoring's description of a "good"
saloma: the five marks are a game's simplification, and the tutorial should say
so and point players toward the real tradition.

### 11.3 Language

Copy is English with Spanish terms kept (*saloma, salomar, quiebre, tanda,
contrapunto, grito, remate*). A **glossary card** sits in the instructions. A
full Spanish localisation is deferred beyond the approved English-first v1.

---

## 12. Integration checklist (outside this folder)

- [ ] `project.godot`: `config/name.sailor_man`,
      `config/custom_user_dir_name.sailor_man="DeskCanSaw Games/Sailor Man"`
      (stable forever once shipped, so confirm the title first),
      `config/icon.sailor_man`, `dcs/build/single_game_id.sailor_man`,
      `[share] stats_urls/sailor_man`. Keep `driver/enable_input` true.
- [ ] `export_presets.cfg`: standalone preset with the tag. Record-audio
      permission on Android/iOS. Add `games/sailor_man/*` to the other presets'
      `exclude_filter`. Keep `tools/` and raw recordings out.
- [ ] `.gitmodules` and gitlink once the folder has a remote (two commits).
- [ ] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list, per-game blurb. `godot-base/README.md` if it lists
      games.
- [ ] `--import` after adding any `class_name`; prefer preload-by-path.

No framework code changes are expected. If one seems needed (for example, a
Game-tab button row), add data to `GameManifest`, never a game-name branch.

---

## 13. Tests — `tests/`

Headless unless noted; each one is a standalone `SceneTree` script that exits 0.
Currently implemented: `saloma_scorer_test.gd`, `voice_normalisation_test.gd`,
`voice_pipeline_test.gd`, `remo_source_test.gd` and the prototype
`sailor_scene_test.gd`. The other
suites below describe later milestones. Run the scene suite without
`--headless` too: it checks actual phone-to-ultrawide rendering and 150% UI
size, without requesting microphone access.

| Suite | Covers |
| --- | --- |
| `saloma_scorer_test.gd` | Each mark on synthetic tracks: breath saturation, break detection and octave guard, softer rule, range, remate glide vs fade, Eco on identical / shifted / time-stretched / unrelated contours, power gate and Quiet Mode |
| `voice_normalisation_test.gd` | The same contour sung by a low and a high profile scores within 2 % |
| `voice_pipeline_test.gd` | MPM on synthesized PCM, sample-rate/buffer independence, streaming normalization, octave guard, source-to-scorer integration and disabled-input failure |
| `remo_source_test.gd` | Key and touch inputs produce the expected frames; an ideal Remo and an ideal sung performance score within 5 % |
| `duel_state_test.gd` | Lead alternation, tanda ties to the answerer, best-of-three, decider leader, chamber clock pausing inside windows, retry |
| `rival_book_test.gd` | Every rival's every take loads, its stored score sits in its difficulty band, and a reachable player score beats each boss |
| `voyage_test.gd` | Level order, achievement gates, free play after the champion, and that progress never regresses |
| `voice_calibration_test.gd` | Profiles round-trip, dead-mic silence detection, missing-falsetto fallback |
| `sailor_scene_test.gd` | Current prototype: opt-in capture, buffered PCM, routed Remo keyboard/gamepad/multitouch, tone/Eco, source switching, cancellation, pause/resume, results, replay and physical layouts; hot-seat checks follow its implementation |
| `canal_view_test.gd` *(window)* | Real render: both boats visible in the two-shot, ribbon readable, draw-call budget, portrait → ultrawide, Remo lane doesn't cover the singers |

The framework suites pick the game up automatically. Run them all with
`--game=all` before calling a milestone done.

---

## 14. Milestones

1. **Scorer spike.** `saloma_scorer.gd` and the synthetic-track tests, plus a
   bare scene that records a mic turn and prints the five marks. *Goal: a real
   saloma and a flat yell score clearly differently.* This is the riskiest part
   of the game; real salomeros' recordings remain the validation gate. The
   owner authorized Milestone 2 under an assumption of success, not as evidence
   that the gate was passed.
2. **Remo mode.** Key/touch sources and the ribbon lane; parity test green.
3. **Duel.** State machine, judges, one placeholder rival and HUD, results,
   all in a grey-box lock.
4. **Calibration.** Soundcheck, profiles, dead-mic path, Quiet Mode.
5. **Canal.** Boats, locks, lake, cut, Pacific; chamber water; ribbon over
   the water; crowd.
6. **Voices.** Recording sessions, `analyse_takes.gd`, rival book, captains.
7. **Campaign.** Five levels, gates, captured level stills, intro, cultural
   review pass.
8. **Shell features.** Hot seat, store, gallery, share art, character preview,
   tutorial video, credits, theme, icon.
9. **Polish and integration.** Accessibility sweep, web/mobile mic passes,
   framework suites with `--game=all`, export preset and docs.

**Stretch:** Spanish localisation; a "salomar to the shore" practice mode on
cruises; more rivals per level; a grito-only quick-fire mode; daily rival.

---

## 15. Owner decisions and open questions

1. **Title — confirmed:** Sailor Man. Its standalone save directory still
   needs a stable feature-tag entry before shipping.
2. **Cultural partner — not yet available:** recordings and review (§11),
   including the real-voice scorer gate, remain blocked.
3. **Language — confirmed:** English first, keeping Spanish saloma terms.
   Full Spanish localisation is deferred.
4. **Gender of the champion title.** "Rey / Reina del Canal" follows the
   captain chosen. Confirm, or pick a neutral title.
5. **Hot seat — confirmed:** two humans in v1, not three. Enable it only once
   the real duel and per-seat profile hand-off are implemented.
6. **Grito — confirmed:** part of Remate, with no separate action.
7. **Real places.** The canal's locks and bridges are named as real places.
   Confirm that the studio is comfortable with that, without any canal
   authority branding.
