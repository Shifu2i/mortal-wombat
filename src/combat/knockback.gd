class_name Knockback
extends RefCounted

# Smash-style knockback formula. Per the Phase 1 spec, this uses floats —
# acceptable for local single-player. Before Phase 5 rollback wiring, port
# to SGFixed arithmetic for determinism across machines.

const DEG_TO_RAD: float = 0.017453292519943295


static func compute(damage_percent: int, hitbox: Hitbox) -> Dictionary:
	var dp: float = float(damage_percent)
	var bd: float = float(hitbox.base_damage)
	var launch_speed: float = (dp * 0.1 + dp * bd * 0.05) * hitbox.knockback_scale + float(hitbox.base_knockback)
	var angle_rad: float = float(hitbox.angle_degrees) * DEG_TO_RAD
	var hitstun_frames: int = int(floor(launch_speed * 0.4))
	# Direction: angle 0 = +x (right), 90 = up. Note Godot y is down, so
	# we negate the y component to make "up" actually up.
	var dir_x: float = cos(angle_rad)
	var dir_y: float = -sin(angle_rad)
	# Convert px/frame velocity to fixed-point. SGFixed.from_float returns
	# a 16.16 fixed-point int; SG character body velocity is already in
	# fixed-point per-frame units.
	var sg: Object = Engine.get_singleton("SGFixed")
	var vx_fixed: int = sg.from_float(dir_x * launch_speed)
	var vy_fixed: int = sg.from_float(dir_y * launch_speed)
	return {
		"velocity_fixed": sg.vector2(vx_fixed, vy_fixed),
		"hitstun_frames": hitstun_frames,
		"launch_speed_px_per_frame": launch_speed,
	}
