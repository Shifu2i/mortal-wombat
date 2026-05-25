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
@export var jab: Resource  # Hitbox resource for the bite; defaults if null

# Movement constants — computed in _ready from SGFixed (fixed-point,
# per-tick). 1 SG unit = 1 pixel at the 480x270 base resolution.
var walk_speed_fx: int
var jump_vel_fx: int
var double_jump_vel_fx: int
var gravity_fx: int
var max_fall_fx: int
var roll_speed_fx: int

# Bite (J): the original jab, just renamed. Quick, low-commit poke.
const BITE_STARTUP: int = 3
const BITE_ACTIVE_END: int = 6
const BITE_TOTAL: int = 12

# Kick (I): slower, longer reach, more damage. Grounded or aerial.
const KICK_STARTUP: int = 6
const KICK_ACTIVE_END: int = 10
const KICK_TOTAL: int = 20
const KICK_DAMAGE: int = 13
const KICK_BASE_KB: int = 45
const KICK_KB_SCALE: float = 1.3
const KICK_SIZE: Vector2i = Vector2i(26, 14)
const KICK_OFFSET: int = 20
const KICK_ANGLE_DEG: int = 35

# Roll (U): ground-only forward roll with damage on contact. Locks
# facing, fast horizontal movement, body is the hitbox.
const ROLL_STARTUP: int = 2
const ROLL_ACTIVE_END: int = 22
const ROLL_TOTAL: int = 26
const ROLL_DAMAGE: int = 8
const ROLL_BASE_KB: int = 25
const ROLL_KB_SCALE: float = 0.9
const ROLL_ANGLE_DEG: int = 20

# Block (K): wombats use the cartilaginous plate in their rump as a
# shield. While held, character is rooted, takes a fraction of incoming
# damage and almost no knockback.
const BLOCK_DAMAGE_DIVISOR: int = 4
const BLOCK_KB_DIVISOR: int = 5
const BLOCK_HITSTUN_DIVISOR: int = 2

# Stamina: integer units so the meter is rollback-deterministic. Drains
# faster than it regens — sitting in block forever isn't viable. Eating
# a hit while blocking costs extra stamina proportional to the damage
# absorbed. When it hits zero the shield breaks: forced exit plus a
# lockout window before block can be entered again.
const BLOCK_STAMINA_MAX: int = 180
const BLOCK_STAMINA_DRAIN_PER_FRAME: int = 2
const BLOCK_STAMINA_REGEN_PER_FRAME: int = 1
const BLOCK_STAMINA_HIT_COST_PER_DMG: int = 4
const BLOCK_STAMINA_MIN_TO_ENTER: int = 20
const BLOCK_BREAK_LOCKOUT_FRAMES: int = 90

# Aerial bonus: aerial bites/kicks deal AERIAL_BONUS_DAMAGE extra
# percent and are aimed in 8 directions from WASD held at the press.
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
var _stamina_fg: Polygon2D = null

