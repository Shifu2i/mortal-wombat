# Tasks only the human can do

These can't be done from a headless coding session. Tick them off as
you complete them.

## Phase 0 — setup

- [ ] Open Godot 4, open this project once so `.godot/` and import
      metadata get generated. The SG Physics 2D GDExtension should
      load automatically (no plugin-enable step needed for
      GDExtensions). If you see "Could not open library" errors for
      `libsgphysics2d.*`, double-check you opened with Godot 4.1+.
      (Headless import + script parse + 30-tick scene run already
      verified clean in CI; if something breaks in the editor it's
      almost certainly platform-specific.)
- [ ] **Mac / ARM users**: upstream v1.0.0-alpha13 only ships
      Linux + Windows x86_64 binaries. To build the macOS dylib or
      ARM .so, clone https://gitlab.com/snopek-games/sg-physics-2d
      and run `scons platform=macos target=template_debug` (or
      release). Drop the resulting library into
      `addons/sg-physics-2d/lib/` and add a matching line to
      `addons/sg-physics-2d/sg-physics-2d.gdextension` under
      `[libraries]`.
- [ ] Install **Godot Rollback Netcode** (Snopek) via AssetLib →
      `addons/godot-rollback-netcode/`. Enable it. (Wiring waits for
      Phase 5; just having it present catches API drift early.)

## Phase 0 — content

- [ ] Fill in `docs/notes.md` from the reference demo dissection.
      Leave this for yourself, not Claude.

## Phase 1 — playtest

- [ ] Open `scenes/main.tscn`, hit Play.
- [ ] Verify the seven Definition-of-Done items from
      `prompts/phase-1-prototype.md`.
- [ ] Note any feel issues — don't tune yet, just log them for Phase 4.

## Phase 1 — art

The current look is a procedural polish pass (layered dusk backdrop,
outlined/shaded polygon wombats, hit sparks, dust, camera shake,
vignette). That is the ceiling for polygons at 480x270. Going further
needs a pixel artist — these can't be done from a coding session:

- [ ] **Wombat sprite sheet.** Idle (4f breathing), run (6f), jump /
      fall (1f each), bite (3f), kick (4f), roll (4f, loops), block
      (1f), hitstun (1f). 24x40 px cell, facing right; the code
      mirrors for left. Drop PNGs under `assets/characters/wombat/`
      and swap `Visual` in `wombat.tscn` for an `AnimatedSprite2D`.
      Gameplay code does not need to change — only
      `_apply_facing_to_visual` / `_refresh_visual_tint` touch the
      visual node.
- [ ] **Stage tileset / parallax.** Replace the generated polygons in
      `test_stage.tscn` (`Backdrop`, `Ground`, platform visuals) with
      painted layers. Keep the `SGStaticBody2D` nodes exactly where
      they are; only their visual children change.
- [ ] **Effect sprites.** `HitSpark` / `DustPuff` are polygon-based and
      fine, but painted spark and dust frames will read better.
- [ ] **Pixel font** for the percent labels (the default font is
      vector and blurs slightly under the integer-scale stretch).
- [ ] Judge the camera shake amount in `stage_camera.gd` by feel
      (`shake()` is called with 1.5–6.3 px from `character_base.gd`).
