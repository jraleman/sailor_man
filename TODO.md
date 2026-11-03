# Sailor Man — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §14, with a scaffolding phase first. Tick a box only when
the item works **and** its tests pass; each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

---

## Owner decisions and remaining blockers (DESIGN §15)

These change names, keys or scope that become permanent once shipped. Nothing
below that depends on one should start until it is answered.

- [x] **Title** (§15.1) — Sailor Man. Feature-tag/save-directory entries still
      belong to the shipping phase.
- [ ] **Cultural partner** (§15.2) — blocks the Milestone 1 real-voice gate,
      Phase 6 recordings and the Phase 7 review.
- [x] **Language** (§15.3) — English first, keeping Spanish saloma terms.
- [ ] **Champion title gender** (§15.4) — "Rey / Reina del Canal" or neutral.
- [x] **Hot seat** (§15.5) — two humans in v1; implemented through shared setup.
- [x] **Grito** (§15.6) — part of Remate, no separate action.
- [x] **Real place names** (§15.7) — the owner approved real names, including
      Gatún, Culebra and Miraflores, without canal-authority branding. This is
      naming permission, not factual/cultural validation.
- [x] **Soundcheck entry** (§10) — the owner chose the game-owned pre-duel /
      next-turn **Soundcheck** button. No generic Settings action-row API or
      framework game-name branch is needed.
- [x] **Arena access during development** (§5.2) — the owner chose all five
      arenas as free practice in the shared level selector. Campaign gates
      come later; normal Culebra practice keeps the synthetic skiff.
- [x] **Self-echo structure** (§5.3) — the owner chose a separate best-of-three
      challenge against a fresh unscored seed snapshot, not a one-answer drill.
      Only completed pitch data drives a neutral tone; no live mic monitoring.
- [x] **Hot-seat practice rules** (§3.5) — the owner chose all five current
      practice arenas and no chamber timeout, including locks. Ordinary
      listening deadlines remain; future campaign access is undecided.

## Discrepancies found while planning

- [x] `mesh_builder.gd` lives in `games/cube_trials/world/`; DESIGN §7.1 now
      names that source. No canal meshes are needed for the spike.
- [x] Verified Godot **4.7.2** on Windows for the prototype's import/tests.
- [x] Hot seat arenas: the owner chose all five current practice arenas.
      §3.5/§5.2 now separate this implemented rule from future solo campaign
      gates; campaign-aware hot-seat access still needs a later decision.
- [x] Dolce's Adventure is implemented at `menu_order = 9`; Sailor Man keeps `10`.

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from here on.

- [ ] Commit `DESIGN.md` and this `TODO.md` to the game repository.
- [x] Folder `AGENTS.md` with game-specific agent notes.
- [x] `sailor_man_options.gd` — constants-only: `GAME_ID`, Quiet Mode, longer
      windows, sensitivity, the spike's Record action and implemented Remo
      bindings. Free practice arena data now lives in `canal_arenas.gd`;
      captains, store and gallery stay undeclared.
- [x] `game.gd` — minimal manifest (§7.4): id, title, tagline, `menu_order = 10`,
      `CONTROL_STYLE_CUSTOM_KEYS`, `uses_shell_round_rules = false`, tunables,
      bindings. Multiplayer stayed off until the tested hot-seat slice below.
- [x] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [x] `tests/` folder and a smoke test that loads the manifest by path.
- [x] Prototype SVG icon and labelled synthetic walkthrough/poster, required
      by the catalog-wide theme/media tests. Final game art remains Phase 8.
- [x] `godot --headless --path . --import`
- [x] **Exit:** all 15 framework suites exit 0 with `--game=all`; standalone
      source startup and direct workbench/tool launches exit cleanly.

## Milestone 1 — Scorer spike (§4.1, §4.4) ⚠ riskiest

- [x] `voice/voice_frame.gd` — `{t, cents, voiced, level}`, 100 Hz.
- [x] `tests/voice_track_fixture.gd` — synthetic track builder: hold, glide, jump,
      gap, wobble, fade, cut-off, all relative to a profile.
