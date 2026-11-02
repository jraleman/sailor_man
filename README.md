# Sailor Man

A saloma call-and-response game in development. The first delivery is a
**shared voice scorer and opt-in microphone workbench**, not yet the canal
campaign or a duel.

## Run the prototype

From `godot-base/`, using Godot 4.7:

```powershell
godot --headless --path . --import
godot --path . -- --game=sailor_man
```

Choose **Play** to open the workbench inside the real game shell. For the
development-only workbench without the HUD:

```powershell
godot --path . res://games/sailor_man/tools/scorer_spike.tscn -- --game=sailor_man
```

The microphone starts **off**. Select a device, choose **Enable microphone**,
and stay quiet for the two-second room check. Set a comfortable chest reference
in Hz and carrying level in linear RMS, then **Record call**. **R** starts or
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
the next recording/example is an answer and can earn Eco. **Finish session**
opens the shell's results, and replay clears the session.

## Implemented

- One node-free scorer for normalized 100 Hz tracks: Aliento, Quiebre,
  Altura, Remate and answer-only Eco, with break/breath evidence.
- Range-relative pitch, short octave-glitch protection, a capped carrying-level
  gate, and Quiet Mode's gate bypass. Extra volume earns nothing.
- A locally adapted MPM detector, continuous microphone-to-track pipeline,
  opt-in capture, device/error handling and a live pitch/reference ribbon.
- Quiet Mode, six/nine-second windows and 50-150% sensitivity in the Game tab.
- Shell discovery, pause, results and replay; scrolling layouts from phone to
  ultrawide, including enlarged UI; original prototype icon and walkthrough.

The manual voice references are **not full calibration**. No PCM, performance
tracks or voice profiles are saved; only declared options/bindings use the
host's normal settings persistence. Source launches use the host development
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

Four suites cover the pure scorer, low/high-register equivalence, synthesized
PCM through the detector/source, and the real workbench/shell:

```powershell
godot --headless --path . --script res://games/sailor_man/tests/saloma_scorer_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_normalisation_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/voice_pipeline_test.gd -- --game=all
godot --headless --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
```

The windowed scene run checks real rendering at 320x568, 568x320, 1280x720
and 2560x1080 with normal and 150% UI size. Tests do not enable a physical
microphone. Buffered-PCM regressions distinguish absent data from actual
silence, check stall recovery and resumed buffers, and verify that pause/error
paths cannot score or retain unfinished calls. The microphone core was adapted
from DeskCanSaw's Dead Metal Jam; Sailor Man has no runtime dependency on it.

The pipeline suite also writes temporary, explicitly synthetic WAV fixtures
in its isolated user profile and removes them afterward. It checks all
mono/stereo and 8-/16-bit combinations at 44.1/48/96 kHz against direct PCM,
preserved silence/gain, rejected input, Quiet Mode/Eco, and actual command-line
JSON and exit codes, including file paths with spaces.

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

Remo controls, full Soundcheck/profiles, rivals, tandas, the 3D canal, campaign
and two-player hot seat remain future work. See `DESIGN.md` and `TODO.md`.

Re-record the labelled synthetic walkthrough only when its visuals/captions
change; it never enables the microphone:

```powershell
pwsh tools\record_tutorials.ps1 -Godot <godot-executable> -Games sailor_man -Variants solo -Quality 6
```