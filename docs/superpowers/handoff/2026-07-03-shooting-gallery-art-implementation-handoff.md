# Claude Code implementation handoff — shrine shooting gallery minigame art

Date: 2026-07-03

Goal: add/wire art for the shrine-street shooting gallery minigame (`射的`). The art is split so targets, shots, hit effects, and the foreground rifle can move independently.

## Asset root

`res://assets/art_direction/new_ink_shrine_style/minigames/shrine_games/`

## Static background

Use:

`shooting_gallery_bg_shrine.png`

This is a static shrine-street shooting stall background. It intentionally has empty target shelves/rails in the center. Do not use background pixels as hit targets; instantiate target sprites separately.

## Gameplay sprites

| Purpose | Asset |
|---|---|
| Full target sheet, optional | `shooting_targets_shrine_game_ready.png` |
| Round bullseye target | `shooting_target_bullseye_game_ready.png` |
| Hanging plaque target | `shooting_target_plaque_game_ready.png` |
| Daruma prize target | `shooting_target_daruma_game_ready.png` |
| Lucky cat prize target | `shooting_target_luckycat_game_ready.png` |
| First-person rifle/hands overlay | `shooting_rifle_hands_shrine_game_ready.png` |
| Reticle/crosshair | `shooting_reticle_game_ready.png` |
| Cork projectile sprite | `shooting_cork_projectile_game_ready.png` |
| Projectile trail overlay | `shooting_projectile_trail_fx_game_ready.png` |

Source/chroma-key files, for art trace only:

- `shooting_targets_shrine_source_chromakey.png`
- `shooting_rifle_hands_shrine_source_chromakey.png`

Do not load `*_source_chromakey.png` in game.

## FX animation assets

Muzzle flash:

- Strip: `shooting_muzzle_flash_strip_6.png`
- Individual frames: `shooting_muzzle_flash_00.png` through `shooting_muzzle_flash_05.png`
- Strip frame size: 256 x 256
- Strip layout: horizontal, 6 frames, total 1536 x 256

Hit burst:

- Strip: `shooting_hit_burst_strip_8.png`
- Individual frames: `shooting_hit_burst_00.png` through `shooting_hit_burst_07.png`
- Strip frame size: 384 x 384
- Strip layout: horizontal, 8 frames, total 3072 x 384

## Recommended scene layering

Suggested Node2D order, back to front:

1. `Background`: Sprite2D, `shooting_gallery_bg_shrine.png`
2. `TargetLayer`: Node2D containing moving target Sprite2D instances
3. `ProjectileLayer`: cork projectile and trail sprites
4. `FxLayer`: hit burst and muzzle flash AnimatedSprite2D/Sprite2D
5. `RifleOverlay`: Sprite2D, `shooting_rifle_hands_shrine_game_ready.png`
6. `Reticle`: Sprite2D, `shooting_reticle_game_ready.png`
7. HUD

## Target behavior recommendation

Use separate target nodes. Do not rely on the background shelves for collision.

Suggested target lanes:

- Back shelf upper lane: slower horizontal targets.
- Middle shelf lane: medium speed, occasional pause.
- Lower shelf lane: fast small targets.

Target variants:

- `shooting_target_bullseye_game_ready.png`: normal target, low score.
- `shooting_target_plaque_game_ready.png`: narrow/harder target, medium score.
- `shooting_target_daruma_game_ready.png`: bonus target.
- `shooting_target_luckycat_game_ready.png`: rare bonus target.

Each target should own a collision area sized to its visible sprite bounds, not the full imported texture rectangle.

## Shooting behavior recommendation

On fire:

1. Briefly show muzzle flash near the rifle barrel.
2. Spawn cork projectile or show projectile trail from rifle direction toward reticle.
3. Test hit against active target areas at the reticle/click point or ray path.
4. If hit, play `shooting_hit_burst_*` at target position.
5. Hide/knock back/score the target.

Implementation can be either instant-hit reticle based or projectile-travel based. The art supports both:

- Instant-hit: use reticle click point + hit burst.
- Projectile-travel: animate `shooting_cork_projectile_game_ready.png` and trail.

## Rifle/reticle notes

The rifle overlay is first-person and should sit in the lower foreground. If the game uses mouse aim, keep the rifle mostly fixed and move only the reticle; optionally add small recoil on shot:

- Position recoil: move rifle down/back for 0.05-0.08s.
- Rotation recoil: rotate a few degrees and ease back.
- Muzzle flash: spawn at barrel tip.

## Verification checklist

After hookup:

1. Background has no baked active targets in the hit lanes.
2. Targets move independently and can be hidden/removed on hit.
3. Reticle/click hit checks use target nodes, not background art.
4. Muzzle flash and hit burst animate at correct positions.
5. Rifle overlay does not block target visibility too much.
6. All loaded paths use `res://assets/art_direction/new_ink_shrine_style/minigames/shrine_games/...`.
