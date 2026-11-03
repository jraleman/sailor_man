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
  Soundcheck, named calibration profiles, the free prototype gallery and
  original toy cosmetics shop are implemented. Campaign and production rival
  crews are not implemented.
- Real canal place names are owner-approved without authority branding.
  Gatún, the lake, Culebra, Pedro Miguel and Pacific have original toy scenery.
  The owner chose freely selectable practice through the existing level selector,
  not campaign gates. Ordinary practice still faces the synthetic skiff.
  The owner chose a separate Culebra self-echo challenge: a fresh unscored
  seed, then best-of-three against that fixed snapshot. It is not a voyage
  boss encounter or live microphone monitoring.
  Hot seat has all five practice arenas from the start and no chamber timeout;
  campaign-aware hot-seat access is still undecided.
  The owner chose **both singers' best turns** for hot-seat share artwork,
  not winner-only art. Free-practice cards are implemented, not voyage cards.
  The owner chose eleven freely viewable current boat/lock/scenery exhibits,
  not a campaign-gated gallery or recorded rival crews.
  Plain crew/spectators imply no traditional dress or reviewed cultural assets.
- No performer recordings or cultural partner are available yet. Synthetic
  fixtures prove algorithm behavior, not authentic saloma quality. The real
  recording comparison in DESIGN Milestone 1 remains unverified. The owner
  explicitly authorized Remo and grey-box duel work assuming validation works;
  that is not evidence to check off the authentic-recording gate.
- The owner chose the blue launch's bow, plain crew and illustrative gold
  Remo ribbon for the captured PNG icon. It and the labelled walkthrough are
  prototype presentation, not a recorded captain or reviewed campaign art.
- The owner chose the current plain crew aboard the blue/red player launch
  for setup before a cosmetics shop. Its single `practice_launch` entry mounts
  the shared plinth; it does not implement the production captain roster.
- The owner chose four cosmetic kinds, earned Balboas and independent P1/P2
  equipment. Shared ownership/wallet do not mean a shared outfit. Use original
  toy designs only; no sombrero pintao, mola patterns or cultural gates.
- The owner chose a three-card practice opening and expanded five-mark Guide,
  with **player-paced** Next/Done rather than automatic card timing. This is
  not the unreviewed five-card campaign story.
- `tools/analyse_takes.gd` is read-only WAV analysis for the recording gate,
  not the later rival-track baking pipeline. Its provisional reports cannot
  certify authentic salomas, performer consent or cultural review.

## Practice onboarding

- `intro.tscn` extends `MenuScreen` and reuses the actual static gallery-stage
  models. Register it only through the manifest's `intro_scene_path`; the
  collection must retain the framework intro.
- Cards wait indefinitely for Next. Done, Skip, Escape and controller B lead
  to the normal title, not a match. Guard repeated exits, including an exit
  requested during Router's incoming fade. Skip remains available on every card.
- Keep original models static and hidden views stopped. Only opacity may
  fade between cards; enabling Reduced motion mid-fade restores readable copy.
  No narration, voice/profile/performance reads, capture, campaign state or
  first-run persistence belongs here.
- Controller extras are game-owned `_input` handling: A uses focused Skip,
  otherwise Next/Done; left/right selects actions, up/down scrolls copy.
  GUI navigation can consume D-pad events before `_unhandled_input`, and the
  built-in UI accept/cancel actions are not guaranteed to contain pad bindings.
  Do not mutate shared input maps to make this opening work.
- The written Guide lives in manifest copy and the existing shared screen,
  not a parallel rules menu. Keep the actual solo/hot-seat/echo/clock rules
  and dynamically generated bindings. Aliento's five-second saturation is
  not a demand; Altura uses source/profile-relative pitch and an unmeasured
  microphone band remains provisional. Grito is Remate, and calls omit Eco.
  Quiet Mode removes the carrying-level gate; no extra-volume reward.
