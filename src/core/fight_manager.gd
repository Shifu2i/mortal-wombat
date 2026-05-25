extends Node2D

# Drives the sim each physics tick: sample inputs, tick characters,
# resolve hits, check KO. Owns the TickClock frame counter and the
# InputBuffer instance. Holds references to the two fighters set up in
# main.tscn.

const InputBufferRes := preload("res://src/core/input_buffer.gd")
const TickClockRes := preload("res://src/core/tick_clock.gd")
const FsmRes := preload("res://src/combat/state_machine.gd")
const CharacterBase := preload("res://src/characters/character_base.gd")
const SeededRngRes := preload("res://src/core/seeded_rng.gd")

# Crits: 1-in-CRIT_DENOM hits double their damage. Roll comes from
# SeededRng (see CLAUDE.md rule 3) so rollback resimulation lands the
# same crits on every machine.
const CRIT_DENOM: int = 20
const CRIT_MULTIPLIER: int = 2
@export var rng_seed: int = 0xC0FFEE

@export var blast_zone: Rect2 = Rect2(-80, -80, 640, 430)
# Default expands the 480x270 viewport by ~80px each side. Going outside
# this rect = KO.

var clock: TickClockRes = TickClockRes.new()
var input_buffer: InputBufferRes
var rng: SeededRngRes
var fighters: Array = []  # CharacterBase
var ko_event: String = ""  # consumed by debug overlay then cleared

signal frame_advanced(frame: int)  # UI/debug only — never gameplay
signal ko_occurred(slot: int)  # UI/debug


func _ready() -> void:
	input_buffer = InputBufferRes.new()
	input_buffer.name = "InputBuffer"
	add_child(input_buffer)
	rng = SeededRngRes.new(rng_seed)

	# Discover fighters: any CharacterBase descendant.
	fighters.clear()
	for child in get_children():
		_collect_fighters(child)
	fighters.sort_custom(func(a, b): return a.player_slot < b.player_slot)


func _collect_fighters(node: Node) -> void:
	if node is CharacterBase:
		fighters.append(node)
	for c in node.get_children():
		_collect_fighters(c)


func _physics_process(_delta: float) -> void:
	input_buffer.sample_tick()
	clock.advance()
	var f_now: int = clock.frame

	var p0_snap: Dictionary = input_buffer.get_snapshot(0, f_now)
	if p0_snap.reset_pressed:
		_reset_round()
		frame_advanced.emit(clock.frame)
		return

	for fighter in fighters:
		var snap: Dictionary = input_buffer.get_snapshot(fighter.player_slot, f_now)
		fighter.tick(snap, f_now)

	for attacker in fighters:
		if not attacker.has_active_hitbox(f_now):
			continue
		var hb_rect: Rect2 = attacker.get_hitbox_rect()
		for victim in fighters:
			if victim == attacker:
				continue
			if attacker.hits_dealt_this_attack.has(victim.get_instance_id()):
				continue
			if hb_rect.intersects(victim.get_hurtbox_rect()):
				var hb: Resource = attacker.get_active_hitbox()
				if hb == null:
					hb = attacker.jab
				var is_crit: bool = rng.next_int(1, CRIT_DENOM) == 1
				var mult: int = CRIT_MULTIPLIER if is_crit else 1
				if is_crit:
					ko_event = "CRIT x%d on frame %d" % [CRIT_MULTIPLIER, f_now]
				victim.apply_hit(hb, attacker.facing, mult)
				attacker.hits_dealt_this_attack[victim.get_instance_id()] = true

	for fighter in fighters:
		if not blast_zone.has_point(fighter.position):
			ko_occurred.emit(fighter.player_slot)
			ko_event = "KO P%d on frame %d" % [fighter.player_slot + 1, f_now]
			fighter.reset_to_spawn()

	frame_advanced.emit(f_now)


func _reset_round() -> void:
	clock.reset()
	input_buffer.reset()
	rng.reset(rng_seed)
	for fighter in fighters:
		fighter.reset_to_spawn()
	ko_event = "RESET"


func get_debug_state() -> Dictionary:
	var p1_state_name: String = "-"
	var p1_percent: int = 0
	var dummy_percent: int = 0
	var p1_input: Dictionary = {}
	for f in fighters:
		if f.player_slot == 0:
			p1_state_name = FsmRes.state_name(f.fsm.state)
			p1_percent = f.damage_percent
			p1_input = input_buffer.get_snapshot(0, clock.frame)
		elif f.is_dummy:
			dummy_percent = f.damage_percent
	return {
		"frame": clock.frame,
		"p1_state": p1_state_name,
		"p1_percent": p1_percent,
		"dummy_percent": dummy_percent,
		"input": p1_input,
		"ko": ko_event,
	}
