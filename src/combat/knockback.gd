class_name Knockback
extends RefCounted

# Smash-style knockback formula. Per the Phase 1 spec, this uses floats —
# acceptable for local single-player. Before Phase 5 rollback wiring, port
# to SGFixed arithmetic for determinism across machines.

const DEG_TO_RAD: float = 0.017453292519943295

# The spec formula yields a "launch_speed" in roughly Smash-style units;
# treating it directly as px/frame puts a 0% jab at 30 px/frame, which
# crosses the 480-wide screen in 16 frames. Divide by SPEED_SCALE to get
# a usable px/frame velocity. Hitstun stays on the raw formula so it
# scales the way the spec intended. SPEED_SCALE is a placeholder for
# Phase 4+ tuning, same as the formula constants themselves.
const SPEED_SCALE: float = 20.0


static func compute(damage_percent: int, hitbox: Hitbox) -> Dictionary:
	var dp: float = float(damage_percent)
	var bd: float = float(hitbox.base_damage)
	var launch_speed: float = (dp * 0.1 + dp * bd * 0.05) * hitbox.knockback_scale + float(hitbox.base_knockback)
	var angle_rad: float = float(hitbox.angle_degrees) * DEG_TO_RAD
	var hitstun_frames: int = int(floor(launch_speed * 0.4))
	var velocity_pxf: float = launch_speed / SPEED_SCALE
	# Direction: angle 0 = +x (right), 90 = up. Godot y is down, so we
	# negate the y component to make "up" actually up.
	var dir_x: float = cos(angle_rad)
	var dir_y: float = -sin(angle_rad)
	var sg: Object = Engine.get_singleton("SGFixed")
	var vx_fixed: int = sg.from_float(dir_x * velocity_pxf)
	var vy_fixed: int = sg.from_float(dir_y * velocity_pxf)
	return {
		"velocity_fixed": sg.vector2(vx_fixed, vy_fixed),
		"hitstun_frames": hitstun_frames,
		"launch_speed_px_per_frame": velocity_pxf,
	}
