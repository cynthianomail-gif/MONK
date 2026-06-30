# Ares VFX Handoff

目的：阿瑞斯一階、二階不要用完整序列圖做待機煙霧。角色本體維持靜態 Sprite，煙霧、火星、受擊、攻擊爆發用 Godot 疊層與 Tween / Particles 製作。

## 新增素材

角色攻擊姿勢：
- `ares_attack_front_black_red_game_ready.png`
- `ares_phase2_attack_front_black_red_game_ready.png`

特效素材：
- `fx_ares_idle_mist_black_red_game_ready.png`
- `fx_ares_ember_sparks_black_red_game_ready.png`
- `fx_ares_hit_impact_black_red_game_ready.png`
- `fx_ares_attack_burst_black_red_game_ready.png`
- `fx_ares_phase2_transform_burst_black_red_game_ready.png`
- `fx_ares_projectile_trail_black_red_game_ready.png`
- `fx_ares_attack_warning_ring_black_red_game_ready.png`
- `fx_ares_charge_aura_black_red_game_ready.png`
- `fx_ares_impact_explosion_black_red_game_ready.png`
- `fx_ares_defeat_dissolve_black_red_game_ready.png`

每張都有對應 `*_source_chromakey.png`，只給美術追溯用；遊戲內請使用 `*_game_ready.png`。

## 建議節點結構

```text
AresBoss
  Sprite2D Body
  Sprite2D BackMistLeft
  Sprite2D BackMistRight
  CPUParticles2D Embers
  Sprite2D HitImpact
  Sprite2D AttackBurst
  Sprite2D Phase2Burst
  Sprite2D WarningRing
  Sprite2D ChargeAura
  Sprite2D DefeatDissolve
  Node2D Projectiles
```

`BackMistLeft`、`BackMistRight` 放在角色後方。`HitImpact` 和 `AttackBurst` 放在角色前方。

## 待機霧

使用 `fx_ares_idle_mist_black_red_game_ready.png` 做兩層：
- 左右各一張，右側可 `flip_h = true`
- alpha 約 `0.28 - 0.45`
- scale 約 `0.75 - 1.05`
- position 在角色左右腰到肩附近
- 用 Tween 讓 position.y、rotation、modulate.a 慢慢循環

一階建議：
- 霧較淡，速度慢
- 紅色火星少

二階建議：
- 霧較濃，scale 較大
- Tween 速度稍快
- Embers emission amount 增加

## 火星粒子

使用 `fx_ares_ember_sparks_black_red_game_ready.png` 作為粒子貼圖或單張 overlay。

建議粒子參數：
- lifetime：`0.8 - 1.4`
- amount：一階 `12 - 18`，二階 `28 - 45`
- initial_velocity：`20 - 60`
- gravity：`Vector2(0, -10)` 或接近 0
- scale_amount：`0.08 - 0.22`
- color alpha 隨生命淡出

火星可以常駐低量發射，攻擊與受擊時短暫提高 amount。

## 受擊效果

受擊不要換角色 hurt 圖，直接做程式效果：
- `Body.modulate = Color(1.6, 0.45, 0.45, 1.0)` 約 `0.06s`
- 角色左右 shake 約 `4 - 8px`，持續 `0.12s`
- 顯示 `fx_ares_hit_impact_black_red_game_ready.png`
- HitImpact 從 scale `0.55` 放大到 `1.05`，alpha 從 `1.0` 淡到 `0`
- 二階受擊可額外讓 BackMist alpha 瞬間提高 `0.15`

## 攻擊效果

攻擊開始：
1. `Body.texture` 換成攻擊姿勢：
   - 一階：`ares_attack_front_black_red_game_ready.png`
   - 二階：`ares_phase2_attack_front_black_red_game_ready.png`
2. `AttackBurst.texture = fx_ares_attack_burst_black_red_game_ready.png`
3. `AttackBurst` 放在伸手方向或胸前軍火庫爆點。
4. AttackBurst scale 從 `0.45` 到 `1.2`，alpha 從 `0.9` 到 `0`。
5. 火星 emission 暫時提高。

