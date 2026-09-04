class_name DustPuff
extends Node2D

# Soft dust cloud for landings and rolls. Visual-only; delta-driven;
# self-freeing. Spread direction comes from `dir_x` (-1/0/+1) so a
# roll trails dust behind it while a landing puffs out both sides.

const LIFETIME: float = 0.38
const COUNT: int = 4

var dir_x: float = 0.0
var size: float = 1.0
var _t: float = 0.0
var _blobs: Array = []
var _vel: Array = []


func _ready() -> void:
	for i in COUNT:
		var p: Polygon2D = Polygon2D.new()
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 10:
			var a: float = TAU * float(j) / 10.0
			pts.append(Vector2(cos(a), sin(a)))
		p.polygon = pts
		p.color = Color(0.9, 0.82, 0.66, 0.85)
		add_child(p)
		_blobs.append(p)
		# Fan out: index picks a side; rolls bias everything backwards.
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var vx: float = side * (5.0 + 3.0 * float(i)) - dir_x * 14.0
		var vy: float = -6.0 - 3.0 * float(i % 3)
		_vel.append(Vector2(vx, vy))


func _process(delta: float) -> void:
	_t += delta
	var k: float = _t / LIFETIME
	if k >= 1.0:
		queue_free()
		return
	var ease: float = 1.0 - (1.0 - k) * (1.0 - k)
	for i in COUNT:
		var p: Polygon2D = _blobs[i]
		p.position = _vel[i] * ease * size
		p.scale = Vector2.ONE * (1.5 + 3.5 * ease) * size
		p.color.a = 0.85 * (1.0 - k)
