# Sailor Man — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §14, with a scaffolding phase first. Tick a box only when
the item works **and** its tests pass; each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

---

## Blocked on the owner (DESIGN §15)

These change names, keys or scope that become permanent once shipped. Nothing
below that depends on one should start until it is answered.

- [ ] **Title** (§15.1) — fixes `custom_user_dir_name` forever. Blocks the
      `project.godot` feature-tag entries in Phase 9.
- [ ] **Cultural partner** (§15.2) — blocks the Milestone 1 real-voice gate,
      Phase 6 recordings and the Phase 7 review.
- [ ] **Spanish localisation in v1?** (§15.3) — if yes, route all copy through a
      translation table from Phase 0 rather than retrofitting it.
- [ ] **Champion title gender** (§15.4) — "Rey / Reina del Canal" or neutral.
- [ ] **Three-seat hot seat in v1?** (§15.5) — `max_local_players` 2 or 3.
- [ ] **Grito as its own move?** (§15.6) — affects scorer marks and bindings.
- [ ] **Real place names** (§15.7) — Gatún, Culebra, Miraflores and so on,
      without canal-authority branding.
- [ ] **"Recalibrate voice" button on the Game tab** (§10) — tunables only
      support slider, toggle and choice. Decide: add a generic action-row field
      to `GameManifest` (a framework change, as data), or open Soundcheck
      somewhere else, such as from the pre-duel card.

## Discrepancies found while planning

- [ ] `mesh_builder.gd` lives in `games/cube_trials/world/`; Chicken Pit has no
      `world/` folder. Copy it from Cube Trials (§7.1 says "chicken_pit/cube_trials").
- [ ] The project targets Godot **4.7**, but this machine has **4.6.2**
      (`/usr/bin/godot`). Install 4.7 before trusting any test result.
- [ ] Hot seat arenas: §3.5 says "any unlocked level", while §5.2 says every
      arena only after the champion. Pick one and fix `DESIGN.md`.
- [ ] Dulce's Adventure (`menu_order = 9`) has only a `DESIGN.md` so far.
      Keep `10` anyway so the order doesn't shift later.

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from here on.

- [ ] Commit `DESIGN.md` and this `TODO.md` to the game repository.
- [ ] Folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has.
- [ ] `sailor_man_options.gd` — constants-only: `GAME_ID`, tunable keys (§10),
      binding keys (§4.5), with empty `LEVELS`, `CAPTAINS`, store and gallery for now.
- [ ] `game.gd` — minimal manifest (§7.4): id, title, tagline, `menu_order = 10`,
      `CONTROL_STYLE_CUSTOM_KEYS`, `uses_shell_round_rules = false`, tunables,
      bindings. Leave multiplayer off until Phase 8.
- [ ] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [ ] `tests/` folder and a smoke test that loads the manifest by path.
- [ ] `godot --headless --path . --import`
- [ ] **Exit:** all 15 framework suites exit 0 with `--game=all`, and
      `godot --path . -- --game=sailor_man` opens the stub.

## Milestone 1 — Scorer spike (§4.1, §4.4) ⚠ riskiest

- [ ] `voice/voice_frame.gd` — `{t, cents, voiced, level}`, 100 Hz.
- [ ] `tests/voice_track_fixture.gd` — synthetic track builder: hold, glide, jump,
      gap, wobble, fade, cut-off, all relative to a profile.
- [ ] `duel/saloma_scorer.gd` (`RefCounted`, every threshold a top-level const):
  - [ ] Voiced segments: 40 ms hysteresis, bridge gaps ≤ 60 ms
  - [ ] Aliento: longest segment / 5 s
  - [ ] Quiebre: ≥ 500 cents in ≤ 90 ms into/out of the falsetto band, cleanness,
        softer rule (≥ 400 at 0.8), octave guard
  - [ ] Altura: p90 − p10 against the calibrated range
  - [ ] Remate: falling glide ≥ 300 cents or crisp stop; fade = half
  - [ ] Eco: median-relative contours, resample to 64, DTW with a ±12 % band,
        distance curve (sincere ≈ 0.6, near copy ≈ 0.9)
  - [ ] Weights, Eco = 0 on calls with the rest rescaled, Fuerza gate (−20 %),
        Quiet Mode bypass
  - [ ] Evidence output: break positions and the longest-breath span
- [ ] `tests/saloma_scorer_test.gd` — every case in §13.
- [ ] `tests/voice_normalisation_test.gd` — low and high profile within 2 %.
- [ ] Port from `dead_metal_jam/input/` (copy, never import):
  - [ ] `voice/mic_capture.gd` — muted "Saloma" bus, dead-mic test
  - [ ] `voice/pitch_detector.gd` — MPM, 70–1100 Hz, continuous cents
  - [ ] `voice/voice_track.gd` — smoothing, voicing hysteresis, octave guard
        that keeps real jumps
  - [ ] `voice/mic_voice_source.gd` — emits `VoiceFrame`s
- [ ] `tools/scorer_spike.tscn` — record one mic turn, print the five marks and
      draw the track. Dev-only.
- [ ] **Exit:** a real saloma and a flat yell score clearly differently on the
      spike, checked against real salomero recordings (blocked on §15.2).
      Record the numbers here before moving on.

## Milestone 2 — Remo mode (§4.5)

- [ ] Declare bindings: Voice, Pitch up/down, Quiebre, Remate (keys + gamepad).
- [ ] `voice/key_voice_source.gd` — virtual profile (chest 0, falsetto
      +700…+1300), 700-cent quiebre over 40 ms, glide 1800 cents/s.
- [ ] `voice/touch_voice_source.gd` — hold, vertical drag, flick up and down,
      Break button, independent multitouch.
