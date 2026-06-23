# 鐵叔（TieShu）立繪生圖 Handoff → Codex（v2，對齊新 game_ready 風格）

日期：2026-06-22（v2 改：對齊 Codex 已生的 `new_ink_shrine_style/characters/game_ready` 全卡司風格）
用途：軍火庫條件 NPC「鐵叔」立繪，2 態（鎖前 locked / 鎖後 freed）。引擎側已全接好（`dialogue/TieShu.dch`＋`.dtl` 用 `TieShu (locked/freed):`＋`project.godot` 已註冊），只缺圖。

## ⚠ v2 更正：風格要 match 新 game_ready 全卡司（不是舊厚塗深背景）
Codex 已把全卡司重生在 `assets/art_direction/new_ink_shrine_style/characters/game_ready/`。鐵叔要**跟這批一致**：
- **半寫實厚塗＋風化做舊質感**、**全身**、**透明底 cutout（game-ready）**、墨黑＋土黃＋金低彩、`ares_red`（軍火庫＝阿瑞斯章）紅調點綴。
- **直接參照同夾的**：`lao_wang_front_ares_red_game_ready.png`（老年男性、破爛和服、背包/鋪蓋）＋ `liaochen_front_game_ready.png`（老僧、破袈裟、念珠）——鐵叔是同年齡層老匠人，跟這兩張站一起要一致。
- 直幅約 9:16 全身、透明底，跟其他 `*_front_*_game_ready.png` 同規格。

## 角色設定
鐵叔：被擄到阿瑞斯軍火庫的老鑄匠。原在神社替人鑄梵鐘/鑄佛具，被戰神強擄來逼著改鑄兵器彈藥。年邁、駝背、腳踝一道鐵鍊。

### 狀態 1：locked（鎖前，阿瑞斯未倒）
> Full-body character cutout on transparent background, semi-realistic thick-paint with weathered grungy texture, muted ink-black + earth-brown + gold palette with subtle red accents, matching reference lao_wang_front and liaochen_front. An elderly East-Asian blacksmith/metal-caster, heavily hunched back, head bowed low in defeat, deep wrinkles, soot-stained tattered work kimono and leather apron, a heavy iron shackle and chain on one ankle, calloused hands, weary hopeless downcast eyes. Edo-era Japan, oppressed prisoner-laborer. 9:16 full body, transparent background, game-ready cutout.

### 狀態 2：freed（鎖後，阿瑞斯已超渡 `ares_purified`）
> Same elderly metal-caster, same face/clothes (consistency), now standing straighter with head lifted, hopeful teary eyes, the ankle shackle broken open and hanging loose, a measure of dignity and relief returning. Still old, worn and tattered but unburdened. Muted ink+earth palette with a warm light accent. 9:16 full body, transparent background, game-ready cutout, matching the cast style.

兩態同一個人（臉、衣著一致），差別在姿態/神情/鐵鍊/光。

## 輸出落點（跟全卡司同夾同命名）
| 檔 | 路徑 |
|---|---|
| 鎖前全身 | `assets/art_direction/new_ink_shrine_style/characters/game_ready/tie_shu_locked_front_ares_red_game_ready.png` |
| 鎖後全身 | `assets/art_direction/new_ink_shrine_style/characters/game_ready/tie_shu_freed_front_ares_red_game_ready.png` |

（同你其他角色的 `*_source_chromakey.png` 追溯圖可留，遊戲用 `*_game_ready.png`。）

## 之後的接線（我來，不用 Codex 管）
鐵叔被納入「全卡司 game_ready 接進遊戲」整合計畫：我會用 PIL 從上面 2 張全身**裁出 bust**落到 `assets/2d/portraits/npcs/bust/npc_tie_shu_{locked,freed}.png`（`TieShu.dch` 已指向此路徑）→ `--import` → 軍火庫對話框自動顯示鐵叔（鎖前駝背／鎖後抬頭）。**所以 Codex 只需生上面 2 張全身透明底圖即可。**