- [x] `duel/saloma_scorer.gd` (`RefCounted`, every threshold a top-level const):
  - [x] Voiced segments: 40 ms hysteresis, bridge gaps ≤ 60 ms
  - [x] Aliento: longest segment / 5 s
  - [x] Quiebre: ≥ 500 cents in ≤ 90 ms into/out of the falsetto band, cleanness,
        softer rule (≥ 400 at 0.8), octave guard
  - [x] Altura: p90 − p10 against the calibrated range
  - [x] Remate: progressive falling glide ≥ 300 cents or crisp stop; fade = half
  - [x] Eco: median-relative contours, resample to 64, DTW with a ±12 % band.
        The distance curve still needs real-voice tuning.
  - [x] Weights, Eco = 0 on calls with the rest rescaled, Fuerza gate (−20 %),
        Quiet Mode bypass
  - [x] Evidence output: break positions and the longest-breath span
- [x] `tests/saloma_scorer_test.gd` — synthetic scorer cases in §13.
- [x] `tests/voice_normalisation_test.gd` — low and high profile within 2 %.
- [x] Port from `dead_metal_jam/input/` (copy, never import):
  - [x] `voice/mic_capture.gd` — uniquely named muted "Saloma" bus, explicit
        disabled/dead/no-data failures; physical-device QA remains open
  - [x] `voice/pitch_detector.gd` — MPM, 70–1100 Hz, continuous cents
  - [x] `voice/voice_track.gd` — smoothing, voicing hysteresis, octave guard
        that keeps real jumps
  - [x] `voice/mic_voice_source.gd` — emits `VoiceFrame`s
- [x] `tools/scorer_spike.tscn` — opt-in microphone window, five marks and pitch
      ribbon; hardware-free examples and kept-reference Eco. Dev-only.
- [x] `tests/voice_pipeline_test.gd` — synthesized PCM, 44.1/48/96 kHz windows,
      arbitrary chunks and full source/scorer flow.
- [x] `tests/sailor_scene_test.gd` — real shell, buffered recording UI,
      options, error recovery, pause/results/replay and responsive rendering.
- [x] Recording-failure hardening: no score/call for missing PCM, four-second
      listening-window stalls disconnect capture, partial turns cannot replace
      scored references, and pause preserves the earlier reference. Regression
      cases also cover resumed buffers and actual captured silence.
- [x] Offline WAV analysis: read-only local takes through the microphone's
      detector/normalizer and shared scorer, optional reference-based Eco,
      explicit errors/exit codes, and synthetic file/CLI regressions. This
      prepares recording comparisons; it does not pass the exit below.
- [ ] **Exit:** a real saloma and a flat yell score clearly differently on the
      spike, checked against real salomero recordings (blocked on §15.2).
      Record the numbers here before moving on.

**Synthetic benchmark only:** shaped call **88.8688/100**, flat hold with a
crisp stop **47.0588/100**, identical shaped answer **90.5385/100** (Eco 1.0).
These fixtures are not recordings and do not satisfy the exit above. Real
salomero recordings, physical microphones/permissions and cultural review
remain unverified. The owner subsequently authorized Remo development assuming
validation works. That assumption is not evidence to complete this exit.

The physical-microphone checklist is in `README.md`; it still requires a person
to explicitly enable a device and test permissions, comfortable calls, Quiet
Mode and interrupted capture. Automated fixtures never open hardware.

**Automated validation (Godot 4.7.2, Windows):** import, all four game suites,
all 15 framework suites and bounded native launches passed. The scene suite
also passed actual OpenGL rendering at 320×568, 568×320, 1280×720 and
2560×1080 with normal and 150% UI size, including a standalone catalog.
`lives_mode_test` and `single_game_test` still log resources in use at shutdown
despite exiting 0; their origin has not been established. `saves_test` logs
the expected malformed-backup parse errors. Sailor Man's own suites and
launches had no engine errors. The synthetic tutorial was re-recorded from
the real buttons, validated, encoded and reimported.

**Recording recovery follow-up:** the expanded scene suite passed headlessly
and in a real graphics window, including all eight size/UI-scale combinations.
Stop drains queued PCM, captured silence still scores zero, and interrupted
turns neither count nor overwrite references. All 15 framework suites again
exited 0, with the same shutdown-resource warnings and expected bad-backup
errors noted above. This follow-up explicitly used the Dummy audio driver;
no physical microphone was opened. The walkthrough's synthetic-only flow is
unchanged.