- [ ] `ui/remo_ribbon.gd` — the drawing lane, with the call's contour for answers.
- [ ] Placeholder captain voice, pitch-shifted along the track (synth allowed for now).
- [ ] `tests/remo_source_test.gd` — inputs → frames; ideal Remo vs ideal sung
      within 5 %.
- [ ] **Exit:** parity test green, and a Remo turn scores on the spike scene.

## Milestone 3 — Duel in a grey box (§3)

- [ ] `duel/duel_state.gd` — tandas, call/answer, lead alternation, decider
      leader, tie to the answerer, best of three, retry, listening window
      (6 s / 9 s long, 1.2 s silence close), chamber clock that pauses inside
      windows.
- [ ] `duel/judges.gd` — 3 or 5 judges, tastes (§6.3), 1–10 paddles, notes
      from scorer evidence.
- [ ] `duel/rival_book.gd` — data shape for rivals, takes and difficulty bands;
      one placeholder rival with a synthetic track.
- [ ] Bleed defences (§4.3): turn gating, 250 ms tail guard, cue pitched
      outside the scored band.
- [ ] `ui/duel_hud.gd` — turn banner, ¡Ya! cue, window timer, paddles with numbers,
      judge cards with text and an icon, Repeat call.
- [ ] `gameplay.gd` hooks (§7.3): one shell round = one duel for now; route
      frames from the active source to the scorer, then the shell's end-of-round path.
- [ ] `_round_totals`, `_player_stats`, `_describe_round_outcome`,
      `_round_highlight_summary`.
- [ ] Grey-box lock: two boxes for boats, water plane, walls.
- [ ] Captions: rival call shape in words, ¡Ya!, verdicts (§9.5).
- [ ] `tests/duel_state_test.gd`, `tests/sailor_scene_test.gd` (first pass).
- [ ] **Exit:** a full duel against the placeholder rival, by mic and by Remo,
      to the results panel. Framework suites green.

## Milestone 4 — Calibration (§4.2, §4.6, §4.7)

- [ ] `voice/voice_calibration.gd` — profile shape, named profiles,
      `user://sailor_man_voice.cfg` (not a `save_files` entry), missing-falsetto
      fallback.
- [ ] `ui/soundcheck.tscn` — Room · Speak · Low · High · Call, device picker,
      dead/denied-mic message with a "Use buttons" path, headphones tip,
      skippable after the first time.
- [ ] Input source tunable: Auto / Microphone / Remo.
- [ ] Quiet Mode and mic sensitivity tunables wired to scorer and capture.
- [ ] Voice-health card: 6 sung turns in 10 minutes → suggest water, offer Remo.
- [ ] Web: Soundcheck acts as the user-gesture gate; detector budget without threads.
- [ ] `tests/voice_calibration_test.gd`.
- [ ] **Exit:** a fresh profile calibrates, round-trips, and a denied mic
      falls back to Remo without a dead end.

## Milestone 5 — The canal (§8)

- [ ] `world/mesh_builder.gd` — copy from `cube_trials/world/`, adapt.
- [ ] `world/canal_view.gd` — isolated `SubViewport`, two-shot, ease toward the
      singer, fixed under reduced motion.
- [ ] `world/boat_rig.gd` — one rig for every boat: hull, paint, pennant (seat
      colour + P1/P2 plaque), hat and bow slots.
- [ ] `world/lock_set.gd` — walls, miter gates, mulas on rails, water level
      driven by the chamber clock.
- [ ] `world/scenery.gd` — jungle banks, lake islands, cut terraces, both
      bridges, Pacific skyline.
- [ ] `world/crowd.gd` — batched spectators; waves off under reduced motion.
- [ ] `world/voice_ribbon.gd` — ribbon unrolls over the water from the pitch
      track, quiebre sparks (no flash with intense effects off).
- [ ] Arena modifiers (§5.3): lock clock, lake Repeat, Culebra echo
      (600 ms, self-duel boss), Pacific five-judge panel.
- [ ] `audio/sailor_audio.gd` — conch, lock horn, water roar, crowd, paddle
      clack, mula bell, cruise-only music bed.
- [ ] `tests/canal_view_test.gd` *(window)* — both boats in shot, ribbon
      readable, < 60 draw calls, portrait → ultrawide, Remo lane clear of the singers.

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
- [ ] `tools/capture_art.gd` — level stills to `assets/levels/`.
- [ ] `tests/voyage_test.gd`.
- [ ] Cultural review pass over every *(verify)* item (§11.2).

## Milestone 8 — Shell features

- [ ] Hot seat: `supports_multiplayer`, `local_multiplayer_turns`, "Pass the
      mic" card with name, colour and P1/P2, per-seat calibration profile.
- [ ] `character_preview.tscn` — captain on the setup plinth.
- [ ] Store (§9.2): Balboas, slots hat/pennant/paint/bow, starter items,
      `store_preview.tscn` covering both boat and captain.
- [ ] Gallery (§9.3): exhibits with level gates, `gallery_stage.tscn` with
      `configure`, `set_view` and `set_auto_spin`.
- [ ] Share card (§9.4): `share_art.tscn`, best-turn ribbon from scorer evidence.
- [ ] `GameTheme` (§8.3) + `assets/game-icon.png` captured from the model.
- [ ] Credits, including every recorded voice.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`, `record_tutorials.ps1`).

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
- [ ] Folder `README.md` written properly.
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.

## Stretch (§14)

- [ ] Spanish localisation (unless pulled into v1)
- [ ] "Salomar to the shore" cruise practice
- [ ] More rivals per level
- [ ] Grito-only quick-fire mode
- [ ] Daily rival
