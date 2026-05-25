class_name TickClock
extends RefCounted

# The canonical sim frame counter. Owned by FightManager and advanced
# exactly once per physics tick. Pure data: no signals, no _process,
# trivially serialisable for rollback save/load.

var frame: int = 0


func advance() -> void:
	frame += 1


func reset() -> void:
	frame = 0
