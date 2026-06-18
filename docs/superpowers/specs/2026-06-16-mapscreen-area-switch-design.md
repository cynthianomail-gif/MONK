# MapScreen 分區場景切換 — 設計文件

日期：2026-06-16
狀態：設計核可（待寫實作計畫）
關聯：西門街原型（`XimenStreet.gd`）、Phase 3 道具、`SceneRouter`、`MenuShell`

## 目標
把已完成的西門霓虹街原型（環境＋人群＋3 道具）從測試場景（`StreetProto.tscn`）接進正式遊戲流程，讓玩家經 `SceneRouter.go_to_map()` 進到的 `MapScreen` 就是可探索的真街，而不是現在的灰地板佔位。

## 背景：現況架構
- 世界是**單一 overworld 地圖場景**（`SceneRouter.MAP_SCENE` = `MapScreen.tscn`）。玩家走一塊 80×80 灰地板，踏進觸發球（`LocationTrigger`）開動作選單（對話/商店/支線/戰鬥/存檔）。
- 5 個地點橫跨 3 個 district（ximen、wanhua_old、linsen）全擠在同一塊灰平面上，座標見 `data/map_locations.json`。
- **沒有任何真實 3D 環境**；`map_locations.json` 的 `scene_file` 欄位從未被接線。
- 破廟 `old_temple`（main_quest＋save 的 hub）屬 `wanhua_old`，跟西門是不同區，不能是同一條街。

## 決策（已與使用者確認）
1. **世界模型＝分區場景切換**：`MapScreen` 依「目前區域」載入對應環境。西門街是第一個真環境；破廟/萬華/林森暫用簡易佔位環境（可走、觸發點還在、能存檔/推主線），真環境之後逐區補。
2. **區域間移動＝手機/經書快速移動選單**（沿用既有 `MenuShell`）。不做街尾出口。
3. **本輪範圍**：分區框架 ＋ 快速移動 ＋ 西門街接成真環境；其餘區佔位。
4. **實作方式＝單一 MapScreen ＋ 環境熱抽換**（非每區獨立場景）。理由：只有一個真環境時不需要 per-area 場景的隔離，卻要先付「抽共用 Player/Camera/HUD base」的重構成本；方式 1 幾乎只動 `MapScreen.gd`。

## 架構
`MapScreen.tscn` 維持唯一地圖場景，常駐 `Player` / `CameraRig` / `HUD` 與一個空的 `Environment` 持有節點。`Environment` 依 `GameManager.player.current_area` 熱抽換為某區環境子節點。觸發點依目前區域的 `district` 過濾建立。快速移動＝設 `current_area`＋spawn 後 `SceneRouter.go_to_map()` 重載（沿用既有轉場，零新轉場碼）。

## 元件與改動

### 新增檔案
- **`data/areas.json`**（新資料表）：區域 → `{ name, environment(.tscn 路徑), default_spawn{x,y,z}, bgm, unlock_flag? }`。
  - `ximen` → `XimenStreet.tscn`
  - `wanhua_old` → `PlaceholderArea.tscn`
  - `linsen` → `PlaceholderArea.tscn`（`unlock_flag: linsen_unlocked`）
- **`src/screens/MapScreen/environments/XimenStreet.tscn`**：root Node3D 掛現有 `XimenStreet.gd`（讓資料驅動 `load().instantiate()`）。
- **`src/screens/MapScreen/environments/PlaceholderArea.tscn`**：灰地板 StaticBody＋基本 WorldEnvironment＋DirectionalLight（從現 `MapScreen.tscn` 內建那組抽出來），給尚未做真環境的區用。

### 修改檔案
- **`MapScreen.tscn`**：移除內建 `Floor` / `WorldEnvironment` / `Sun`（改由各區環境自帶）；新增空的 `Environment` 持有節點；`CameraRig.camera_offset = (0, 3.4, 5.2)`。
- **`MapScreen.gd`**：
  - `_ready`：`_current_area = GameManager.player.current_area`（fallback `"ximen"`）→ 讀 `areas.json` → instantiate 該區環境到 `$Environment` → `_build_triggers()` 依 `district == _current_area` 過濾（保留現有 `unlock_flag` / period 顯示邏輯）→ 玩家生在 `last_position`（若屬本區）否則 `default_spawn` → `AudioManager.switch_bgm(area.bgm)`。
  - 新增 `travel_to(area_id, spawn := Vector3.ZERO)`：設 `GameManager.player.current_area` 與 `last_position`，呼叫 `SceneRouter.go_to_map()`。
- **`CameraRig.gd`**：加 `@export var camera_pitch_deg := -12.0`，`_ready` 用它取代寫死的 `-50.0`。
- **`GameManager`（player 狀態）**：加 `current_area: String = "ximen"`；存/讀檔（SaveManager）含此欄。
- **`MenuShell`**：加「快速移動」清單，列出已解鎖區域（`unlock_flag` 過濾），選擇 → `MapScreen.travel_to(area_id, spawn)`。實際接法寫 plan 前先讀 `MenuShell` 確認；若其結構不適合，改做獨立 `FastTravelMenu` 由 MenuShell 開啟。
- **`map_locations.json`**：把 `ximen_mrt`(原 x12,z-8)、`wannian_mall`(原 x8,z-5) 的 `position_3d` 改到西門街內合理座標（街寬 x±7、長 z±34，放人行道側）。其餘區地點座標維持（佔位環境夠大）。

## 資料流
1. 開遊戲/讀檔 → `GameManager.player.current_area`（預設 `ximen`）。
2. `SceneRouter.go_to_map()` → `MapScreen._ready` 依 `current_area` 載環境＋過濾觸發＋定位玩家＋切 BGM。
3. 玩家走街、踏觸發 → 既有動作選單流程不變。
4. 開選單 → 快速移動 → `travel_to` 設新區＋spawn → `go_to_map()` 重載 →（回到 2，已在新區）。

## 行為決策
- **本輪起始區＝西門町**（一開遊戲直接看到真街）；破廟真環境之後做後，正式起始可改回破廟 hub。
- **相機**沿用 Phase 2 過肩那組（offset 0,3.4,5.2 / pitch −12），單一設定；per-area 相機之後再說。
- 觸發點的 period 顯示切換（`_on_time_advanced`）邏輯保留。

## 錯誤處理 / 邊界
- `areas.json` 查無該區或環境檔不存在 → fallback 載 `PlaceholderArea.tscn` 並 `push_warning`，避免黑畫面。
- `last_position` 屬於別區（區不符）→ 改用該區 `default_spawn`。
- 快速移動目的地未解鎖 → 不列出（或 disabled）。

## 測試
- **headless（邏輯）**：載 `MapScreen` with `current_area=ximen` → 確認 `$Environment` 掛到 XimenStreet、只建 ximen 的觸發點、`travel_to("wanhua_old")` 後重載成 PlaceholderArea 且觸發換成該區。
- **視窗截圖（視覺）**：街景＋過肩相機＋觸發提示，存 PNG 自檢（沿用 `Godot ... res://...` 視窗截圖流程）。
- **快速移動往返**：ximen ↔ wanhua_old 來回，確認環境/觸發/spawn 正確；存檔再讀檔保住 `current_area`。

## YAGNI（本輪不做）
- 街尾出口觸發切區。
- per-area 相機設定。
- 破廟/萬華/林森的真環境。
- 每區獨立場景（方式 2）與共用 base 重構。