var block_stamina: int = BLOCK_STAMINA_MAX
var block_lockout: int = 0

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
	roll_speed_fx = sg.from_int(4)

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

	_percent_label = get_node_or_null("PercentLabel") as Label
	_refresh_percent_label()

	_visual = get_node_or_null("Visual") as Node2D
	_apply_facing_to_visual()

	_stamina_fg = get_node_or_null("StaminaBarFg") as Polygon2D
	_refresh_stamina_bar()


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
		if hitstun_remaining == 0:
			_settle_state_after_hitstun(current_frame)
	elif fsm.state == FsmRes.State.ATTACK_BITE or fsm.state == FsmRes.State.ATTACK_KICK:
		# Movement still input-driven during a strike — the player can
		# chase knockback. Facing is locked from the moment the attack
		# began so the hitbox stays aimed.
		v.x = walk_speed_fx * eff.move_x
		_tick_attack(current_frame)
	elif fsm.state == FsmRes.State.ROLL:
		# Forward roll: fixed velocity in the facing direction; player
		# can't steer or jump out. Releases the BLOCK/attack queue at
		# the end like any other action.
		v.x = roll_speed_fx * facing
		_tick_roll(current_frame)
		_apply_roll_spin()
	elif fsm.state == FsmRes.State.BLOCK:
		# Rooted while held. Drain stamina each tick; if it bottoms out
		# the shield breaks and goes on lockout. Release K to drop.
		v.x = 0
		block_stamina -= BLOCK_STAMINA_DRAIN_PER_FRAME
		if block_stamina <= 0:
			block_stamina = 0
			_shield_break(current_frame)
		elif not eff.block:
			_exit_block(current_frame)
	else:
		# Stamina regens outside of block. Lockout ticks down here too.
		if block_stamina < BLOCK_STAMINA_MAX:
			block_stamina = min(BLOCK_STAMINA_MAX,
				block_stamina + BLOCK_STAMINA_REGEN_PER_FRAME)
		if block_lockout > 0:
			block_lockout -= 1

		v.x = walk_speed_fx * eff.move_x
		if eff.move_x != 0:
			facing = eff.move_x

		if eff.jump_pressed and jumps_used < MAX_JUMPS:
			var jv: int = jump_vel_fx if jumps_used == 0 else double_jump_vel_fx
			v.y = -jv
			jumps_used += 1
			fsm.transition_to(FsmRes.State.JUMP_RISE, current_frame)

		# Action priority: block > roll > kick > bite. Block needs to win
		# over other actions so you can shield-cancel a walk; roll/kick
		# are committal, bite is the spammy poke.
		if (eff.block and is_on_floor()
				and block_lockout == 0
				and block_stamina >= BLOCK_STAMINA_MIN_TO_ENTER):
			_enter_block(current_frame)
		elif eff.roll_pressed and is_on_floor():
			_begin_roll(current_frame)
		elif eff.kick_pressed:
			_begin_kick(eff, current_frame)
		elif eff.attack_pressed:
			_begin_bite(eff, current_frame)

		_update_locomotion_state(eff.move_x, current_frame)

	velocity = v
	move_and_slide()
	_apply_facing_to_visual()
	_refresh_percent_label()
	_refresh_stamina_bar()


func has_active_hitbox(current_frame: int) -> bool:
	var f: int = fsm.frames_in_state(current_frame)
	match fsm.state:
		FsmRes.State.ATTACK_BITE:
			return f >= BITE_STARTUP and f < BITE_ACTIVE_END
		FsmRes.State.ATTACK_KICK:
			return f >= KICK_STARTUP and f < KICK_ACTIVE_END
		FsmRes.State.ROLL:
			return f >= ROLL_STARTUP and f < ROLL_ACTIVE_END
	return false


func get_hitbox_rect() -> Rect2:
	# Pixel-space world rect for the active hitbox. Float math is fine here
	# — this rect is only used for AABB overlap against another fighter's
	# hurtbox, and both come from the same float positions, so the test is
	# self-consistent within one tick. (For Phase 5 rollback, replace with
	# fixed-point comparison.)
	var hb: Resource = _active_hitbox if _active_hitbox != null else jab
	var center: Vector2 = position + Vector2(hb.offset_px)
	var size: Vector2 = Vector2(hb.size_px)
	return Rect2(center - size * 0.5, size)


func get_hurtbox_rect() -> Rect2:
	var center: Vector2 = position
	var size: Vector2 = Vector2(BODY_HALF_W * 2, BODY_HALF_H * 2)
	return Rect2(center - size * 0.5, size)


func apply_hit(hb: Resource, _attacker_facing: int = 1, damage_multiplier: int = 1) -> void:
	# Blocking: the cartilaginous bum eats most of the impact. Future
	# tuning could add directional checks (only blocks from rear), a
	# stamina meter, and shield-break. For now it's a flat damage and
	# knockback divisor with reduced hitstun.
	var blocking: bool = fsm.state == FsmRes.State.BLOCK
	var damage: int = hb.damage * damage_multiplier
	if blocking:
		damage = max(1, damage / BLOCK_DAMAGE_DIVISOR)
		# Taking a hit costs stamina too — turtling through a heavy
		# string burns the shield faster than just holding it.
		block_stamina -= damage * BLOCK_STAMINA_HIT_COST_PER_DMG
		if block_stamina <= 0:
			block_stamina = 0
			_shield_break(0)
	damage_percent += damage

	var kb: Dictionary = KnockbackUtil.compute(damage_percent, hb)
	if blocking:
		var v: SGFixedVector2 = kb.velocity_fixed
		v.x = v.x / BLOCK_KB_DIVISOR
		v.y = v.y / BLOCK_KB_DIVISOR
		velocity = v
		hitstun_remaining = max(1, kb.hitstun_frames / BLOCK_HITSTUN_DIVISOR)
	else:
		velocity = kb.velocity_fixed
		hitstun_remaining = kb.hitstun_frames
		fsm.transition_to(FsmRes.State.HITSTUN, 0)
		_clear_block_visual()
		_clear_roll_visual()
	_refresh_percent_label()


