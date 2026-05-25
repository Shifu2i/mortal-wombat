# Mortal Wombat — Initial Prototype Build

## Context

You're helping build **Mortal Wombat**, a 2D platform fighter with Australian
animals as characters. Solo dev project, target platform Steam, target launch
~Oct–Nov 2027. This prompt covers **Phase 0 (foundation) + Phase 1 (single-
character combat prototype)** only — the first ~5 weeks of work.

The dev (Magnus) has already: installed Godot 4 stable, cloned
`blast-harbour/Godot-Rollback-Fighter-Demo` as a read-only reference, locked
the seven Day 1 decisions, and initialised an empty git repo. Your job is to
scaffold the project and build the Phase 1 prototype.

## Locked decisions (do not change)

- **Engine:** Godot 4 (latest stable)
- **Language:** GDScript with static typing throughout
- **Physics:** SG Physics 2D (deterministic, MIT) — install as addon
- **Netcode:** Snopek's Godot Rollback Netcode / BimDav's Delta Rollback —
  install addon stub now, wire up in Phase 5
- **Base resolution:** 480×270, integer-scaled
- **Tick rate:** 60Hz fixed simulation tick
- **Input:** keyboard + gamepad from day one, via Godot InputMap actions
- **Visibility:** private repo, closed source

## Rollback-readiness principles (apply from line one)

1. All gameplay state advances on a deterministic simulation tick. Never use
   `delta`-based math in gameplay logic.
2. Use SG Physics 2D for all gameplay collision and movement — not Godot's
   default `CharacterBody2D`.
3. All gameplay randomness comes from a seeded RNG (`SeededRng` wrapper),
   never Godot's global.
4. No `await`, no `set_deferred`, no signals in gameplay logic. Restrict
   signals to UI and audio only.
5. Inputs sampled per tick into an input queue, then read from the queue.
   Never read raw inputs mid-simulation.
6. Floating point is fine for visuals; gameplay uses integer / fixed-point
   via SG Physics 2D types.

## Knockback formula (use exactly)

```
launch_speed = (damage_percent * 0.1 + damage_percent * base_damage * 0.05)
               * knockback_scale + base_knockback
launch_angle = hitbox.angle  # degrees
hitstun_frames = floor(launch_speed * 0.4)
```

## Definition of done

Magnus can run Godot, open `main.tscn`, hit play, and:

1. See a wombat on a flat stage with a training dummy
2. Move left/right, jump, double-jump
3. Press attack and see a hitbox flash for 3 frames
4. Hit the dummy and see percentage rise
5. Watch the dummy launch with knockback proportional to its percentage
6. KO it off the screen
7. Press R, reset, repeat

## Out of scope

Second character, AI opponent, online play, polished menus, music, SFX, real
sprite art, balance tuning, particles, hit pause, screen shake.
