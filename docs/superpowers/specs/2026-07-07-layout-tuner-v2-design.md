# 佈局工具 v2 設計（2026-07-07）

## 背景與目標

現有 `LayoutTuner`（src/autoloads/LayoutTuner.gd）是「量測工具」：遊戲內拖曳 2D
節點、`S` 匯出 `_layout_tuning.json`，再由人手動把數值烙進程式。使用者要升級成一套
**真正的遊戲內佈局系統**：

1. **每個可調物件身上直接畫框＋標名字**（取代任何額外的列表面板）。
2. **同類一起動**：重複元件（如多個敵人血條）調一個、全部套用。
3. **永久套用＋每場自動生效**：存一次，之後每次進該畫面都用新位置。
4. **調完立刻烙進程式**：不要「匯出 JSON 再等人手動貼」的兩段式。

### 拍板方向：A 務實版

Godot UI 分兩類：**自由定位**（anchor/offset 直接擺）與**容器排版**
（HBox/VBox/PanelContainer 自動算位置，設 `.position` 會被容器彈回）。戰鬥畫面大部分
小元件（單一血條、敵人名字、敵人立繪）都在容器裡，拖不動。

**A 務實版**（使用者拍板）：
- 工具**只自由拖「可自由定位的大塊」**（見下方戰鬥登記清單），這些拖了永久存。
- 容器內小元件**不假裝能拖**：標成琥珀色、顯示「樣板元件，改樣板」，實際調整由改
  `EnemyPanel.gd` 之類的樣板/容器參數達成（同一樣板實例化 N 份，改一次全套用＝天然同步）。

### 涵蓋範圍（分期）

- **P1（本 spec 主體，先做）**：戰鬥畫面。做完系統 + 戰鬥登記 + 測試 + GPU 驗證。
- **P2–P4**：同一套系統擴到 地圖 HUD／對話框立繪／小遊戲（只是逐場景加登記，不改系統）。

---

## 架構

三個部分：**LayoutStore（資料+套用）**、**登記機制**、**LayoutTuner 升級（編輯 UX）**。

### 1. LayoutStore（新 autoload）

檔案：`src/autoloads/LayoutStore.gd`，加進 `project.godot` autoload（名稱 `LayoutStore`，
排在 `LayoutTuner` **之前**，因為 LayoutTuner 會用它）。

職責：持有「識別鍵 → 已存位置」的持久資料，遊戲內登記時即時套用，並負責存讀 JSON。

```gdscript
extends Node

const OVERRIDES_PATH := "res://_layout_overrides.json"

## 持久：layout_key(String) -> entry(Dictionary)。載入自 JSON，S 存檔寫回。
## Control entry: {"kind":"control","offsets":[l,t,r,b],"group":"..."}
## Node2D  entry: {"kind":"node2d","pos":[x,y],"group":"..."}
var _overrides: Dictionary = {}

## 暫態：layout_key -> 目前活著的節點（每次 register 重建，節點離開樹時清掉）。
## 供 LayoutTuner 列舉「現在畫面上有哪些可調節點」用。
var _live: Dictionary = {}

func _ready() -> void:
    _load()

## 場景在 _ready/build 時對每個可調節點呼叫一次。key 要全域唯一且穩定
## （例："battle/player_figure"）；group 同類共用（例多個同型自由元件），沒有填 ""。
## 登記後：記進 _live、掛 meta("layout_key")、加入 group "layout_tunable"，
## 若 _overrides 有這個 key 就 deferred 套用（等版面/anchor 定位後）。
func register(node: CanvasItem, key: String, group: String = "") -> void

## 反登記（節點離開樹時自動呼叫，把 _live[key] 清掉）。
func unregister(key: String) -> void

## 把 _overrides[key] 的位置套到 node 上（Control 設 offsets、Node2D 設 position）。
## 沒有該 key 就不動。用 call_deferred 呼叫以確保容器/anchor 已完成一次 layout。
func apply_override(node: CanvasItem, key: String) -> void

## 讀目前 node 的位置寫進 _overrides[key]（含 group）。tuner 拖曳/微調後呼叫。
func capture(key: String, group: String = "") -> void

## 同群組套用：把 key 這個節點目前的「相對位置」套到所有同 group 的 live 節點
## （全部設成同一個 local position ＝ 使用者說的「全部變成我更新後的位置」）。
## P1 戰鬥的自由塊都是唯一的，暫時用不到；先實作備用。
func apply_group(group: String) -> void

## 寫 _overrides 進 JSON（人可讀、進版控）。
func save() -> void

## 判斷節點是不是自由定位（父節點不是 Container）。
func is_free(node: CanvasItem) -> bool

## 列出目前活著的登記節點：[{key, node, group, free:bool}]，供 tuner 畫框。
func live_entries() -> Array
```