**Offline WAV follow-up:** all four Sailor Man headless suites passed; the
affected pipeline/CLI regressions passed again after adding strict RIFF chunk
and PCM frame validation. The file matrix covers mono/stereo 8-/16-bit inputs
at 44.1/48/96 kHz. Actual commands verified provisional comparison/Eco reports,
unchanged input hashes and failure exits for missing takes/references, bad
arguments and damaged recordings. Valid padded metadata remains accepted.
All runs used Dummy audio and isolated profiles, with no engine/script errors
in the final checks. This is still synthetic evidence, not the real-voice exit.

## Milestone 2 — Remo mode (§4.5)

- [x] Declare bindings: Voice, Pitch up/down, Quiebre, Remate (keys + gamepad).
- [x] `voice/key_voice_source.gd` — virtual profile (chest 0, falsetto
      +700…+1300), 700-cent quiebre over 40 ms, glide 1800 cents/s.
- [x] `voice/touch_voice_source.gd` — hold, vertical drag, flick up and down,
      Break button, independent multitouch.
- [x] `ui/remo_ribbon.gd` — the drawing lane, with the call's contour for answers.
- [x] Labelled, original synthetic tone preview following the track's pitch.
      Real captain recordings remain Phase 6, not implied by this placeholder.
- [x] `tests/remo_source_test.gd` — inputs → frames; ideal Remo vs ideal sung
      within 5 %.
- [x] **Exit:** parity test green, and a Remo turn scores on the spike scene.

The owner approved this milestone under the assumption that the real-voice
gate works; Milestone 1 above remains unchecked. The ideal synthetic Remo and
normalized sung fixtures both score **91.3846/100**. All five game suites and
all 15 framework suites exited 0 with Dummy audio and isolated profiles, with
no script errors. Actual viewport-input regressions cover keyboard/gamepad/
multitouch, Eco, preview pitch, source switching, pause/resume and held-trigger
jitter across turns. The trigger regression failed before its fix. The scene
suite also passed all eight real OpenGL phone-to-ultrawide layouts with
normal/150% UI size, including multitouch at 320×568 and 150% UI.

The 21-second Remo walkthrough was re-recorded from actual keyboard events,
validated, encoded and reimported with a refreshed poster. Its call scored
**91.4434/100** and answer **92.7269/100**, with three breaks and Eco 1.0.
These are synthetic controls, not recordings or physical-device checks.

The existing framework shutdown-resource diagnostics and deliberate bad-backup
errors remain. Some scene runs also logged an intermittent shutdown resource
warning; verbose native tracing identified the shared `assets/audio/ui_back.wav`
and its playback, not Remo's generated tone. All scene assertions passed and
the process exited 0. This shared-audio cleanup issue was not changed here.

## Milestone 3 — Duel in a grey box (§3)

- [x] `duel/duel_state.gd` — tandas, call/answer, lead alternation, decider
      leader, tie to the answerer, best of three, retry, listening window
      (6 s / 9 s long, 1.2 s silence close), chamber clock that pauses inside
      windows.
- [x] `duel/judges.gd` — 3 or 5 judges, tastes (§6.3), 1–10 paddles, notes
      from scorer evidence.
- [x] `duel/rival_book.gd` — data shape for rivals, takes and difficulty bands;
      one placeholder rival with a synthetic track.
- [x] Bleed defences (§4.3): turn gating, 250 ms tail guard, cue pitched
      outside the scored band.
- [x] `ui/duel_hud.gd` — turn banner, ¡Ya! cue, window timer, paddles with numbers,
      judge cards with text and an icon, Repeat call.
- [x] `gameplay.gd` hooks (§7.3): one shell round = one duel for now; route
      frames from the active source to the scorer, then the shell's end-of-round path.
- [x] `_round_totals`, `_player_stats`, `_describe_round_outcome`,
      `_round_highlight_summary`.
- [x] Grey-box lock: two boxes for boats, water plane, walls.
- [x] Captions: rival call shape in words, ¡Ya!, verdicts (§9.5).
- [x] `tests/duel_state_test.gd`, `tests/duel_scene_test.gd` and the preserved
      `tests/sailor_scene_test.gd` practice path.
