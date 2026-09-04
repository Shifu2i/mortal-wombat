class_name StageCamera
extends Camera2D

# Visual-only camera with impact shake. Runs on _process/delta, which is
# allowed for visuals (CLAUDE.md rule 1). Nothing in gameplay reads the
# camera, so the float wobble can't leak into the sim. Found via the
# "stage_camera" group so characters don't need a NodePath to it.

const DECAY_PER_SEC: float = 14.0

var _shake: float = 0.0
var _t: float = 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if _shake <= 0.01:
		_shake = 0.0
		offset = Vector2.ZERO
		return
	_t += delta
	# Two incommensurate sines read as noise without any RNG.
	offset = Vector2(sin(_t * 97.0) * _shake, cos(_t * 83.0) * _shake * 0.7)
	_shake = maxf(0.0, _shake - DECAY_PER_SEC * delta * maxf(_shake, 1.0))
