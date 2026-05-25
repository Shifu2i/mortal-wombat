class_name CharacterBase
extends SGCharacterBody2D

# All gameplay state and per-tick logic for a fighter. Inherits
# SGCharacterBody2D so movement runs through SG Physics 2D's deterministic
# fixed-point integrator. FightManager drives tick(input, frame) — never
# tick from _physics_process directly.
#
# Visuals (body sprite, hitbox flash, percentage label) live as child
# nodes and are positioned in local pixel space.

const HitboxRes := preload("res://src/combat/hitbox.gd")
const KnockbackUtil := preload("res://src/combat/knockback.gd")
const FsmRes := preload("res://src/combat/state_machine.gd")

@export var player_slot: int = 0
@export var is_dummy: bool = false
@export var jab: Resource  # Hitbox resource; defaults if null

# Movement constants — computed in _ready from SGFixed (fixed-point,
# per-tick). 1 SG unit = 1 pixel at the 480x270 base resolution.
var walk_speed_fx: int
var jump_vel_fx: int
var double_jump_vel_fx: int
var gravity_fx: int
var max_fall_fx: int

# Attack timeline (jab) in frames.
const JAB_STARTUP: int = 3
const JAB_ACTIVE_END: int = 6  # startup(3) + active(3) — frames 3..5 are hot
const JAB_TOTAL: int = 12

# Aerial bonus: aerial jabs deal AERIAL_BONUS_DAMAGE extra percent and are
# aimed in 8 directions from WASD held at the moment of the press.
const AERIAL_BONUS_DAMAGE: int = 5

# Character body extents in pixels — must match the SGCollisionShape2D set
# up in wombat.tscn. Used for hurtbox AABB queries.
const BODY_HALF_W: int = 12
const BODY_HALF_H: int = 20

var fsm: FsmRes
var damage_percent: int = 0
var facing: int = 1  # +1 right, -1 left
var jumps_used: int = 0
const MAX_JUMPS: int = 2
var hitstun_remaining: int = 0

# Each attack gets a unique id so the hit resolver can mark a victim as
# already-struck-by-this-attack and avoid multi-hit.
var current_attack_id: int = -1
var hits_dealt_this_attack: Dictionary = {}

var _spawn_position_fx_x: int = 0
var _spawn_position_fx_y: int = 0
var _hitbox_visual: Polygon2D = null
var _percent_label: Label = null
var _visual: Node2D = null

# KO counter — incremented every time the fighter crosses the blast zone
# and gets teleported back to spawn. Unlimited (no stock system in
# Phase 1); both player and dummy use the same handler.
var ko_count: int = 0

# The actual hitbox in play for the current attack — derived from `jab`
# but with aim direction, aerial damage bonus, etc. baked in at attack
# start. Cleared between attacks.
var _active_hitbox: Resource = null


func _ready() -> void:
	var sg: Object = Engine.get_singleton("SGFixed")
	walk_speed_fx = sg.from_int(2)
	jump_vel_fx = sg.from_int(4)
	double_jump_vel_fx = sg.from_float(3.5)
	gravity_fx = sg.from_float(0.2)
	max_fall_fx = sg.from_int(5)

	fsm = FsmRes.new()
	if jab == null:
		jab = HitboxRes.new()

	# Remember spawn for reset.
	var pos: SGFixedVector2 = get_fixed_position()
	_spawn_position_fx_x = pos.x
	_spawn_position_fx_y = pos.y

	# Set up reference back from the hurtbox if one exists in the scene.
	var hurt: Node = get_node_or_null("Hurtbox")
	if hurt != null and "character" in hurt:
		hurt.character = self

	# Up direction for floor detection: -y is up.
	var up: SGFixedVector2 = sg.vector2(0, -sg.from_int(1))
	set_up_direction(up)

	# Cache the percent label if the scene includes one.
	_percent_label = get_node_or_null("PercentLabel") as Label
	_refresh_percent_label()

	# Cache the visual subtree so we can mirror it by facing.
	_visual = get_node_or_null("Visual") as Node2D
	_apply_facing_to_visual()


