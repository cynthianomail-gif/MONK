# 開場醒來橋接 → 雨夜茶攤（無縫）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除 ch1 開場敘事斷尾——昏厥黑屏 → 圓形睜眼醒來 → 落在雨夜茶攤 → 了塵整場對話（c1_aftermath＋c1_intel）都疊在茶攤背景上 → 講完才走入雨中回地圖，全程不露街景。

**Architecture:** 在 `MainQuestManager` 加「cinematic hold」概念：被標 `hold` 的過場播完**不回地圖**，把最後一格凍結當背景供緊接的對話 overlay；整段 cinematic 鏈結束（第一個無 `hold` 的 stage 收尾）才 `go_to_map`。回地圖決策抽成兩個**純函式**以便 headless 單測。資料層只動 `ch01_ares` 前兩 stage 與新增一段醒來過場；dtl 與 SceneRouter/StoryCutscene 零改（只用既有 `eye_open`/`groggy`/`next_scene==""` 能力）。

**Tech Stack:** Godot 4.5 / GDScript；資料驅動 JSON（`data/cutscenes.json`、`data/main_quests.json`）；Dialogic 2 對話；自製 headless 測試場景（`test/TestCh1Expansion.tscn`）。

**關聯 spec:** `MONK/docs/superpowers/specs/2026-06-17-ch1-opening-wakeup-design.md`

---

## 前置慣例（每個 task 都適用）

**專案不在 git 下**（spec §備註）。因此本計畫**不含 git commit 步驟**；每個 task 的「收尾」改為跑完整 headless 測試套件並確認 `CH1_EXPANSION_TEST: ALL PASS`。

**測試跑法（標準指令，全計畫共用）：**

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestCh1Expansion.tscn
```

判定標準：輸出含 `CH1_EXPANSION_TEST: ALL PASS`。
（headless teardown 退碼非 0 屬引擎 bug，以印出的字串為準，不看 exit code。）

**編輯器 parse 檢查（資料/腳本改動後）：**

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" --editor --quit
```

判定標準：無 `SCRIPT ERROR` / `Parse Error` / JSON 解析錯誤輸出。

---

## File Structure

| 檔案 | 動作 | 責任 |
|------|------|------|
| `data/cutscenes.json` | 修改 | 新增 `ch1_aftermath_wake` 過場資料（黑淡入 → 圓形睜眼揭茶攤）。 |
| `data/main_quests.json` | 修改 | `c1_demolition` 加 `hold`；`c1_aftermath` 加 `cutscene`+`hold`。`c1_intel` 不動。 |
| `src/systems/MainQuestManager.gd` | 修改 | 新增兩純函式 `cutscene_return_to_map` / `should_return_to_map_after`；新增 `_on_cinematic_backdrop` 成員；`_play_cutscene` 加 `return_to_map` 參數；`_run_stage` 用純函式決策。 |
| `test/TestCh1Expansion.gd` | 修改 | 新增 `_test_opening_wakeup()`：過場資料存在、hold 接線、回地圖決策表；於 `_ready` 呼叫。 |
| `assets/cutscenes/ch1_aftermath_wake/tea_stall.jpg` | 新增（美術，可後補） | 雨夜茶攤背景圖；缺圖時 StoryCutscene 安全顯示黑底。 |

**不動：** `dialogue/main_ch1_aftermath.dtl`、`dialogue/main_ch1_intel.dtl`、`src/autoloads/SceneRouter.gd`、`StoryCutscene`、ch2–12 所有 stage。

---

## Task 1: 新增醒來過場資料 `ch1_aftermath_wake`

新增一段輕量 2 鏡過場：shot1 承接開場結尾的黑（fade_in）、shot2 圓形睜眼揭示茶攤。先寫測試確認資料存在且 `shots` 非空。

**Files:**
- Modify: `data/cutscenes.json`（在 `ares_intro` 之後新增一個 key）
- Test: `test/TestCh1Expansion.gd`（新增 `_test_opening_wakeup()` 的第一段）

- [ ] **Step 1: 寫失敗測試 — 過場資料存在**