- [x] **Exit:** full duels against the placeholder rival by Remo and the
      buffered-PCM microphone path reach shell results; framework suites green.
      Physical-device QA remains open under the owner's real-voice assumption.

The owner approved continuing this milestone under the existing real-voice
assumption, not as evidence to check off Milestone 1. The owner resolved equal
winning margins in the decider rule: the loser of tanda two calls.

The first rival is the **Practice skiff**, an explicitly synthetic 3.6-second
call with two register breaks and a 120 ms finish. Its real scorer/judge band
and a reachable Remo win are tested; a short flat microphone take loses.
The single-player mode owns this rival instead of offering a duplicate generic
vs-CPU setup. No production crew, recorded voice or hot-seat mode is implied.
The 2400 Hz, 60 ms cue has a full 250 ms guard before capture admission.
The chamber's four-minute budget counts between turns, including a Repeat.
Buffered audio after the 1.2-second real-silence cutoff cannot enter the score.

Both source routes reach shell results in automated integration checks:
actual Remo viewport input and buffered PCM through the existing microphone
pipeline. The latter does not open or validate a physical microphone.
Named Soundcheck profiles and saved source selection are implemented in
Milestone 4 below. Measured acoustic room-tail protection remains later work.

**Final automated validation (Godot 4.7.2, Windows):** all seven game suites
and all 15 framework suites exited 0 with Dummy audio and isolated profiles;
none had script errors. Both scene suites passed real OpenGL layouts at
320x568, 568x320, 1280x720 and 2560x1080 with normal/150% UI. The duel suite
also checks actual boat-mesh corners, isolated worlds and a nonempty render
below 60 draw calls. Actual viewport keyboard, gamepad and independent touch
events exercise the admitted sources, not fabricated scores.

Focused regressions caught and now prevent stale hidden/disabled Remo controls
after microphone setup, elapsed time surviving replay or being erased by
pausing a rival, and cue playback remaining active as listening opens.
The cue is explicitly stopped before admission. The duel test also allows
the asynchronous audio mixer to release stopped playback before quitting;
its final headless and native runs had no engine errors.

The 32-second walkthrough completes a real 2-0 Remo duel and enters shell
results: its answer scores **87.0470/100** (Eco **0.621341**), and its call
**91.2670/100**, each with three breaks and Remate. The clip was recorded
natively, validated, encoded to silent 960x540/30 fps Theora, fully decoded
and reimported with a new 640x360 WebP poster. These are synthetic controls,
not performer recordings or microphone QA.

The preserved practice and pre-existing lives/single-game suites still log
intermittent shutdown-resource diagnostics despite passing. Verbose walkthrough
tracing identified shared `ui_click.wav`/`ui_focus.wav` playback, not recorded
voices; earlier practice tracing identified `ui_back.wav`. Those framework
diagnostics were not broadly changed here. The Saves suite's malformed-backup
parse errors are deliberate negative cases.

## Milestone 4 — Calibration (§4.2, §4.6, §4.7)

- [x] `voice/voice_calibration.gd` — validated scalar measurements, named profiles,
      `user://sailor_man_voice.cfg` (not a `save_files` entry), missing-falsetto
      fallback, merge saves and explicit damaged/newer/write failures.
- [x] `ui/soundcheck.gd` / `.tscn` — Room · Speak · Low · High · Call, device
      picker, explicit Enable, comfortable-voice/headphones tips, Skip high,
      saved-profile reuse and a denied/dead-mic **Use Remo** exit. Only Save
      publishes a complete profile; cancelling preserves earlier measurements.
- [x] Persisted input source tunable: Auto / Microphone / Remo. Selection
      never opens hardware; Auto falls back on unavailable/failed input.
- [x] Quiet Mode uses measured speaking RMS and bypasses the carrying-level
      gate without changing range or mark weights. Sensitivity remains available.
- [x] Optional voice-rest card: six completed voiced microphone turns in a
      rolling ten minutes suggest water/rest or Remo between duels. Failed,
      silent, cancelled and Remo turns do not count; dismissal is non-coercive.
