# Sailor Man

A saloma call-and-response game in development. The prototype offers
**five free toy-canal arenas for synthetic-skiff practice**, plus an optional
Culebra self-echo challenge and **two-human hot seat**, using the same scorer,
Remo or an opt-in microphone. The finished canal campaign and recorded rival
crews are not implemented. A free gallery displays eleven of the current
original boat, lock and scenery models. Completed duels earn Balboas for an
original toy cosmetics shop with separate P1/P2 outfits.

## Run the prototype

From `godot-base/`, using Godot 4.7:

```powershell
godot --headless --path . --import
godot --path . -- --game=sailor_man
```

The standalone opening waits for **Next**/**Done**, or **Skip** to the title.
Choose **Play**, then **Single Player** or two-human **Multiplayer**, select a
**Practice arena** in setup, and begin. All five are freely selectable;
these are not unlocked voyage levels. Solo's **Practice** opens the full scorer
workbench; **Back to duel** starts a fresh duel. For the development-only
workbench without the shell:

```powershell
godot --path . res://games/sailor_man/tools/scorer_spike.tscn -- --game=sailor_man
```

## Practice opening and written Guide

Standalone boot shows three player-paced cards using the actual static toy
lock and P1/P2 launches: **Free canal practice**, **Shape the call** and
**Take turns, stay comfortable**. There is no automatic advance. **Next**
becomes **Done** on card three; Done and the always-available **Skip** lead to
the normal title, never directly into a match. Escape or controller B skips.
Controller left/right focuses Skip/Next, A activates it, and up/down scrolls
the copy. Keyboard, mouse and touch use the same visible actions.

The opening is registered through `intro_scene_path`, so a collection retains
the framework intro. It uses no narration, voice source, profile/performance
data, campaign state or first-run save. Models stay static; card changes use
only an optional opacity fade, cancelled immediately by Reduced motion.
Hidden/finished stages stop rendering.

After setup, **Guide** opens the shared scrollable written briefing, keeping
the real solo/hot-seat rules and current rebindable controls. Its five marks
describe existing game mechanics, not a cultural definition:

| Mark | Game meaning |
| --- | --- |
| Aliento | Longest continuous voiced span, saturated at five seconds; stop whenever comfortable, not when a target demands it |
| Quiebre | Clean chest/high-register jumps; Remo's Break changes register |
| Altura | Source/profile-relative pitch span, not absolute Hz; an unmeasured microphone band remains provisional |
| Remate | Falling glide or crisp finish; grito belongs here, not to a sixth action |
| Eco | Match the caller's relative contour when answering; calls omit Eco |

Extra loudness earns nothing. Quiet Mode removes the carrying-level gate;
Remo needs no voice. The Guide keeps Start visible on short enlarged-UI
screens by compacting its context row and using **On start**; full context
remains in tooltips/accessibility text. The five-card campaign story, cultural
review and recorded rivals remain pending.

## Setup launch preview

The shared setup plinth shows the actual player launch and plain toy crew.
**Practice launch** is the only prototype entry, not a production captain
roster or a gameplay modifier. Focusing P1 or P2's row shows their blue/red
launch, equipped cosmetics, explicit P1/P2 plaque and matching identity ring;
solo uses P1.

The transparent Compatibility preview is static and only the featured seat
renders. It opens no microphone, reads no voice/profile/performance data and
writes no options or progress. Production captains and recorded voices remain
pending. Setup's compact arena summary gives the judge count and free access;
**Details** explains the different solo/hot-seat clock rules. The briefing and
choices scroll together, including on short screens and with enlarged UI.

## Prototype cosmetics shop

Open **Store** from the standalone title or the running game's pause menu.
The twelve-item catalogue has four free original defaults and eight paid
original toy designs. No item changes voice, scoring, judges or arena access.
There is no traditional dress, mola pattern, recorded captain or cultural gate.

| Kind | Free original default | Paid designs (Balboas) |
| --- | --- | --- |
| Hat | Plain crew, bare-headed | Deck cap 8; Toy sun hat 12 |
| Pennant | Player pennant | Cream stripes 8; Toy bunting 12 |
| Hull paint | Player hull | Cream lower hull 10; Deep lower hull 14 |
| Bow | Plain bow | Toy fish 12; Bow star 14 |

P1 and P2 have independent hat/pennant/paint/bow slots, using stable `p1_` /
`p2_` ids. **Ownership and the Balboas wallet are shared within Sailor Man**:
buy once and equip either or both singers without buying again. A purchase
auto-equips the first matching still-default slot; the card's P1/P2 buttons
choose the other slots explicitly. The existing Store saves wallet, ownership
and equipment in the game's slice of `user://store.cfg`, not settings or
calibration. Other games keep their own wallets.

A normally completed best-of-three duel pays
**`round(best human's accumulated judge points / 10)`**, including losses and
self-echo. Hot seat uses the higher human's total, not the sum, and pays the
shared wallet once. An ordinary solo win against the synthetic skiff adds
**5 Balboas**; echo/hot seat have no win bonus. Results display the payout.
Workbench sessions, seeds, unfinished/abandoned duels and chamber timeouts pay
nothing. Synthetic-rival points never fund the human wallet.

Valid silence is different from missing/failed capture: every valid judge
paddle has the existing minimum of one. A completed three-judge silent loss
can therefore total six human judge points and pay one Balboa; this does not
change the scorer or reward extra amplitude.

The actual game-owned meshes show equipped outfits in gameplay, setup and
gallery. Hull finishes retain upper player paint, roof, shirt, pennant and
explicit P1/P2 identity; the synthetic skiff/echo remains plain. Shop previews
are static P1 advertisements. Finished share cards freeze both humans' actual
cosmetic ids, so later equipment changes cannot rewrite a requested card.
The four defaults retain the original launch/icon/tutorial appearance.
Production captains, reviewed traditional assets and campaign gates remain
separate work.

## The practice duel

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

Three neutral development judges prefer Quiebre, Aliento and Eco. The Pacific
adds Remate and Altura judges, for five actual paddles and a 50-point maximum
per turn instead of 30. Each
multiplies that mark's weight by 1.5, renormalizes the same scorer's marks,
and shows a 1-10 paddle with an evidence note. Calls omit Eco. The higher
judge-point total wins a tanda; a tie goes to its answerer. The player calls
tanda two. If a decider is needed, the loser of the closer tanda calls it;
equal winning margins use the loser of tanda two.

Win two tandas to finish. In either lock, the four-minute chamber clock pauses
inside scored performances; reviewing, getting ready and repeating consume
between-turn time. Time expiring awards the rival the duel, not a lost life.
Open-water practice has no between-turn deadline; its once-only Repeat is free.
The six/nine-second scored windows and tail guard still apply in every arena.
The toy lock's water follows its clock, rising at Gatún and falling at Pedro
Miguel. **Results / Retry** opens the real shell
results, with judge totals, tandas, best turn, breaks, longest breath and input
source; replay keeps the selected arena but clears duel-local scores, tracks
and references. Arena selection is session-local and writes no voyage progress.

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

## Two-human hot seat

Choose **Multiplayer** in the existing setup, then any of the five practice
arenas. Two humans share one device and the same keyboard/gamepad/touch controls.
Mobile builds remain solo. The second boat and judge rows identify **P2**,
not a synthetic rival or ECHO.

**P1 calls tanda one; P2 answers and calls tanda two.** Each handoff names the
next singer with their player name, colour and P1/P2 tag. Choose that singer's
calibration profile and **Auto / Microphone / Remo**, then **P1 Ready / P2 Ready**.
On phones and short screens, the profile/source details scroll; focus reveals
Ready and keyboard/controller navigation follows the focused control.
Each singer starts with no profile selected rather than inheriting another
person's voice. Use a saved profile or that singer's **Soundcheck** for voice
calibration, or use Remo immediately.

Profile/source choices on the card stay **per player for this gameplay session**,
including rematches. They do not rewrite the saved source default or the other
seat's choices. Explicit Soundcheck Save/use still writes the named scalar
calibration/selection, but applies it only to the active seat. A new P2
Soundcheck defaults its save name to P2 and preselects no other singer's profile.
Opening a card or choosing a source/profile never requests microphone access.
Capture closes after each performance and must be explicitly enabled again
before the next microphone turn. A fresh Soundcheck Save can hand over its
already checked capture without reparenting or restarting it.

Hot seat has **no chamber timeout in any arena**, including both locks; their
water stays at its initial height. The ordinary cue/250 ms guard, six/nine-second
listening deadline and actual-silence cutoff still apply. Both humans use the
same scorer, three judges (five in the Pacific), answerer-wins-ties and existing
decider rule. **Repeat call (free)** is once-only before an answer: it plays
the completed caller's contour/profile as a neutral tone from that caller's
boat, with capture stopped, not recorded voice. Cancellation retries the same
singer without replacing the completed call.

Both players' actual scores and winner reach shell results; each player's
statistics count only their own performances. Rematch clears both scores,
tracks and references, retains their session choices, and opens no microphone.
Voice-rest counts are separate per singer; offers appear at results or that
singer's first handoff in a new duel, never during listening. Choosing Remo
for a rest changes only that seat. Full Practice and Culebra self-echo remain
separate solo entries, not additional opponents inside a human match.

## Five toy practice arenas

The shared setup selector reads `canal_arenas.gd` through `GameManifest.levels`;
`GameSession.selected_level()` supplies gameplay's arena. No new framework
branches, selector, settings key or campaign achievement gate is involved.
The rule column below describes solo practice; hot seat is untimed in every
arena and retains its actual judge count.

| Arena | Practice rules | Original scenery |
| --- | --- | --- |
| Gatún practice lock | Rising chamber; four-minute clock; three judges | Miter gates, rail-mounted mulas, palms and wall crowd |
| Lago Gatún | Untimed between turns; free Repeat; three judges | Jungle islands, canopy howlers, distant generic ships and gentle rival drift |
| Corte Culebra | Untimed skiff practice or a separate seeded self-echo challenge; three judges | Red-earth terraces and a toy cable-stayed Centennial Bridge |
| Pedro Miguel | Descending chamber; four-minute clock; three judges | Lock, plain service houses and cool evening colours |
| Miraflores & the Pacific | Untimed between turns; five judges | Arched Bridge of the Americas, skyline, causeway and boats with bunting |

These are batched meshes in an isolated Compatibility viewport, not final
campaign encounters. Culebra's optional self-echo challenge uses a completed
pitch-track snapshot, never delayed microphone audio or live monitoring.
Both boats retain blue/red paint, pennants and explicit **P1 / CPU**, **ECHO**
or **P2** labels appropriate to the selected mode.
Their toy crew imply no named captain or traditional costume. The same batched
boat rig draws the human's equipped toy cosmetics without changing its mouth,
attachment anchors or scoring. The synthetic opponent keeps the original outfit.

The camera eases modestly toward the performing singer while keeping both
complete boats in shot. The admitted pitch track unrolls from the crew's
mouth over the water, relative to that source's own profile. Silence breaks
the strip; extra volume cannot widen it. Static review diamonds use the
scorer's existing break evidence, not another detector or scoring path.
Cancellation restores the scored reference rather than displaying a partial
take as a finished performance.

Reduced motion parks the two-shot, lake drift, bobbing and crowd waves immediately;
essential water and contour updates still work. Turning intense effects off
omits review diamonds, not the pitch contour. Pause stops decorative time,
and deliberately hidden layouts/overlays stop the viewport's rendering.
Narrow listening still gives priority to the input ribbon and Break controls.

Real place names are owner-approved **without canal-authority branding**.
These are compressed toy interpretations, not a simulator or reviewed factual
reconstructions. Cruise music, campaign encounters/progression and cultural
review remain future work.

## Captured prototype art

The transparent 512x512 game icon shows the owner-selected blue launch's bow,
plain crew and illustrative gold Remo ribbon. It uses the actual boat/ribbon
builders and synthetic input, never a person's performance or voice profile.
The existing palette and full-colour logo tint are unchanged. This replaces
the temporary SVG on the title cartridge, picker and shared cards; it is not
a named campaign captain, reviewed traditional dress or final shipping art.

The setup's five 640x360 PNG previews also come from the real arena meshes,
not separate promotional drawings. Regenerate the icon **and** all five stills
from `godot-base/` with a graphics window, then reimport:

```powershell
godot --audio-driver Dummy --path . --script res://games/sailor_man/tools/capture_art.gd -- --game=all
godot --headless --path . --import
```

Append `--only=icon` or `--only=levels` after `--` to regenerate just that
selection. `--output-dir=<directory>` redirects the icon and `levels/` folder
for inspection without overwriting the checked-in assets. Empty/unknown
selectors, empty output paths and headless capture fail explicitly.
The icon's isolated 1024x1024 Compatibility render is downsampled to 512px
and framed from actual vertices, independently of the OS window size.
No microphone, audio player, calibration or duel is opened.

## Free prototype gallery

Open **Gallery** from the standalone title screen or the running game's pause
menu. All eleven exhibits are free: P1's launch, the synthetic skiff, both
human launches, a mula on rails, the gate leaves, one canopy howler and all
five practice dioramas. These are the match's actual meshes, not replacement
promotional models, recorded crews or culturally reviewed assets.
Human launch exhibits show their equipped outfits; the synthetic skiff remains
plain. Changing equipment preserves the current orbit.

The shared viewer supplies mouse/touch/keyboard/gamepad orbit, zoom and reset,
with descriptions and input help in tooltips. It also advances auto-spin through
the stage's `set_view`; `gallery_stage.tscn` implements `configure` and `set_view`,
not a second spin loop or a redundant `set_auto_spin`. Reduced motion parks
auto-spin while retaining manual inspection. Water, drift and crowd waves are
static, and hidden exhibits stop their private Compatibility rendering.

The stage reads no voice profile or performance, opens no microphone, creates
no audio players and writes no progress or options. Recorded rival boats,
the dredge, whole-canal exhibit and achievement gates remain campaign work.

## Culebra self-echo challenge

Select **Single Player** and **Corte Culebra**, then **Challenge your echo**
on its ready card.
Press **Ready: seed call**, wait through the normal cue/250 ms guard and make
a comfortable call with Remo or an explicitly enabled microphone. The seed
earns no judge points or tandas. Silence, missing PCM and interrupted seeds
remain visible, retryable failures; an unfinished take cannot become the opponent.
**Skiff practice** returns to the ordinary ready card before seeding.

The completed seed's 100 Hz frames, scoring profile and Quiet Mode are copied
together and stay fixed for the whole best-of-three duel. After **600 ms of
silence**, its contour returns with a neutral synthetic tone, 6 dB softer than
the normal Remo preview. Every echo turn and once-only free Repeat uses that
delay; pausing playback restarts the full gap and the same take. The **ECHO**
boat/paddles are not another recorded crew. No microphone audio is monitored,
replayed or saved, and no seed tracks persist.

The echo calls tanda one; you call tanda two. The shared scorer, numbered
paddles, answerer-wins-ties and closer-tanda decider rules are unchanged.
Your later calls do not replace the seed, and changing source, calibration
or Quiet Mode affects new player turns, not that frozen opponent. A strong
seed can be difficult to beat; no hidden handicap weakens it.

Wins and losses reach shell results. Replay keeps the challenge but requires
a **fresh seed**, with no automatic microphone activation. Practice/Back to
duel returns to ordinary skiff practice. The seed is excluded from result
counts/maxima but a completed voiced microphone seed still counts toward
the existing rest reminder. This is free practice, not a voyage boss encounter
or a campaign unlock.

## Canal audio

Original synthesized lock horn, filling-water wash, applause, paddle clack and
mula bell use game-owned players on the normal **SFX** bus. These are non-vocal
toy effects, not performer recordings. Water is decorative and runs only
between Remo turns in locks only; open water has no filling loop. The visible
chamber clock remains authoritative. Reviews clack the paddles, a tanda review
adds applause (and a mula bell in locks only), and a judged duel finish
gets horn/paddles/applause. A chamber timeout gets only its horn.

Reference playback, Repeat, the guard and listening never have competing
canal effects. Selecting Microphone already disables water and judge feedback,
before Enable or room measurement; final feedback waits until capture stops.
Soundcheck, Practice, pause, focus loss, source changes, results, replay and
exit stop the effects immediately. The protected 2400 Hz ready cue and synthetic
pitch/reference tones are unchanged. Title music is stopped on entry; there
is no duel music or cruise bed yet.

**Settings -> Accessibility -> Audio captions** shows call-shape, ready and
sound-verdict captions even when SFX is muted. Simultaneous effects share one
caption rather than replacing one another. The duel reuses the shell's caption
widget below its scroller; the permanent **YA!** banner replaces the transient
ready caption during listening, leaving the full input ribbon available.
Stopping/changing context clears old transient captions. Real playback,
speakers/headphones and acoustic room tails still require manual validation.

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

## Keyboard navigation and feedback

Practice and Soundcheck scroll with keyboard focus, keeping focused buttons
and editors wholly visible from portrait phones to ultrawide at 150% UI size.
Soundcheck initially focuses **Back**, not microphone consent. Opening or
browsing it does not request access. The temporary numeric editors and
Soundcheck's profile, device and name fields identify their purpose; the duel's
profile picker identifies the active singer and selected calibration.

The workbench's visible Remo/microphone timer keeps updating without continuous
live announcements. Stable status, completion and errors use polite live-region
metadata. These checks validate actual focus and metadata, not screen-reader
speech or physical hardware. Controller-only navigation across all shared
menus remains outside this slice.

## Soundcheck and saved voice profiles

The game-owned **Soundcheck** button opens a pre-duel overlay, also available
before your next turn. It suspends the chamber clock, preserves the pending
call and does not request microphone access. Pick a device and profile name
(default **P1** in solo, or the active seat's tag for a new human profile),
then explicitly press **Enable microphone**:

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

## Share cards

**See Scores** previews the same 1200x630 card that **Save Image** explicitly
writes/downloads as PNG. Preview alone creates no image file. The existing
desktop **Open Image** action remains available after saving.

Hot seat features **both singers**, not just the winner: original blue/red
launches, P1/P2 labels and each person's best accepted turn ribbon with its
actual judge paddles. Best means the highest normalized scorer total;
equal totals keep the first turn. The other statistics show actual judge
points, tandas won, best normalized scores, accumulated Quiebres and longest
Aliento. Solo and self-echo feature only P1, with the synthetic opponent clearly
identified in the score labels. Seeds and Repeat never become scored best turns.

Valid captured silence has an explicit silent-turn caption and no invented
contour. No completed turn, an incomplete duel and development scorer examples
also have distinct labels; none imply a winner or campaign progress.
Artwork is always parked, with isolated Compatibility lighting and no
decorative animation or review sparks. Hidden portraits stop rendering.

Only frozen geometry and scalar captions enter the in-memory artwork snapshot.
Replay drops it without mutating an already requested card. The saved PNG shows
the ribbon, but exports no PCM, full pitch-frame/profile files or text/EXIF
metadata. `sailor_stats` contains domain statistics; `sailor_art` is renderer-only
geometry, not a payload for a future publisher.
The renderer-only `sailor_outfits` ids are frozen at results too; artwork never
reads live shop equipment.
The QR currently opens **https://deskcansaw.com**, labelled **Discover more
games**. No public run record is published; there is no new stats endpoint.

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
- Five freely selectable, original toy canal arenas in an isolated Compatibility
  viewport, rising/descending locks, free open-water Repeat and five Pacific
  judges, with captured setup icons and no campaign gates.
- Two-human hot seat through shared setup, named pass-the-mic cards, per-seat
  profile/source/rest state, guarded real input and untimed practice arenas.
- A static setup-plinth preview of each human's actual launch and plain crew,
  using the existing shared character-preview contract, not production captains.
- Twelve original toy shop items, four cosmetic kinds and independent P1/P2
  equipment, with a shared earned-Balboas wallet and once-only duel payout.
  Actual gameplay/setup/gallery rigs and frozen share portraits wear the outfits.
- Original boats, numeric P1/CPU/ECHO/P2 paddles, source-relative world ribbons,
  captions and responsive duel/input presentation.
- Frozen share portraits for both actual humans, truthful duel/test statistics
  and the shell's memory-only preview / explicit PNG save.
- Eleven free original-model gallery exhibits through the shared viewer,
  with live orbit/zoom/reset, reduced-motion parking and no voice state or save writes.
- Original owned canal SFX, microphone-quiet ambience rules and combined,
  responsive audio captions; no cruise music or performer samples.
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

Seventeen suites cover the scorer, low/high-register equivalence, synthesized PCM,
Remo parity, duel rules, calibration/persistence, canal audio, real scene/3D
paths, rendered sharing, the free gallery, captured branding, setup previews,
cosmetics/payouts and practice onboarding.
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

The first fifteen suites support headless runs. `canal_view_test.gd` and
`share_card_test.gd` require a real graphics window and deliberately exit 1
with `--headless`. Also run the three scene suites, gallery, art-capture,
setup-preview, store and onboarding suites with a window: ten windowed checks
in total.
Scene/canal/gallery checks cover rendering at
320x568, 568x320, 1280x720
and 2560x1080 with normal and 150% UI size. Tests do not enable a physical
microphone. Real Tab navigation checks eight workbench layouts and sixteen
empty/loaded-profile Soundcheck layouts, including whole focused controls,
actual numeric-editor names and capture/save isolation. Remo and buffered-PCM
calls verify quiet timer metadata and polite stable start/completion/errors.
Buffered-PCM regressions distinguish absent data from actual
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

Audio checks cover seeded PCM, usable headroom, smooth starts/ends and the
water-loop seam, real owned playback and immediate context stops. Real duel
events verify once-only captions with muted SFX, quiet microphone/setup/guard/
reference states, pause/retry/exit and the timeout-versus-judged finish.
Native checks verify actual visible verdict captions in all eight layouts,
not merely emitted signals, and retain the full compact listening ribbon.
Mixer waits deliberately allow playback to start before interruption and drain
before shutdown; these Dummy-driver checks do not establish acoustic safety.

Canal checks render both singer framings at both water endpoints in all eight
size/UI combinations, inspect actual launch paint and visible contour pixels,
and verify labels, pause, hidden-view shutdown and accessibility toggles.
All five arenas run through that matrix: **40 arena/size/UI combinations**.
Hiding individual scenery batches must change real pixels, including canopy
howlers; landmark bounds alone are not sufficient. The measured native maximum
is **23 draw calls**, below the 60-draw budget.
Headless regressions cover source-relative/amplitude-independent geometry,
silent gaps, water changes under reduced motion and clearing/retrying tracks.
Native duel checks also verify that articulated tow lines stay attached.
Pass `--sailor-capture-dir=<absolute directory>` after `--` for captures.
Scene checks also select all five icons through the real setup picker, verify
both lock deadlines/water directions, free repeats without ghost lock geometry,
drift-attached contours, all five actual judge rows/maxima, and a complete
five-judge Remo win through shell results/replay.

Gallery checks select every real shared-menu row, compare its meshes with the
match, verify CPU/P1/P2 identity and reject unknown exhibits before and after
ready without stale models. They check no audio/capture buses or save writes,
actual mouse/pad/touch camera changes, reset, shared auto-spin, reduced motion
and hidden-view shutdown. Native coverage is **88 exhibit/size/UI cases**,
including whole geometry/landmark framing and actual pixels from every launch,
with a measured maximum of **13 draw calls** against the 60-draw budget.
Pass `--sailor-gallery-capture-dir=<absolute directory>` after `--` for captures.
The two unavailable-exhibit errors are intentional rejection tests.

Art checks verify transparency, real CLI rejection paths, icon-only/levels-only
output isolation and default regeneration in a temporary directory. Native
checks reproduce the icon, preserve the five level stills and inspect actual
gold/blue pixels at 512, 64 and 32 pixels, with two measured draws against a
ten-draw limit. The actual title, standing picker cartridge and share texture
use the PNG without a colour tint. Pass
`--sailor-icon-capture-dir=<absolute directory>` after `--` for inspections.

Setup-preview checks use the real shared menu in collection and standalone,
with solo and two-human selection, all five arenas, actual mesh reuse and
canonical P1/P2 identity. Unknown prototypes, out-of-range seats and non-integer
seats clear old geometry and fail visibly; their three errors are intentional.
Native checks cover **25 cases**: solo/P1/P2 across the eight size/UI combinations,
plus expanded Details on a 320px phone at 150%. They verify usable focused
arena/player pickers and visible Start, complete geometry, actual paint/face/
plaque pixels, static frames, hidden-render shutdown and no audio/save changes.
The measured maximum is **3 draws** against a ten-draw limit. Pass
`--sailor-setup-capture-dir=<absolute directory>` after `--` for UI/model captures.

Shop checks exercise actual Buy/P2 Equip buttons, insufficient funds, one-time
spending, shared ownership, independent equipment and real save reload.
All twelve items run on both actual rigs: **24 model cases**. Native coverage
includes **24 shelf previews** at two widths and **eight shop size/UI layouts**,
with whole focused actions remaining scroll-accessible. Combined outfits are
fully framed in match, setup, gallery and frozen share portraits; later equips
cannot change old cards. Invalid data clears stale preview art and recovers
visibly. The suite restores exact Store bytes/state and checks other games,
settings, achievements, profiles and audio are untouched. Preview maximum is
**3 draws**, below ten. Pass `--sailor-store-capture-dir=<absolute directory>`
after `--` for shelf/shop/decorated-view captures. The duel suite settles
**seven actual completed matches**, including losses, echo and both human
winners, through the real results/payout path. It checks rounding boundaries,
human-only totals, bonus exclusions and that a second settlement cannot pay again.

Onboarding checks use actual Next/Done/Skip, Escape, controller, mouse and
emulated touch input, including seven real Router exit paths and finishing
during an incoming fade. They check player pacing, held-key repeats, live
Reduced motion, static/hidden rendering and no voice/audio/save changes.
The actual solo/hot-seat Guide retains all five definitions and live shared
key rebinding. Native coverage is **40 layouts**: three cards and both Guide
modes across four window sizes and normal/150% UI. Whole actions, physical
text size, scroll-reachable final lines, complete model framing and actual
pixels pass, with a measured maximum of **12 draws**, below 60.
Pass `--sailor-onboarding-capture-dir=<absolute directory>` after `--` for
opening/Guide captures.

Self-echo checks cover rejected/paused/missing seeds, the complete 600 ms gap,
frozen profiles/Quiet Mode, discarded idle PCM, softer synthetic playback,
delayed repeats and restarted/captioned returns after pause. A real buffered-PCM
seed faces actual Remo input through a 2-0 win; a fresh Remo seed also reaches
an echo win and the real shell result label. Replay drops every old snapshot.
Native runs check seed-ready/listening and echo review in all eight layouts,
including the ECHO boat label, visible controls and complete boat framing.

Hot-seat checks use the real shared setup/briefing and all five arenas, then
actual input for P1 and P2 2-0 wins, including a five-judge Pacific match.
They cover guards, cancellation, caller-relative free Repeat, pause/reannounced
playback, both shell scores/results and rematch cleanup. Buffered PCM at
160/280 Hz verifies separate measured/unmeasured profiles, reference isolation,
capture shutdown, session-only card choices and per-singer rest counts.
Fresh P2 Soundcheck uses actual synthetic PCM and explicit Save to adopt its
capture without a tree exit/restart or changing P1's profile/source.
All eight size/UI combinations cover both singers' handoff, live and review,
including scroll-accessible profiles, Ready after layout changes and actual P2
touch/gamepad input. These checks use Dummy audio, not physical devices.

Sharing checks cover accepted-best selection/ties, per-seat PCM geometry,
privacy, replay, silent/incomplete calls and seed/rival exclusion. The native
suite renders six complete input-driven duels, incomplete/scorer cases and a
display-only width fixture, with complete boats, visible gold and readable statistics,
static frames, isolated worlds and reversible human/solo/other-game card reuse.
Its measured maximum is **5 draws per portrait**, below the 20-draw limit.
All **27 final QR variants** decoded: full PNG, 600x315 PNG and quality-75
600x315 JPEG for nine cards. All 18 PNGs contained no text/EXIF metadata.
The real shell preview, explicit Save and direct preview produced identical PNG
pixels. No browser/mobile save or physical-device gate is thereby passed.
Pass `--sailor-share-capture-dir=<absolute directory>` after `--` for captures.
The default suite never saves a share PNG or changes the clipboard.
`--sailor-test-save` opts into the real Save action; use isolated user data and
preserve/restore the desktop clipboard, because the existing Save copies the
image path. That check removes only the PNG it creates.

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
examples should remain usable. Check SFX volume/mute/captions, comfortable cue
levels and that speaker reverberation cannot enter the next turn. This manual
pass has not been completed. For hot seat, repeat with two people using their
own profiles and mixed Microphone/Remo choices; verify each handoff requires
fresh microphone activation and that room tails cannot score as the next singer.

**Still unverified:** physical microphones and OS permissions, web/mobile
capture, real saloma scoring and cultural review. No licensed performer
recordings or cultural partner are available yet. The five marks are a game's
simplification, not a definition of the tradition. Do not treat synthetic
scores as passing the real-recording milestone gate.

The owner authorized Remo and grey-box duel work assuming that real-voice
validation works. That assumption does not mark its unchecked gate complete.
Recorded rival crews and campaign encounters/progression remain future work.
Hot seat currently uses all five free-practice arenas; future campaign access
is not decided. See `DESIGN.md` and `TODO.md`.

Re-record the labelled solo duel walkthrough only when its visuals/captions change.
It completes both tandas and reaches shell results with actual keyboard
events through the scorer and judges, never enabling
the microphone or substituting a prerecorded saloma:

```powershell
pwsh tools\record_tutorials.ps1 -Godot <godot-executable> -Games sailor_man -Variants solo -Quality 6
```