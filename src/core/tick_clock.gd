class_name TickClock
extends Node

# Fixed-step 60Hz tick driver. Drives FightManager.advance_tick() from
# _physics_process. Godot's physics step is already fixed at 60Hz (see
# project.godot [physics] common/physics_ticks_per_second), so one
# _physics_process callback is one sim tick. No accumulator needed.
#
# Gameplay must NEVER read the delta parameter — it's named _delta to
# make accidental use compile-fail-loud. Reads of `delta` belong only
# in visual interpolation code.

signal tick_advanced(frame: int)  # UI/debug only — never consumed by gameplay

var frame: int = 0
var paused: bool = false


func _physics_process(_delta: float) -> void:
	if paused:
		return
	frame += 1
	tick_advanced.emit(frame)


func reset() -> void:
	frame = 0