- [x] Thread-free web analysis policy: eight detector windows per live update;
      Stop and deadlines drain queued samples without truncation. Explicit
      Enable is the gesture boundary. Actual browser/device QA remains open.
- [x] `tests/voice_calibration_test.gd`, `tests/soundcheck_scene_test.gd` and
      focused pipeline/deadline regressions.
- [x] **Automated exit:** a fresh synthetic-PCM profile calibrates and
      round-trips; denied/missing input has a usable Remo path. This verifies
      implementation, not real microphones, permissions or authentic voices.

The owner selected the pre-duel entry rather than extending shared Settings.
Soundcheck suspends the chamber clock and preserves a pending answer. Its
checked capture stays in the tree when the overlay closes: adoption transfers
the reference, never reparents/restarts the live audio node. Quiet Mode uses
the separately measured speaking level; Remo retains its own authored band.
Only scalar profiles persist, never PCM/tracks or rest-reminder timestamps.

**Automated validation (Godot 4.7.2, Windows):** all nine game suites and all
15 framework suites exited 0 with Dummy audio and isolated profiles, with no
script errors. All three native scene suites passed at 320x568, 568x320,
1280x720 and 2560x1080 with normal/150% UI. Soundcheck covers Room, High,
recording Call and Complete, including the visible chest-relative ribbon,
pinned 44px actions and save errors revealed from a scrolled view.
Regressions also cover measured high breaks/fallbacks, raw-RMS normalization,
named selection without activation, non-reparented handoff, preserved pending
answers, bounded Stop/deadline finishing, actual-silence cutoffs, device
mismatches, Auto failures and optional rest actions.

The refreshed 32-second walkthrough completes the real 2-0 Remo duel and
shell results, now with an accurate Soundcheck/privacy caption. The silent
960x540/30 fps Theora clip was fully decoded before replacement, with a new
640x360 WebP poster; asset import and the framework instructions-video suite
passed again. It contains synthetic controls, not microphone recordings.

Known shared UI-WAV shutdown-resource diagnostics remain despite passing
assertions and exit codes. Invalid-profile/microphone warnings and the Saves
suite's malformed-backup errors are deliberate negative cases. No physical
microphone was opened. Acoustic room-tail measurement, real device/browser/
mobile permissions, authentic recordings and cultural review remain unverified.

## Milestone 5 — The canal (§8)

- [x] `world/mesh_builder.gd` — locally adapt/prune the Cube Trials batcher;
      no cross-game runtime dependency, Compatibility materials/palette.
- [x] `world/canal_view.gd` — isolated `SubViewport`, two-shot, ease toward the
      singer, fixed under reduced motion.
- [x] `world/boat_rig.gd` — reusable original hull, cabin, deck, fenders, plain
      crew, seat paint/pennant, explicit P1/CPU plaques and empty hat/bow slots.
      No captain roster, traditional costume or store is implied.
- [x] `world/lock_set.gd` — walls, miter gates, mulas on rails, water level
      driven by the chamber clock.
- [x] `world/scenery.gd` — practice-lock tabletop, tropical banks, palms/hills.
- [x] Remaining scenery — lake islands/howlers/ships, cut terraces and cable
      bridge, Pedro Miguel evening town, Pacific arch/skyline/causeway/bunting.
- [x] `world/crowd.gd` — batched plain toy spectators; waves off under reduced motion.
- [x] `world/voice_ribbon.gd` — admitted, source-relative pitch unrolls over
      water; silent gaps remain gaps and amplitude cannot widen it. Static
      quiebre diamonds use scorer evidence and disappear with intense effects off.
- [x] `canal_arenas.gd` and shared manifest levels — all five free practice
      selections with real scene-derived icons; no voyage unlocks/progress.
- [x] Clear practice modifiers (§5.3): rising/descending lock clock, free
      once-only open-water Repeat, lake drift, and five actual Pacific judges
      through scoring/HUD/totals/shell results. Listening deadlines are unchanged.
- [x] Culebra self-echo practice — fresh unscored seed, fixed profile/Quiet Mode,
      600 ms quiet returns, normal best-of-three, separate from skiff practice.
      Completed pitch frames only; no live monitoring or recorded-voice playback.
      Campaign boss placement remains Milestone 7.
