# Sailor Man

A saloma call-and-response game in development. The current delivery is a
**playable grey-box duel against one explicitly synthetic practice skiff**,
using the shared voice scorer, Remo controls or an opt-in microphone. The
finished canal campaign, recorded rival crews and hot seat are not implemented.

## Run the prototype

From `godot-base/`, using Godot 4.7:

```powershell
godot --headless --path . --import
godot --path . -- --game=sailor_man
```

Choose **Play**, then **Start duel**. **Practice** opens the full scorer
workbench; **Back to duel** starts a fresh duel. For the development-only
workbench without the shell:

```powershell
godot --path . res://games/sailor_man/tools/scorer_spike.tscn -- --game=sailor_man
```

## The grey-box duel

The practice skiff calls tanda one. Review its numbered paddles, then
**Continue**, optionally **Repeat call** once, and press **Ready**. A short
2400 Hz cue and 250 ms guard precede **YA!** and the six-second listening
window. Without a saved profile, Auto starts with microphone-free Remo. Choose
**Soundcheck** on a ready card to measure a microphone profile, or use Remo
immediately. The saved source preference is **Auto / Microphone / Remo**;
Auto prefers an available calibrated device, otherwise Remo. Neither loading
a profile nor selecting Microphone opens hardware. After Ready, recording
begins only when the guard finishes.
Cue playback is explicitly stopped before admitting the scored input.

Three neutral development judges prefer Quiebre, Aliento and Eco. Each
multiplies that mark's weight by 1.5, renormalizes the same scorer's marks,
and shows a 1-10 paddle with an evidence note. Calls omit Eco. The higher
judge-point total wins a tanda; a tie goes to its answerer. The player calls
tanda two. If a decider is needed, the loser of the closer tanda calls it;
equal winning margins use the loser of tanda two.

Win two tandas to finish. The four-minute chamber clock pauses inside scored
performances; reviewing, getting ready and repeating consume between-turn
time. Time expiring awards the rival the duel, not a lost life. The static
3D lock's water follows this clock. **Results / Retry** opens the real shell
results, with judge totals, tandas, best turn, breaks, longest breath and input
source; replay clears duel-local scores, tracks and references.

The window closes at six seconds, nine with Longer listening windows, or
after 1.2 seconds of actual silence following voice. Audio buffered after
that cutoff is excluded. Missing PCM is an error, never presumed silence.
Pause, focus loss and failed capture discard a partial turn and retry the
same call/answer with its earlier reference intact. Rival playback restarts
the same turn after pause. Auto falls back to Remo after capture failure
without changing the saved Auto preference.

The skiff's authored track and synthetic tone are development placeholders,
not performer recordings. Turn gating and tail protection are implemented,
but real room reverb, devices and permissions still need physical QA.

## Remo controls and practice (no microphone)

In a duel, press **Ready** and wait for **YA!**; in Practice, choose
**Start Remo call**. Draw a performance with these controls:

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Voice | Hold Space | Hold A or right trigger | Hold the ribbon |
| Pitch | Hold W/S or up/down arrows | Left stick Y or D-pad | Drag vertically |
| Quiebre | J | X or right bumper | Flick up, or use a second finger on Break |
| Remate | K | B | Flick down to finish |

The five Remo keys are rebindable under **Settings -> Controls**;
the on-screen hints follow the current bindings. Arrows and gamepad controls
are fixed extras. You can also hold/drag with the mouse and click Break or
Remate. In Practice, touching the ribbon starts a window without first
pressing Start, and a fresh Voice press starts another turn while it has focus.
In a duel, only Ready and its cue can admit a new turn; input or fixtures
outside that window cannot score.

Remo emits the same consecutive 100 Hz frames and uses the same scorer,
marks, evidence and kept-reference Eco as the microphone. Its virtual chest
centre is 0 cents, with an authored +700-1300-cent falsetto band. Quiebre
normally moves 700 cents over 40 ms, ensuring a low note still reaches that
band; pitch glides at 1800 cents/s within -300 to +1300 cents. The known
virtual band uses the calibrated-band rule, not the microphone's unmeasured
fallback. It does not mark any human voice as calibrated.

