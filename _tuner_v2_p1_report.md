# 佈局工具 v2 P1（戰鬥畫面）實作報告

規格：`docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md`

## 改了/新增了哪些檔

1. **新增** `src/autoloads/LayoutStore.gd`（167 行）：資料 + 套用 + 存讀。
   - `register/unregister/apply_override/capture/apply_group/is_free/live_entries` 全數依 spec API 實作。
   - `save()`/`_load()` 走固定路徑 `res://_layout_overrides.json`；另外開了 `save_to_path(path)`/`load_from_path(path)`
     供測試寫 `user://` 暫存，不寫進 repo（`save()`/`_load()` 內部就是呼叫這兩個帶固定路徑）。
   - `register()` 用 `node.tree_exited.connect(...)` 做自動反登記（不用每 frame 輪詢）。
2. **project.godot**（第 33 行）：新增 `LayoutStore="*res://src/autoloads/LayoutStore.gd"`，排在 `LayoutTuner` 之前。
3. **升級** `src/autoloads/LayoutTuner.gd`（129 行 → 588 行）：
   - 保留原有 `_input` 攔截、整棵樹命中測試、拖曳/微調/右鍵循環，未retreat任何既有能力。
   - 新增：進調整模式 `_build_entry_boxes()`（第 198-218 行）一次畫出 `LayoutStore.live_entries()` 綠框 + 
     全樹掃描 `layout_template` meta 節點的琥珀框，`_process()`（第 274-278 行）每幀刷新框位置跟隨節點移動。
   - `_candidate_less`（第 431-438 行）加入 tracked 優先排序：已登記/已標註節點的命中優先於一般未登記節點。
   - `_can_drag_selection()`（第 325-328 行）+ 在 keyboard nudge（第 104 行）與 mouse motion（第 129 行）
     兩處加了守衛：琥珀（`free==false`）節點選中後 `_dragging` 直接為 false，不能拖/微調。
   - `_capture_if_registered()`（第 485-496 行）：`_set_pos()` 每次移動後，若選中節點是已登記自由塊，
     即時呼叫 `LayoutStore.capture()`（+ `apply_group`）。
   - `S`/`F9`（第 93-99 行）：改呼叫 `LayoutStore.save()`，不再寫 `_layout_tuning.json`。
     `save_tuning()` 函式本身保留（供未登記節點的舊式量測用，測試沿用它驗證 old_pos/new_pos/delta 記錄邏輯）。
   - `_refresh_info_card()`（第 280-299 行）：依 `_selected_entry` 狀態顯示「已登記可拖」／「樣板/容器改樣板調整」／
     「未登記不會存檔」三態文字。
4. **`src/screens/BattleScreen/BattleUI.gd`**：
   - 第 82 行 `_ready()` 尾端呼叫新增的 `_register_layout_tunables()`（第 84-95 行）。
   - 7 個 `LayoutStore.register(...)` 呼叫。注意 `PlayerPanel` 節點本身**沒有** `unique_name_in_owner`（scene 裡
     沒設，只有它底下的子節點如 PlayerName/PlayerHPBar 有），不能用 `%PlayerPanel`，改用 `get_node("PlayerPanel")`
     相對路徑取得（已修正並實測 GPU 截圖驗證 present=true）。
5. **`src/screens/BattleScreen/EnemyPanel.gd`**：
   - 第 79-81 行：`_hp_bar.set_meta("layout_template", "enemy/hp_bar")`。
   - 第 46-48 行：`_figure.set_meta("layout_template", "enemy/portrait")`。純標註，未改任何遊戲行為。
6. **新增** `test/TestLayoutStore.gd`（216 行）+ `test/TestLayoutStore.tscn`：單元測試涵蓋驗收條件 1。
7. **新增** `test/CaptureLayoutTunerBattle.gd`（99 行）+ `test/CaptureLayoutTunerBattle.tscn`：GPU 截圖驗證，
   涵蓋驗收條件 2、3、（間接示範 4 的即時 capture 部分）。

## 驗收條件逐條

**1. LayoutStore 單元測試全過** ── 通過。
`TestLayoutStore.gd` 5 個子測試（register/live_entries/反登記、is_free、Control capture-save-load-apply、
Node2D capture-save-load-apply、apply_group）全數斷言通過。
證據：`LAYOUT_STORE_TEST: ALL PASS`，exit=0（無 FAIL 行）。

**2. 戰鬥畫面登記正確（7 key，free==true）** ── 通過。
GPU 截圖測試印出：
```
LIVE_ENTRY_CHECK battle/player_figure -> present=true free=true
LIVE_ENTRY_CHECK battle/player_panel -> present=true free=true
LIVE_ENTRY_CHECK battle/enemy_area -> present=true free=true
LIVE_ENTRY_CHECK battle/command_host -> present=true free=true
LIVE_ENTRY_CHECK battle/skill_menu -> present=true free=true
LIVE_ENTRY_CHECK battle/combo_label -> present=true free=true
LIVE_ENTRY_CHECK battle/log_label -> present=true free=true
```
7 個 key 全數 present=true、free=true。

**3. 調整模式全框標註 + 綠拖琥珀擋（GPU 截圖）** ── 通過。
- `_cap_tuner_v2_battle.png`：7 綠框（player_figure/player_panel/enemy_area/command_host/skill_menu/
  combo_label/log_label）+ 名牌同時出現；敵人血條/立繪處出現琥珀框（`enemy/hp_bar` ×2、`enemy/portrait` ×2，
  兩隻敵人各一組）。
