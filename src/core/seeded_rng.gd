class_name SeededRng
extends Resource

# Deterministic RNG wrapper. All gameplay randomness goes through this.
# Never use randf() / randi() / Godot's RandomNumberGenerator globally in
# gameplay — rollback resimulation requires identical sequences from the
# same seed.

@export var seed: int = 0

var _state: int = 0

func _init(initial_seed: int = 0) -> void:
	seed = initial_seed
	_state = initial_seed


func reset(new_seed: int) -> void:
	seed = new_seed
	_state = new_seed


# xorshift64. Cheap, deterministic, good enough for gameplay variance.
func next_u64() -> int:
	var x: int = _state
	if x == 0:
		# Non-zero seed required for xorshift; this is the 64-bit golden
		# ratio with the sign bit cleared so it fits in signed int64.
		x = 0x1E3779B97F4A7C15
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	_state = x
	return x


func next_int(min_inclusive: int, max_inclusive: int) -> int:
	var span: int = max_inclusive - min_inclusive + 1
	if span <= 0:
		return min_inclusive
	var v: int = next_u64()
	if v < 0:
		v = -v
	return min_inclusive + (v % span)


# 0.0 .. 1.0. Float ok here — used only when caller has already accepted
# the float compromise (e.g. Phase 1 knockback variance, none currently).
func next_float() -> float:
	var v: int = next_u64()
	if v < 0:
		v = -v
	return float(v % 1000000) / 1000000.0
