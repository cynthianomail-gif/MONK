# 鐵叔（TieShu）立繪生圖 Handoff → Codex

日期：2026-06-22
用途：軍火庫條件 NPC「鐵叔」的 VN 對話立繪，2 態（鎖前 locked / 鎖後 freed）。引擎側已全接好（`dialogue/TieShu.dch`＋兩支 `.dtl` 用 `TieShu (locked/freed):` 發話＋`project.godot` 已註冊），**只缺這 2 張圖**；圖一落到下方路徑就會在對話框自動顯示，無需再改程式。

## 畫風（務必 match 現有 NPC 立繪，不要水墨）
- **半寫實厚塗（semi-realistic digital painting / thick paint）**，深色近黑背景，戲劇性側光，低彩度土黃／鐵灰色調。
- 直接對齊參考圖：`assets/2d/portraits/npcs/npc_liaochen.png`（了塵，老年僧侶、灰袍、厚塗、深背景）——鐵叔要能跟它＋無戒站同一個對話框不違和。
- ⚠ 環境是大神水墨 3D，但**角色立繪一律維持這個厚塗風**（無戒12張/Cherry/全 NPC 都是）。別生成水墨／線稿／動漫賽璐璐。
- 直幅約 2:3，全身或 3/4 身（同 npc_liaochen 構圖）。

## 角色設定
鐵叔：被擄到阿瑞斯軍火庫的老鑄匠。原本在神社替人鑄梵鐘、鑄佛具的匠人，被戰神強擄來逼著改鑄兵器彈藥。年邁、駝背、腳踝上一道鐵鍊。

### 狀態 1：locked（鎖前，阿瑞斯未倒）
ready-to-use prompt：
> Semi-realistic digital thick-paint portrait, dark near-black background, dramatic side lighting, muted earthy iron-grey palette. An elderly East-Asian male blacksmith/metal-caster, hunched back, head bowed low in defeat, deep wrinkles, soot-stained grey work clothes and leather apron, a heavy iron shackle and chain on one ankle, calloused hands, weary hopeless eyes avoiding the viewer, dim forge glow and ammunition crates behind. Oppressive, beaten-down mood. Full body, 2:3 portrait, painterly brushwork matching reference npc_liaochen.

### 狀態 2：freed（鎖後，阿瑞斯已超渡 `ares_purified`）
ready-to-use prompt：
> Semi-realistic digital thick-paint portrait, same elderly East-Asian metal-caster, same face/clothes as the locked version (consistency), but now standing straighter with head lifted, hopeful teary eyes, the ankle shackle broken open, warm daylight streaming from an opened door behind him, a measure of dignity and relief returning. Still old and worn but unburdened. Muted earthy palette with a warm light accent. Full body, 2:3 portrait, painterly brushwork matching reference npc_liaochen.

兩態須是**同一個人**（臉、衣著一致），差別在姿態/神情/鐵鍊/光。

## 輸出落點（檔名固定，引擎已指向）
照現有 NPC 管線（full → 去背 → bust 裁切）：

| 用途 | 路徑 | 說明 |
|---|---|---|
| 全身原圖 locked | `assets/2d/portraits/npcs/npc_tie_shu_locked.png` | 生成原圖 |
| 全身原圖 freed | `assets/2d/portraits/npcs/npc_tie_shu_freed.png` | 生成原圖 |
| **VN 半身 locked** | `assets/2d/portraits/npcs/bust/npc_tie_shu_locked.png` | ⭐ `.dch` 讀這張（頭+上半身裁切，比照 `bust/npc_lao_wang.png`） |
| **VN 半身 freed** | `assets/2d/portraits/npcs/bust/npc_tie_shu_freed.png` | ⭐ `.dch` 讀這張 |
| 去背（選配） | `assets/2d/portraits/_nobg/npc_tie_shu_locked.png` / `_freed.png` | 比照其他 NPC 的 `_nobg/` |

**最關鍵是 `bust/` 兩張**（對話框實際顯示的）。落定後跑一次 `--import`，鐵叔對話即帶立繪。

## 落定後驗收（生圖回來後我或你跑）
1. `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import`
2. windowed 進軍火庫踏鐵叔觸發 → 鎖前對話框左下出現駝背鐵叔；超渡阿瑞斯後再來 → 抬頭含淚態。
3. 確認鐵叔立繪與無戒同框不違和（同厚塗風）。
