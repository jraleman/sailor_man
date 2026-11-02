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
microphone. The microphone core was adapted from DeskCanSaw's Dead Metal Jam;
Sailor Man has no runtime dependency on that game.

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