- [x] `audio/sailor_audio.gd` — original synthesized lock horn, water wash,
      applause, paddle clack and mula bell on game-owned SFX players.
- [x] Quiet input states and once-only event feedback: no environmental audio
      under reference/repeat, guard, listening, Soundcheck or Practice. Selecting
      Microphone silences it before Enable; completion stops capture first.
- [x] Meaningful combined audio captions in the visible, responsive duel HUD,
      independent of SFX mute; the persistent YA header leaves listening room clear.
- [x] `tests/sailor_audio_test.gd` and real-duel regressions for PCM/seams,
      context cancellation, captions, guarded input and genuine timeout feedback.
- [ ] Production conch-style ready cue, preserving the above-band cue/guard
      contract and only after separate bleed validation.
- [ ] Optional cruise-only music bed when cruise flow exists; no duel music.
- [x] `tests/canal_view_test.gd` *(window)* — both boats in shot, ribbon
      readable, < 60 draw calls, portrait → ultrawide, Remo lane clear of the singers.
- [x] **Practice-lock exit:** all game/framework/native suites pass; refreshed
      real-input tutorial/poster validated and fully decoded. Other arena/art/audio
      items above remain open; the full Milestone 5 is not complete.

**Automated validation (Godot 4.7.2, Windows):** all ten game suites and all
15 framework suites passed with isolated profiles and Dummy audio, without
script errors. Nine game suites support headless runs; the new canal suite
requires a graphics window. All three existing scene suites also passed
natively. The canal suite renders both singer framings at both water endpoints
across 320x568, 568x320, 1280x720 and 2560x1080 with normal/150% UI. Its maximum
was **21 draw calls**, with complete boats, distinct paint/labels and actual
visible contour pixels. Rendered frames were inspected.

Regressions cover water/attached tow lines, mid-ease reduced-motion toggling,
pause/hidden-view shutdown, source-profile forwarding, amplitude invariance,
silent gaps, effects-off contours and clearing/restoring tracks on replay or
cancellation. Native checks read MultiMesh transforms; the headless dummy
renderer does not retain those transforms.

The refreshed real-input walkthrough still completes the same 2-0 duel and
shell results: **87.0470/100** for the answer (Eco **0.621341**) and
**91.2670/100** for the call, each with three breaks and Remate. The silent
960x540/30 fps Theora clip fully decodes to **962 timeline frames / 32.066667 s**,
with a new 640x360 WebP poster. Reimport and both headless/native instructions-
video checks passed. No microphone was opened. Existing shared-audio shutdown
diagnostics and the Saves suite's deliberate damaged-backup parse errors remain.
At that practice-lock checkpoint, other arenas/modifiers, production audio,
physical-device/browser/mobile QA, authentic recordings and cultural review
were still open; subsequent slices are recorded below.

**Canal-audio follow-up:** all **eleven** game suites and all **15** framework
suites passed with isolated profiles and Dummy audio; ten game suites support
headless runs and the canal suite requires a window. All four native runs also
passed. The duel verifies actual visible, wrapped verdict captions at all eight
size/UI combinations, with the full compact input ribbon retained; requests
alone were insufficient because the shell's default margins are hidden here.
The existing shell caption is now mounted in the duel, not duplicated.

PCM checks cover deterministic original clips, headroom/DC, smooth ends and
the water seam. Real events cover muted-SFX captions, once-only review/tanda/
completion feedback, source/room/setup silence, reference/repeat, guard,
listening, pause, focus, replay and teardown. Incoming menu music is stopped;
no microphone opens automatically and no scoring/clock rules changed.
Final own-audio checks have no shutdown warnings; existing shared UI-audio
diagnostics and the Saves negative cases remain. No physical output, room-tail,
device/permission, authentic-voice or cultural gate is thereby checked off.
The walkthrough remains silent with its existing visual/caption flow.

**Free-practice arena follow-up:** all **eleven** game suites and all **15**
framework suites passed with isolated profiles and Dummy audio, without script
errors. All four windowed runs passed. The canal suite covers all five arenas
across **40 arena/size/UI combinations**, both singers and both chamber endpoints,
with a maximum of **23 draw calls**. It checks actual paint/contours and
pixel differences when individual landmarks are hidden, including the howlers,
not only named nodes. Rendered dioramas and representative frames were inspected.

