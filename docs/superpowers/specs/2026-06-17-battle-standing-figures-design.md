# 戰鬥畫面「站立對峙」立繪 + 程式呼吸 設計

日期：2026-06-17
關聯：[[project-build-status]]、[[project-art-direction]]（先定基底再批量／畫風統一）、前案 `2026-06-17-battle-screen-art-design.md`（框版，本案取代其呈現方式）。

## 目標

把戰鬥畫面從「框育立繪面板」改成 **Persona 5 式站立對峙**：敵我雙方都是**去背戰姿立繪**站在共用戰鬥背景上，並用**程式呼吸**讓他們有「活著」的微動。畫風品質優先（重生立繪，非去背舊圖）。

## ⚠ 方向更新（2026-06-17，定基底時拍板）

- **無戒改背面視角**：無戒面向敵人，玩家看到的是他的**背影**（更正統 P5 構圖）。只有玩家（無戒）是背面；敵人維持正面朝玩家。
- **背面無臉 → 取消 calm/angry 換臉**；改成 **正常 / 受傷 兩態**：每職做 2 張背面圖——`wujie_<job>.png`（戰鬥架式）＋ `wujie_<job>_hurt.png`（HP<30% 換的踉蹌護腹受傷姿）。不靠表情、不靠 modulate。
  → 無戒每職 2 態 × 3 職 ＝ **6 張**（檔名無 calm/angry，改 `_hurt` 後綴）。
- **生圖工具**：實際用 **higgsfield `nano_banana_pro`**（2:3 / 2k，吃角色參考圖）生戰姿；**magnific `images_remove_background`** 去背（higgsfield 該 workspace 去背額度用盡）。畫風一致靠「同一張鎖定基底（v3 微側版）當參考」批量。
- **基底鎖定**：無戒 ascetic ＝ v3「微側背影、低馬步、飄逸長袍雙肩」；chanter ＝金黃袍＋長念珠繞背；beggar ＝破爛補丁褐袍。三者同人同樁同畫風。

## 與前案的關係
- **保留**：背景資料驅動（`resolve_battle_bg`、`bg_battle_pantheon` 等）、`battle_art.gd`、Boss 4 表情切換邏輯、玩家依職業/低HP換臉、`BattleManager`/`BattleUI` 的事件接線骨架。
- **取代**：`EnemyPanel` 的「框 + 名字血條 VBox」呈現 → 改「站立立繪 + 浮動名牌/HP」；`neon_frame` 從框立繪改用在名牌/HP 條；`PlayerPanel` 立繪改前景站立大圖。

## 美術管線（重生戰姿立繪）

1. **生圖**：magnific Nano Banana（`imagen-nano-banana-2`）生**戰鬥姿勢**全/半身立繪——敵人戒備或攻擊架式、無戒武僧馬步出拳式；生在**單純可去背底**（純色/灰）、半寫實厚塗 noir、暗金×黑、與既有立繪同畫風同打光。
2. **去背**：`images_remove_background` → 透明 PNG。
3. **存放**：`assets/2d/portraits/enemies/cut/<id>.png`、`…/boss/cut/ares_<mood>.png`、`…/wujie/cut/wujie_<job>_<mood>.png`。
4. **先定基底**（沿用 [[project-art-direction]] 慣例）：**先生 1 張無戒戰姿**，使用者確認畫風/比例後，才批量其餘（畫風鎖定參數一致）。
5. **本輪範圍**（ch1 demo 戰力）：無戒 3 職 ×{正常,受傷}背面 ＝6；`pantheon_guard` ＝1；阿瑞斯 {base, phase2}＝2＝**共 9 張**（見上「方向更新」）。其餘敵人（punk/vendor/ghost/temple_ghost）+ 阿瑞斯 {mocking_laugh, pained} 於畫風鎖定後同管線補（spec 列為 phase 2，不擋本輪驗收）。
6. **比例/構圖**：去背後高度一致化（圖內角色佔滿畫布高、腳底對齊底邊），方便引擎統一縮放、腳踩地。

## 程式呼吸（`src/screens/BattleScreen/breathing_figure.gd`）

