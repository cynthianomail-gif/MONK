# Minigames Okami Art Wiring Handoff to Claude

Date: 2026-06-27
Repo root: `D:\monk\MONK`

## Context

This continues the handoff from `docs/superpowers/specs/2026-06-24-minigames-okami-art-handoff.md`.

Goal was to replace polygon placeholder art in:

- `src/screens/Minigames/BeggarChallenge.gd`
- `src/screens/Minigames/WoodenFishRhythm.gd`

with Okami-style PNG cutouts under:

`assets/art_direction/new_ink_shrine_style/minigames/`

Backgrounds and Jie portrait were intentionally left alone.

## What Was Done

Generated and imported the requested minigame assets:

- Beggar pedestrians, side-view facing left, 2 walk frames each:
  - `beggar_ped_office_worker_a.png`
  - `beggar_ped_office_worker_b.png`
  - `beggar_ped_tourist_a.png`
  - `beggar_ped_tourist_b.png`
  - `beggar_ped_rich_lady_a.png`
  - `beggar_ped_rich_lady_b.png`
  - `beggar_ped_drunk_man_a.png`
  - `beggar_ped_drunk_man_b.png`
- Begging Wujie side-view:
  - `beggar_wujie_begging.png`
- Wooden fish rhythm props:
  - `woodenfish_instrument.png`
  - `woodenfish_note.png`
  - `woodenfish_hit_fx.png`
- Wujie front portraits copied from existing `characters/game_ready/` to avoid identity drift:
  - `wujie_chanter_front_game_ready.png`
  - `wujie_beggar_front_game_ready.png`
- Preview sheet:
  - `_handoff_generated_preview.png`

Godot import was run, so matching `.png.import` files exist for these assets.

## Code Changes

### `src/screens/Minigames/BeggarChallenge.gd`

Key changes:

- Added `MINIGAME_ART_DIR`.
- Changed default `monk_portrait_path` to:
  `res://assets/art_direction/new_ink_shrine_style/minigames/wujie_beggar_front_game_ready.png`
- Added `begging_sprite_path` for side-view begging Wujie:
  `res://assets/art_direction/new_ink_shrine_style/minigames/beggar_wujie_begging.png`
- Added `citizen_sprite_paths` mapping each citizen type to its A/B frame.
- `_spawn_citizen()` now loads the A/B PNGs and spawns a `Sprite2D`.
- `_process()` calls `_update_citizen_walk_frame()` to alternate frames every 250 ms.
- Existing polygon body/head generation remains as fallback if sprite loading fails.
- Begging Wujie now uses `begging_sprite_path` first, then falls back to `monk_portrait_path`.

Useful line anchors from current file:

- `MINIGAME_ART_DIR`: line 11
- `citizen_sprite_paths`: line 24
- `_citizen_frames()`: line 157
- `_update_citizen_walk_frame()`: line 167
- begging Wujie sprite load: line 208

### `src/screens/Minigames/WoodenFishRhythm.gd`

Key changes:

- Added `MINIGAME_ART_DIR`.
- Changed default `monk_portrait_path` to:
  `res://assets/art_direction/new_ink_shrine_style/minigames/wujie_chanter_front_game_ready.png`
- Added:
  - `woodenfish_sprite_path`
  - `note_sprite_path`
  - `hit_fx_sprite_path`
- `_build_scene()` now renders the wooden fish instrument as `Sprite2D`; polygon remains fallback.
- `_build_chart()` now creates each note through `_make_note_sprite()`; polygon remains fallback.
- `_register()` triggers `_show_hit_fx()` on every 10-combo bonus.

Useful line anchors from current file:

- `MINIGAME_ART_DIR`: line 11
- wooden fish / note / FX exports: lines 19-21
- instrument sprite load: line 184
- `_make_note_sprite()`: line 211
- `_show_hit_fx()`: line 227

### `test/TestMinigames.gd`

Added checks for:

- Beggar default art paths.
- Beggar office worker A/B resource existence.
- Spawned beggar citizen uses `Sprite2D` art.
- WoodenFish default art paths.
- WoodenFish instrument and note resources exist.
- WoodenFish instrument and note nodes use `Sprite2D`.

Also updated stale SoupCarry assertions from old API names to current `step_slosh()` / `build_result()` usage. This was needed because the old test was producing a `SCRIPT ERROR` even after minigame art wiring passed.

Useful line anchors:

- Beggar art checks: lines 28-37
- SoupCarry current API checks: lines 59-66
- WoodenFish art checks: lines 78-86

## Verification Already Run

Initial TDD red run failed as expected because new exports/resources were missing:

```powershell
& 'D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe' --headless --path 'D:\monk\MONK' 'res://test/TestMinigames.tscn'
```

Then Godot import was run:

```powershell
& 'D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe' --headless --path 'D:\monk\MONK' --import
```

Final verification command:

```powershell
& 'D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe' --headless --path 'D:\monk\MONK' 'res://test/TestMinigames.tscn'
```

Observed output:

```text
MINIGAME_TEST: ALL PASS
```

Exit code was `0`.

Godot still prints engine shutdown resource leak messages:

```text
WARNING: ObjectDB instances leaked at exit
ERROR: 26 resources still in use at exit
```

No `SCRIPT ERROR` or parse error remained in the final run.

## Important Working Tree Notes

`git status --short` currently shows modified:

- `src/screens/Minigames/BeggarChallenge.gd`
- `src/screens/Minigames/WoodenFishRhythm.gd`
- `test/TestMinigames.gd`

It also shows many untracked files under `assets/art_direction/new_ink_shrine_style/minigames/`.

Important: some untracked `minigame_*` soup-carry assets appear to have already existed before this handoff. Do not delete or clean them blindly. For this handoff, focus on:

- `beggar_*`
- `woodenfish_*`
- `wujie_beggar_front_game_ready.*`
- `wujie_chanter_front_game_ready.*`
- `_handoff_generated_preview.*`

## Suggested Next Steps for Claude

1. Review the visual scale/placement in a windowed run or screenshot.
2. Confirm walk-cycle silhouettes feel acceptable in `BeggarChallenge`.
3. Confirm WoodenFish note readability and hit FX placement.
4. If visuals are acceptable, commit code + relevant assets/import files.
5. If committing, avoid accidentally staging unrelated pre-existing untracked soup assets unless the user wants them included.

Suggested visual run:

```powershell
& 'D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe' --path 'D:\monk\MONK' 'res://test/TestMinigames.tscn'
```

For focused validation, it may be better to create or reuse a capture scene that opens each minigame with `auto_start=false` and saves a screenshot.
