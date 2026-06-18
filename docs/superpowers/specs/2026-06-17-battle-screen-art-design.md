# 戰鬥畫面美術串接（Step 4 visuals）設計

日期：2026-06-17
關聯：[[project-build-status]]、戰鬥系統（`src/screens/BattleScreen/`）、UI 色系（暗金×黑，見 `project-art-direction`、`project-dialogue-vn-style`）

## 目標

把「已生成但戰鬥畫面從未顯示」的美術全部接上：戰鬥背景、敵人/Boss 立繪、玩家立繪。目前 `BattleScreen.tscn` 背景是一塊純色 `ColorRect`，`EnemyPanel` 只畫文字血條，`enemies.json`/`boss.json` 的 `portrait`、`battle_bg` 欄位無人讀（程式註解：「Step 4 將換成立繪 + 霓虹框」）。

## 範圍

**做：**
1. 戰鬥背景圖（資料驅動，取代純色 ColorRect）。
2. 敵人/Boss 立繪（`EnemyPanel` 顯示，暗金霓虹框，死亡轉灰）。
3. 阿瑞斯動態 4 立繪（base / mocking_laugh / pained / phase2 依戰況切換）。
4. 玩家立繪（`PlayerPanel`，依職業 ascetic/chanter/beggar，低 HP 換怒臉）。
5. 共用 neon StyleBox helper（暗金×黑）。
6. 新生 1 張 pantheon 專屬戰鬥背景（magnific）。

**不做（另案，僅記錄）：**
- `boss.json` 的 `defeat_cutscene: "ares_defeated"` 是死資料（無程式讀、無影格）——非本案，另行處理。
- 戰鬥「霓虹斜切」進階美化（panel 斜切動畫等）超出本次，先把圖接上＋基本金框。
- 一般敵人的多表情立繪（目前各只 1 張，維持）。

## 元件與改動

### ① 背景（BattleScreen.tscn + BattleManager.gd）
- `BattleScreen.tscn`：在 `BattleUI` 最底層（`Background` ColorRect 之上、`EnemyArea` 之下）新增 `TextureRect`「BattleBg」，`expand_mode=IGNORE_SIZE`、`stretch_mode=STRETCH_KEEP_ASPECT_COVERED`、full rect。原 `Background` ColorRect 保留在其下當載入失敗的保險底色。
- `BattleManager.setup(enemy_id)`：解析背景路徑並設 `BattleBg.texture`。解析規則（`resolve_battle_bg(data)` 純函式，供測試）：
  1. `data.battle_bg` 有值 → `res://assets/2d/backgrounds/<battle_bg>`（boss 走這條）。
  2. 否則依 `data.district` 對照表：`ximen→bg_battle_ximen`、`wanhua_old→bg_battle_wanhua`、`linsen→bg_battle_linsen`、`pantheon→bg_battle_pantheon`（新生）。
  3. 對照不到 → fallback `bg_battle_ximen`。
  - 載入失敗（檔不存在）→ 不設 texture，露底色 ColorRect（安全）。

### ② 敵人/Boss 立繪（Combatant.gd + EnemyPanel.gd）
- `Combatant.from_enemy(...)`：解析並存 `portrait_path`。規則（`resolve_portrait_path(filename)` 純函式）：先試 `res://assets/2d/portraits/enemies/<f>`，再試 `res://assets/2d/portraits/boss/<f>`，皆無回空字串。
- `EnemyPanel`：名字上方加 `TextureRect`（`custom_minimum_size≈(200,150)`、`expand_mode=IGNORE_SIZE`、`STRETCH_KEEP_ASPECT_CENTERED`），包在套了 neon StyleBox 的 `PanelContainer`。`portrait_path` 為空則隱藏立繪框（退回純文字面板，安全）。死亡：沿用現有 `modulate` 轉灰（連立繪一起灰）。

### ③ 阿瑞斯動態 4 立繪（boss.json + BattleManager.gd + EnemyPanel.gd）
- `boss.json` `ares` 加 `portrait_moods`（明確對照，利於 ch2–12 各 Boss 自定義）：
  ```json
  "portrait_moods": { "hurt": "ares_pained.jpg", "act": "ares_mocking_laugh.jpg", "phase2": "ares_phase2.jpg" }
  ```
  路徑同 `portrait`（boss/ 目錄）。