**套用時機**：`register()` 內若有 override，用 `call_deferred("apply_override", node, key)`，
避免 `_ready` 當下父容器/anchor 尚未定尺寸。Control 存/套 `offset_left/top/right/bottom`
（最穩，完整釘住位置與大小）；Node2D 存/套 `position`。

**存讀位置**：沿用現行 `res://`——編輯器跑（debug）時 `res://` 對應專案資料夾、可寫；
匯出版 `res://` 打包唯讀但**可讀**，所以 commit 進去的 JSON 在正式版一樣會被 `_load()`
讀到並套用＝「永久烙進」。這就滿足需求 3+4，不需要從執行中的遊戲改 `.tscn`。

### 2. 登記機制（戰鬥畫面 = P1 唯一要改的遊戲檔）

在 `BattleUI.gd` 已有各節點的 `%unique_name` 參照。找到它們的 `@onready`（或 build 時取得
節點處），對這 7 個**自由定位塊**各加一行登記（在節點確定存在後，建議 `_ready()` 尾或
`build()` 內）：

| layout_key | 節點（unique name） | 型別 | 說明 |
|---|---|---|---|
| `battle/player_figure` | `%PlayerFigure` | TextureRect | 玩家立繪 |
| `battle/player_panel` | `%PlayerPanel` | PanelContainer | 玩家血條/資源面板（整塊） |
| `battle/enemy_area` | `%EnemyArea` | HBoxContainer | 敵人區整排（整塊移動） |
| `battle/command_host` | `%CommandHost` | Control | 攻擊/技能/防禦/道具/護法選單容器 |
| `battle/skill_menu` | `%SkillMenu` | PanelContainer | 技能子選單 |
| `battle/combo_label` | `%ComboLabel` | Label | 連擊計數 |
| `battle/log_label` | `%LogLabel` | Label | 戰鬥日誌 |

登記範例：
```gdscript
LayoutStore.register(%PlayerFigure, "battle/player_figure")
LayoutStore.register(%PlayerPanel, "battle/player_panel")
# ...其餘 5 個
```

註：這 7 個的**父節點都是 `BattleUI`（CanvasLayer），不是 Container** → `is_free()` 皆為
true → 皆可自由拖。（`%EnemyArea` 自己是 HBoxContainer，但它「被誰排版」看的是父節點，
其父是 CanvasLayer，所以整塊可自由移動。）

**敵人樣板標註**：不個別登記敵人面板內的血條/立繪（它們在容器內、拖不動）。改為在
`EnemyPanel.gd` 建構時，對面板內的血條與立繪掛一個 meta 標記
`set_meta("layout_template", "enemy/hp_bar")` / `"enemy/portrait"`，讓 tuner 掃到時知道
「這是樣板元件、顯示琥珀框 + 該 key，但不可拖」。（純標註，不影響遊戲行為。）

### 3. LayoutTuner 升級（src/autoloads/LayoutTuner.gd）

保留現有開關鍵（`` ` `` 開關、`S` 存檔、方向鍵微調、右鍵循環、`_input` 攔截、暫停遊戲）。
改動：

**a) 進調整模式 → 一次畫出所有可調節點的框＋名字牌**
- 列舉 `LayoutStore.live_entries()`，對每個 entry 在 overlay 上畫一個外框 + 一張小名牌
  （顯示該 key 的短名，如「玩家立繪」）。
- **綠框**＝`free==true`（可拖）；**琥珀框**＝容器/樣板元件（`free==false` 或有
  `layout_template` meta，不可拖）。
- 另外掃 `get_tree()` 找有 `layout_template` meta 的節點（敵人血條/立繪），也畫琥珀框 + 標
  它的樣板 key。
- 名牌用小字、半透明底，避免蓋住畫面；框隨節點位置。選中的節點框加粗/變色以區別。

**b) 選取與拖曳**
- 左鍵點擊：優先命中「已登記/已標註」的節點（用它們的螢幕矩形做命中測試，面積小者優先、
  深度深者優先——沿用現有 `_candidate_less`）。
- 命中**綠框（free 且已登記）**：可拖曳 + 方向鍵微調；每次移動後呼叫
  `LayoutStore.capture(key, group)`（並若有 group 呼叫 `apply_group`）。
- 命中**琥珀框（容器/樣板）**：**不進入拖曳**；資訊卡顯示「⚠樣板/容器元件：<key>，
  改樣板調整（告訴 Claude 你要的位置）」。
- 保留右鍵循環（重疊時切換候選）。
- 保留「未登記的一般 CanvasItem」可被點中拖曳的舊行為當**臨時量測**用，但資訊卡標明
  「未登記，移動不會存檔」——不列入 P1 驗收，只是不要退化掉上一批修好的整棵樹命中能力。

**c) 存檔**
- `S` → `LayoutStore.save()`（寫 `_overrides` 進 `_layout_overrides.json`）。
- 舊的 `_layout_tuning.json` 機制淘汰：移除對 `res://_layout_tuning.json` 的寫入，改走
  LayoutStore。（保留 tuner 內的拖曳/命中/微調基礎邏輯，只把「記錄與存檔」導向 LayoutStore。）

