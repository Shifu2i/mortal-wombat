# Mortal Wombat — Phase 1 design

## Loop

Two characters on a flat stage. Player 1 controls a wombat; player 2 is
an immobile training dummy with the same hurtbox. Attacks raise the
dummy's percentage and launch it. Crossing the screen boundary KOs.
Press R to reset.

## Controls

| Action       | Keyboard         | Gamepad           |
|--------------|------------------|-------------------|
| move_left    | A, Left arrow    | left stick / dpad |
| move_right   | D, Right arrow   | left stick / dpad |
| move_up      | W, Up arrow      | left stick / dpad |
| move_down    | S, Down arrow    | left stick / dpad |
| jump         | Space, W         | south face button |
| attack       | J                | west face button  |
| reset        | R                | start             |

Bindings live in `project.godot` `[input]` section. Don't read keys
directly anywhere else.

`move_up` overlaps with `jump` on W — tapping W jumps, holding W in
the air also aims the next attack upward. `move_down` (S) is purely
for aiming aerial attacks downward; there's no fast-fall yet.

## Movement constants (Phase 1 placeholders)

All values in pixels and frames (60 fps). These tune later.

| Constant            | Value |
|---------------------|-------|
| walk_speed          | 120   |
| jump_impulse        | 240   |
| double_jump_impulse | 210   |
| gravity_per_frame   | 12    |
| max_fall_speed      | 300   |
| ground_friction     | 0.85  |
| air_drag            | 0.95  |

## Attack — neutral jab

- Startup: 3 frames
- Active: 3 frames (hitbox spawned)
- Recovery: 6 frames
- Hitbox damage: 8 (+5 if airborne)
- Hitbox angle: 40 degrees grounded (mirrored by facing). Aerial jabs
  read WASD at the press-frame and snap to one of 8 directions; the
  hitbox offset and knockback angle both follow the aim.
- Hitbox base_knockback: 30
- Hitbox knockback_scale: 1.0
- Hitbox base_damage: 8

## Knockback formula

Exactly as specified:

```
launch_speed = (damage_percent * 0.1 + damage_percent * base_damage * 0.05)
               * knockback_scale + base_knockback
launch_angle = hitbox.angle  # degrees, measured from +x axis
hitstun_frames = floor(launch_speed * 0.4)
```

`damage_percent` is the victim's percentage AFTER the hit's damage is
added.

## KO

Stage has a rectangular blast zone slightly larger than the camera
view. If the character's position leaves the rect, KO event fires
(Phase 1: just resets percentage and respawns at centre).

## Debug overlay

Top-left CanvasLayer label, monospace, shows:
- current sim frame
- player 1 state name
- last 8 ticks of player 1 input buffer (compact glyphs)
- dummy percentage

Toggle with F3 (later).
