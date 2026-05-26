extends CanvasLayer

# Debug HUD: top-left monospace readout of sim frame, P1 state, input
# snapshot tail, and percentages. Reads FightManager once per render
# frame — not in the sim path, so signals/await/whatever are fine here
# (this is UI, not gameplay).

@export var fight_manager_path: NodePath
@onready var _label: Label = $Label

var _fight_manager: Node


func _ready() -> void:
	_fight_manager = get_node_or_null(fight_manager_path)


func _process(_delta: float) -> void:
	if _fight_manager == null:
		_label.text = "(no fight manager)"
		return
	var d: Dictionary = _fight_manager.get_debug_state()
	var inp: Dictionary = d.input
	var move_glyph: String = "."
	if inp.get("move_x", 0) < 0:
		move_glyph = "<"
	elif inp.get("move_x", 0) > 0:
		move_glyph = ">"
	var jump_glyph: String = "J" if inp.get("jump", false) else "."
	var atk_glyph: String = "B" if inp.get("attack", false) else "."
	var kick_glyph: String = "K" if inp.get("kick", false) else "."
	var roll_glyph: String = "R" if inp.get("roll", false) else "."
	var block_glyph: String = "S" if inp.get("block", false) else "."
	_label.text = ("frame: %d\n" % d.frame
		+ "p1 state: %s\n" % d.p1_state
		+ "p1 input: [%s%s%s%s%s%s]\n" % [move_glyph, jump_glyph, atk_glyph, kick_glyph, roll_glyph, block_glyph]
		+ "p1 %%: %d (KOs: %d)\n" % [d.p1_percent, d.p1_kos]
		+ "dummy %%: %d (KOs: %d)\n" % [d.dummy_percent, d.dummy_kos]
		+ ("%s" % d.ko if d.ko != "" else ""))
