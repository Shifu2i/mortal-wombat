# Tasks only the human can do

These can't be done from a headless coding session. Tick them off as
you complete them.

## Phase 0 — setup

- [ ] Open Godot 4, open this project once so `.godot/` and import
      metadata get generated. The SG Physics 2D GDExtension should
      load automatically (no plugin-enable step needed for
      GDExtensions). If you see "Could not open library" errors for
      `libsgphysics2d.*`, double-check you opened with Godot 4.1+.
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

## Phase 1 — art (optional, can stay rectangles)

- [ ] Replace the coloured rectangle in `wombat.tscn` with a real
      placeholder sprite if you feel like it. Not required.