在 `test/TestCh1Expansion.gd` 檔尾（`_smoke_phone_menu` 之後）新增函式：

```gdscript
func _test_opening_wakeup() -> void:
	# --- 醒來過場資料存在 ---
	var cuts: Dictionary = JsonLoader.load_json("res://data/cutscenes.json")
	var wake: Dictionary = cuts.get("ch1_aftermath_wake", {})
	_check(not wake.is_empty(), "ch1_aftermath_wake 過場存在")
	_check((wake.get("shots", []) as Array).size() > 0, "ch1_aftermath_wake shots 非空")
```

並在 `_ready()` 的 `_test_new_dialogues()` 之後加一行呼叫：

```gdscript
	_test_new_dialogues()
	_test_opening_wakeup()
```

- [ ] **Step 2: 跑測試確認失敗**

Run（標準測試指令，見前置慣例）。
Expected: 輸出含 `FAIL: ch1_aftermath_wake 過場存在` 與 `FAIL: ch1_aftermath_wake shots 非空`，結尾 `CH1_EXPANSION_TEST: HAS FAILURES`。

- [ ] **Step 3: 在 `data/cutscenes.json` 新增過場資料**

在 `ares_intro` 物件結尾的 `}` 後補逗號，於 `}`（檔案最外層收尾）之前新增：

```jsonc
  },

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

注意：原本 `ares_intro` 區塊的收尾是 `  }\n}`；改成 `ares_intro` 收尾 `  },`（加逗號）→ 新區塊 → 最後 `}`。確保整檔仍是合法 JSON（無尾逗號）。

- [ ] **Step 4: 跑測試確認通過**

Run（標準測試指令）。
Expected: 不再出現上述兩條 FAIL；其餘既有斷言維持，結尾 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 5: 跑編輯器 parse 檢查**

Run（編輯器 parse 檢查指令，見前置慣例）。
Expected: 無 JSON 解析錯誤。

---

## Task 2: `main_quests.json` 接 hold（c1_demolition / c1_aftermath）

讓開場過場與醒來過場標 `hold` 不回地圖；`c1_aftermath` 掛上新過場與既有對話。先寫資料層斷言。

**Files:**
- Modify: `data/main_quests.json`（`ch01_ares.stages` 前兩個 stage）
- Test: `test/TestCh1Expansion.gd`（`_test_opening_wakeup()` 續寫 hold 接線段）

- [ ] **Step 1: 寫失敗測試 — hold 接線**

在 `_test_opening_wakeup()` 末尾（Task 1 寫的兩行 `_check` 之後）續加：

```gdscript
	# --- main_quests hold 接線 ---
	var raw: Dictionary = JsonLoader.load_json("res://data/main_quests.json")
	var stages: Array = raw.get("ch01_ares", {}).get("stages", [])
	var by_id: Dictionary = {}
	for s in stages:
		by_id[String(s.get("id", ""))] = s
	_check(bool(by_id.get("c1_demolition", {}).get("hold", false)), "c1_demolition 帶 hold")
	var aft: Dictionary = by_id.get("c1_aftermath", {})
	_check(bool(aft.get("hold", false)), "c1_aftermath 帶 hold")
	_check(String(aft.get("cutscene", "")) == "ch1_aftermath_wake", "c1_aftermath cutscene=ch1_aftermath_wake")
	_check(String(aft.get("dialogue", "")) == "main_ch1_aftermath", "c1_aftermath 仍有 main_ch1_aftermath 對話")
	_check(not by_id.get("c1_intel", {}).has("hold"), "c1_intel 無 hold")
```

- [ ] **Step 2: 跑測試確認失敗**

Run（標準測試指令）。
Expected: 輸出含 `FAIL: c1_demolition 帶 hold`、`FAIL: c1_aftermath 帶 hold`、`FAIL: c1_aftermath cutscene=ch1_aftermath_wake`，結尾 `HAS FAILURES`。
（`c1_aftermath 仍有 main_ch1_aftermath 對話` 與 `c1_intel 無 hold` 此刻應已 PASS——它們驗證的是不變量。）

- [ ] **Step 3: 改 `data/main_quests.json` 前兩 stage**

`c1_demolition` 原行：

```json
      {"id": "c1_demolition", "desc": "破廟遭強拆、舍利塔被奪走。", "cutscene": "opening_temple_falls", "set_flag": "relic_stolen"},
