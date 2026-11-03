# Sailor Man

Read the root `AGENTS.md`, then `DESIGN.md` and `TODO.md`. The design describes
the target game; the current implementation has five free toy-canal practice
arenas against one synthetic skiff, an optional Culebra self-echo challenge and
two-human hot seat, plus the microphone/Remo scorer workbench. Do not advertise
a finished voyage or recorded salomero opponents.

## Current scope

- The owner confirmed **Sailor Man**, English-first copy with Spanish saloma
  terms, two-human hot seat in v1, and grito as part of Remate.
- The manifest enables solo practice and two-human hot seat through shared setup.
  It declares `supports_multiplayer` and `local_multiplayer_turns`, with two seats.
  The game owns its placeholder rival; it does not offer a second generic
  vs-CPU setup mode.
  Soundcheck and named calibration profiles are implemented. Campaign,
  production rival crews, store and gallery are not implemented.
- Real canal place names are owner-approved without authority branding.
  Gatún, the lake, Culebra, Pedro Miguel and Pacific have original toy scenery.
  The owner chose freely selectable practice through the existing level selector,
  not campaign gates. Ordinary practice still faces the synthetic skiff.
  The owner chose a separate Culebra self-echo challenge: a fresh unscored
  seed, then best-of-three against that fixed snapshot. It is not a voyage
  boss encounter or live microphone monitoring.
  Hot seat has all five practice arenas from the start and no chamber timeout;
  campaign-aware hot-seat access is still undecided.
  Plain crew/spectators imply no traditional dress or reviewed cultural assets.
- No performer recordings or cultural partner are available yet. Synthetic
  fixtures prove algorithm behavior, not authentic saloma quality. The real
  recording comparison in DESIGN Milestone 1 remains unverified. The owner
  explicitly authorized Remo and grey-box duel work assuming validation works;
  that is not evidence to check off the authentic-recording gate.
- The SVG icon and walkthrough are prototype presentation assets required by
  the framework's catalog-wide tests, not finished game art.
- `tools/analyse_takes.gd` is read-only WAV analysis for the recording gate,
  not the later rival-track baking pipeline. Its provisional reports cannot
  certify authentic salomas, performer consent or cultural review.

## Model contracts

- `voice/voice_frame.gd` defines consecutive 100 Hz dictionaries:
  `{t, cents, voiced, level}`. Pitch is relative to `chest_hz`; linear level is
  relative to `carry_level` and capped at 1.
- The scoring profile is `{chest_hz, falsetto_low, falsetto_high,
  falsetto_calibrated, carry_level}`. Falsetto bounds are relative cents.
  Never treat the temporary default band as a measured calibration.
- `voice/voice_track.gd`, `voice/mic_voice_source.gd`,
  `voice/key_voice_source.gd`, `voice/touch_voice_source.gd` and
  `duel/saloma_scorer.gd` are node-free and autoload-free. Remo uses explicit
  events, never hardware polling. Touch inherits the key source's 100 Hz clock,
  pitch speed and register transitions; keep authored tracks on this same path.
- Remo's authored 700-1300-cent band uses the calibrated-band scoring rule;
  that must never mark a human microphone profile as measured. Explicit
  Remate retains 120 ms of unvoiced frames; a timeout must not invent a finish.
- The scorer returns `valid`, marks, total and evidence; invalid input has
  an explicit error. Do not turn malformed tracks into plausible zero scores.
- Keep thresholds at the top of the scorer. Preserve sustained register
  jumps when removing short octave glitches, and do not confuse a single
  register drop with a falling Remate.
- The detector/capture were adapted locally from Dead Metal Jam. Do not add
  runtime imports from another game or game-name branches to the framework.
- `duel/duel_state.gd` alone owns tandas, leads, ties, clocks and the winner.
  Equal winning margins give the decider call to the loser of tanda two.
  `judges.gd` reweights the scorer's marks; `rival_book.gd` uses that same
  scorer. The synthetic rival must remain beatable through actual Remo input.
- Hot seat admits two actual human performances per tanda: P1 calls first,
  P2 leads tanda two, then the existing decider rule applies. The legacy
  `Singer.RIVAL` slot is actual P2 in this mode, never synthetic input.
  It forcibly disables the chamber clock, including locks, not the six/nine-second
  windows or guard. Both singers can use once-only free Repeat before answering.
  Keep caller frames/profile/singer separate from the next input lane; Repeat
  uses that completed caller's contour as a neutral tone with capture closed.
  Results/statistics count each singer's actual turns. Replay clears both
  scores/tracks/references but preserves session-local profile/source choices.
