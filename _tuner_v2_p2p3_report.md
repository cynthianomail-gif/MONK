# 佈局工具 v2 — P2（地圖 HUD）＋ P3（對話框/立繪）登記報告

規格：docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md（P1 主體；本次為 P2–P3 擴充，
系統本身 LayoutStore.gd / LayoutTuner.gd 未改動，只在既有場景腳本加 register 呼叫）。

## 改了 / 新增哪些檔

- `src/screens/MapScreen/MapHUD.gd`
  - 新增 `_minimap` 欄位、`_ready()` 尾端呼叫 `_register_layout_tunables()`。
  - 新增 `_register_layout_tunables()`：對 5 個 HUD 直接子節點 + 動態建立的 Minimap 呼叫
    `LayoutStore.register()`。
  - `_add_minimap()` 內補一行 `_minimap = mm` 記住參照供登記用。
- `src/ui/dialogue_style/speaker_bust_layer.gd`
  - `_apply_export_overrides()` 尾端 `call_deferred("_register_layout_tunables", con)`。
  - 新增 `_register_layout_tunables(portrait_con)`：登記本層立繪 `dialogue/portrait`；
    再掃 `get_parent().get_layers()`（DialogicLayoutBase 的兄弟層），用 `has_node("%Sizer")`
    + `has_node("%NameLabelPanel")` 探測出 Dialogic 內建的 `VN_TextboxLayer`，登記其
    `%Sizer`→`dialogue/textbox`、`%NameLabelPanel`→`dialogue/nameplate`。
  - **沒有改動 addons/dialogic 底下任何檔案**——純粹從外部用 unique-name 取得節點參照登記，
    不影響 Dialogic 原本行為。
- 新增 GPU capture 場景（仿 test/CaptureLayoutTunerBattle.gd）：
  - `test/CaptureLayoutTunerMap.gd` + `.tscn`
  - `test/CaptureLayoutTunerP3Dialogue.gd` + `.tscn`（跟既有 `CaptureLayoutTunerDialogic.gd`
    不同：後者驗證的是 P1 前置的「命中測試整棵樹掃描」修法，這支驗證的是 P3 新增的
    LayoutStore 登記本身）。

## 登記的 key 清單

| key | 節點 | free / template |
|---|---|---|
| `map/time_label` | HUD/TimeLabel（Label） | free（父=HUD CanvasLayer） |
| `map/stats_label` | HUD/StatsLabel（Label） | free |
| `map/interaction_prompt` | HUD/InteractionPrompt（PanelContainer） | free |
| `map/action_menu` | HUD/ActionMenu（PanelContainer） | free |
| `map/toast` | HUD/Toast（Label） | free |
| `map/minimap` | HUD/Minimap（動態建立的 Control，Minimap.gd） | free |
| `dialogue/portrait` | SpeakerBustLayer/SpeakerPortrait（DialogicNode_PortraitContainer） | free（父=SpeakerBustLayer，Control 非 Container） |
| `dialogue/textbox` | VN_TextboxLayer/Anchor/AnimationParent/Sizer（Control，Dialogic 內建） | free（父=AnimationParent，Control 非 Container） |
| `dialogue/nameplate` | .../DialogTextPanel/NameLabelHolder/NameLabelPanel（PanelContainer，Dialogic 內建） | free（父=NameLabelHolder，Control 非 Container） |

未登記為可拖、仍在容器內排版的部分（沒有加 layout_template，因為不在本次任務範圍，屬於
Dialogic 內部細節或非重複元件，見「意外/做不到」段）：`MenuButtons` 內動態生成的行動按鈕、
`DialogicNode_DialogText`/`DialogicNode_NameLabel`（文字本身，非框）。

## 驗收條件逐條

**1. 地圖 HUD `LayoutStore.live_entries()` 含 `map/*` key 且 free==true**
GPU capture `test/CaptureLayoutTunerMap.tscn` 執行輸出（`_cap_map.log`）：
```
LIVE_ENTRY_CHECK map/time_label -> present=true free=true
LIVE_ENTRY_CHECK map/stats_label -> present=true free=true
LIVE_ENTRY_CHECK map/interaction_prompt -> present=true free=true
LIVE_ENTRY_CHECK map/action_menu -> present=true free=true
LIVE_ENTRY_CHECK map/toast -> present=true free=true
LIVE_ENTRY_CHECK map/minimap -> present=true free=true
```
全部 present=true、free=true。通過。

**2. 對話框/立繪 `dialogue/*` key 生效；Dialogic 控制的內部元件有 layout_template 標註**
GPU capture `test/CaptureLayoutTunerP3Dialogue.tscn` 輸出：
```
LIVE_ENTRY_CHECK dialogue/portrait -> present=true free=true
LIVE_ENTRY_CHECK dialogue/textbox -> present=true free=true
LIVE_ENTRY_CHECK dialogue/nameplate -> present=true free=true
```
三者皆 free==true（可自由拖）。**誠實說明**：P3 範圍內找到的三個節點（立繪、對話框本體
Sizer、名牌 NameLabelPanel）父節點皆為一般 Control（非 Container），依 spec 定義的
`is_free()` 判準（父不是 Container）全數為 true，**沒有**在 P3 範圍內找到需要標
`layout_template`（容器內重複樣板元件）的情況——Dialogic 對話框內其餘節點
（DialogTextPanel、NextIndicator、AutoAdvanceProgressbar、DialogicNode_DialogText 文字本身）
要嘛是這三個已登記節點的容器/子節點、要嘛不是使用者會想個別拖曳的獨立版面塊，故未額外
掛 meta。若之後使用者覺得三者不夠精細（例如想單獨移動 NextIndicator 或
AutoAdvanceProgressbar），屬於範圍外增項，未在本次做。

