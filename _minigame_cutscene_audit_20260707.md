# 小遊戲過場（intro/win/lose）盤點報告 — 2026-07-07

## 結論

**零缺口。** 9 款小遊戲 × 3 種過場（intro/win/lose）= 27 格，資產與程式接線全部已套。
`TestMinigameCutscene.tscn` headless 全跑通過（含 2026-07-07 當天新增、專門針對「支線/打工路徑
是否繞過開場短片」疑慮的兩個測試），exit code 0，ALL PASS。

---

## 矩陣表（9 × 3）

| 小遊戲 (id) | intro | win | lose |
|---|---|---|---|
| **batting**<br>(Batting.gd) | 資產＝`assets/cutscenes/minigame_batting_intro`(61幀+audio.ogg) ✅／程式＝`SceneRouter.go_to_minigame` 統一播放(`SceneRouter.gd:211`) ／判定：**已套** | 資產＝`minigame_batting_win`(61幀+audio) ✅／程式＝`Batting.gd:173 show_result_panel(...)`→`MinigameBase.gd:100 _play_end_cutscene`／判定：**已套** | 資產＝`minigame_batting_lose`(49幀+audio) ✅／程式同上／判定：**已套** |
| **beggar_challenge**<br>(BeggarChallenge.gd) | 資產＝`minigame_beggar_challenge_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_beggar_challenge_win`(61幀+audio) ✅／程式＝`BeggarChallenge.gd:384 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_beggar_challenge_lose`(49幀+audio) ✅／程式同上／判定：**已套** |
| **blackjack**<br>(Blackjack.gd) | 資產＝`minigame_blackjack_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_blackjack_win`(61幀+audio) ✅／程式＝`Blackjack.gd:391 show_result_panel(...)`（另有內部 `_show_result_panel` 於 `:611` 是不同的中途提示，非結尾面板，不影響此判定）／判定：**已套** | 資產＝`minigame_blackjack_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **bowling**<br>(Bowling.gd) | 資產＝`minigame_bowling_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_bowling_win`(61幀+audio) ✅／程式＝`Bowling.gd:231 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_bowling_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **darts**<br>(Darts.gd) | 資產＝`minigame_darts_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_darts_win`(61幀+audio) ✅／程式＝`Darts.gd:319 show_result_panel(...)`（TestMinigameCutscene.gd 第 6 項測試直接驗過這一支的完整流程）／判定：**已套** | 資產＝`minigame_darts_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **offering_toss**<br>(OfferingToss.gd) | 資產＝`minigame_offering_toss_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_offering_toss_win`(61幀+audio) ✅／程式＝`OfferingToss.gd:140 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_offering_toss_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **roulette**<br>(Roulette.gd) | 資產＝`minigame_roulette_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_roulette_win`(61幀+audio) ✅／程式＝`Roulette.gd:334 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_roulette_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **soup_carry**<br>(SoupCarry.gd) | 資產＝`minigame_soup_carry_intro`(61幀+audio) ✅／程式＝同上共用路徑／判定：**已套** | 資產＝`minigame_soup_carry_win`(49幀+audio) ✅／程式＝`SoupCarry.gd:914 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_soup_carry_lose`(61幀+audio) ✅／程式同上／判定：**已套** |
| **wooden_fish_rhythm**<br>(WoodenFishRhythm.gd) | 資產＝`minigame_wooden_fish_rhythm_intro`(61幀+audio) ✅／程式＝同上共用路徑（TestMinigameCutscene.gd 第 8a 項測試走 QuestManager「jie」支線實資料驗過這條路徑）／判定：**已套** | 資產＝`minigame_wooden_fish_rhythm_win`(61幀+audio) ✅／程式＝`WoodenFishRhythm.gd:356 show_result_panel(...)`／判定：**已套** | 資產＝`minigame_wooden_fish_rhythm_lose`(61幀+audio) ✅／程式同上／判定：**已套** |

備註：SoupCarry 專案裡雖有 `SoupCarry.gd`（無獨立 `SoupCarry3D`），確認場景檔只有一份 `SoupCarry.tscn`，非兩套並存，矩陣以此為準。

---

## 缺口清單

**無。** 27 格資產全部存在（每格 49–61 幀 PNG + audio.ogg），9 款小遊戲的 `minigame_id()`
回傳值與過場目錄命名（`minigame_<id>_intro/win/lose`）逐一核對一致，且全部 9 支 `_end()`/結算函式
都呼叫共用的 `MinigameBase.show_result_panel()`，該函式內建呼叫 `_play_end_cutscene()`
（`MinigameBase.gd:98-100`），所以「掛在共用基底」這件事本身就保證全部套上，不需要每款另外接線。

開場（intro）同理是掛在 `SceneRouter.go_to_minigame()`（`SceneRouter.gd:201-212`）這一個入口，
所有目前已知的啟動路徑都會經過它：
- `MapScreen.gd:263/265/271/273/275`（地圖上直接點小遊戲入口）
- `QuestManager.gd:87`（支線 `trigger_minigame`）
- `JobApp.gd:44`（105 打工）
- `UndergroundParlor.gd:85`（地下遊藝場房間內的賭具）

`TestMinigameCutscene.gd` 於 2026-07-07 當天新增了第 8a／8b 兩項測試，專門針對「支線與打工路徑
是否繞過開場短片」這個歷史疑慮做實測（見該檔案第 15 行註解：「2026-07-07 使用者回饋：這兩條路徑
曾繞過開場短片」），目前這兩項測試都通過——代表這個疑慮已經被抓到並修掉。實跑 headless
（`Godot_v4.5-stable_win64_console.exe --headless --path D:\monk\MONK res://test/TestMinigameCutscene.tscn`）
輸出 `MINIGAME_CUTSCENE_TEST: ALL PASS`，exit code 0。