```

改為（加 `"hold": true`）：

```json
      {"id": "c1_demolition", "desc": "破廟遭強拆、舍利塔被奪走。", "cutscene": "opening_temple_falls", "hold": true, "set_flag": "relic_stolen"},
```

`c1_aftermath` 原行：

```json
      {"id": "c1_aftermath", "desc": "落魄進城，雨夜茶攤遇斷臂修練者了塵；他道破萬神殿，並一一引介十二主神。", "dialogue": "main_ch1_aftermath"},
```

改為（加 `"cutscene": "ch1_aftermath_wake"` 與 `"hold": true`，保留既有 `dialogue`）：

```json
      {"id": "c1_aftermath", "desc": "落魄進城，雨夜茶攤遇斷臂修練者了塵；他道破萬神殿，並一一引介十二主神。", "cutscene": "ch1_aftermath_wake", "hold": true, "dialogue": "main_ch1_aftermath"},
```

`c1_intel`、其餘 stage、章節 metadata **不動**。

- [ ] **Step 4: 跑測試確認通過**

Run（標準測試指令）。
Expected: 新增 5 條 hold 斷言全 PASS；既有 `ch1 有 9 stage`、`stage id 順序正確`、`仍有 opening_temple_falls`、`complete_flag 仍 ares_purified` 維持 PASS；結尾 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 5: 跑編輯器 parse 檢查**

Run（編輯器 parse 檢查指令）。
Expected: 無 JSON 解析錯誤。

---

## Task 3: MainQuestManager 純函式 + 回地圖決策表測試

把「該不該回地圖」抽成兩個無副作用純函式，headless 直接斷言決策表（`go_to_map` 本身有場景切換副作用，headless 難斷言，故抽純函式）。

**兩函式語意：**
- `cutscene_return_to_map(stage)` → `_play_cutscene` 的 `return_to_map` 值＝`not (hold or 有 dialogue)`。held、或同 stage 後面還有 dialogue 要疊 → 不回地圖。
- `should_return_to_map_after(stage, on_cinematic_backdrop)` → stage 收尾該不該回地圖＝`(not hold) and on_cinematic_backdrop`。

**Files:**
- Modify: `src/systems/MainQuestManager.gd`（新增兩純函式 + `_on_cinematic_backdrop` 成員）
- Test: `test/TestCh1Expansion.gd`（`_test_opening_wakeup()` 續寫決策表段）

- [ ] **Step 1: 寫失敗測試 — 回地圖決策表**

在 `_test_opening_wakeup()` 末尾（Task 2 的 hold 斷言之後，沿用同一個 `by_id` / `aft` 變數）續加：

```gdscript
	# --- 回地圖決策表（純函式，無副作用） ---
	var m := MainQuestManager
	# cutscene-only 未 held：過場後回地圖、收尾不回（同現行）
	var cs_only := {"id": "x", "cutscene": "foo"}
	_check(m.cutscene_return_to_map(cs_only) == true, "cutscene-only 未 held → 過場後回地圖")
	_check(m.should_return_to_map_after(cs_only, false) == false, "cutscene-only 未 held → 收尾不回")
	# c1_demolition(hold)：過場不回、收尾仍 held
	_check(m.cutscene_return_to_map(by_id["c1_demolition"]) == false, "c1_demolition 過場不回地圖")
	_check(m.should_return_to_map_after(by_id["c1_demolition"], true) == false, "c1_demolition 收尾仍 held")
	# c1_aftermath(hold+dialogue)：過場不回、收尾仍 held
	_check(m.cutscene_return_to_map(aft) == false, "c1_aftermath 過場不回地圖")
	_check(m.should_return_to_map_after(aft, true) == false, "c1_aftermath 收尾仍 held")
	# c1_intel(無 hold，承 held)：收尾回地圖
	_check(m.should_return_to_map_after(by_id["c1_intel"], true) == true, "c1_intel 收尾回地圖")
	# dialogue-only 未 held 未承 cinematic：收尾不回（不會每段對話重載地圖）
	var dlg_only := {"id": "y", "dialogue": "bar"}
	_check(m.should_return_to_map_after(dlg_only, false) == false, "dialogue-only 未承 cinematic 收尾不回")
