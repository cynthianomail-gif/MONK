# 開場醒來橋接 → 雨夜茶攤（無縫）設計 spec

日期：2026-06-17
關聯：[[project-build-status]]、[[project-monk-game]]、[[project-2d-map]]；既有 spec `2026-06-15-ch1-ares-expansion-design.md`（ch1 九 stage 結構）。

## 願景與範圍

消除 ch1 開場的敘事斷尾：目前開場過場 `opening_temple_falls` 結束在「無戒昏厥 → 5.5 秒純黑（雨聲淡出）」，接著 `MainQuestManager._play_cutscene` 直接 `go_to_map()`（硬切城市地圖），然後 `c1_aftermath` 的了塵茶攤對話以 Dialogic overlay 疊在空地圖上。問題＝**昏厥黑屏 → 硬切街景地圖 → 對話**中間沒有「醒來」銜接，茶攤也沒有專屬畫面（旁白描述很有畫面，玩家卻看到街景）。

改成：**昏厥 → 圓形睜眼醒來 → 落在雨夜茶攤 → 了塵整場對話（介紹 12 神 ＋ 聚焦阿瑞斯 ＋ 傳羅漢拳）都在茶攤背景上 → 講完走入雨中（回地圖去歷練）。全程不露街景。**

**範圍邊界（拍板）：**
- 茶攤背景涵蓋 `c1_aftermath`（12 神介紹）＋ `c1_intel`（聚焦阿瑞斯＋傳羅漢拳）兩 stage；`c1_intel` 跑完才 `go_to_map`。
- `c1_armory_gate`（驗修為，會 fail→中止回地圖）**之後**才發生，在地圖上，沿用既有 gate fail→回地圖行為（不納入茶攤，避免 gate fail 的收尾複雜度）。
- 醒來分量＝**輕量**：黑屏淡入 → 圓形睜眼 → 落茶攤定格，~2 鏡，不做「走了一夜」蒙太奇。
- 不改 ch2–12 任何 stage 行為（DEMO 只做 ch1）。

## 現況（已探查確認）

- `data/main_quests.json` `ch01_ares.stages`：`c1_demolition`(cutscene=opening_temple_falls, set_flag=relic_stolen) → `c1_aftermath`(dialogue=main_ch1_aftermath) → `c1_intel`(dialogue=main_ch1_intel) → `c1_armory_gate`(gate) → …
- `data/cutscenes.json` `opening_temple_falls` 結尾 shot＝`{"black": true, "duration": 5.5, "bgm_db": -45, "bgm_fade": 1.6}`（昏厥長黑、雨聲淡出）。
- `MainQuestManager._play_cutscene(id)`：`await play_story_cutscene(id, "")` 然後 `await go_to_map()`（每段過場後都回地圖當中性 hub）。
- `MainQuestManager._run_stage(stage)`：依序處理 gate → cutscene → dialogue → battle → boss → set_flag。
- `SceneRouter.play_story_cutscene(id, next_scene)`：`next_scene==""` 播完留在 CutsceneScreen（不切場景）；`"map"` 回地圖；其他非空字串＝串接下一段過場。場景切換經 `_change_scene`（過場用 FADE_BLACK、地圖用 INK_SPLASH）。
- `StoryCutscene`：`_unhandled_input` 只在 `_playing` 為真時吃 confirm/cancel 跳過鍵；`_finish()` 設 `_playing=false`、`_done=true` 並 `finished.emit()`，**不 queue_free**（場景留著顯示最後一格）。已具備圓形睜眼 `eye_open` 與半昏迷 `groggy` 機制（開場昏厥用的圓形閉眼即同套）。
- `main_ch1_intel.dtl`：**零個 `[background]` 事件**（純旁白＋了塵＋2 選分支＋signals armory_known/ch1_help_side/skill:arhat_strike），開頭已寫「天快亮時，雨小了些。了塵用唯一的右手畫地圖」＝接著茶攤。
- `main_ch1_aftermath.dtl`：12 神段落用 `[background <god>.jpg]` 逐張切、介紹完 `[background arg=""]`（透明，原意「收回露地圖」）。

## 架構：MainQuestManager 加「cinematic hold」

核心＝讓某些過場**播完不回地圖**，把最後一格凍結當背景，供緊接的對話 overlay；整段 cinematic 結束才回地圖。

**改動：**
1. `_play_cutscene(id: String, return_to_map: bool = true)` 加參數：
   - `return_to_map == true`（預設，等同現行）：`await play_story_cutscene(id, "")` → `await go_to_map()`。
   - `return_to_map == false`：`await play_story_cutscene(id, "")` → **不 go_to_map**；設 `_on_cinematic_backdrop = true`。