- Self-echo reuses the guarded player window for its seed; only a completed
  voiced track can seed it. Seed capture awards no points/records/tandas.
  `rival_book.gd` deep-copies frames, the actual source profile and Quiet Mode;
  later input/profile/settings changes must not rewrite them. The original
  scorer, lead/tie/decider rules apply without an echo handicap.
  `duel_state.gd` owns the 600 ms quiet gap before every echo/repeat.
  Paused playback restarts the full gap and reannounces the call caption.
  Only the completed snapshot drives its softer neutral tone, never live PCM.
  Echo replay drops all seed/playback tracks and requires a new seed.
  Returning to ordinary practice drops echo mode; neither choice is saved.
- `canal_arenas.gd` is the autoload-free source for five stable arena IDs,
  captions and rule data. Its `levels()` supplies the shared manifest selector;
  gameplay reads `GameSession.selected_level()`. Do not add a second selector
  or put an arena ID in Settings. Selection survives replay, not app restart.
  In solo, only locks consume the chamber clock; open-water Repeat is once-only
  and free.
  Hot seat is untimed in all arenas and parks lock water at its initial height.
  Every arena retains the listening deadline/guard. Pacific uses five actual
  judges throughout scoring, HUD, totals and results, not just extra labels.
- `voice_calibration.gd` is the unscored Room/Speak/Low/High/Call model and
  scalar-only profile codec. Only complete validated measurements save;
  skipped/unobserved high breaks retain `falsetto_calibrated = false`.
  A preview range is for drawing, not a usable or saveable profile.

## Microphone and UI

- Capture starts only after **Enable microphone**. Opening scenes, selecting
  profiles/sources, tutorial recording and tests must not request microphone access.
- Soundcheck is a game-owned **pre-duel button**, not a shared Settings action
  row. The overlay suspends duel stepping and blocks underlying input. Back,
  pause, focus loss and failure discard partial takes without touching a save.
- The two-second room check alone is not full calibration. The dev workbench
  retains temporary manual references; gameplay uses the saved human profile.
  Keep that profile separate from Remo's authored band. Quiet Mode substitutes
  measured speaking RMS, never pitch/range/mark weights.
- Never monitor microphone audio or persist PCM/tracks. Only completed named
  scalar profiles/selection belong in `user://sailor_man_voice.cfg`; it is not
  progress or a `save_files` entry. Refuse damaged/newer files without rewriting
  them. Source/reminder options use the shared Settings persistence.
- The game-owned **Challenge your echo** entry exists only on Culebra's ready
  card. **Skiff practice** returns before seed capture; the shell's replay
  preserves echo mode but not the seed. The seed remains excluded from duel
  results, though completed voiced mic seeds count toward the rest reminder.
- Soundcheck mounts capture beside the transient overlay, not beneath it.
  Adoption transfers the reference, **not the node's parent**: a tree exit
  stops `MicCapture` and its `AudioStreamPlayer`. Release the owned bus on failure,
  pause and scene exit;
  identify it by its unique name, not a stale bus index.
- Auto prefers an available calibrated device, otherwise Remo. It does not open
  hardware, and a failed mic falls back without rewriting the Auto preference.
- Human cards start without a selected profile. Their profile/source choices
  are independent and session-local, not edits to the saved source default.
  Only explicit Soundcheck Save/use writes calibration/selection and adopts it
  for the active seat. New P2 Soundcheck must not preselect P1 or the file's last
  selected name. Source/profile selection never opens hardware; capture stops
  after each completed human turn and before Repeat. Do not reparent checked
  capture when adopting a fresh Soundcheck result.
- Live web analysis yields after eight detector windows. Zero-budget pushes
  queue only; default `-1` is unlimited for offline work. Drain bounded pending
  analysis before `finish`; cancellation drops it. A wall-clock deadline stops
  capture, not already queued analysis. Preserve the actual-silence frame cutoff.
