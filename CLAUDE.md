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
- Gameplay scripts inherit `Node` or `Resource`. Never inherit
  `Node2D` / `Sprite2D` directly — visuals live in child nodes of the
  scene, owned by the gameplay node.
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

- `addons/sg-physics-2d` and `addons/godot-rollback-netcode` are
  `.gitkeep` placeholders. Real install happens via Godot AssetLib by
  the human (see `TODO_HUMAN.md`).
- 2 input slots are wired from day one even though Phase 1 has one
  human player + one immobile dummy. Slot 2 is fed empty inputs.
- Knockback formula constants (`base_damage`, `knockback_scale`,
  `base_knockback`) are placeholders for Phase 4+ tuning. The formula
  shape is locked; the numbers are not.