- `class_name BreathingFigure extends TextureRect`。`pivot_offset` 設**底部中央**（腳踩地）。`_process(delta)` 跑 sine：
  - 垂直浮動：`position.y = _base_y - sin(t)*amp_y`（amp_y≈5px）。
  - 胸口縮放：`scale.y = 1 + sin(t)*0.015`、`scale.x = 1 - sin(t)*0.008`（吸氣脹、微縮）。
  - 輕搖：`rotation = sin(t*0.5)*0.009`（≈0.5°）。
- `@export` 參數：`amp_y`、`period`、`sway`、`enabled`。`_ready` 隨機 `_phase`（各圖不同步）。
- 受擊/出招的暫態 shake 與表情切換沿用既有（疊在呼吸上，呼吸 `_base_y` 不被 shake 永久位移）。

## 版面（重構 `BattleScreen.tscn`）

- **EnemyField**（取代 EnemyArea 的框面板）：上半/右上區，敵人站立立繪橫向分佈（多隻間距、可微縮做景深），每隻下方浮動**名牌＋HP 條**（暗金霓虹 StyleBox，`neon_frame` 改用於此）。整隻立繪可點＝選目標（TextureButton 或 figure 上疊透明 Button）。
- **PlayerFigure**：無戒站左下前景（放大），依 `player.job` 取 cut 背面立繪（`wujie_<job>.png`），HP<30% 換受傷姿（`wujie_<job>_hurt.png`，背面無臉故換姿不換臉），套 BreathingFigure。
- **保留**：底部玩家狀態列（HP/業障/功德/金幣）、右下技能選單、中下戰鬥訊息、AllOut overlay。

## 元件邊界
- `BreathingFigure`：純呈現微動，吃一張 texture，無戰鬥邏輯。
- `EnemyPanel`（重構為「站立敵方單位」）：持 `Combatant`，組 figure(BreathingFigure)＋浮動名牌/HP，發 `target_pressed`，提供 `set_base_portrait`/`flash_mood`（換 cut 立繪貼圖）＋死亡灰化。
- `battle_art.gd`：新增 `resolve_figure_path(group, filename)`＝先試 `<dir>/cut/<f>` 再退回原圖；`player_figure_path(job, mood)`＝`wujie/cut/wujie_<job>_<mood>.png`，缺則退 `_nobg`/原 jpg。
- `BattleManager`/`BattleUI`：接線不變（set bg、flash/ set_enemy_base、玩家換臉），只是面板呈現改站立。

## 測試（headless）
`TestBattleArt` 擴充：
- cut 立繪路徑解析 + 載入為 Texture2D（本輪範圍那些）；缺 cut 時 `resolve_figure_path` 正確退回原圖。
- `BreathingFigure` 可建構、`_process` 一幀後 position/scale 有偏移且 `_base_y` 記錄正確（呼吸不漂移）。
- 重構後 `EnemyPanel`（站立單位）建構含 figure、`set_base_portrait` 換圖、`target_pressed` 可發。
- 場景煙霧：`BattleScreen.tscn` 實例化、`%`-節點解析。
- 回歸：TestMainQuest/TestMenuSystem/TestCh1Expansion ALL PASS、parse clean。
- **GPU**：capture 場景重截 ares/guard 站立圖給使用者看呼吸與站位。

## 風險／雷
- **去背乾淨度**：Nano Banana 生在純底 + remove_background 才好去乾淨；複雜背景去背會有殘邊。生圖務必要求單純底。
- **比例不一**：各圖角色佔比不同會導致站起來忽大忽小→生圖統一「全身入鏡、腳底對齊底邊、留頭頂空間」，引擎再統一縮放。
- **新 png 要 `--import`**（同 [[project-2d-map]]）。
- **呼吸 + shake 疊加**：shake 改當前 frame 偏移、不要污染 `_base_y`（否則圖會慢慢漂走）。
- **headless 不驗觀感**：呼吸節奏/站位/去背邊緣要 GPU 看。
- **先定基底未過就批量**＝浪費 credits：務必先生 1 張無戒、使用者點頭再批。