```

- [ ] **Step 2: 跑測試確認失敗**

Run（標準測試指令）。
Expected: 因 `cutscene_return_to_map` / `should_return_to_map_after` 尚未定義，輸出 `SCRIPT ERROR` 或 `Invalid call. Nonexistent function 'cutscene_return_to_map'`，測試中止（不會印 ALL PASS）。

- [ ] **Step 3: 在 `MainQuestManager.gd` 新增成員與純函式**

於成員宣告區（`var _demo_last_chapter ...` 那行之後，約 line 17）新增：

```gdscript
var _on_cinematic_backdrop: bool = false   # 上一過場 held 住（凍結最後一格當對話背景，未回地圖）
```

於 `gate_passed()` 之前（約 line 108，純函式集中區）新增兩個純函式：

```gdscript
## 此 stage 的過場播完是否該回地圖（= _play_cutscene 的 return_to_map 值）。
## held、或同 stage 後面還有 dialogue 要疊在過場上 → 不回地圖。純函式，供測試。
func cutscene_return_to_map(stage: Dictionary) -> bool:
	return not (bool(stage.get("hold", false)) or stage.has("dialogue"))

## 此 stage 收尾是否該回地圖：非 held 且目前正掛在 cinematic 背景上（承接 held 鏈）。
## 純函式，供測試。
func should_return_to_map_after(stage: Dictionary, on_cinematic_backdrop: bool) -> bool:
	return (not bool(stage.get("hold", false))) and on_cinematic_backdrop
```

- [ ] **Step 4: 跑測試確認通過**

Run（標準測試指令）。
Expected: 7 條決策表斷言全 PASS；結尾 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 5: 跑編輯器 parse 檢查**

Run（編輯器 parse 檢查指令）。
Expected: 無 `SCRIPT ERROR` / `Parse Error`。

---

## Task 4: 接線 MainQuestManager 執行期（_play_cutscene + _run_stage）

把純函式接進實際播放流程：`_play_cutscene` 依 `return_to_map` 決定播完回不回地圖；`_run_stage` 用 `cutscene_return_to_map` 決定過場、收尾用 `should_return_to_map_after` 決定整段 cinematic 是否落幕回地圖。此 task 改的是有副作用的 async 路徑（場景切換），headless 難直接斷言 `go_to_map`，正確性由 Task 3 決策表測試 + 既有回歸斷言守住，實機節奏於 Task 5 人工抽驗。

**Files:**
- Modify: `src/systems/MainQuestManager.gd`（`_play_cutscene` 簽章與本體、`_run_stage` 的 cutscene 分支與收尾）

- [ ] **Step 1: 改 `_play_cutscene` 加 `return_to_map` 參數**

原本（約 line 141）：

```gdscript
func _play_cutscene(id: String) -> void:
	await SceneRouter.play_story_cutscene(id, "")
	await SceneRouter.go_to_map()  # 結束後回地圖當中性 hub，供下一 stage 的對話/操作
```

改為：

```gdscript
func _play_cutscene(id: String, return_to_map: bool = true) -> void:
	await SceneRouter.play_story_cutscene(id, "")
	if return_to_map:
		await SceneRouter.go_to_map()  # 結束後回地圖當中性 hub，供下一 stage 的對話/操作
	else:
		_on_cinematic_backdrop = true  # held：凍結最後一格當背景，整段 cinematic 結束才回地圖
```

- [ ] **Step 2: 改 `_run_stage` 的 cutscene 分支與收尾**

`_run_stage` 內，cutscene 分支原本（約 line 127）：

```gdscript
	if stage.has("cutscene"):
		await _play_cutscene(String(stage.cutscene))
```

改為：

```gdscript
	if stage.has("cutscene"):
		await _play_cutscene(String(stage.cutscene), cutscene_return_to_map(stage))