- The marks are game simplifications. Do not copy the pending campaign story
  or unreviewed cultural claims into this prototype opening/Guide.

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
- The workbench and Soundcheck scrollers follow keyboard focus. Soundcheck
  defers initial focus to Back, never Enable microphone. Label the actual
  focused editor: a SpinBox's name/description must reach its internal LineEdit.
  Duel profile metadata follows the active singer and selected calibration.
- Workbench `_set_status` keeps stable feedback polite but disables live
  announcements for changing elapsed-time text. Preserve visible timers and
  every error/cancellation path; this does not change scoring or microphone consent.
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

## Setup preview

- `Options.CHARACTERS` and `character_preview.tscn` use the existing shared
  setup contract. Reuse the actual `BoatRig`, canonical player paint and P1/P2
  plaques with that seat's equipped outfit; extra colour, scene or profile
  fields must not change the model.
- Keep static, transparent, isolated Compatibility lighting and frame the actual
  mesh vertices. Pre-ready configuration works; unchanged seats reuse their rig.
  Invalid IDs/seats clear old geometry, show/log an error and stop rendering.
  Hidden and nonfeatured seats do not render. No audio, capture, profile/
  performance reads, scoring or persistence belongs in this presentation.
- Arena setup summaries are compact and mode-neutral; Details explains solo
  clocks versus untimed hot seat. The generic setup scroller owns briefing and
  choices, reflow/focus, narrow seat stacking and compact action wrapping.

## Shop and launch outfits

- `Options.STORE_ITEMS`, `STORE_SLOTS` and `STORE_CURRENCY` declare twelve items:
  four free original defaults and eight paid toy designs. Stable kinds are
  `hat`, `pennant`, `paint`, `bow`; stable slots are `p1_hat`, `p1_pennant`,
  `p1_paint`, `p1_bow` and the matching `p2_` slots. Never rename saved ids.
- The existing Store owns the one Sailor wallet, purchases and equipment in
  `user://store.cfg`. A purchase can dress either/both humans without repurchase;
  it auto-equips the first matching still-default slot. Never add another save,
  wallet, menu implementation or framework game-name branch.
- Normally completed best-of-three duels earn
  `round(best human's accumulated judge points / 10)`. Hot seat uses the higher
  human total, not their sum. Ordinary solo synthetic-skiff wins add five;
  echo/hot seat add no win bonus. Workbench, seeds, incomplete/abandoned duels
  and chamber timeouts earn nothing. Bank exactly once through the shell.
  A valid silent turn still has the judges' existing minimum paddle of one;
  a completed three-judge silent loss can therefore earn one Balboa.
- `world/launch_outfit.gd` validates canonical cosmetic ids and supplies batched
  geometry. It and `BoatRig` resolve no autoload: controllers pass Store
  explicitly. Rebuild only the rig's one surface; preserve mouth/attachment
  anchors, ribbons, player paint/plaques and voice/scoring state.
- `store_preview.tscn` reuses setup's original rig, but only the canonical item
  id configures its static P1 advertisement. Ignore injected colours, kinds,
  seats and profiles; do not read live equipment or open audio/capture.
  Render on demand and frame actual ornament vertices.
- Gameplay, setup and gallery show human equipment; the synthetic skiff/echo
  remains plain. Freeze actual human outfit ids at results in `sailor_outfits`;
  share art must never read live Store. Missing legacy outfit data means the
  original launch. Invalid kinds/ids must log and explain the rejection;
  hide cached preview textures and recover on valid equipment.

## Captured branding

- `GameTheme` uses the full-colour `assets/game-icon.png`, preserving the
  existing palette and white logo tint. The original launch/plain crew and
  synthetic Remo contour imply no named campaign captain or recorded voice.
- `tools/capture_art.gd` regenerates both the transparent 512x512 icon and five
  640x360 setup stills from the actual game-owned builders. Run with a graphics
  window; reimport afterward. `--only=icon` and `--only=levels` limit outputs;
  `--output-dir=<directory>` redirects them for verification.
- The icon uses an isolated, supersampled Compatibility viewport and fits
  actual mesh vertices, not the OS window or conservative AABB corners. Keep
  the ribbon's gold face visible from the bow camera and at 32/64 pixels.
  Never open capture, load profiles/performance data or add audio for branding.