# Driven by FightManager. Never set on _physics_process directly.
func tick(input: Dictionary, current_frame: int) -> void:
	var sg: Object = Engine.get_singleton("SGFixed")
	var v: SGFixedVector2 = velocity
	var eff: Dictionary = input if not is_dummy else _empty_input()

	# Gravity is applied every tick — move_and_slide cancels it on floor
	# contact. Zeroing vy on floor would lose contact and make
	# is_on_floor() flip false next tick.
	var new_vy: int = v.y + gravity_fx
	if new_vy > max_fall_fx:
		new_vy = max_fall_fx
	v.y = new_vy
	if is_on_floor():
		jumps_used = 0

	if hitstun_remaining > 0:
		hitstun_remaining -= 1
		# Don't override velocity — momentum from the hit carries us.
		if hitstun_remaining == 0:
			_settle_state_after_hitstun(current_frame)
	elif fsm.state == FsmRes.State.ATTACK_NEUTRAL:
		# Walk speed is still input-driven during the jab — the swing
		# doesn't lock movement, so the player can attack mid-dash and
		# chase knockback without stopping. Facing is locked from the
		# moment the attack began so the hitbox stays aimed.
		v.x = walk_speed_fx * eff.move_x
		_tick_attack(current_frame)
	else:
		v.x = walk_speed_fx * eff.move_x
		if eff.move_x != 0:
			facing = eff.move_x
		if eff.jump_pressed and jumps_used < MAX_JUMPS:
			var jv: int = jump_vel_fx if jumps_used == 0 else double_jump_vel_fx
			v.y = -jv
			jumps_used += 1
			fsm.transition_to(FsmRes.State.JUMP_RISE, current_frame)
		if eff.attack_pressed:
			# Phase 1: jab works grounded or airborne, walking or not.
			# One button always swings. Aerial jabs aim per WASD and
			# deal +AERIAL_BONUS_DAMAGE.
			_begin_attack(eff, current_frame)
		_update_locomotion_state(eff.move_x, current_frame)

	velocity = v
	move_and_slide()
	_apply_facing_to_visual()
	_refresh_percent_label()


func has_active_hitbox(current_frame: int) -> bool:
	if fsm.state != FsmRes.State.ATTACK_NEUTRAL:
		return false
	var f: int = fsm.frames_in_state(current_frame)
	return f >= JAB_STARTUP and f < JAB_ACTIVE_END


func get_hitbox_rect() -> Rect2:
	# Pixel-space world rect for the active hitbox. Float math is fine here
	# — this rect is only used for AABB overlap against another fighter's
	# hurtbox, and both come from the same float positions, so the test is
	# self-consistent within one tick. (For Phase 5 rollback, replace with
	# fixed-point comparison.)
	var hb: Resource = _active_hitbox if _active_hitbox != null else jab
	# Offset already encodes direction (aim or facing), so no facing
	# multiplication here.
	var center: Vector2 = position + Vector2(hb.offset_px)
	var size: Vector2 = Vector2(hb.size_px)
	return Rect2(center - size * 0.5, size)


func get_hurtbox_rect() -> Rect2:
	var center: Vector2 = position
	var size: Vector2 = Vector2(BODY_HALF_W * 2, BODY_HALF_H * 2)
	return Rect2(center - size * 0.5, size)


func apply_hit(hb: Resource, _attacker_facing: int = 1, damage_multiplier: int = 1) -> void:
	# Hitbox angle_degrees already encodes direction (grounded
	# facing-mirrored, aerial aimed), so we don't flip velocity by
	# attacker facing here. damage_multiplier is integer to keep
	# damage_percent deterministic — crits pass 2.
	damage_percent += hb.damage * damage_multiplier
	var kb: Dictionary = KnockbackUtil.compute(damage_percent, hb)
	velocity = kb.velocity_fixed
	hitstun_remaining = kb.hitstun_frames
	fsm.transition_to(FsmRes.State.HITSTUN, 0)
	_refresh_percent_label()


func ko_and_respawn() -> void:
	# KO = teleport back to spawn + full state reset.
	#
	# set_fixed_position only marks the node's transform dirty; the SG
	# physics server's collision rep doesn't sync until something else
	# touches it. Without sync_to_physics_engine(), move_and_slide on
	# the next tick still operates from the offscreen position, drags
	# the visible position back outside the blast zone, and the KO
	# loops every frame.
	var sg: Object = Engine.get_singleton("SGFixed")
	set_fixed_position(sg.vector2(_spawn_position_fx_x, _spawn_position_fx_y))
	sync_to_physics_engine()
	velocity.x = 0
	velocity.y = 0
	damage_percent = 0
	jumps_used = 0
	hitstun_remaining = 0
	current_attack_id = -1
	hits_dealt_this_attack.clear()
	_active_hitbox = null
	fsm = FsmRes.new()
	ko_count += 1
	_hide_hitbox_visual()
	_refresh_percent_label()


# Backwards-compat alias for any caller still using the old name.
func reset_to_spawn() -> void:
	ko_and_respawn()


func _begin_attack(input: Dictionary, current_frame: int) -> void:
	fsm.transition_to(FsmRes.State.ATTACK_NEUTRAL, current_frame)
	current_attack_id += 1
	hits_dealt_this_attack.clear()
	_active_hitbox = _build_active_hitbox(input)