```

`_run_stage` 結尾原本（約 line 137-139）：

```gdscript
	if stage.has("set_flag"):
		GameManager.set_flag(String(stage.set_flag), true)
	return true
```

改為（在 `return true` 前插入收尾回地圖判斷）：

```gdscript
	if stage.has("set_flag"):
		GameManager.set_flag(String(stage.set_flag), true)
	# 整段 cinematic 鏈落幕：第一個非 held 的 stage（如 c1_intel）收尾，把 held 茶攤換回地圖。
	if should_return_to_map_after(stage, _on_cinematic_backdrop):
		await SceneRouter.go_to_map()
		_on_cinematic_backdrop = false
	return true
```

- [ ] **Step 3: 跑測試確認回歸全綠**

Run（標準測試指令）。
Expected: 結尾 `CH1_EXPANSION_TEST: ALL PASS`。既有斷言（ch1 九 stage、gate type/min、gate_passed、aftermath signal≥12、各 dtl 解析、intel app/phone smoke）與本案新增斷言皆 PASS。

- [ ] **Step 4: 跑編輯器 parse 檢查**

Run（編輯器 parse 檢查指令）。
Expected: 無 `SCRIPT ERROR` / `Parse Error`。

- [ ] **Step 5: 逐型推演自查（不需跑、紙上核對，確認無回歸）**

對照 spec §架構「為何不回歸既有行為」，核對改後行為：

| stage 型態 | `cutscene_return_to_map` | 過場後 | 收尾 `should_return_to_map_after` | 結果 |
|---|---|---|---|---|
| cutscene-only 未 held（如 c1_ares_intro） | `not(false or false)=true` | 回地圖、`_on_cinematic_backdrop` 維持 false | `not(false) and false=false` | 同現行，無重複 go_to_map ✓ |
| dialogue-only 未 held 未承 cinematic（如 c2_lead） | n/a（無 cutscene） | — | `false`（backdrop=false） | 對話疊地圖、不重載 ✓ |
| cutscene+boss（如 c2_boss / c1_ares_intro→c1_ares） | `true` | 過場後回地圖再進戰鬥 | `false` | 同現行 ✓ |
| c1_demolition(hold) | `false` | 不回、backdrop=true、set_flag 照常 | `not(true) and true=false` | held ✓ |
| c1_aftermath(hold+dialogue) | `false` | 不回、backdrop=true、對話疊 held 茶攤 | `false` | held ✓ |
| c1_intel(無 hold，承 held) | n/a | — | `not(false) and true=true` | go_to_map（走入雨中）、清 backdrop ✓ |

確認：gate fail / battle loss 走 `return false` 早退，跳過收尾 go_to_map——而 ch1 的 held stage（c1_demolition/c1_aftermath）皆無 gate/battle，不會在 held 狀態下早退，`_on_cinematic_backdrop` 不會洩漏（spec §風險已接受此邊界）。

---

## Task 5: 美術資產佔位 + 實機 GPU 人工抽驗

接線可缺圖（StoryCutscene 缺圖安全顯示黑底）。本 task 建立資產資料夾佔位、並列出實機抽驗清單（人工，列入收尾）。

**Files:**
- Create: `assets/cutscenes/ch1_aftermath_wake/`（資料夾；`tea_stall.jpg` 正式圖以 magnific 產出後抽換）

- [ ] **Step 1: 建立資產資料夾**

```powershell
New-Item -ItemType Directory -Force "D:\monk\MONK\assets\cutscenes\ch1_aftermath_wake"
```

正式圖規格（交付美術 / magnific Nano Banana Pro，對齊 [[project-2d-map]] 定調）：
- 路徑：`assets/cutscenes/ch1_aftermath_wake/tea_stall.jpg`
- 內容：雨夜舊城區巷弄深處、昏黃燈下無招牌茶攤、桌上一盞燈與一碗熱茶；**構圖留出底部對話框空間**；**不要把了塵畫太顯眼**（了塵由 Dialogic 疊既有立繪 `npc_liaochen`，避免雙重）。
- 風格：21:9、半寫實厚塗、新梵市 noir 霓虹雨夜。
- 缺圖時 StoryCutscene 安全顯示黑底，先接線測通、美術後填。

- [ ] **Step 2: 實機 GPU 抽驗（人工，需 GUI 啟動，非 headless）**

啟動遊戲、從頭跑 ch1 開場（或從存檔 c1_aftermath resume），目視確認：

- [ ] 開場昏厥 5.5s 黑 → 醒來過場 `fade_in` 黑接黑**真無縫**（看不到轉場跳動）。
- [ ] 圓形睜眼（`eye_open`）揭示茶攤、`groggy` 恍惚感節奏自然（睜眼時長 / duration 4.5s 視觀感微調）。
- [ ] `main_ch1_aftermath` 旁白與 12 神 `[background <god>]` 逐張切、介紹完 `[background arg=""]` **露回 held 茶攤**（非露街景）。
- [ ] 若 Dialogic 起始背景非透明蓋住茶攤 → 於 `main_ch1_aftermath.dtl` 最前補一行 `[background arg=""]`（spec §對話檔唯一風險，僅在此情況才動 dtl）。
- [ ] `main_ch1_intel` 整段續疊 held 茶攤、講完 `go_to_map`（INK_SPLASH，走入雨中）切回地圖、無殘留 CutsceneScreen（無洩漏）。
- [ ] 對話框在茶攤圖上可讀（底部留空有效）。
- [ ] BGM `rain_street` 從開場結尾 -45 淡回 ~-9，雨聲銜接自然。

- [ ] **Step 3: 同步文件與記憶（spec §備註＋專案慣例：改動要同步 docs/memory）**

- 更新 `MONK/docs/PROJECT_STATUS`（或等效進度文件）：標記「開場醒來橋接已實作」。
- 更新記憶 `project_build_status.md`：ch1 開場斷尾已修復、新增 `ch1_aftermath_wake` 過場與 `tea_stall.jpg` 美術缺口（待 magnific 產圖）。
- 若 Step 2 實機發現需補 dtl `[background arg=""]`，一併記錄在 spec/plan 的「已知差異」。

---

## Self-Review

**1. Spec coverage**（逐節核對）：
- §架構 MainQuestManager hold（`_play_cutscene(return_to_map)` + `_on_cinematic_backdrop` + `_run_stage` 收尾）→ Task 3（純函式/成員）+ Task 4（接線）。✓
- §stage 接線（c1_demolition/c1_aftermath hold、c1_intel 不動）→ Task 2。✓
- §新增醒來過場 `ch1_aftermath_wake` → Task 1。✓
- §美術 tea_stall.jpg → Task 5。✓
- §音訊（沿用 rain_street，無新檔）→ Task 1 過場資料的 `bgm`/`bgm_db`/`bgm_fade` 已含，無獨立 task（YAGNI）。✓
- §對話檔 dtl 零改（唯一風險補 `[background arg=""]`）→ Task 5 Step 2 實機條件性處理。✓
- §測試（醒來過場存在、hold 接線、回地圖決策表、既有斷言回歸、--editor --quit）→ Task 1/2/3 斷言 + 每 task Step 5 parse 檢查。✓
- §風險／邊界（held×Dialogic z-order、resume、gate fail 不受影響、實機抽驗）→ Task 4 Step 5 推演 + Task 5 Step 2 抽驗。✓

**2. Placeholder scan:** 無 TBD/TODO/「實作細節後補」；所有 code step 含完整程式碼與確切指令、預期輸出。Task 5 的美術正式圖屬「可後補資產」非計畫佔位（spec 明示缺圖安全），已標明規格。✓

**3. Type consistency:** 兩純函式名 `cutscene_return_to_map` / `should_return_to_map_after` 在 Task 3 定義、Task 3 測試與 Task 4 接線一致引用；成員 `_on_cinematic_backdrop` 定義（Task 3）與讀寫（Task 4 `_play_cutscene`/`_run_stage`）一致；測試變數 `by_id`/`aft` 跨 Task 1→2→3 在同一函式 `_test_opening_wakeup()` 內累加、無重複宣告衝突（`aft` 於 Task 2 宣告、Task 3 沿用）。✓