Remate deliberately releases Voice and retains 120 ms of silent frames
before judging. **Stop Remo** scores the current track without inventing a
finish; the six/nine-second deadline also closes the window. An original,
clearly labelled **synthetic tone**, routed through the normal SFX bus,
previews the pitch. It is not a recorded captain or an authentic saloma.

Starting Remo disconnects any microphone and discards an unfinished mic call.
Switching to the microphone, pausing, losing window focus or rebinding cancels
an unfinished Remo turn and stops its tone, without changing the last shell
score or an earlier kept reference. No performance audio or tracks are saved.

## Microphone practice

The microphone starts **off**. A loaded Soundcheck profile supplies its measured
range and levels; choose **Enable microphone** for a fresh room check before
recording. Without a saved profile, the development workbench also retains
temporary manual chest-Hz and carrying-RMS inputs. **R** starts or
stops recording after the room check; it is rebindable under Controls.
Recording stops automatically at six seconds, or nine with Longer listening
windows. Pause disconnects the microphone.

During a call, four seconds without incoming audio buffers aborts recording
and disconnects capture. Stopping before any audio can be analyzed reports an
error instead of counting a zero-score call; actual captured silence can still
score zero. Pausing, disconnecting or failing a call discards its unfinished
track while preserving an earlier scored reference. Only successfully scored
calls can become references. Stop drains already queued audio before judging,
even when pressed before the next regular input poll.

The shaped and flat examples are explicitly **synthetic fixtures**, available
without microphone permission. **Keep reference** retains a call in memory;
the next Remo call, recording or example is an answer and can earn Eco.
**Finish session** opens the shell's results, and replay clears the session.

## Soundcheck and saved voice profiles

The game-owned **Soundcheck** button opens a pre-duel overlay, also available
before your next turn. It suspends the chamber clock, preserves the pending
call and does not request microphone access. Pick a device and profile name
(default **P1**), then explicitly press **Enable microphone**:

1. **Room:** two seconds of actual input measure the noise floor. Dead,
   denied or absent input is an explicit failure, with a **Use Remo** exit.
2. **Speak:** record a short phrase at normal speaking level.
3. **Low:** hold a comfortable, steady low *ooo* to establish the chest reference.
4. **High:** move into a comfortable light voice, or **Skip high** for the fallback.
   Only an observed register break marks the high band as measured; the
   unmeasured +700-1300-cent fallback retains the softer Quiebre rule.
5. **Call:** try an unscored call and see its chest-relative ribbon.

Speak/Low/High stop after three seconds; Call allows six. Stop earlier whenever
comfortable. Each voice measurement needs at least 0.6 seconds of clear voice.
No cue, monitoring or performance playback is needed. **Save and use mic**
alone writes the completed profile and hands the checked capture to gameplay
without moving/restarting its audio node. Back, Escape, pause, focus loss and
failure release capture without saving partial measurements.

Named scalar profiles and the selected name live in
`user://sailor_man_voice.cfg`: chest Hz, high-band bounds/measured flag,
speaking/carrying RMS, noise floor and device. No PCM or tracks persist.
Saving merges names; retry/cancel cannot replace an earlier profile.
Damaged/newer files are reported and not overwritten. **Use saved profile**
selects one without opening hardware; Enable still performs a fresh room check.
Calibration is not progress and is deliberately absent from `save_files`.

**Quiet Mode** normalizes to the measured speaking RMS and bypasses the
carrying-level gate, without changing pitch or scoring weights. The optional
**Voice-rest reminders** setting offers water/rest or Remo between duels after
six completed voiced microphone turns in a rolling ten minutes. Silent,
failed, cancelled, synthetic and Remo turns do not count. It never forces a
break or input switch; dismissal acknowledges that group. Counts stay only in
the current gameplay session, including replays, not the profile file.

Web input uses at most eight detector windows per live update. Stop queues
its final PCM and finishes over subsequent updates without dropping samples
or blocking on the whole take. Offline analysis remains unlimited. This is
automated bounded-processing coverage, not browser/device performance QA.

## Implemented

- One node-free scorer for normalized 100 Hz tracks: Aliento, Quiebre,
  Altura, Remate and answer-only Eco, with break/breath evidence.
- Range-relative pitch, short octave-glitch protection, a capped carrying-level
  gate, and measured speaking-level Quiet Mode. Extra volume earns nothing.
- A locally adapted MPM detector, continuous microphone-to-track pipeline,
  opt-in capture, device/error handling and a live pitch/reference ribbon.