2. 新增成員 `var _on_cinematic_backdrop: bool = false`。`go_to_map` 經過的路徑（在 `_run_stage` 收尾呼叫）會清掉它。
3. `_run_stage(stage)` 調整：
   - 讀 `var hold := bool(stage.get("hold", false))`。
   - cutscene：`await _play_cutscene(String(stage.cutscene), not (hold or stage.has("dialogue")))`
     （held、或同 stage 後面還有 dialogue 要疊 → 不回地圖）。
   - dialogue / battle / boss / set_flag：維持現行順序與行為。
   - stage 收尾：`if not hold and _on_cinematic_backdrop: await SceneRouter.go_to_map(); _on_cinematic_backdrop = false`。

**為何不回歸既有行為（已逐型推演）：**
- cutscene-only、`hold` 未設、無 dialogue：`return_to_map = not(false or false) = true` → 播完回地圖（同現行）；`_on_cinematic_backdrop` 維持 false，收尾不重複 go_to_map。
- dialogue-only、無 cutscene、未 held：`_on_cinematic_backdrop` 為 false → 對話疊在地圖、收尾不 go_to_map（**不會每段對話重載地圖**，同現行）。
- cutscene+boss（如 c2_boss / c1_ares_intro→c1_ares）：cutscene `return_to_map = not(false or false)=true` → 過場後回地圖再進戰鬥（同現行）。
- 只有被標 `hold` 的 cinematic 鏈（本案 c1_demolition / c1_aftermath）行為改變。

## stage 接線（`data/main_quests.json`，只動 ch1 前兩 stage）

- `c1_demolition`：新增 `"hold": true`。
  → 開場過場 `opening_temple_falls` 播完（停在 5.5s 黑）**不回地圖**，`_on_cinematic_backdrop=true`。`set_flag: relic_stolen` 照常（在 cutscene 之後）。
- `c1_aftermath`：新增 `"cutscene": "ch1_aftermath_wake"` ＋ `"hold": true`（保留既有 `"dialogue": "main_ch1_aftermath"`）。
  → 醒來過場以 `_change_scene(STORY_CUTSCENE, FADE_BLACK)` 進場＝**黑接黑、轉場不可見**（接上一個 held 黑屏）→ 圓形睜眼揭示茶攤 → 不回地圖 → `main_ch1_aftermath` 對話疊在 held 茶攤 → 因 hold，收尾仍不回地圖。
- `c1_intel`：**不動**（無 `hold`、無 `cutscene`）。
  → 對話疊在仍 held 的茶攤 CutsceneScreen 上 → 收尾 `not hold and _on_cinematic_backdrop=true` → `go_to_map()`（INK_SPLASH，走入雨中、去歷練），清 `_on_cinematic_backdrop`。`go_to_map` 的 `_change_scene` 會把 held CutsceneScreen 換成 MapScreen（自動釋放，無洩漏）。

## 新增醒來過場 `ch1_aftermath_wake`（`data/cutscenes.json`，輕量 2 鏡）

```jsonc
"ch1_aftermath_wake": {
  "bgm": "rain_street", "bgm_db": -9, "bgm_fade": 1.4,
  "shots": [
    {"black": true, "duration": 0.6, "fade_in": true},
    {"image": "res://assets/cutscenes/ch1_aftermath_wake/tea_stall.jpg", "duration": 4.5, "motion": "none", "eye_open": true, "groggy": true}
  ],
  "captions": [
    {"start": 0.9, "end": 4.2, "speaker": "", "text": "雨，沒有要停的意思。"}
  ]
}
```
- shot 1＝承接開場結尾的黑（fade_in）。
- shot 2＝圓形睜眼（`eye_open: true`，callback 開場昏厥的圓形閉眼）揭示茶攤；`groggy` 半昏迷恍惚感可選（與 05_lineup 同機制）。
- BGM＝`rain_street` 從開場結尾的 -45 淡回 ~-9（無新音檔）。
- duration/字幕秒數實作時依實機微調。

## 美術（1 張新圖）

- 檔案：`res://assets/cutscenes/ch1_aftermath_wake/tea_stall.jpg`（與過場 id 同名資料夾，沿用既有 `assets/cutscenes/<id>/` 慣例）。
- 內容：雨夜舊城區巷弄深處、昏黃燈下一座無招牌茶攤、桌上一盞燈與一碗熱茶；構圖**留出底部對話框空間**，且**不要把了塵畫太顯眼**（了塵用既有立繪 `assets/2d/portraits` 的 `npc_liaochen` 透過 Dialogic 疊上，避免雙重）。
- 風格：對齊 [[project-2d-map]] 定調＝magnific Nano Banana Pro、21:9、半寫實厚塗、新梵市 noir 霓虹雨夜。
- 先接線可缺圖：StoryCutscene 缺圖安全顯示黑底，正式圖以 export/路徑抽換。

## 音訊

沿用既有 `rain_street`；醒來過場靠 `bgm`+`bgm_db`+`bgm_fade` 把雨聲從開場結尾淡回。無新音檔。

