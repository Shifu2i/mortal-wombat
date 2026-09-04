class_name HitSpark
extends Node2D

# One-shot impact burst: a white flash ring plus radiating sparks.
# Purely visual — animated on delta, frees itself when done. Directions
# are index-derived (no RNG) so it never touches SeededRng.

const LIFETIME: float = 0.26
const COUNT: int = 8
const RING_VERTS: int = 14

var _t: float = 0.0
var _sparks: Array = []
var _dirs: Array = []
var _ring: Polygon2D = null
var strength: float = 1.0


func _ready() -> void:
	_ring = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in RING_VERTS:
		var a: float = TAU * float(i) / float(RING_VERTS)
		pts.append(Vector2(cos(a), sin(a)))
	_ring.polygon = pts
	_ring.color = Color(1.0, 0.98, 0.9, 0.95)
	add_child(_ring)

	for i in COUNT:
		var p: Polygon2D = Polygon2D.new()
		var l: float = 3.0 if i % 2 == 0 else 2.0
		p.polygon = PackedVector2Array([
			Vector2(-l, -0.9), Vector2(l, -0.9), Vector2(l, 0.9), Vector2(-l, 0.9)])
		p.color = Color(1.0, 0.92, 0.55, 1.0) if i % 2 == 0 else Color(1.0, 0.6, 0.28, 1.0)
		var ang: float = TAU * float(i) / float(COUNT) + 0.35
		p.rotation = ang
		add_child(p)
		_sparks.append(p)
		_dirs.append(Vector2(cos(ang), sin(ang)))


func _process(delta: float) -> void:
	_t += delta
	var k: float = _t / LIFETIME
	if k >= 1.0:
		queue_free()
		return
	var ease: float = 1.0 - (1.0 - k) * (1.0 - k)
	_ring.scale = Vector2.ONE * (2.0 + 12.0 * ease) * strength
	_ring.color.a = (1.0 - ease) * 0.9
	for i in COUNT:
		var p: Polygon2D = _sparks[i]
		p.position = _dirs[i] * (4.0 + 20.0 * ease) * strength
		p.scale = Vector2(1.0, 1.0) * (1.0 - k * 0.7)
		p.modulate.a = 1.0 - k
