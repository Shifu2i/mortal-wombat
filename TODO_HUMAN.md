# Tasks only the human can do

These can't be done from a headless coding session. Tick them off as
you complete them.

## Phase 0 — setup

- [ ] Open Godot 4, open this project once so `.godot/` and import
      metadata get generated.
- [ ] Install **SG Physics 2D** via AssetLib → confirm files land in
      `addons/sg-physics-2d/`. Enable in Project Settings → Plugins.
- [ ] Install **Godot Rollback Netcode** (Snopek) via AssetLib →
      `addons/godot-rollback-netcode/`. Enable it. (Wiring waits for
      Phase 5; just having it present catches API drift early.)
- [ ] After the SG addon is installed, swap the placeholder
      `StaticBody2D` / `CharacterBody2D` nodes in `test_stage.tscn`
      and `wombat.tscn` for their `SG*` equivalents. The script-side
      code is already written against an SG-style API behind a thin
      wrapper; see `src/core/sg_bridge.gd` for the seam.

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