> **實作後修正（2026-06-17）：** 經查 `StoryCutscene.gd`，cutscene **頂層**只讀 `bgm`+`bgm_db`（line 72，`switch_bgm` 淡入時間寫死 0.5s），**不讀頂層 `bgm_fade`**；`bgm_fade` 只在**鏡頭(shot)級**且該 shot 同時有 `bgm_db` 時才生效（line 163-164 `fade_bgm_to`）。故 `ch1_aftermath_wake` 頂層的 `bgm_fade: 1.4` 為死資料——雨聲仍會淡回 −9（功能成立），但實際淡入是 0.5s 而非 1.4s。若實機聽起來想要更緩的 1.4s 淡入，把 `bgm_db: -9, bgm_fade: 1.4` 移到某個 shot（例如黑幀 shot 0 或茶攤 shot 1）即可；目前保留頂層寫法（觀感由實機 GPU 抽驗時決定）。

## 對話檔（dtl）

- `main_ch1_aftermath.dtl`：**零改動**。開頭旁白疊在 held 茶攤；12 神 `[background <god>]` 覆蓋茶攤、介紹完 `[background arg=""]`（透明）露回 held 茶攤。
- `main_ch1_intel.dtl`：**零改動**。無 `[background]`，直接疊在仍 held 的茶攤。
- 唯一風險：若 Dialogic 起始背景非透明（會蓋住 held 茶攤），於 `main_ch1_aftermath.dtl` 最前補一行 `[background arg=""]`。實作時實機驗證後決定。

## 測試（擴充既有 headless 測試，不新建場景）

於 `test/TestCh1Expansion.tscn` / `test/TestMainQuest.tscn` 既有測試加：
- `ch1_aftermath_wake` 在 `cutscenes.json` 存在且 `shots` 非空。
- `c1_demolition` 帶 `hold==true`；`c1_aftermath` 帶 `hold==true` 且 `cutscene=="ch1_aftermath_wake"`、仍保有 `dialogue=="main_ch1_aftermath"`；`c1_intel` 無 `hold`。
- **回地圖決策抽成純函式可單測**：把 `_run_stage` 收尾「該不該回地圖」與 `_play_cutscene` 的 `return_to_map` 邏輯抽成輸入 stage dict（與 `_on_cinematic_backdrop` 狀態）回傳 bool 的純函式，headless 驗決策表（go_to_map 本身在 headless 難直接斷言）：
  - cutscene-only 未 held → cutscene return_to_map=true、收尾不回。
  - c1_demolition(hold) → cutscene return_to_map=false、收尾不回（held）。
  - c1_aftermath(hold+dialogue) → cutscene return_to_map=false、收尾不回（held）。
  - c1_intel(無 hold，承 held) → 收尾回地圖。
  - dialogue-only 未 held（未承 cinematic） → 收尾不回。
- 既有斷言（ch1 九 stage、gate type/min、gate_passed、aftermath signal≥12、各 dtl 解析）回歸 ALL PASS。
- `--editor --quit` 註冊新 cutscene 資料無 parse error。
- 跑法：`& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestCh1Expansion.tscn`（以印出的 `ALL PASS` 為準，headless teardown 退碼非 0 為引擎 bug）。

## 風險／邊界

- **held CutsceneScreen × Dialogic 的 z-order／`[background ""]` 透明度**＝實作時實機 GPU 驗（已從程式碼確認：`_finish` 後 `_playing=false` → 不搶輸入；Dialogic layout 為高層 CanvasLayer 疊於 current_scene 之上）。
- **resume 存檔停在 c1_aftermath**：`continue_story` 從 c1_aftermath 起跑，醒來過場以 FADE_BLACK 從地圖進場（非黑接黑，但仍是合理淡入），可接受。
- **gate fail 不受影響**：c1_armory_gate 在回地圖後才跑，沿用既有 fail→中止回地圖。
- **實機 GPU 抽驗**（人工，列入收尾）：醒來節奏（睜眼時長/groggy）、茶攤觀感、黑接黑是否真無縫、對話框在茶攤圖上的可讀性。

## 檔案清單

**新增：**
- `assets/cutscenes/ch1_aftermath_wake/tea_stall.jpg` — 雨夜茶攤背景圖（美術）。

**修改：**
- `data/cutscenes.json` — 新增 `ch1_aftermath_wake` 過場資料。
- `data/main_quests.json` — `c1_demolition` 加 `hold`；`c1_aftermath` 加 `cutscene`+`hold`。
- `src/systems/MainQuestManager.gd` — `_play_cutscene` 加 `return_to_map` 參數、新增 `_on_cinematic_backdrop`、`_run_stage` 處理 `hold` 與收尾回地圖、（建議）抽出可測的回地圖決策純函式。
- `test/TestCh1Expansion.gd`（或 TestMainQuest.gd） — 加上述斷言。

**不動：**
- `main_ch1_aftermath.dtl` / `main_ch1_intel.dtl`（除非實機發現 Dialogic 起始背景非透明，補一行 `[background arg=""]`）。
- ch2–12 所有 stage、SceneRouter、StoryCutscene 程式（只用既有 `eye_open`/`groggy`/`next_scene=""` 能力）。

## 備註

專案不在 git 下，故略過「commit 設計文件」步驟（與既有流程一致）。