**唯一值得標記但不算「缺口」的觀察**：`git status` 顯示 `src/screens/Minigames/*.gd`（Batting、
BeggarChallenge、Blackjack、Bowling、Darts、OfferingToss、Roulette、WoodenFishRhythm 共 8 個檔）
與 `LayoutTuner.gd` 目前有未提交的本地修改（推測是佈局工具 v2/v3 相關，見記憶
`project_layout_tuner.md`），本次盤點的程式讀取都是讀「目前工作目錄的最新版本」（含這些未提交修改），
過場接線本身不受影響——但如果之後要 commit，記得這批連動修改也要一起處理，不是本報告範圍。

---

## 現行「結束流程」逐步說明

從小遊戲內呼叫結束到玩家回到哪個畫面，完整鏈路如下（以任一小遊戲的 `_end()` 為例，機制對 9 款一致）：

1. **小遊戲內部判定回合結束**，呼叫自己的 `_end()`（例：`WoodenFishRhythm.gd:351`），組出 `result: Dictionary`
   （`{id, score, win, gold, merit, karma}`，見 `MinigameBase.gd:7-9` 契約），呼叫
   `show_result_panel(title, rating, rows, result, leave_label)`。

2. **`MinigameBase.show_result_panel()`**（`MinigameBase.gd:98`）：
   - 若 `suppress_end_cutscene == false`（真正遊戲流程的預設值，`MinigameBase.gd:84`），先
     `await _play_end_cutscene(result)`（`MinigameBase.gd:100`）。
   - `_play_end_cutscene()`（`MinigameBase.gd:55-63`）依 `result.win` 組出
     `minigame_<id>_win` 或 `minigame_<id>_lose`，呼叫
     `SceneRouter.play_minigame_cutscene(clip_id)`（`SceneRouter.gd:149`），**播完（或被玩家點滑鼠/按鍵跳過）
     後停在最後一幀**，回傳 `overlay: CanvasLayer`。
   - 緊接著 `await SceneRouter.dismiss_minigame_cutscene(overlay)`（`SceneRouter.gd:186`）：
     0.3 秒淡出後把 overlay `queue_free()`，過場正式移除。
   - **過場移除之後**（`_close_result_panel()` 接著執行，`MinigameBase.gd:101`），才建立
     結算面板（`CanvasLayer` layer=100，`MinigameBase.gd:107-184`）：標題、評級大字、明細列、
     「再玩一次」與「離開」（或自訂 `leave_label`，如 21 點用「離開賭桌」）兩顆按鈕。
   - 若缺過場素材（`ResourceLoader.exists` 判斷失敗，`SceneRouter.gd:151`）或沒有 SceneRouter
     autoload（純測試環境），`play_minigame_cutscene` 立即回傳 `null`，`dismiss` 對 `null` 安全
     不做事（`SceneRouter.gd:187`），結算面板照常直接出現，不會被卡住。