- Keyboard/gamepad and independent multitouch Remo sources on the same
  100 Hz track contract, with a synthetic pitch preview and no microphone access.
- Deterministic best-of-three duel state, weighted judges, a beatable synthetic
  rival, call repeats, chamber/turn clocks and guarded source admission.
- Original primitive boats and lock in an isolated compatibility viewport,
  numeric P1/CPU paddles, captions and responsive duel/input presentation.
- Guided Soundcheck, named scalar profiles, saved source choice, optional
  voice-rest reminders and a bounded web analysis path.
- Quiet Mode, six/nine-second windows and 50-150% sensitivity in the Game tab.
- Shell discovery, pause, results and replay; scrolling layouts from phone to
  ultrawide, including enlarged UI; original prototype icon and walkthrough.

Manual workbench references are **not full calibration**. No PCM or performance
tracks are saved; Soundcheck alone saves completed scalar profiles. Declared
options/bindings use the host's normal settings persistence. Source launches use the host development
user directory. A dedicated standalone export is not configured.

## Offline recording comparison

`tools/analyse_takes.gd` reads local WAVs through the **same PCM detector,
normalizer and scorer** as live capture, without opening a microphone or
playing audio. Keep consented source recordings outside the repository and
exports. Prepare a short file for each call; the entire file is one window.

From `godot-base/`, compare two calls without the carrying-level gate:

```powershell
godot --headless --audio-driver Dummy --no-header --path . `
  --script res://games/sailor_man/tools/analyse_takes.gd -- `
  --game=sailor_man --quiet-mode `
  "C:\VoiceChecks\saloma.wav" "C:\VoiceChecks\flat_hold.wav"
```

For Eco, supply a reference WAV and the answer:

```powershell
godot --headless --audio-driver Dummy --no-header --path . `
  --script res://games/sailor_man/tools/analyse_takes.gd -- `
  --game=sailor_man --reference="C:\VoiceChecks\call.wav" `
  --chest-hz=160 --carry-level=0.08 --noise-floor=0.004 `
  "C:\VoiceChecks\answer.wav"