func ko_and_respawn() -> void:
	# See CLAUDE.md note on the SG teleport gotcha — sync_to_physics_engine
	# after set_fixed_position is non-negotiable.
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
	block_stamina = BLOCK_STAMINA_MAX
	block_lockout = 0
	_hide_hitbox_visual()
	_clear_block_visual()
	_clear_roll_visual()
	_refresh_percent_label()
	_refresh_stamina_bar()


func reset_to_spawn() -> void:
	ko_and_respawn()


func _begin_bite(input: Dictionary, current_frame: int) -> void:
	fsm.transition_to(FsmRes.State.ATTACK_BITE, current_frame)
	current_attack_id += 1
	hits_dealt_this_attack.clear()
	_active_hitbox = _build_bite_hitbox(input)


func _begin_kick(input: Dictionary, current_frame: int) -> void:
	fsm.transition_to(FsmRes.State.ATTACK_KICK, current_frame)
	current_attack_id += 1
	hits_dealt_this_attack.clear()
	_active_hitbox = _build_kick_hitbox(input)


func _begin_roll(current_frame: int) -> void:
	fsm.transition_to(FsmRes.State.ROLL, current_frame)
	current_attack_id += 1
	hits_dealt_this_attack.clear()
	_active_hitbox = _build_roll_hitbox()


func _enter_block(current_frame: int) -> void:
	if fsm.state == FsmRes.State.BLOCK:
		return
	fsm.transition_to(FsmRes.State.BLOCK, current_frame)
	_apply_block_visual()


func _exit_block(current_frame: int) -> void:
	_clear_block_visual()
	fsm.transition_to(FsmRes.State.IDLE, current_frame)


func _shield_break(current_frame: int) -> void:
	# Stamina depleted: drop the shield and lock the input out for a
	# spell. Visually flash the bar red via the modulate on the fg poly.
	block_lockout = BLOCK_BREAK_LOCKOUT_FRAMES
	_clear_block_visual()
	fsm.transition_to(FsmRes.State.IDLE, current_frame)


func _build_bite_hitbox(input: Dictionary) -> Resource:
	var hb: Resource = HitboxRes.new()
	hb.base_damage = jab.base_damage
	hb.base_knockback = jab.base_knockback
	hb.knockback_scale = jab.knockback_scale
	hb.active_frames = jab.active_frames
	hb.size_px = jab.size_px

	var aerial: bool = not is_on_floor()
	hb.damage = jab.damage + (AERIAL_BONUS_DAMAGE if aerial else 0)
	_aim_hitbox(hb, input, jab.angle_degrees, 16)
	return hb


func _build_kick_hitbox(input: Dictionary) -> Resource:
	var hb: Resource = HitboxRes.new()
	hb.base_damage = KICK_DAMAGE
	hb.base_knockback = KICK_BASE_KB
	hb.knockback_scale = KICK_KB_SCALE
	hb.active_frames = KICK_ACTIVE_END - KICK_STARTUP
	hb.size_px = KICK_SIZE

	var aerial: bool = not is_on_floor()
	hb.damage = KICK_DAMAGE + (AERIAL_BONUS_DAMAGE if aerial else 0)
	_aim_hitbox(hb, input, KICK_ANGLE_DEG, KICK_OFFSET)
	return hb


func _build_roll_hitbox() -> Resource:
	# Roll's hitbox tracks the body — no aim, no aerial branch (ground
	# only). Damage and knockback are modest; the appeal is mobility.
	var hb: Resource = HitboxRes.new()
	hb.damage = ROLL_DAMAGE
	hb.base_damage = ROLL_DAMAGE
	hb.base_knockback = ROLL_BASE_KB
	hb.knockback_scale = ROLL_KB_SCALE
	hb.active_frames = ROLL_ACTIVE_END - ROLL_STARTUP
	hb.size_px = Vector2i(BODY_HALF_W * 2 + 4, BODY_HALF_H * 2)
	var angle: int = ROLL_ANGLE_DEG if facing >= 0 else 180 - ROLL_ANGLE_DEG
	hb.angle_degrees = angle
	hb.offset_px = Vector2i(facing * 4, 0)
	return hb


