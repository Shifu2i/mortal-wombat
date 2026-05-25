# Claude Code conventions — Mortal Wombat

## Project at a glance

2D platform fighter, Godot 4, GDScript, SG Physics 2D, rollback-ready
from line one. Solo dev project. See `docs/decisions.md` for the seven
locked decisions and `docs/design.md` for mechanics.

## Hard rules (rollback-readiness)

1. Gameplay advances on a fixed 60Hz simulation tick. **Never** use
   `delta` in gameplay logic. `delta` is for visuals/interpolation only.
2. All gameplay collision and movement uses **SG Physics 2D**, not
   Godot's `CharacterBody2D` / `Area2D`.
3. All gameplay randomness goes through `SeededRng`. Never call
   `randf()`, `randi()`, or Godot's `RandomNumberGenerator` in gameplay.
4. **No** `await`, **no** `call_deferred` / `set_deferred`, **no**
   signals in gameplay code. Signals are allowed only in UI and audio.
5. Inputs are sampled once per tick into `InputBuffer`. Gameplay reads
   from the buffer; never call `Input.is_action_*` mid-simulation.
6. Use SG fixed-point types for gameplay positions/velocities. Floats
   are fine for purely visual interpolation.

## Code style

- Static typing everywhere: `var x: int = 0`, never `var x = 0`.
  Function signatures fully typed including return type.
- snake_case for files, variables, functions. PascalCase for classes
  and `class_name` declarations.
- Gameplay scripts attach to `Node`, `Resource`, or `SG*` nodes
  (`SGFixedNode2D`, `SGCharacterBody2D`, `SGStaticBody2D`,
  `SGArea2D`). Never inherit plain `Node2D` / `Sprite2D` for gameplay
  — the floating-point transform on those is not deterministic.
  Visuals (sprites, labels, particles) live as children of the
  gameplay node; SG nodes update their float transform from the
  fixed transform automatically.
- One class per file. File name matches the class.

## Commits

- One logical change per commit.
- Prefix messages with the phase tag: `[P0]` for foundation,
  `[P1]` for Phase 1 prototype work, etc.
- Example: `[P1] add hitbox resource with damage and angle fields`.

## Workflow

- When something requires a human (addon install via AssetLib, opening
  Godot, drawing art, playtest feel), append it to `TODO_HUMAN.md`
  rather than faking it.
- Update this file when a non-obvious decision is made, with the why.

## Non-obvious choices recorded so far

- **SG Physics 2D** is installed from the upstream GitLab release zip
  (v1.0.0-alpha13 godot4-gdextension), committed into
  `addons/sg-physics-2d/` with Linux + Windows x86_64 binaries.
  macOS / ARM binaries are not shipped by upstream; if a target build
  needs them, compile from source. `addons/godot-rollback-netcode/`
  remains a `.gitkeep` until Phase 5.
- All gameplay collision/movement uses the SG types: `SGFixedNode2D`,
  `SGCharacterBody2D`, `SGStaticBody2D`, `SGArea2D`,
  `SGRectangleShape2D`, with `SGFixedVector2` / `SGFixed` for math.
- 2 input slots are wired from day one even though Phase 1 has one
  human player + one immobile dummy. Slot 2 is fed empty inputs.
- Knockback formula constants (`base_damage`, `knockback_scale`,
  `base_knockback`) are placeholders for Phase 4+ tuning. The formula
  shape is locked; the numbers are not.
- The knockback formula uses floats (per spec). For Phase 1 (local
  single-player) this is fine; before Phase 5 rollback wiring, port
  it to `SGFixed` arithmetic.
- **SG teleport gotcha**: `set_fixed_position` at runtime only marks
  the node's transform dirty; the SG physics server's collision rep
  isn't updated until `move_and_slide` (or similar) touches it
  again. Without an explicit `sync_to_physics_engine()` after the
  teleport, the next `move_and_slide` operates from the *old*
  position and drags the visible position right back to where it
  was. `character_base.ko_and_respawn()` calls
  `sync_to_physics_engine()` for this reason.