**d) 資訊卡**：沿用左上小卡，顯示操作說明 + 目前選中節點的 key/類別/free 與否/座標。

---

## JSON 格式（`_layout_overrides.json`）

```json
{
  "battle/player_figure": {"kind": "control", "offsets": [40, -620, 480, -20], "group": ""},
  "battle/enemy_area":    {"kind": "control", "offsets": [-700, 100, 700, 945], "group": ""}
}
```
以 `layout_key` 為鍵（穩定、人可讀）。存讀合併：載入舊檔 → 本次改動覆蓋同 key → 寫回。

---

## 驗收條件

1. **LayoutStore 存在且可運作**（單元測試 `test/TestLayoutStore.gd`）：
   - `register` 後 `live_entries()` 含該節點；節點離開樹後不再列出。
   - `capture` → `save` → 重建 store `_load` → `apply_override` 後，節點位置與存檔一致
     （Control 用 offsets、Node2D 用 position 各測一個）。
   - `is_free`：Container 的子節點回 false、CanvasLayer/一般 Control 的直接子節點回 true。
   - `apply_group`：兩個同 group 的 live 節點，capture 其一後 apply_group，兩者 local
     position 相同。
2. **戰鬥畫面登記正確**：進戰鬥後 `LayoutStore.live_entries()` 含上表 7 個 key，且各自
   `free==true`。（可在 TestLayoutStore 或戰鬥流程測試中斷言。）
3. **調整模式全框標註 + 綠拖琥珀擋**（GPU 截圖驗證）：
   - 開 `` ` `` → 畫面上 7 個綠框 + 名牌同時出現；敵人血條/立繪處出現琥珀框。
   - 點綠框（如玩家立繪）→ 可拖動，資訊卡顯示 key。
   - 點琥珀框（敵人血條）→ 不被拖動，資訊卡顯示「樣板/容器」訊息。
   - 截圖：`_cap_tuner_v2_battle.png`（全框標註）、`_cap_tuner_v2_drag.png`（拖動綠框後）。
4. **永久套用**（測試模擬）：capture 玩家立繪新位置 → save → 重新載入 store → apply →
   位置為新值（證明「下次進戰鬥自動套用」的核心路徑）。
5. **回歸零新增 FAIL**：下列既有測試改動前先跑記錄基準、改動後全過（exit=0、無新增
   SCRIPT ERROR/FAIL）：`TestLayoutTuner`、`TestMinigamePause`、`TestMinigames`、
   `TestMouseLook`、`TestBattleTutorial`、`TestBattleFlow`（若存在且原本會過）。
   TestLayoutTuner 若因 API 改動需調整呼叫端，一併更新並保持其斷言精神。
6. **不留殘骸**：不 commit；不留臨時 JSON 在 repo（測試用暫存寫 `user://` 並刪除）；
   驗收截圖 `_cap_tuner_v2_*.png` 放專案根當交付證據可保留。

## 測試指令（Windows）

headless（測試）：
```
D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path . test/TestLayoutStore.tscn
```
GPU 截圖（新增 capture 場景，仿 test/CaptureLayoutTunerDialogic.gd 進戰鬥觸發）：
```
D:\monk\tools\godot\Godot_v4.5-stable_win64.exe --path . test/CaptureLayoutTunerBattle.tscn
```

## 不在 P1 範圍（明列，避免超收）
- 地圖 HUD／對話框／小遊戲的登記（P2–P4）。
- 把 override 真的寫死進 `.tscn` 常數（出貨前收尾，非必要）。
- 容器內元件的自由拖曳（A 版明確不做）。
- 右上列表面板（使用者明說不要）。
