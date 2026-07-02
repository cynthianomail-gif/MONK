# Claude Code implementation handoff — parlor/shrine minigame art hookup

Date: 2026-07-03

Goal: wire the new minigame art assets into the existing Godot scenes without baking gameplay objects into backgrounds.

## Key rule

Use backgrounds only as static environment art. Anything that moves, rotates, spawns, is hit, or is repositioned by gameplay must be a separate sprite/node.

## Asset roots

Casino/parlor assets:

`res://assets/art_direction/new_ink_shrine_style/minigames/parlor/`

Shrine-street leisure assets:

`res://assets/art_direction/new_ink_shrine_style/minigames/shrine_games/`

## Backgrounds to use

Use these new close-up backgrounds instead of the old full parlor establishing shot for the gambling minigames:

| Minigame | New background | Notes |
|---|---|---|
| Darts | `parlor/darts_bg_v2.png` | Close-up dart station only. Still overlay moving dart sprite in code. |
| Roulette | `parlor/roulette_table_top_v2.png` | Table/top view with wheel and betting layout. Use separate wheel/ball/effects below for motion. |
| Blackjack | `parlor/blackjack_table_top_v2.png` | Empty table zones. Do not expect cards to be baked in; overlay card sprites/text in code. |

Use these shrine-street replacements for the leisure minigames:

| Minigame | New background | Notes |
|---|---|---|
| Batting | `shrine_games/batting_bg_shrine_v2.png` | Empty pitching-machine platform. Do not use older `batting_bg_shrine.png`; it has the machine baked in. |
| Bowling | `shrine_games/bowling_lane_shrine_v2.png` | Empty pin deck. Do not use older `bowling_lane_shrine.png`; it has pins baked in. |

## Separate gameplay sprites

Existing or new separate sprites to overlay:

| Purpose | Asset |
|---|---|
| Darts moving dart | `parlor/darts_dart_game_ready.png` |
| Darts board overlay, optional if code still needs target sprite | `parlor/darts_board_game_ready.png` |
| Roulette wheel sprite, static/rotatable | `parlor/roulette_wheel_top_game_ready.png` |
| Roulette ball sprite | `parlor/roulette_ball_game_ready.png` |
| Roulette 12-frame spin strip | `parlor/roulette_wheel_spin_strip_12.png` |
| Roulette individual spin frames | `parlor/roulette_wheel_spin_frames/roulette_wheel_spin_00.png` through `_11.png` |
| Roulette additive spin glow | `parlor/roulette_spin_glow_fx_game_ready.png` |
| Roulette ball trail overlay | `parlor/roulette_ball_trail_fx_game_ready.png` |
| Blackjack card back | `parlor/card_back_game_ready.png` |
| Blackjack blank card frame | `parlor/card_frame_blank_game_ready.png` |
| Batting ball | `parlor/baseball_ball_game_ready.png` |
| Batting first-person hands/bat | `parlor/batting_hands_game_ready.png` |
| Batting movable pitching machine | `shrine_games/pitching_machine_shrine_game_ready.png` |
| Bowling ball | `parlor/bowling_ball_game_ready.png` |
| Bowling pin sprite | `parlor/bowling_pin_game_ready.png` |

Optional source file for the pitching machine:

`shrine_games/pitching_machine_shrine_source_chromakey.png`

Do not load `*_source_chromakey.png` in game.

## Roulette implementation recommendation

Preferred implementation:

1. Use `roulette_table_top_v2.png` as the static table background.
2. Place `roulette_wheel_top_game_ready.png` as a centered Sprite2D on top of the wheel area.
3. Rotate that Sprite2D directly in code for the actual spin. This gives smooth motion and deterministic stopping.
4. During fast spin, show `roulette_spin_glow_fx_game_ready.png` over the wheel with additive or screen-style blend if available.
5. Move `roulette_ball_game_ready.png` around an orbit path while wheel spins.
6. During fast ball orbit, show `roulette_ball_trail_fx_game_ready.png` as a transient overlay.
7. Use `roulette_wheel_spin_strip_12.png` or the individual frames only if AnimatedSprite2D is simpler than runtime rotation.

The 12-frame strip layout is horizontal:

- Frame count: 12
- Each frame size: 1254 x 1254
- Strip size: 15048 x 1254

## Batting implementation notes

Use `batting_bg_shrine_v2.png` as the background.

Add separate Sprite2D nodes:

- `PitchingMachine`: texture `shrine_games/pitching_machine_shrine_game_ready.png`
- `Baseball`: texture `parlor/baseball_ball_game_ready.png`
- `Hands`: texture `parlor/batting_hands_game_ready.png`

The pitching machine can now animate independently. Suggested simple behavior:

- Idle: small horizontal sway or mechanical shake.
- Pitch windup: brief scale/position recoil.
- Pitch release: spawn/move baseball from the machine toward the player/camera.

## Bowling implementation notes

Use `bowling_lane_shrine_v2.png` as the background.

Add separate Sprite2D nodes:

- Bowling ball: `parlor/bowling_ball_game_ready.png`
- Pins: instantiate 10 copies of `parlor/bowling_pin_game_ready.png`

The background intentionally has an empty pin deck. Pins should be positioned/animated by code so hits can knock them down or hide them.

## Assets to avoid for final hookup

These are older/incorrect backgrounds and should not be used as final gameplay backgrounds:

- `parlor/parlor_bg_wide.png` — old gray full room.
- `parlor/parlor_bg_wide_v2.png` — good establishing shot, but too wide for Darts/Roulette/Blackjack gameplay.
- `parlor/batting_bg.png` and `parlor/batting_bg_v2.png` — casino version; batting moved to shrine street.
- `parlor/bowling_lane_bg.png` and `parlor/bowling_lane_bg_v2.png` — casino version; bowling moved to shrine street.
- `shrine_games/batting_bg_shrine.png` — has pitching machine baked into background.
- `shrine_games/bowling_lane_shrine.png` — has bowling pins baked into background.

## Verification checklist

After hookup:

1. Darts screen shows only the close-up dart station background, not the full parlor.
2. Roulette screen uses close-up table background and wheel/ball can move independently.
3. Blackjack screen has no baked-in cards under the programmatic cards.
4. Batting screen has no baked-in pitching machine; the machine node can move.
5. Bowling screen has no baked-in pins; pin nodes can be knocked down/hidden.
6. Paths use `res://assets/art_direction/new_ink_shrine_style/minigames/...`.