- `EnemyPanel.set_mood(path)`：換立繪 texture（path 空則維持當前）。
- `BattleManager` 對 Boss（`is_boss`）wire：
  - **base**：開戰＝`portrait`（ares_base）。
  - **act**：Boss 執行技能時（`_enemy_turn` 內、`execute_enemy_action` 後）→ 暫態切 `mood.act`（mocking_laugh）約 0.8s 再revert 當前 base。
  - **hurt**：Boss 受傷時（panel `hp_changed` 下降）→ 暫態切 `mood.hurt`（pained）約 0.6s 再 revert；或 HP<40% 後持久 hurt。採「暫態 0.6s」較簡單，低 HP 不持久（避免狀態機複雜化）。
  - **phase2**：`_maybe_trigger_boss_phase2` 切到 phase2 後，把 base 更新成 `mood.phase2`（持久；之後 revert 都回 phase2）。
  - 暫態用單一 `Timer`/`create_timer`，新事件覆蓋舊的（重設回 base 再切），避免疊加。
- 一般敵人無 `portrait_moods` → 永遠 base，set_mood 不被呼叫。

### ④ 玩家立繪（BattleScreen.tscn + BattleUI.gd）
- `PlayerPanel` 改成左立繪 + 右資訊（HBox）。左加 `TextureRect`（neon 框），右沿用現有 VBox（名/HP/資源）。
- `BattleUI.build`：依 `GameManager.player.job`（ascetic/chanter/beggar，預設 ascetic）載 `res://assets/2d/portraits/wujie/wujie_<job>_calm.jpg`。`player_portrait_path(job)` 純函式。
- 低 HP：`player.hp_changed` 內，HP<30% 換 `wujie_<job>_angry.jpg`，回升則換回 calm。載入失敗 → 隱藏立繪框（安全）。

### ⑤ neon StyleBox helper
- 新 `src/ui/battle/neon_frame.gd`（或併入既有 ui helper）：`static func make(gold:=Color(0.788,0.659,0.38)) -> StyleBoxFlat`，近黑底 + 金邊 `border_width≈2` + `shadow_color`(金, alpha 低) + `shadow_size≈6` 做光暈 + `corner_radius≈6`。供 EnemyPanel／PlayerPanel／立繪框共用。沿用對話 VN 版面同一套暗金×黑觀感（不另做 shader）。

### ⑥ 新 pantheon 戰鬥背景（美術產製）
- magnific Nano Banana（`imagen-nano-banana-2`）16:9 2k：「萬神殿保全集團總部內部·軍火庫：冷光金屬貨架、武器箱、企業冷藍光＋暗金、混凝土地、雨夜玻璃帷幕遠景、半寫實厚塗 noir、無人無字、適合當戰鬥背景留中間空間」。出 2 版選一，PNG→存 `assets/2d/backgrounds/bg_battle_pantheon.png`，`--headless --import` 生 `.import`。

## 路徑解析彙整（純函式，全可 headless 測）
- `resolve_battle_bg(data) -> String`
- `resolve_portrait_path(filename) -> String`
- `player_portrait_path(job, mood:="calm") -> String`

## 測試（headless）
新增 `test/TestBattleArt.tscn`：
1. `resolve_battle_bg`：street_punk→ximen、night_ghost→wanhua、drunk_guard→linsen、pantheon_guard→pantheon、ares→boss（explicit）；對照表 fallback。
2. 解析出的每個 bg 路徑 `ResourceLoader.exists` 且 `load is Texture2D`（含新 bg_battle_pantheon）。
3. `resolve_portrait_path`：5 敵人 + ares_base 解析到正確目錄、可載成 Texture2D。
4. 阿瑞斯 `portrait_moods` 三張（pained/mocking_laugh/phase2）路徑可載成 Texture2D。
5. `player_portrait_path`：ascetic/chanter/beggar 的 calm + angry 皆可載。
6. 煙霧：`Combatant.from_enemy` 後 `portrait_path` 非空；`EnemyPanel.new(c)` 含立繪建構無 error；`BattleUI.build` 玩家立繪建構無 error。
回歸：`TestMainQuest`/`TestMenuSystem`/`TestCh1Expansion` 仍 ALL PASS；`--editor --quit` 無 parse error。
**GPU（待使用者抽驗）**：背景/立繪/霓虹框實機觀感、阿瑞斯 4 立繪切換時機、玩家低 HP 換臉。

## 風險／雷
- **新 bg 要 `--import`**：新 jpg/png 丟進專案後 runtime 不自動匯入，必跑 `--headless --import`（同 [[project-2d-map]]、本日 A1 教訓）。
- **headless 不驗觀感**：只驗路徑/載入/建構；霓虹框、立繪縮放、切換時機要 GPU 看。
- **暫態 mood 競態**：act/hurt 暫態切換要用「新事件先 revert 再切 + 單一計時器」避免兩個 timer 互踩把立繪卡在錯誤表情；phase2 是持久態，暫態 revert 要回「當前持久 base」非寫死 ares_base。
- **立繪長寬比**：boss/enemy 立繪是半身 jpg，框內用 KEEP_ASPECT_CENTERED 避免變形；過高的立繪靠固定框高 + 置中裁切感。
- **死亡轉灰**：modulate 作用在整個 panel（含立繪），沿用現有不重寫。