- This is prototype theme art, not standalone export configuration. Stable
  save directories, production captains and cultural review remain separate work.

## Gallery

- `Options.GALLERY_EXHIBITS` and `gallery_stage.tscn` use the existing shared
  gallery contract. All eleven current prototypes remain free; future recorded
  rivals, dredge/whole-canal models and campaign gates are not implemented.
- Reuse the actual boat, chamber, crowd and scenery builders. Public static
  `LockSet.gate`, `LockSet.mula` and `Scenery.howler` serve both the match and
  close-ups; do not author imitations or change match geometry for presentation.
- The shared menu advances yaw through `set_view`, even for stages that offer
  `set_auto_spin`. Our static stage needs only `configure` and `set_view`;
  never add a second yaw loop or a meaningless optional-method stub.
- Keep isolated Compatibility lighting, complete default framing and explicit
  P1/CPU/P2 plaques. Park ambient motion and stop hidden rendering. The stage
  must not read voice/profile/performance data, create audio/capture nodes or
  write settings/progress. Unknown exhibits must show an error, never old art.
  Human launches read their equipped outfits; the skiff remains plain.
  Equipment changes retain the viewer's orbit rather than resetting it.

## Share cards

- `share_art.tscn` is registered through the existing manifest art hook.
  Keep its original launches, toy crew and P1/P2 labels game-owned; no
  framework game-name branch or new publisher is needed.
- Retain the highest **accepted normalized scorer total** per actual human,
  keeping the first on equal totals. Freeze the contour while its actual
  source profile/window are available, after successful turn admission.
  Seeds, synthetic/echo playback, Repeat and failed/cancelled input cannot
  populate human artwork. Valid silence may be a best turn with no mesh.
- Snapshots hold only frozen Mesh geometry and scalar captions, not raw
  frames, PCM, profiles, calibration names or devices. `sailor_art` is
  renderer-only in-memory data, as are the frozen `sailor_outfits` cosmetic ids;
  `sailor_stats` contains domain statistics.
  Never hand the complete rendering dictionary to a future public API.
- Share totals use the shell's canonical `_scores`. A solo two-sided match
  may include opponent points in `score_values`; `player_count`, stat rows and
  portraits still count actual humans. Do not invent numeric hit/miss/combo
  aliases for judge points. Label tandas, Quiebres and Aliento truthfully.
- Hot seat always shows both humans. Solo/echo show only P1; no seed or rival
  impersonates P2. Explicitly label silent/empty turns, incomplete duels and
  development scorer sessions without fabricating completion or voyage progress.
- Replay replaces snapshot dictionaries rather than clearing ones a pending
  renderer may still hold. Reconfiguring a card must remove obsolete portraits
  and restore another game's artwork without mutating scored meshes.
- Every portrait has isolated Compatibility lighting and remains static,
  including effects/reduced-motion settings. No bobbing, review sparks or audio;
  hidden views stop rendering. Keep the gold face visible from the bow camera.