- `_cap_tuner_v2_drag.png`：點選玩家立繪（綠框）後注入拖曳，資訊卡顯示「已選中：.../PlayerFigure @ (100.0, 420.0)」
  「已登記：battle/player_figure（可拖曳，S 存檔永久生效）」，框跟著移動且加粗標示選中。
- 程式斷言（同一次跑）：
  ```
  PLAYER_FIGURE_SELECTED: true can_drag=true
  PLAYER_FIGURE_DRAG: before=(40.0, 460.0) after=(100.0, 420.0) moved=true
  ENEMY_HP_BAR_SELECTED: true can_drag=false (expect false)
  ENEMY_HP_BAR_DRAG_BLOCKED: before=(0.0, 60.0) after=(0.0, 60.0) unchanged=true
  ```
  綠框可拖（位置真的變了）、琥珀框選中但 can_drag=false 且拖曳注入後位置不變，兩者皆驗證成立。

**4. 永久套用（capture→save→重載→apply 位置為新值）** ── 通過。
`TestLayoutStore.gd` 的 `_test_capture_save_load_apply_control` 與 `_test_capture_save_load_apply_node2d`：
capture 新位置 → `save_to_path` 寫 `user://` 暫存 → 清空 `_overrides` → `load_from_path` 重新讀回 →
把節點挪到別處 → `apply_override` → 斷言位置回到 capture 時的新值。Control 用 offsets、Node2D 用 position
各驗一次，皆通過（見上方 ALL PASS）。
這條路徑與正式遊戲的 `_load()`/`register()`（`res://_layout_overrides.json`，出貨可讀）完全同一套函式，
只是測試換了路徑參數，核心邏輯未分岔。

**5. 回歸零新增 FAIL** ── 通過。詳見下方測試輸出摘要。

**6. 不留殘骸** ── 通過。
- 未 commit（本次改動全部停留在 working tree）。
- `_layout_tuning.json`／`_layout_overrides.json` 皆未出現在 repo 根目錄（已用 `ls` 確認不存在）。
- `TestLayoutStore.gd` 全程用 `user://_test_layout_overrides_tmp.json`，測完刪除。
- `_cap_tuner_v2_battle.png`、`_cap_tuner_v2_drag.png` 依驗收條件 6 保留在專案根當交付證據。

## 測試輸出摘要（基準 vs 改後）

| 測試 | 基準 exit | 基準結果 | 改後 exit | 改後結果 |
|---|---|---|---|---|
| TestLayoutTuner | 0 | LAYOUT_TUNER_TEST: ALL PASS | 0 | LAYOUT_TUNER_TEST: ALL PASS |
| TestMinigamePause | 0 | MINIGAME_PAUSE_TEST: ALL PASS | 0 | MINIGAME_PAUSE_TEST: ALL PASS |
| TestMinigames | 0 | MINIGAME_TEST: ALL PASS | 0 | MINIGAME_TEST: ALL PASS |
| TestMouseLook | 0 | TEST PASS（無 FAIL/ERROR） | 0 | TEST PASS（無 FAIL/ERROR） |
| TestBattleTutorial | 0 | BATTLE_TUTORIAL_TEST: ALL PASS | 0 | BATTLE_TUTORIAL_TEST: ALL PASS |
| TestBattleFlow | 0 | BATTLE_FLOW_TEST: ALL PASS | 0 | BATTLE_FLOW_TEST: ALL PASS |
| TestLayoutStore（新增） | - | - | 0 | LAYOUT_STORE_TEST: ALL PASS |

全部 exit=0，全程 grep `FAIL|SCRIPT ERROR|Parse Error|Invalid call/get/set` 皆無命中（含 TestMouseLook
既有的「ObjectDB instances leaked / resources still in use at exit」是既有的關閉期噪音，基準與改後一致，非本次改動引入）。

## 意外發現／卡住的地方

1. **`%PlayerPanel` 解析失敗**：spec 表格把 `PlayerPanel` 列為可用 unique name 存取，但實際 `BattleScreen.tscn`
   裡 `PlayerPanel` 節點本身沒有勾 `unique_name_in_owner`（只有它底下的 PlayerName/PlayerHPBar 等子節點才有）。
   第一次跑 GPU 截圖測試時直接報錯 `Node not found: "%PlayerPanel"`。已改用 `get_node("PlayerPanel")`
   相對路徑解決，並重新實測確認 `battle/player_panel` present=true free=true。這算是 spec 文件與實際 scene
   狀態的小落差，不影響其餘 6 個 key（它們确實都有 unique_name_in_owner）。
2. **CommandMenu 動畫定位是否跟著 CommandHost 移動**：已實測確認——`CommandHost`（登記節點）本身是
   `set_anchors_preset(FULL_RECT)` 的靜態容器，`CommandMenu`（其動態子節點）在自己的 `.position` 上做
   滑入動畫（`CommandMenu.gd:117-122`，`position = target - Vector2(120,0)` → tween 回 `target`）。
   v2 只登記/框選 `CommandHost` 這個外層容器本身，不追蹤 `CommandMenu` 內部動畫位移——這符合 spec
   （只登記 7 個「自由定位大塊」，CommandMenu 是 CommandHost 底下的子節點，其動畫是既有的演出效果，
   v2 不介入）。GPU 截圖中 `battle/command_host` 綠框穩定顯示在 CommandHost 的滿版區域，未被動畫誤導，
   行為符合預期，非 bug。
3. 沒有其他卡關；未觸發任何「同一點失敗兩次」的情況。

## 落檔證據路徑

- `D:\monk\MONK\_cap_tuner_v2_battle.png`（全框標註）
- `D:\monk\MONK\_cap_tuner_v2_drag.png`（拖動綠框後）
- 本報告：`D:\monk\MONK\_tuner_v2_p1_report.md`