蓄力可先顯示 `fx_ares_charge_aura_black_red_game_ready.png`：
- 放在右手、胸口或二階軍火庫爆點。
- scale 從 `0.35` 到 `0.85`，alpha 從 `0.0` 到 `0.9`。
- 攻擊發生瞬間快速縮小或淡出，再顯示 AttackBurst。

攻擊結束：
- `Body.texture` 換回 idle：
  - 一階：`ares_front_black_red_game_ready.png`
  - 二階：`ares_phase2_front_black_red_v2_game_ready.png`（若確認採用 v2，可再改成正式檔名）

## 攻擊警示圈

使用 `fx_ares_attack_warning_ring_black_red_game_ready.png`。

建議流程：
1. 產生在玩家腳下或目標區。
2. scale 從 `0.65` 到 `1.0`，alpha 從 `0.0` 到 `0.75`。
3. 停留 `0.25 - 0.45s`。
4. 攻擊發生前 `0.08s` 快速閃一下紅色。
5. 攻擊發生後 alpha 淡到 `0`。

這張圖沒有文字與數字，可以當地面 telegraph。若場景不是正俯視，可把 Sprite2D scale.y 壓到 `0.35 - 0.55` 做成地面橢圓。

## 彈道 / 拖尾

使用 `fx_ares_projectile_trail_black_red_game_ready.png`。

建議做法：
- 建一個 Projectile scene，裡面放 Sprite2D。
- texture 指向 projectile trail。
- 依攻擊方向旋轉整個 Projectile。
- 移動速度由技能資料決定。
- 命中時生成 `fx_ares_hit_impact_black_red_game_ready.png` 或 `fx_ares_attack_burst_black_red_game_ready.png`。
- 大招或彈道命中時，改生成 `fx_ares_impact_explosion_black_red_game_ready.png`。

如果要做近戰式橫掃，也可以不移動 Projectile，只把這張當 slash overlay：scale.x 從 `0.6` 到 `1.15`，alpha 淡出。

## 命中爆炸

使用 `fx_ares_impact_explosion_black_red_game_ready.png`。

建議流程：
1. 生成在命中點。
2. scale 從 `0.45` 到 `1.25`。
3. alpha 從 `1.0` 到 `0.0`，時間 `0.22 - 0.38s`。
4. 同時短暫啟動 camera shake。

小招可用 `fx_ares_hit_impact_black_red_game_ready.png`，大招或二階攻擊用這張。

## 二階轉場

建議流程：
1. 一階 Body 閃紅並 shake。
2. BackMist scale / alpha 增加。
3. Ember emission 爆量 `0.8s`。
4. 顯示 `fx_ares_phase2_transform_burst_black_red_game_ready.png`，放在身體前方。
5. Phase2Burst scale 從 `0.75` 到 `1.15`，alpha 從 `0.0` 到 `1.0` 再淡出。
6. 在 Phase2Burst alpha 最高點，把 Body texture 換成 `ares_phase2_front_black_red_v2_game_ready.png`。
7. Mist 速度和 alpha 切到二階參數。

## 擊敗 / 退場

使用 `fx_ares_defeat_dissolve_black_red_game_ready.png`。

建議流程：
1. Body 先閃白紅 `0.08s`，再開始 alpha 淡出。
2. 顯示 DefeatDissolve，放在 Body 同位置或略上方。
3. DefeatDissolve scale 從 `0.85` 到 `1.15`，position.y 向上 `-30px`。
4. alpha 從 `0.0` 到 `1.0` 再淡出到 `0.0`，總長 `0.9 - 1.4s`。
5. Embers emission 短暫提高後停止。

## 驗證重點

- 圖層排序：霧在身後，HitImpact / AttackBurst 在身前。
- 受擊時不要永久改到 Body.modulate，Tween 結束要還原白色。
- 攻擊姿勢與 idle 需要同一錨點，建議 Sprite2D centered 開啟，position 不要每次重設。
- 如果二階正式採用 v2，請把使用處統一指向 `ares_phase2_front_black_red_v2_game_ready.png`，或由美術端之後覆蓋正式 `ares_phase2_front_black_red_game_ready.png`。
