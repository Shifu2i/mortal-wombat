class_name InputBuffer
extends Node

# Per-player rolling input queue, 60 ticks deep. The ONLY place that
# reads raw Input.* during gameplay. Characters read from
# `get_snapshot(slot, frame)` — never from Input directly.
#
# Slot 0: local human (keyboard + gamepad merged through InputMap).
# Slot 1: Phase 1 dummy — always empty snapshots. Phase 5 will swap
# this for the remote player's inputs delivered via the rollback addon.

const BUFFER_DEPTH: int = 60
const SLOT_COUNT: int = 2

# An input snapshot is a Dictionary with these keys (all bool except move_x):
#   move_x: int        (-1, 0, +1)
#   jump: bool         (held)
#   jump_pressed: bool (rising edge this tick)
#   attack: bool
#   attack_pressed: bool
#   reset_pressed: bool
#
# Dictionary not a class so it's trivially serialisable for rollback.

var _buffers: Array = []  # Array of Arrays of Dictionary
var _prev_held: Array = []  # per-slot last tick's held state, for edges


func _ready() -> void:
	_buffers.resize(SLOT_COUNT)
	_prev_held.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_buffers[i] = []
		_prev_held[i] = _empty_snapshot()


# Called once per tick by FightManager, before character ticks run.
func sample_tick() -> void:
	var snap_p0: Dictionary = _sample_local_player()
	_push(0, snap_p0)
	# Slot 1: empty for Phase 1.
	_push(1, _empty_snapshot())


# Read the snapshot for `slot` at sim `frame`. If the frame is older than
# what we still hold, returns an empty snapshot (safe default).
func get_snapshot(slot: int, frame: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return _empty_snapshot()
	var buf: Array = _buffers[slot]
	if buf.is_empty():
		return _empty_snapshot()
	var newest_frame: int = buf.size() - 1  # 0-indexed within current buffer
	# We store snapshots in tick order; the last entry is the latest tick.
	# Frame mapping: caller passes the absolute sim frame; we keep at most
	# BUFFER_DEPTH entries, so the entry for frame F is at index
	# F - (latest_frame - buf.size() + 1). For Phase 1 callers just want
	# "the current tick's input", so they pass the frame they're processing.
	# Simplest: return the latest entry. This matches single-machine
	# simulation. Rollback will replace this lookup.
	return buf[newest_frame]


func reset() -> void:
	for i in SLOT_COUNT:
		_buffers[i].clear()
		_prev_held[i] = _empty_snapshot()


func _push(slot: int, snap: Dictionary) -> void:
	var buf: Array = _buffers[slot]
	buf.append(snap)
	if buf.size() > BUFFER_DEPTH:
		buf.pop_front()


func _sample_local_player() -> Dictionary:
	var held: Dictionary = {
		"move_x": _axis("move_left", "move_right"),
		"move_y": _axis("move_up", "move_down"),
		"jump": Input.is_action_pressed("jump"),
		"attack": Input.is_action_pressed("attack"),
	}
	var prev: Dictionary = _prev_held[0]
	var snap: Dictionary = {
		"move_x": held.move_x,
		"move_y": held.move_y,
		"jump": held.jump,
		"jump_pressed": held.jump and not prev.get("jump", false),
		"attack": held.attack,
		"attack_pressed": held.attack and not prev.get("attack", false),
		"reset_pressed": Input.is_action_just_pressed("reset"),
	}
	_prev_held[0] = held
	return snap


func _axis(neg_action: String, pos_action: String) -> int:
	var v: int = 0
	if Input.is_action_pressed(pos_action):
		v += 1
	if Input.is_action_pressed(neg_action):
		v -= 1
	return v


func _empty_snapshot() -> Dictionary:
	return {
		"move_x": 0,
		"move_y": 0,
		"jump": false,
		"jump_pressed": false,
		"attack": false,
		"attack_pressed": false,
		"reset_pressed": false,
	}