3. **玩家在結算面板二選一**：
   - **「再玩一次」**（`MinigameBase._on_result_restart`，`MinigameBase.gd:272-275`）：
     關閉面板、發 `result_panel_restart` 訊號、呼叫子類覆寫的 `restart()`
     （9 款皆有各自實作，例：`WoodenFishRhythm.gd:364`）歸零計分重開一局。
     **不呼叫 `finish()`，不套用任何獎勵，不切場景，不會再播 intro 短片**
     （intro 只掛在 `SceneRouter.go_to_minigame` 這個「進場」入口，restart 走的是另一條路徑，
     天然不會重播）。這就是使用者記憶中「木魚可重試」的現成機制，且已推廣到全部 9 款。
   - **「離開」**（`MinigameBase._on_result_leave`，`MinigameBase.gd:277-281`）：
     關閉面板、發 `result_panel_leave` 訊號、呼叫 `finish(result)`（`MinigameBase.gd:33`）
     → `SceneRouter.finish_minigame(r)`（`SceneRouter.gd:221`）：
     依 `result` 套用 intrinsic 獎勵（gold/merit/karma）＋支線 `quest_win`/`quest_lose` 獎勵，
     發 `minigame_finished` 訊號（給 `QuestManager` 等監聽端推進劇情），最後依
     `context.return_scene` 回原 3D 場景（如地下遊藝場房間，`SceneRouter.gd:239-243`），
     沒帶 `return_scene` 則回城市地圖 `go_to_map()`（`SceneRouter.gd:24`）。

**目前「再玩一次」機制的現況**（回應使用者「想把 win/lose 播完停最後一幀→跳出重試視窗」的改版意圖）：
**這個機制已經是現行流程，不是要新建的東西**——win/lose 短片播完（或跳過）停最後一幀、
過場淡出移除、結算面板（含「再玩一次」＋「離開」兩顆按鈕）疊上，這條鏈路已經是全部 9 款
小遊戲共用的既有行為，且有 `TestMinigameCutscene.gd` 第 6 項測試（`_test_result_panel_waits_for_end_cutscene`）
和 `TestResultPanel.tscn`（headless 跑通，exit 0）分別驗證播放/移除時序與面板行為。
若使用者要的是「跳出獨立的重試視窗」（不同於現在疊在同一個結算面板上的按鈕），
這是 UI 呈現形式的改動意圖，不是「接線缺口」——目前的結算面板本身就同時承擔
「顯示戰績」與「重試/離開選擇」兩個角色，尚未拆成两個獨立畫面。

---

## 意外發現

1. `TestMinigameCutscene.gd` 第 8a／8b 測試的檔頭註解直接寫出「2026-07-07 使用者回饋：這兩條路徑
   曾繞過開場短片」——這代表使用者的懷疑**曾經是真的**，但已經在今天稍早的工作中被發現並修正
   （測試現在通過）。這解釋了使用者「懷疑還沒接上」的直覺來源：懷疑可能基於修正前的記憶或印象。
2. `Blackjack.gd` 裡有兩個容易混淆的函式：`show_result_panel`（`:391`，真正的結尾結算，觸發過場）
   與 `_show_result_panel`（`:611`，內部命名相近但是不同東西，是牌局中途的提示，不觸發過場）。
   命名相似但職責不同，未來若要重構「結束流程」要注意別誤改到 `:611` 那個。
3. `SoupCarry` 只有一份場景/腳本（`SoupCarry.gd` + `SoupCarry.tscn`），沒有找到獨立的 `SoupCarry3D`
   檔案——使用者在任務描述提到「SoupCarry（或 SoupCarry3D）」，盤點時特別搜過 `find . -iname
   "*soupcarry3d*"`／`find . -iname "*soup_carry_3d*"` 均無結果，確認是同一份，不是缺漏。
4. 除小遊戲過場外，`assets/cutscenes/` 目錄下還有 12 神開場（`zeus_intro` 等）與主線過場
   （`ch1_ares`、`ending_true` 等），這些不在本次盤點範圍（任務只要求 9 款小遊戲），列出僅供
   佐證目錄結構完整、沒有命名衝突。

---

## 搜過的目錄與 pattern（供交叉核對，證明非漏找）

- `find assets/cutscenes -maxdepth 1 -type d`（列出全部 46 個過場目錄，其中 27 個是 `minigame_*`）
- 對每個 `minigame_*` 目錄跑 `find "$d" -maxdepth 1 -iname "frame_*.png" | wc -l` 與
  `-iname "audio.ogg" | wc -l` 逐一清點幀數與音訊
- `grep -n "func minigame_id"` / `grep -n "show_result_panel("` / `grep -n "func restart"`
  掃過 `src/screens/Minigames/*.gd` 全部 9 支腳本 + `MinigameBase.gd`
- `grep -n "func go_to_minigame\|func play_minigame_cutscene\|func dismiss_minigame_cutscene\|func finish_minigame"`
  掃過 `src/` 全目錄，確認只有 `SceneRouter.gd` 一處定義
- `grep -n "go_to_minigame("` 掃過 `src/` 全目錄，找出全部 4 個呼叫端檔案
  （MapScreen.gd／QuestManager.gd／JobApp.gd／UndergroundParlor.gd）
- 實跑 headless 測試：`TestMinigameCutscene.tscn`（9 項子測試全過）、`TestResultPanel.tscn`（過）