**3. GPU 截圖各一張，顯示該場景進調整模式後有框**
- `D:\monk\MONK\_cap_tuner_v2_map.png`：神社街 HUD，6 個綠框（time_label 右上、
  minimap 右上角小圓盤、action_menu 右側、toast 上方置中、stats_label 左下、
  interaction_prompt 畫面下方置中）清楚可見，人工檢視截圖確認位置與 HUD 實際元件吻合。
- `D:\monk\MONK\_cap_tuner_v2_dialogue.png`：cherry_first_meeting 對話，3 個綠框
  （dialogue/portrait 包住立繪、dialogue/textbox 包住對話框區域、dialogue/nameplate
  在立繪右側小名牌處）清楚可見。

**4. TestLayoutStore/TestLayoutTuner＋地圖/對話既有測試回歸零新增 FAIL**

| 測試 | exit code | FAIL/SCRIPT ERROR |
|---|---|---|
| TestLayoutStore | 0 | 無（僅既有的 "26 resources still in use at exit" 引擎關閉期無關訊息） |
| TestLayoutTuner | 0 | 無 |
| TestMenuSystem | 0 | 無，`MENU_TEST: ALL PASS` |
| TestMapScreen3D | 0 | 無，`TEST PASS: MapScreen 3D 接線 OK` |
| TestAllDialogue | 0 | 無，`ALL_DIALOGUE_TEST: ALL PASS (27 timelines, 11 characters)`（本次未遇到 memory 提過的
  shutdown segfault，exit=0 乾淨結束） |
| TestBattleFlow（P1 既有回歸項，順手覆核未受影響） | 0 | 無 |
| TestBattleTutorial（同上） | 0 | 無 |

全部 exit=0、無新增 FAIL / SCRIPT ERROR。基準即改後（本任務只新增 register 呼叫，未改任何
既有邏輯分支，故基準與改後預期一致，實測相符）。

**5. 沒改系統檔、沒 commit、沒留 override JSON 垃圾**
- 未修改 `src/autoloads/LayoutStore.gd`、`src/autoloads/LayoutTuner.gd`（`git diff --stat` 確認
  這兩檔不在本次 diff 內）。
- 未執行任何 git commit。
- `D:\monk\MONK\_layout_overrides.json` 不存在（`ls` 確認），沒有存檔動作留檔。
- 兩個 capture 場景輸出的驗收截圖（`_cap_tuner_v2_map.png`、`_cap_tuner_v2_dialogue.png`）
  按 spec 第 6 節可保留作為交付證據。

## 意外 / 做不到的部分

- **Dialogic 對話框登記走「探測法」而非直接引用**：因為 `vn_textbox_layer.tscn` 是
  addons/dialogic 底下的檔案，不能加自訂腳本欄位或改場景。改用 `speaker_bust_layer.gd`
  （本專案唯一自己掌控的 layout layer）在 `_apply_export_overrides()` 時反查
  `get_parent().get_layers()`，用 `has_node("%Sizer")` + `has_node("%NameLabelPanel")`
  兩個 unique-name 是否同時存在，探測出哪個兄弟層是 `VN_TextboxLayer`，再登記它的節點參照。
  這是「純登記」不改 Dialogic 行為，但耦合了 Dialogic 內部節點命名（`%Sizer`/
  `%NameLabelPanel`），若 Dialogic 版本升級改了這兩個 unique name，登記會靜默失效
  （`has_node` 找不到就整段 for 迴圈跳過，不會報錯）——這是已知的脆弱點，寫在這裡供未來
  維護參考，不在本次修。
- **沒有找到需要 `layout_template` meta 的 P3 容器/樣板元件**：P2/P3 範圍內的自由塊全數
  `is_free()==true`，不像 P1 戰鬥的敵人血條/立繪那樣有「容器內重複實例」的情境。地圖 HUD
  的 `MenuButtons`（動作選單按鈕）雖在 VBoxContainer 容器內、屬於「容器排版」，但它們是
  單純文字按鈕、不是像敵人面板那樣值得標註的「樣板元件」，故未掛 meta；如使用者認為
  需要標註，屬於範圍外追加。
- **地圖 HUD 沒有玩家血條**：spec 範例清單提到「玩家血條若有」，實際探勘 MapHUD.gd/
  MapScreen.gd 沒有找到地圖 HUD 上的血條（HP 顯示走 `stats_label` 文字，已登記），
  故沒有獨立血條需要登記。

## 測試 log 位置（scratchpad，非 repo）

`C:\Users\cynth\AppData\Local\Temp\claude\D--monk\57a84232-ada6-4f58-8d30-49c7653e292d\scratchpad\`
下的 `test_layoutstore.log`、`test_layouttuner.log`、`test_menusystem.log`、
`test_mapscreen3d.log`、`test_alldialogue.log`、`test_battleflow.log`、
`test_battletutorial.log`、`cap_map.log`、`cap_dialogue.log`。
