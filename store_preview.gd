extends "res://games/sailor_man/character_preview.gd"

## A still P1 shelf model uses the same rig, cosmetics and framing as setup.
## Item ownership, injected colours and live equipment never alter the advert.

var _preview_outfit := Outfit.complete({})


func _init() -> void:
	_watch_equipment = false


## Only the canonical item id selects the advertised model.
func configure(item: Dictionary) -> void:
	var declared := Outfit.item(str(item.get("id", "")))
	_preview_outfit = Outfit.complete({})
	if declared.is_empty():
		super({"id": ""})
		return
	_preview_outfit[str(declared["kind"])] = str(declared["id"])
	super({"id": Options.CHARACTER_ID, "player_index": 0})
	if is_node_ready():
		_refresh_outfit()


## Still artwork remains available with reduced motion, without an animation loop.
func set_preview_running(_running: bool) -> void:
	_update_visibility()


func _read_outfit() -> Dictionary:
	return _preview_outfit.duplicate(true)


func _update_visibility() -> void:
	super()
	if viewport != null and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