- Preview is memory-only; explicit Save exports PNG through the existing
  ShareManager. No PCM, full pitch-frame/profile files or PNG text/EXIF metadata.
  The current QR opens `https://deskcansaw.com`, with **Discover more games**
  and explicit no-public-run copy. Do not claim score publishing exists.

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
godot --headless --path . --script res://games/sailor_man/tests/gallery_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/art_capture_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/character_preview_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/store_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/onboarding_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/duel_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/soundcheck_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/canal_view_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/share_card_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/gallery_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/art_capture_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/character_preview_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/store_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/onboarding_test.gd -- --game=all
```

Seventeen distinct suites: fifteen support headless runs; `canal_view_test.gd` and
`share_card_test.gd` require graphics and deliberately refuse `--headless`.
Also run the three scene suites, gallery, art-capture, setup-preview, store
and onboarding suites with a window: ten windowed checks in total.
The four scene/canal windowed runs verify actual rendered layouts and accept
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
Workbench and Soundcheck checks dispatch actual Tab input across eight and
sixteen size/profile/UI cases, without manually revealing focused controls.
After forcing a scroll position, let queued layout settle before establishing
fresh starting focus. Metadata assertions do not establish screen-reader speech,
physical input hardware or controller-only navigation across shared menus.
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
Onboarding runs seven actual Router exit paths without letting duplicate-exit
checks substitute for missing primary input. Native coverage is 40 layouts
for opening cards and solo/hot-seat Guides, whole actions, legible text,
scroll-reachable copy, complete actual model framing/pixels and a maximum of
12 draws below 60. It checks pacing, held-key repeats, live Reduced motion,
controller/mouse/emulated-touch routing, hidden views and audio/save isolation.
Capture with `--sailor-onboarding-capture-dir=<absolute directory>`.
Load autoload-dependent scenes at runtime. Even naming a `GameSession` enum
in a headless dependency can pull in its autoload-dependent body; resolve
that enum through the runtime node's script constant map instead.
Share checks cover normalized-best selection/ties, frozen per-seat PCM geometry,
privacy, silence/incomplete/scorer labels, seed/rival exclusion and replay.
The share-card windowed run renders nine cases: six complete input-driven duels,
incomplete/scorer cases and a display-only width fixture. It verifies gold/paint pixels,
complete framing, static/hidden-view behavior and reversible card reuse, with
5 measured draws per portrait against a 20-draw limit. Capture with
`--sailor-share-capture-dir=<absolute directory>`; decode full/half PNG and
quality-75 half JPEG QR variants and reject PNG text/EXIF chunks.
Default checks do not save or change the clipboard. `--sailor-test-save`
opts into actual PNG Save/preview parity and deletes only its generated PNG;
use isolated user data and preserve/restore every desktop clipboard format,
because the existing Save copies the PNG path.
Gallery checks compare all actual match meshes, list selections, canonical
configuration/error recovery, voice/audio/save isolation and real camera input.
Its windowed run covers 88 exhibit/size/UI cases, complete geometry and actual
launch pixels, with a measured maximum of 13 draws. Mouse/pad/touch, reset,
shared auto-spin, reduced-motion parking and hidden-render shutdown reach the
real stage, not a spy. Capture with `--sailor-gallery-capture-dir=<absolute directory>`.
The two unavailable-exhibit errors are intentional negative cases.
Art checks exercise actual CLI failures, selector isolation and default
regeneration without overwriting checked-in assets. Native checks reproduce
the transparent icon, preserve all five level stills, inspect gold/blue pixels
at 512/64/32 sizes and verify actual title/picker rendering and share-logo wiring.
The icon uses two measured draws against a ten-draw limit. Capture inspections
with `--sailor-icon-capture-dir=<absolute directory>`.
Setup-preview checks exercise actual collection/standalone solo/hot-seat rows,
all five arenas, canonical rig replacement/rejection, P1/P2 identity and no
audio/profile reads or save writes. The native run covers 24 solo/P1/P2 size/UI
cases plus
compact expanded Details, including actual focused-picker/Start visibility,
whole-mesh framing, paint/face/plaque pixels, static frames and hidden rendering.
Maximum 3 draws against a ten-draw limit; the three rejected-preview errors
are intentional. Capture with `--sailor-setup-capture-dir=<absolute directory>`.
Store checks exercise actual Buy/P2 Equip, shared ownership and independent
slots, exact save reload/restoration, canonical previews and damaged-equipment
recovery. Every item runs on both rigs (24 model cases); native checks render
24 shelf previews, eight shop size/UI layouts and complete decorated
match/setup/gallery/share framing. Preview maximum is 3 draws, below ten.
Capture with `--sailor-store-capture-dir=<absolute directory>`. Duel checks
settle seven real completed matches, verify actual Balboas/results, rounding,
human-only totals, bonus exclusions and duplicate-settlement protection.
These do not verify physical devices, OS permissions, acoustic output or real
singers. Use `--audio-driver Dummy` for automated runs. Run all 15 framework
suites with `--game=all` after integration changes. Keep `README.md` and
`TODO.md` honest about those limits.
