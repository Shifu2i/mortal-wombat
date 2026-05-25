# Day 1 locked decisions

These are not up for debate during Phase 0–1. Revisit only with explicit
go-ahead from Magnus, and document the why if changed.

1. **Engine**: Godot 4 (latest stable).
2. **Language**: GDScript with static typing throughout.
3. **Physics**: SG Physics 2D (deterministic, MIT). Installed via
   Godot AssetLib as an addon. All gameplay collision/movement uses it.
4. **Netcode**: Snopek's Godot Rollback Netcode (with BimDav's Delta
   Rollback as backup reference). Addon placeholder lives in
   `addons/godot-rollback-netcode/` from day one; wiring happens in
   Phase 5.
5. **Base resolution**: 480×270, integer-scaled to the window. Pixel
   art native scale.
6. **Tick rate**: 60Hz fixed simulation tick. Gameplay never reads
   `delta`.
7. **Input**: Keyboard and gamepad supported from day one, via Godot
   `InputMap` actions. Raw inputs are sampled once per tick into
   `InputBuffer`; gameplay reads from the buffer.

Also: private repo, closed source.