func _aim_hitbox(hb: Resource, input: Dictionary, ground_angle_deg: int, reach: int) -> void:
	var aerial: bool = not is_on_floor()
	var aim_x: int = 0
	var aim_y: int = 0
	if aerial:
		aim_x = input.get("move_x", 0)
		aim_y = input.get("move_y", 0)
	if aim_x == 0 and aim_y == 0:
		var ground_angle: int = ground_angle_deg if facing >= 0 else 180 - ground_angle_deg
		hb.angle_degrees = ground_angle
		var rad: float = float(ground_angle) * 0.017453292519943295
		hb.offset_px = Vector2i(int(round(cos(rad) * reach)), int(round(-sin(rad) * reach)))
	else:
		var rad: float = atan2(float(-aim_y), float(aim_x))
		hb.angle_degrees = int(round(rad * 57.29577951308232))
		hb.offset_px = Vector2i(int(round(cos(rad) * reach)), int(round(-sin(rad) * reach)))


func get_active_hitbox() -> Resource:
	return _active_hitbox


func _tick_attack(current_frame: int) -> void:
	var f: int = fsm.frames_in_state(current_frame)
	match fsm.state:
		FsmRes.State.ATTACK_BITE:
			if f == BITE_STARTUP:
				_show_hitbox_visual()
			elif f == BITE_ACTIVE_END:
				_hide_hitbox_visual()
			elif f >= BITE_TOTAL:
				_settle_state_after_hitstun(current_frame)
		FsmRes.State.ATTACK_KICK:
			if f == KICK_STARTUP:
				_show_hitbox_visual()
			elif f == KICK_ACTIVE_END:
				_hide_hitbox_visual()
			elif f >= KICK_TOTAL:
				_settle_state_after_hitstun(current_frame)


func _tick_roll(current_frame: int) -> void:
	var f: int = fsm.frames_in_state(current_frame)
	if f >= ROLL_TOTAL:
		_clear_roll_visual()
		_settle_state_after_hitstun(current_frame)


func _settle_state_after_hitstun(current_frame: int) -> void:
	_clear_block_visual()
	_clear_roll_visual()
	if is_on_floor():
		fsm.transition_to(FsmRes.State.IDLE, current_frame)
	else:
		fsm.transition_to(FsmRes.State.FALL, current_frame)


func _update_locomotion_state(move_x: int, current_frame: int) -> void:
	if fsm.state in [FsmRes.State.ATTACK_BITE, FsmRes.State.ATTACK_KICK,
			FsmRes.State.ROLL, FsmRes.State.BLOCK, FsmRes.State.HITSTUN]:
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
	# Don't fight the roll spin: while ROLLing, scale.x is set but the
	# spin owns rotation; otherwise rotation is held at 0.
	_visual.scale.x = float(facing)


func _apply_roll_spin() -> void:
	# Visual-only: rotate the sprite a chunk per tick so the roll reads
	# as a tumble. With scale.x mirroring facing, positive rotation
	# already looks like forward roll in both directions.
	if _visual == null:
		return
	_visual.rotation += 0.45


func _clear_roll_visual() -> void:
	if _visual == null:
		return
	_visual.rotation = 0.0


func _apply_block_visual() -> void:
	if _visual == null:
		return
	# Steel-blue tint reads as "hardened". Cleared on any state change.
	_visual.modulate = Color(0.65, 0.8, 1.05, 1.0)


func _clear_block_visual() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1, 1, 1, 1)


func _refresh_stamina_bar() -> void:
	if _stamina_fg == null:
		return
	var ratio: float = float(block_stamina) / float(BLOCK_STAMINA_MAX)
	ratio = clamp(ratio, 0.0, 1.0)
	_stamina_fg.scale.x = ratio
	# Red while broken/locked, amber when low, green otherwise. Pure
	# visual — no gameplay reads from this colour.
	if block_lockout > 0:
		_stamina_fg.color = Color(0.85, 0.25, 0.25, 1)
	elif ratio < 0.33:
		_stamina_fg.color = Color(0.95, 0.7, 0.25, 1)
	else:
		_stamina_fg.color = Color(0.35, 0.85, 0.4, 1)


func _empty_input() -> Dictionary:
	return {
		"move_x": 0,
		"move_y": 0,
		"jump": false,
		"jump_pressed": false,
		"attack": false,
		"attack_pressed": false,
		"kick": false,
		"kick_pressed": false,
		"roll": false,
		"roll_pressed": false,
		"block": false,
		"reset_pressed": false,
	}