The real shared setup selects each arena/icon without unlocking or opening a
microphone. Scene regressions check both lock deadlines and water directions,
level open water without ghost walls/tethers or filling/mula audio, free
once-only Repeat, drift-attached contours and a full five-judge Remo win through
shell results/replay. Retry retains the arena and clears duel-local results.
`tools/capture_art.gd` generated all five 640x360 setup PNGs from the actual
models; final import passed. The default Gatún tutorial's visuals/flow are
preserved, so its silent clip is unchanged. No campaign, echo boss, production
voices, physical-device/acoustic, browser/mobile or cultural gate is complete
because of these automated results.

**Self-echo follow-up:** the owner selected a separate seeded best-of-three
challenge. **Challenge your echo** appears only in Culebra; **Skiff practice**
returns before seeding. Real input captures an unscored seed through the
existing guard/window, then the same scorer/judges evaluate its fixed frames,
profile and Quiet Mode against later performances. Every echo/repeat waits
600 ms; interruption restarts the full gap and call caption. The echo uses
a softer neutral tone, not microphone audio. No tracks or mode choice persist.
The seed cannot inflate turn counts, points, tandas or result maxima.

All **eleven** game suites and all **15** framework suites passed with isolated
profiles and Dummy audio, without script errors. All **four windowed runs**
passed; native canal coverage remains **40 arena/size/UI combinations** and
**23 maximum draw calls**. The expanded duel suite checks seed-ready/listening
and echo review at all eight phone-to-ultrawide/normal-150% UI layouts.
Rendered frames were inspected. A real buffered-PCM seed is beaten 2-0 by
actual Remo input, with unchanged snapshot/profile, proper ECHO labels and
shell results. A fresh Remo seed also reaches an echo win. Replay requires
a new seed and clears old playback caches; ordinary skiff practice remains usable.

Silent/interrupted/missing seeds, idle PCM discard, guarded admission,
delayed free Repeat, pause/reannounced playback and fresh source-profile
selection are covered. Existing shared UI-audio shutdown diagnostics and
deliberate bad-profile/backup/capture negatives remain; the new duel runs
have no shutdown-resource errors. No physical microphone/output, acoustic,
browser/mobile, authentic-recording or cultural gate is thereby complete.
Campaign encounters/progression remain unimplemented. Default Gatún's tutorial
flow/visuals are unchanged, so its silent clip is not re-recorded.

## Milestone 6 — Voices (§11) — blocked on §15.2

- [ ] Recording plan: rivals (clean and rough takes), captains (sustained
      vowels + breaks), consent forms, payment, credits.
- [ ] `tools/analyse_takes.gd` — raw → processed OGG + `.track` file.
- [ ] Raw recordings kept outside export (`.gdignore` or outside the repo).
- [ ] Fill `rival_book.gd` for all ten rivals (§6.2), including the Howlers
      interlude (unscored).
- [ ] Captains `capt_tito`, `capt_yari`, `capt_abuela` with Remo voices.
- [ ] `tests/rival_book_test.gd` — every take loads, sits in its band, every
      boss is beatable with a reachable score.
- [ ] **Exit:** no synthesized rival left in `assets/voices/`.

## Milestone 7 — Campaign (§5)

- [ ] `campaign/voyage.gd` — level → duels → cruise → boss; duels won stay won
      within an attempt; shell round = one level in solo.
- [ ] `LEVELS` with achievement gates (§5.2), free play after the champion.
- [ ] Cruise segments: non-interactive, next rival's intro card.
- [ ] Progress in `user://sailor_man.cfg` (declared `save_files`), merging
      rather than rebuilding, never regressing.
- [ ] Achievements (§9.1) — all eleven keys, each reachable in Remo and Quiet Mode.
- [ ] `intro.tscn` — five story cards (§1).
- [ ] Instructions copy + glossary card; tutorial says the marks are a simplification.
- [x] `tools/capture_art.gd` — practice arena stills to `assets/levels/`;
      regenerate when the later campaign changes those views.
