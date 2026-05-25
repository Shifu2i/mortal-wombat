class_name Hitbox
extends Resource

# Data definition for a single attack hitbox. A character's attack state
# spawns an SGArea2D using this resource's parameters during the attack's
# active frames. Constants here are placeholders — tuning is a Phase 4+ job.

@export var damage: int = 8
@export var base_damage: int = 8        # used by the knockback formula
@export var angle_degrees: int = 40     # launch direction, 0 = +x, 90 = up
@export var base_knockback: int = 30
@export var knockback_scale: float = 1.0
@export var active_frames: int = 3
@export var size_px: Vector2i = Vector2i(20, 16)   # AABB extents in pixels
@export var offset_px: Vector2i = Vector2i(16, 0)  # spawn offset from owner
