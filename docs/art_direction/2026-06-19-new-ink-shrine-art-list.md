# New Ink Shrine Art List

## 🔄 2026-06-20 更新（修正下方框架）

- **街景探索＝3D 水墨場景**（幾何盒體＋水墨 shader，見 `ShrineStreet` / spec `2026-06-20-3d-shrine-street-scene-design.md`），**不是 2D 平面背景圖**。→ 下方「First Batch To Regenerate」的 **#1–#3 街景（`2d/map/scenes/*.png`）作廢**；AI 街景圖只當**概念參考／遠景天幕**用（已生 `_art_review/_ximen_okami_test.png`）。
- **仍是 2D 平面圖**的：戰鬥背景 `bg_battle_*`（#5–#6）、地點內景 `old_temple`（#4，除非也改 3D）。
- **產線分工**：角色立繪（#7 wujie cut 等）→ **Codex**（存 `assets/art_direction/new_ink_shrine_style/characters/game_ready/`）；背景圖 → **Magnific（Freepik MCP / nano_banana）**。higgsfield 額度已乾。
- 下方 Style Baseline 與 Prompt Spine（畫風/咒語）續用。

## Style Baseline

Story setting is now Japan. Religious spaces should read as Japanese shrine or shrine-adjacent sacred districts, not Taiwanese or Chinese temples.

Core visual language:
- Aged rice paper texture, sumi-e ink wash, rough calligraphic black strokes.
- Black, smoky gray, parchment cream, restrained vermilion, lantern amber, small antique gold flecks.
- Strong monk silhouette: bald head, flowing black robe, readable from the back.
- Japanese shrine motifs: torii, shimenawa, shide paper streamers, stone lanterns, shrine roofs, wet stone paths, cedar forest mist.
- No Chinese temple roofs, no Taiwan street signs, no readable text, no Okami-like white animal motif.

## Generated Baseline

- `assets/art_direction/new_ink_shrine_style/key_visual_japanese_shrine_v1.png`

Purpose: key visual and style anchor for the new art direction.

## First Batch To Regenerate

These should be generated before replacing existing in-game assets:

1. `assets/2d/map/scenes/ximen_street.png`
   - Replace conceptually with a Japanese shrine-town street district.
   - Side-scrolling exploration background.

2. `assets/2d/map/scenes/wanhua_street.png`
   - Replace conceptually with an older market lane near a shrine approach.
   - More worn, smoky, folk-religious atmosphere.

3. `assets/2d/map/scenes/linsen_street.png`
   - Replace conceptually with a nightlife alley in Japan.
   - Keep shrine/ritual undertones through lanterns, talismans, and ink shadows.

4. `assets/2d/map/interiors/old_temple.png`
   - Replace with a Japanese shrine inner court or small shrine office.
   - Must show torii/shimenawa/shide or shrine architecture clearly.

5. `assets/2d/backgrounds/bg_battle_temple.png`
   - Replace with shrine courtyard battle background.
   - Needs empty mid-ground for standing figures.

6. `assets/2d/backgrounds/bg_battle_wanhua.png`
   - Replace with shrine-market battle background.
   - Needs readable ground plane and mist depth.

7. `assets/2d/portraits/wujie/cut/*.png`
   - Repaint as black-robed monk silhouette in the new ink style.
   - Keep existing gameplay poses: ascetic, beggar, chanter, and hurt variants.

## Prompt Spine

Use this as the common prompt base:

Japanese dark Buddhist fantasy game art, sumi-e ink wash on aged rice paper, rough black calligraphic brushwork, smoky gray mist, parchment cream, restrained vermilion shrine accents, antique gold flecks, warm lantern glow, wet stone reflections, Japanese shrine visual language with torii, shimenawa, shide, stone lanterns, cedar forest atmosphere, cinematic but usable as game background, no readable text, no logo, no watermark, no Chinese temple architecture, no Taiwan street signs.