- Rest reminders count only completed voiced microphone turns, six in a rolling
  ten minutes. They stay session-local across replays and offer a choice only
  between duels. Hot-seat counts are per singer; an offer may appear on that
  singer's first handoff of a new duel. Their Remo choice affects only that seat.
  Dismissal, disabled reminders and Remo must remain non-coercive.
- Keep errors visible and the explicitly synthetic examples usable when a
  microphone is absent, disabled or denied. Extra amplitude earns no points.
- Starting Remo disconnects capture. Its neutral synthetic preview is on the
  SFX bus, labelled as a tone, not an authentic or recorded captain voice.
  Stop it on finish, cancellation, pause, focus loss and source changes.
- `audio/sailor_audio.gd` owns original non-vocal SFX players, not shared-pool
  voices or delayed callbacks. Only Remo review/ready states allow decorative
  judge feedback; filling water and mula bells belong to locks only.
  Reference/repeat, guard, listening, Soundcheck,
  Practice and pause stay quiet; selecting Microphone already silences them
  before Enable. Final feedback waits for capture to stop. Stop on focus loss,
  source changes, results/replay and exit; do not infer a new score in audio.
- Meaningful simultaneous sounds emit one combined caption through AudioManager.
  The duel mounts the existing shell caption outside its hidden default margins,
  below the scroller. The permanent YA header captions listening without a second
  row shrinking the input ribbon. Clear stale captions on context changes.
  Preserve the above-band 60 ms cue/250 ms guard; the conch-style cue, cruise
  music and physical acoustic-tail validation are still pending.
- Preserve independent ribbon/Break touch ownership and ignore emulated mouse
  twins. Hit testing must respect ancestor clipping in the scroll container.
  Keyboard/pad gameplay input takes precedence over GUI activation only inside
  Remo; leave the shell's pause action alone and respect live key rebinding.
- Missing/unanalyzable PCM is a recording failure, not a zero-score call.
  Actual captured silence may score zero. Four seconds without buffers during
  a call aborts capture; cancelled tracks cannot become references, and a
  previously scored reference survives pause/failure.
- `ui/scorer_spike.gd` is shared by the shell and dev-only scene.
  In a duel, its automatic processing is disabled; `gameplay.gd` advances it
  once per frame and admits frames only after the 250 ms guard. Keep the
  model's frame limit: a buffered poll may contain audio after the 1.2-second
  real-silence cutoff. Never let a practice fixture submit a duel score.
  Pause/failure retries the same turn; a repeat is playback, not a scored turn.
  Keep the ribbon and Break controls together in `%RemoPanel`.
  Restore both visibility and enabled state when returning to full Practice.
  Scale fonts/targets against the real canvas transform, not only logical
  viewport bounds. Check portrait, short landscape, ultrawide and 150% UI size.
- `world/canal_view.gd` owns the isolated Compatibility viewport and singer-aware
  two-shot. `boat_rig.gd`, `lock_set.gd`, `scenery.gd` and `crowd.gd` are batched,
  game-owned geometry; the local mesh builder has no cross-game runtime imports.
  Keep both complete boats/labels framed at both water endpoints. Reduced motion
  immediately parks framing, lake drift, bobbing and waves, not essential water state.
  Gatún rises and Pedro Miguel descends; open-water surfaces stay level and have
  no lock walls, mulas or tow lines. Contours translate with their drifting source
  without mutating scored tracks. Primary landmarks participate in camera bounds.
  Hidden layouts stop rendering/processing; ordinary shell pause stops decoration.
- `world/voice_ribbon.gd` draws only admitted frames using their source profile.
  Never mutate tracks, connect silent spans, infer new breaks or reward amplitude.
  Review diamonds come from scorer evidence and disappear with intense effects off;
  the contour remains. Cancellation restores the scored reference, replay clears it.
  Narrow listening deliberately prioritizes the input ribbon over the canal.
- Preserve `GameShell` pause/results/replay and call `super(value)` in both
  accessibility overrides. Keep `gl_compatibility`.
  Duel stats use the shell's `details` entries, not renamed hits/streaks.
  Elapsed duel time survives pause and resets on replay; do not confuse it
  with the chamber's between-turn clock.

## Offline recordings

- Keep WAV loading/CLI code under `tools/`, already excluded from exports.
  Feed its PCM through `MicVoiceSource`; do not add a second pitch/scoring path.
