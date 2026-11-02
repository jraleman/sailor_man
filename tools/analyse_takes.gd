extends SceneTree

## Local, read-only WAV comparisons before authentic-recording review.
## Output contains provisional scores/evidence, never PCM, tracks or profiles.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const WavSource = preload("res://games/sailor_man/tools/wav_voice_source.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")

const PROFILE_OPTIONS := {
	"--chest-hz": "chest_hz", "--carry-level": "carry_level",
	"--falsetto-low": "falsetto_low", "--falsetto-high": "falsetto_high",
}
const USAGE := """Sailor Man offline WAV analysis (provisional game scores)
After Godot's -- separator:
  [options] <file.wav> [more.wav ...]
  --reference=PATH       Score every take as an answer to this WAV.
  --chest-hz=HZ          Manual chest reference (default 160).
  --carry-level=RMS      Manual carrying reference (default 0.08).
  --falsetto-low=CENTS   Relative band lower bound (default 700).
  --falsetto-high=CENTS  Relative band upper bound (default 1300).
  --measured-falsetto    Declare that the supplied band was actually measured.
  --noise-floor=RMS     Recording's room RMS (default 0.004).
  --sensitivity=GAIN    Positive linear gain (default 1).
  --quiet-mode          Bypass the scorer's carrying-level gate.
  --help                Show this help.
Use short, single-call mono/stereo RIFF/WAVE recordings outside the repository.
Rates must exceed 8800 Hz; 44.1/48/96 kHz are covered by the WAV tests.
No microphone, playback, automatic trimming or amplitude normalization.
JSON totals/marks are 0..1; score_out_of_100 is the headline score.
Exit 0: every input scored; exit 2: arguments or any input failed.
These scores do not certify authentic saloma quality or cultural review."""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := parse_arguments(OS.get_cmdline_user_args())
	if not bool(options["valid"]):
		printerr("Sailor Man analysis: %s" % options["error"])
		print(JSON.stringify(options))
		quit(2)
		return
	if bool(options["help"]):
		print(USAGE)
		quit(0)
		return
	var report := analyse(options)
	print(JSON.stringify(report))
	if not bool(report["valid"]):
		printerr("Sailor Man analysis: %s" % report["error"])
	quit(0 if bool(report["valid"]) else 2)


## Use explicit manual references; malformed options must not become defaults.
static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var profile := Frame.profile()
	var files := PackedStringArray()
	var options := {
		"valid": true, "help": false, "profile": profile, "reference": "",
		"noise_floor": WavSource.DEFAULT_NOISE_FLOOR, "sensitivity": 1.0,
		"quiet_mode": false,
	}
	for argument in arguments:
		if argument in ["--help", "-h"]:
			options["help"] = true
		elif argument == "--quiet-mode":
			options["quiet_mode"] = true
		elif argument == "--measured-falsetto":
			profile["falsetto_calibrated"] = true
		elif argument.begins_with("--game="):
			continue
		elif argument.begins_with("--"):
			var parts := argument.split("=", true, 1)
			if parts.size() != 2 or parts[1].is_empty():
				return _argument_error("Expected --option=value, got '%s'." % argument)
			var key := parts[0]
			var value := parts[1]
			if key == "--reference":
				options["reference"] = value
				continue
			if not PROFILE_OPTIONS.has(key) and key not in ["--noise-floor", "--sensitivity"]:
				return _argument_error("Unknown option '%s'." % key)
			if not value.is_valid_float() or not is_finite(value.to_float()):
				return _argument_error("Option '%s' needs a finite number." % key)
			if PROFILE_OPTIONS.has(key):
				profile[PROFILE_OPTIONS[key]] = value.to_float()
			else:
				options[key.trim_prefix("--").replace("-", "_")] = value.to_float()
		else:
			files.append(argument)
	if bool(options["help"]):
		return options
	var error := WavSource.configuration_error(
		profile, float(options["noise_floor"]), float(options["sensitivity"])
	)
	if not error.is_empty():
		return _argument_error(error)
	if files.is_empty():
		return _argument_error("Supply at least one WAV file, or use --help.")
	options["files"] = files
	return options


## A failed reference aborts; a failed take remains visible beside valid ones.
static func analyse(options: Dictionary) -> Dictionary:
	var profile: Dictionary = options["profile"]
	var reference: Array[Dictionary] = []
	var reference_path := str(options["reference"])
	var noise_floor := float(options["noise_floor"])
	var sensitivity := float(options["sensitivity"])
	var report := {
		"valid": true, "provisional": true, "reference": reference_path,
		"quiet_mode": bool(options["quiet_mode"]), "takes": [],
	}
	if not reference_path.is_empty():
		var loaded := WavSource.read(reference_path, profile, noise_floor, sensitivity)
		if not bool(loaded["valid"]):
			report["valid"] = false
			report["error"] = "Reference '%s': %s" % [reference_path, loaded["error"]]
			return report
		reference = loaded["track"]
	for path: String in options["files"]:
		var loaded := WavSource.read(path, profile, noise_floor, sensitivity)
		var take := loaded.duplicate()
		take.erase("track")
		take["file"] = path
		if bool(loaded["valid"]):
			var score := Scorer.score(
				loaded["track"], profile, reference, bool(options["quiet_mode"])
			)
			take["valid"] = bool(score["valid"])
			if bool(score["valid"]):
				take["score"] = score
				take["score_out_of_100"] = float(score["total"]) * 100.0
			else:
				take["error"] = str(score["error"])
		if not bool(take["valid"]):
			report["valid"] = false
		report["takes"].append(take)
	if not bool(report["valid"]):
		report["error"] = "One or more WAV takes could not be analyzed; see each take's error."
	return report


static func _argument_error(error: String) -> Dictionary:
	return {"valid": false, "provisional": true, "error": error}