- [ ] `tests/voyage_test.gd`.
- [ ] Cultural review pass over every *(verify)* item (§11.2).

## Milestone 8 — Shell features

- [x] Hot seat: `supports_multiplayer`, `local_multiplayer_turns`, "Pass the
      mic" card with name, colour and P1/P2, per-seat calibration profile.
      Two actual singers, all five free-practice arenas, no chamber timeout,
      source/profile/rest isolation, safe handoffs and shared results/replay.
- [ ] `character_preview.tscn` — captain on the setup plinth.
- [ ] Store (§9.2): Balboas, slots hat/pennant/paint/bow, starter items,
      `store_preview.tscn` covering both boat and captain.
- [ ] Gallery (§9.3): exhibits with level gates, `gallery_stage.tscn` with
      `configure`, `set_view` and `set_auto_spin`.
- [ ] Share card (§9.4): `share_art.tscn`, best-turn ribbon from scorer evidence.
- [ ] `GameTheme` (§8.3) + `assets/game-icon.png` captured from the model.
- [ ] Credits, including every recorded voice.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`, `record_tutorials.ps1`).

**Two-human follow-up:** implemented ahead of blocked production voices/campaign,
under the owner's all-practice/untimed choices. P1 calls tanda one, P2 leads
tanda two and the existing tie/decider rules apply. Both performances use the
same scorer and actual arena judge count. Named P1/P2 pass cards offer separate,
session-local source/profile choices; a new singer inherits no other calibration.
Opening/selecting requests no microphone access. Capture stops after each turn
and before free Repeat; cancellation preserves the completed caller. Soundcheck
Save/use applies only to its seat, with fresh checked capture adopted without
reparent/restart. Rematches retain seat choices, not tracks/scores or capture.
Per-singer rest offers do not count another person's turns or change their source.

All **eleven game suites**, all **15 framework suites** and all **four windowed
runs** passed with isolated profiles and Dummy audio, without script errors.
Real shared setup/briefing covers all five arenas. Actual Remo input reaches
both P1 and P2 2-0 wins, including five Pacific judges and both shell result
scores. Buffered 160/280 Hz PCM checks separate measured/unmeasured profiles,
unchanged caller references and explicit fresh P2 Soundcheck Save/adoption.
All eight phone-to-ultrawide/normal-150% UI layouts cover both handoffs, live
input and reviews, with actual P2 touch/gamepad input. A short-landscape focus
regression failed before Ready was revealed after the final action-row layout;
profile scrolling remains usable. Rendered frames were inspected. Native
canal coverage remains **40 arena/size/UI cases** and **23 maximum draw calls**.

Existing shared-audio shutdown-resource diagnostics remain in Soundcheck and
some scene/framework runs; deliberate capture/profile/backup negatives remain.
The expanded duel runs have no shutdown-resource errors. No physical-device/
permission/output, acoustic-tail, browser/mobile, authentic-recording or
cultural gate is complete. The existing silent solo Gatún tutorial's gameplay
visuals/captions are unchanged, so it was not re-recorded. Campaign progression,
recorded opponents, store/gallery and shipping assets remain pending.

## Milestone 9 — Polish and integration (§12)

- [ ] Accessibility sweep against §9.5.
- [ ] Web and mobile mic passes; Android/iOS record-audio permission.
- [ ] `project.godot`: `config/name.sailor_man`, `custom_user_dir_name.sailor_man`
      (after the title is fixed), `config/icon.sailor_man`,
      `dcs/build/single_game_id.sailor_man`, `[share] stats_urls/sailor_man`
      (≤ 42 bytes), `driver/enable_input` kept on.
- [ ] `export_presets.cfg`: standalone preset; exclude `games/sailor_man/*`
      from other presets; keep `tools/` and raw recordings out.
- [ ] Remote for this repository → `.gitmodules` + gitlink (two commits).
- [ ] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, blurb. `godot-base/README.md` if it lists games.
- [x] Folder `README.md` documents the current prototype and its limitations.
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.

## Stretch (§14)

- [ ] Spanish localisation (unless pulled into v1)
- [ ] "Salomar to the shore" cruise practice
- [ ] More rivals per level
- [ ] Grito-only quick-fire mode
- [ ] Daily rival