# Builds a per-attack Hitbox derived from `jab`. Aerial attacks get a
# damage bonus and are aimed via WASD; grounded attacks aim along the
# current facing.
func _build_active_hitbox(input: Dictionary) -> Resource:
	var hb: Resource = HitboxRes.new()
	hb.base_damage = jab.base_damage
	hb.base_knockback = jab.base_knockback
	hb.knockback_scale = jab.knockback_scale
	hb.active_frames = jab.active_frames
	hb.size_px = jab.size_px

	var aerial: bool = not is_on_floor()
	hb.damage = jab.damage + (AERIAL_BONUS_DAMAGE if aerial else 0)

	var aim_x: int = 0
	var aim_y: int = 0
	if aerial:
		aim_x = input.get("move_x", 0)
		aim_y = input.get("move_y", 0)
	if aim_x == 0 and aim_y == 0:
		# No direction held — aim forward along facing, slightly upward
		# like the original grounded jab (40 deg).
		var ground_angle: int = jab.angle_degrees if facing >= 0 else 180 - jab.angle_degrees
		hb.angle_degrees = ground_angle
		var rad: float = float(ground_angle) * 0.017453292519943295
		hb.offset_px = Vector2i(int(round(cos(rad) * 16.0)), int(round(-sin(rad) * 16.0)))
	else:
		# 8-direction aim. Angle: 0=right, 90=up, in math convention.
		var rad: float = atan2(float(-aim_y), float(aim_x))
		hb.angle_degrees = int(round(rad * 57.29577951308232))
		hb.offset_px = Vector2i(int(round(cos(rad) * 16.0)), int(round(-sin(rad) * 16.0)))
	return hb


func get_active_hitbox() -> Resource:
	return _active_hitbox


func _tick_attack(current_frame: int) -> void:
	var f: int = fsm.frames_in_state(current_frame)
	if f == JAB_STARTUP:
		_show_hitbox_visual()
	elif f == JAB_ACTIVE_END:
		_hide_hitbox_visual()
	elif f >= JAB_TOTAL:
		_settle_state_after_hitstun(current_frame)


func _settle_state_after_hitstun(current_frame: int) -> void:
	if is_on_floor():
		fsm.transition_to(FsmRes.State.IDLE, current_frame)
	else:
		fsm.transition_to(FsmRes.State.FALL, current_frame)


func _update_locomotion_state(move_x: int, current_frame: int) -> void:
	if fsm.state == FsmRes.State.ATTACK_NEUTRAL or fsm.state == FsmRes.State.HITSTUN:
		return
	if not is_on_floor():
		var v: SGFixedVector2 = velocity
		if v.y < 0:
			if fsm.state != FsmRes.State.JUMP_RISE:
				fsm.transition_to(FsmRes.State.JUMP_RISE, current_frame)
		else:
			if fsm.state != FsmRes.State.FALL:
				fsm.transition_to(FsmRes.State.FALL, current_frame)
	else:
		if move_x != 0:
			if fsm.state != FsmRes.State.RUN:
				fsm.transition_to(FsmRes.State.RUN, current_frame)
		else:
			if fsm.state != FsmRes.State.IDLE:
				fsm.transition_to(FsmRes.State.IDLE, current_frame)


func _show_hitbox_visual() -> void:
	if _hitbox_visual != null:
		return
	var hb: Resource = _active_hitbox if _active_hitbox != null else jab
	_hitbox_visual = Polygon2D.new()
	var hw: float = float(hb.size_px.x) * 0.5
	var hh: float = float(hb.size_px.y) * 0.5
	_hitbox_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	_hitbox_visual.color = Color(1.0, 0.3, 0.2, 0.55)
	_hitbox_visual.position = Vector2(hb.offset_px)
	add_child(_hitbox_visual)


func _hide_hitbox_visual() -> void:
	if _hitbox_visual != null:
		_hitbox_visual.queue_free()
		_hitbox_visual = null


func _refresh_percent_label() -> void:
	if _percent_label == null:
		return
	_percent_label.text = "%d%%" % damage_percent


func _apply_facing_to_visual() -> void:
	if _visual == null:
		return
	# Mirror the whole visual subtree by flipping scale.x. The character
	# polygons are authored facing +x; -x facing renders them mirrored.
	_visual.scale.x = float(facing)


func _empty_input() -> Dictionary:
	return {
		"move_x": 0,
		"jump": false,
		"jump_pressed": false,
		"attack": false,
		"attack_pressed": false,
		"reset_pressed": false,
	}