```

Those numeric defaults are **unmeasured references**, not calibration. Use
values from the recording session. `--falsetto-low` / `--falsetto-high` are
cents relative to chest, and `--measured-falsetto` is only for a genuinely
measured band. `--sensitivity` is a positive linear gain; `--quiet-mode`
bypasses the power gate, not the detector's noise threshold. `--help` lists
every option. Use `--no-header`, not Godot's `--quiet`, which silences JSON
output; the game's `--quiet-mode` goes after the `--` separator.
One invocation uses one profile/noise floor for every take and reference;
use separate invocations when recording sessions need different references.

Mono/stereo 8-/16-bit PCM WAVs at 44.1, 48 and 96 kHz are regression-tested.
The loader preserves rate, gain, channels and surrounding silence, explicitly
disabling Godot's default lossy QOA conversion, normalization, trimming and
rate reduction. Stereo is averaged exactly as live capture does. Sample rates
at or below 8800 Hz are rejected because the shared detector cannot cover its
full pitch range there. Other uncompressed PCM/IEEE-float encodings depend on
Godot's decoder; higher-bit-depth input may be converted to 16-bit PCM for analysis.
Container/chunk bounds, padding and PCM frame alignment are validated before
decoding, rather than silently accepting Godot's damaged-file recovery.

The JSON report contains provisional scores/evidence, input metadata and a
`score_out_of_100`; raw totals/marks stay in 0-1. It never includes PCM, full
tracks or voice profiles. Inputs are read-only and no track/profile files are
created, although normal Godot logs may contain the printed report.
`frame_count` and `voiced_frames` count normalized 100 Hz voice frames,
not the WAV's PCM sample frames.
Exit **0** means every take scored; **2** means invalid arguments or at least
one failed input. A bad take remains listed alongside successful ones. An
unreadable reference aborts the comparison instead of silently turning answers
into calls.

`valid` means technically analyzable, **not culturally validated**. Synthetic
WAV tests do not satisfy the real-saloma gate. Keep the chosen command,
recording/session references and reviewer notes with any eventual comparison;
record approved real-voice numbers in `TODO.md` only after that review.

## Validation and limits

Nine suites cover the scorer, low/high-register equivalence, synthesized PCM,
Remo parity, duel rules, calibration/persistence and three real scene paths.
Use `--audio-driver Dummy` for automated runs:

```powershell
godot --headless --path . --script res://games/sailor_man/tests/saloma_scorer_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_normalisation_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_pipeline_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/remo_source_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/duel_state_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/duel_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_calibration_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/soundcheck_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/duel_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/soundcheck_scene_test.gd -- --game=all
```

The windowed scene runs check real rendering at 320x568, 568x320, 1280x720
and 2560x1080 with normal and 150% UI size. Tests do not enable a physical
microphone. Buffered-PCM regressions distinguish absent data from actual
silence, check stall recovery and resumed buffers, and verify that pause/error
paths cannot score or retain unfinished calls. The microphone core was adapted
from DeskCanSaw's Dead Metal Jam; Sailor Man has no runtime dependency on it.

Duel regressions play a complete Remo win and a buffered-microphone loss to
shell results, then replay. They exercise real key/pad/touch input, rebinding,
out-of-turn/cue rejection, repeat, pause/focus cancellation, missing audio and
the real-silence cutoff inside a buffered poll. They also check that replay
resets elapsed time, pausing playback preserves it, and Practice restores
usable Remo controls after microphone setup. Native checks project the
complete boat meshes through the actual camera, verify an isolated 3D world
and guard a nonempty render below 60 draw calls. Narrow listening layouts
deliberately hide the arena to keep the ribbon and touch buttons usable.

Soundcheck checks feed synthesized PCM through the real wizard, detector and
normalizer, including a queued Stop, observed versus skipped high band,
named-profile round-trips and unchanged files after cancellation/failure.
Gameplay checks cover capture handoff without a tree exit, pending-answer
preservation, speaking-level Quiet Mode, bounded late analysis, device mismatch,
Auto failure fallback and optional rest actions. Windowed checks also cover
Room, High, recording Call and Complete at all eight size/UI combinations,
including the visible Call ribbon, pinned actions and scrolled save errors.

The pipeline suite also writes temporary, explicitly synthetic WAV fixtures
in its isolated user profile and removes them afterward. It checks all
mono/stereo and 8-/16-bit combinations at 44.1/48/96 kHz against direct PCM,
preserved silence/gain, rejected input, Quiet Mode/Eco, and actual command-line
JSON and exit codes, including file paths with spaces.

Remo regressions cover render-frame-independent sampling, key rebinding/repeat,
gamepad axes/triggers and mixed holds, touch ownership/hand-off, flicks and
the shared scorer. The synthetic ideal Remo and normalized sung fixtures both
score **91.3846/100**, within the required 5% parity. The scene suite sends
simulated keyboard, gamepad and multitouch events through the actual viewport,
including preview pitch, Eco, source switching, cancellation and real pause/resume.
A held trigger must be released before its next press can start another turn;
analog jitter cannot silently restart one. These are not physical gamepad/
touchscreen or acoustic-listening checks. `TODO.md` records the validation
results and remaining shared-audio shutdown diagnostic.

For physical-device QA, explicitly enable a microphone and check the room
measurement, a comfortable call, Quiet Mode and Stop. Then test unavailable
or denied input, loss of incoming buffers, and pausing mid-call: no failed turn
should change the previous score or replace its reference, and the synthetic
examples should remain usable. This manual pass has not been completed.

**Still unverified:** physical microphones and OS permissions, web/mobile
capture, real saloma scoring and cultural review. No licensed performer
recordings or cultural partner are available yet. The five marks are a game's
simplification, not a definition of the tradition. Do not treat synthetic
scores as passing the real-recording milestone gate.

The owner authorized Remo and grey-box duel work assuming that real-voice
validation works. That assumption does not mark its unchecked gate complete.
Recorded rival crews, the finished 3D canal, campaign and two-player hot seat
remain future work. See `DESIGN.md` and `TODO.md`.

Re-record the labelled duel walkthrough only when its visuals/captions change.
It completes both tandas and reaches shell results with actual keyboard
events through the scorer and judges, never enabling
the microphone or substituting a prerecorded saloma:

```powershell
pwsh tools\record_tutorials.ps1 -Godot <godot-executable> -Games sailor_man -Variants solo -Quality 6
```