- Explicitly disable the WAV loader's default QOA compression, normalization,
  trimming and rate reduction. Preserve input gain/silence and live stereo
  downmixing. Validate RIFF chunk bounds, padding, frame alignment and the
  detector's sample-rate floor before decoding; Godot may recover malformed
  data and still return a playable stream.
- Never copy performer recordings into the repository or emit PCM, complete
  tracks or profiles in reports. An invalid reference fails the job rather
  than falling back to call scoring; report failed takes and a nonzero exit.
- Automated file fixtures are synthesized, live only in isolated test data
  and are removed after the suite. Run the CLI with `--audio-driver Dummy`;
  use `--no-header` for clean JSON, not the stdout-silencing `--quiet`.

## Validation

Run from `godot-base/` with Godot 4.7:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://games/sailor_man/tests/saloma_scorer_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_normalisation_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_pipeline_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/remo_source_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/duel_state_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/duel_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_calibration_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/soundcheck_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/sailor_audio_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/duel_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/soundcheck_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/canal_view_test.gd -- --game=all
```

Ten suites support headless runs. `canal_view_test.gd` requires a graphics
window and deliberately refuses `--headless`. The four windowed runs verify
actual rendered layouts; they also accept
`--sailor-capture-dir=<absolute directory>` after `--`. Use isolated user data
for integration runs. On Windows, use the console executable or
`Start-Process -Wait -PassThru` and check `ExitCode`; a direct GUI-executable
invocation can return before the suite finishes. The buffered microphone
fixture exercises PCM through the real UI/source/scorer without opening
hardware. The pipeline suite also checks synthetic WAV/direct-PCM parity,
read-only inputs, invalid recordings, reference/Quiet Mode handling and actual
offline command exit codes/JSON. Remo's scene checks route simulated key/pad/
multitouch events through the actual viewport, including pause/resume. Pin a
usable window size and UI scale before coordinate-based input checks, even
headlessly, and resume the real pause menu rather than only freeing it.
Native duel checks include full boat-mesh framing, an isolated 3D world,
a nonempty render below 60 draw calls and all eight size/UI-scale combinations.
The canal suite covers all five arenas, both singer framings/water endpoints,
actual paint/contour and individual landmark pixels, hidden-view shutdown,
pause and reduced-motion/effects switches across 40 arena/size/UI combinations.
Its measured maximum is 23 draws. Headless checks cover profile-relative contours,
amplitude invariance, silent gaps and essential water updates. MultiMesh endpoint
checks run natively: the dummy renderer does not retain instance transforms.
Soundcheck covers Room/High/Call/Complete, including the live ribbon staying
visible after resize and failed saves revealing their status in the scroller.
Keep the duel suite's audio-mixer cleanup wait: stopping playback is queued,
and two fast headless process frames alone do not release it before shutdown.
The audio suite also allows the mixer to consume starts before interrupting
real playback. It checks PCM headroom/DC/seams and admitted events; duel checks
assert actual visible, in-bounds muted-SFX captions at every native layout,
not just caption requests. Digital stop is not measured acoustic-tail safety.
The duel suite uses the real shared arena picker and checks both water directions,
free repeats, drift-attached contours and five-judge shell results/replay.
It also runs the optional echo entry, silent/missing/interrupted seed recovery,
actual buffered-PCM seeding, frozen source profiles, quiet delays/repeats,
pause/caption recovery and actual Remo win/echo loss through shell results.
All eight native layouts cover seed-ready/listening and echo review.
Human checks use the actual shared setup/briefing and real input for both winners,
including five Pacific judges, per-seat 160/280 Hz PCM normalization and actual
fresh P2 Soundcheck Save/capture adoption. They verify no profile/source/default
leaks, caller-relative free Repeat, pause/recovery, per-singer rest, both shell
scores and rematches. Both human handoffs/live/reviews cover all eight layouts,
including Ready after final action-row layout, focused profile scrolling and
actual P2 touch/gamepad input. Do not replace those with injected scored turns.
`tools/capture_art.gd` regenerates the setup's `assets/levels/*.png` from the
real arena meshes with a graphics window; reimport after running it.
These do not verify physical devices, OS permissions, acoustic output or real
singers. Use `--audio-driver Dummy` for automated runs. Run all 15 framework
suites with `--game=all` after integration changes. Keep `README.md` and
`TODO.md` honest about those limits.
