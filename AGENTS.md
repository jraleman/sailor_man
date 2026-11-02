# Sailor Man

Read the root `AGENTS.md`, then `DESIGN.md` and `TODO.md`. The design describes
the target game; the current implementation is only its scorer/microphone
experiment. Do not advertise a playable voyage, opponents or Remo controls.

## Current scope

- The owner confirmed **Sailor Man**, English-first copy with Spanish saloma
  terms, two-human hot seat in v1, and grito as part of Remate.
- The manifest currently enables solo only. Campaign, rivals, Remo, saved
  calibration, hot seat, store and gallery are not implemented.
- No performer recordings or cultural partner are available yet. Synthetic
  fixtures prove algorithm behavior, not authentic saloma quality. The real
  recording comparison in DESIGN Milestone 1 must pass before later gameplay.
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
- `voice/voice_track.gd`, `voice/mic_voice_source.gd` and
  `duel/saloma_scorer.gd` are node-free and autoload-free. Keep future Remo
  and authored tracks on this same path.
- The scorer returns `valid`, marks, total and evidence; invalid input has
  an explicit error. Do not turn malformed tracks into plausible zero scores.
- Keep thresholds at the top of the scorer. Preserve sustained register
  jumps when removing short octave glitches, and do not confuse a single
  register drop with a falling Remate.
- The detector/capture were adapted locally from Dead Metal Jam. Do not add
  runtime imports from another game or game-name branches to the framework.

## Microphone and UI

- Capture starts only after **Enable microphone**. Opening scenes, examples,
  tutorial recording and tests must not request microphone access.
- The two-second room check is not full vocal calibration. Chest frequency
  and carrying RMS are temporary manual inputs. Quiet Mode currently bypasses
  the power gate; speaking-level calibration belongs to a later milestone.
- Never monitor microphone audio or persist PCM, tracks or profiles in this
  experiment. Release the owned capture bus on failure, pause and scene exit;
  identify it by its unique name, not a stale bus index.
- Keep errors visible and the explicitly synthetic examples usable when a
  microphone is absent, disabled or denied. Extra amplitude earns no points.
- Missing/unanalyzable PCM is a recording failure, not a zero-score call.
  Actual captured silence may score zero. Four seconds without buffers during
  a call aborts capture; cancelled tracks cannot become references, and a
  previously scored reference survives pause/failure.
- `ui/scorer_spike.gd` is shared by the shell and dev-only scene.
  Scale fonts/targets against the real canvas transform, not only logical
  viewport bounds. Check portrait, short landscape, ultrawide and 150% UI size.
- Preserve `GameShell` pause/results/replay and call `super(value)` in both
  accessibility overrides. Keep `gl_compatibility`.

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
godot --headless --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
godot --path . --script res://games/sailor_man/tests/sailor_scene_test.gd -- --game=all
```

The last run verifies actual rendered layouts; it also accepts
`--sailor-capture-dir=<absolute directory>` after `--`. Use isolated user data
for integration runs. On Windows, use the console executable or
`Start-Process -Wait -PassThru` and check `ExitCode`; a direct GUI-executable
invocation can return before the suite finishes. The buffered microphone
fixture exercises PCM through the real UI/source/scorer without opening
hardware. The pipeline suite also checks synthetic WAV/direct-PCM parity,
read-only inputs, invalid recordings, reference/Quiet Mode handling and actual
offline command exit codes/JSON. Neither verifies OS permissions, device
quality or real singers. Run all 15 framework suites with
`--game=all` after integration changes. Keep `README.md` and `TODO.md` honest
about those limits.
