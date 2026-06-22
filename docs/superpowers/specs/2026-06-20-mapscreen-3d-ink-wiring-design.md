# MapScreen 接回 3D 水墨探索 — 設計文件

日期：2026-06-20
狀態：設計核可（待寫實作計畫）
關聯：3D 水墨場景（`ShrineStreet.tscn` / `ArmoryDistrict.tscn`，spec `2026-06-20-3d-shrine-street-scene-design.md`）、舊 2D 協調者（現 `MapScreen.gd`）、舊 3D 分區框架（spec `2026-06-16-mapscreen-area-switch-design.md`）、`LocationTrigger`、手機「移動」app（`TravelApp`）、`MainQuestManager`。

## 目標
把兩個已建好、已截圖驗證的 3D 水墨可走場景（神社街、軍火庫街）接進正式遊戲流程：玩家經 `SceneRouter.go_to_map()` 進到的 `MapScreen` 就是可走的 3D 水墨街，能踏觸發點開動作選單（對話/商店/支線/主線/存檔），能用手機「移動」app 在兩區間往返。所有後端遊戲邏輯（`perform_action`、HUD、存檔、主線、商店、成就、時間）全留用。

## 背景：現況
- **現 `MapScreen.gd` 是 2D Control 協調者**（2026-06-16 楓谷期改建），持有 `DistrictScene`（2D 捲動街景）/`LocationInterior`（2D 內景）/`CityMap`（2D 選區）三個 Control 子節點 + `HUD`。
- **遊戲邏輯與 2D/3D 無關**：`MapScreen.gd` 只是收子節點的 `location_entered(id)` → 開動作選單 → `perform_action(action)` 做事。`perform_action` 整段（main_quest/shop/save/支線/破戒/休息/打工/化緣）可原封不動重用。
- **3D 元件全在、沒被刪**：`LocationTrigger`（Area3D 球體觸發，`setup(id, data)` 讀 `position_3d`/`trigger_radius`，`player_entered`/`player_exited` 訊號）、`CameraRig`、`PlayerController`、`PlayerAnimTree`、`Player.tscn`、`Portal`。
- **`map_locations.json` 每個地點已有 `position_3d` + `trigger_radius`**（3D 觸發資料現成）。
- **新場景自帶 Player + CameraRig**：`ShrineStreet.tscn` / `ArmoryDistrict.tscn` 各內含一個 `Player`（z=6 起點）、`CameraRig`（offset (0,4.6,7.2)、pitch −16、`Camera3D current=true`），自帶水墨 shader 環境與走動。但**無觸發點、無 HUD**。
- `areas.json` 仍是**舊 3 區**（ximen/wanhua_old/linsen），`environment` 指向舊 `XimenStreet.tscn`/`PlaceholderArea.tscn`，未指向新場景。

## 決策（已與使用者確認）
1. **架構＝A：MapScreen 當 3D 宿主，instantiate 整個區場景。** 不採環境熱抽換（B），以免改動剛驗證過的新場景。
2. **世界收成 2 區**：`shrine`（神社區，hub）＋ `armory`（軍火庫區，阿瑞斯地盤）。退役 ximen/wanhua_old/linsen 三分法。
3. **所有現有 NPC/地點全放神社區**；軍火庫只放一個**條件 NPC（鐵叔）**。
4. **跨區移動＝沿用手機「移動」app**（不做街尾出口）。
5. **軍火庫上鎖**：`armory_unlocked` flag，由 ch1 主線 `c1_intel` 階段（了塵點破軍火庫位置）`set_flag` 開放。

## 架構
`MapScreen.tscn` 根節點由 `Control` 改 `Node`，持有：
- `$World`（Node3D holder）— `_ready` 依 `GameManager.player.current_area` 把該區 3D 場景（`ShrineStreet.tscn`/`ArmoryDistrict.tscn`，自帶 Player+CameraRig+走動+水墨）整個 instantiate 進來。
- `$HUD`（現有 `MapHUD` CanvasLayer）— 不動，重用。
- 選單（`MenuShell`）/商店（`ShopScreen`）overlay — 不動，重用（皆 CanvasLayer，可掛在 Node 根下）。

`MapScreen.gd` 改寫成 3D 協調者：instantiate 區場景 → 依 `map_locations.json`（過濾 `district == current_area`）灑 `LocationTrigger` 進場景 → 每個 trigger `player_entered` → 開動作選單 → `perform_action`（照搬）。退役 2D `DistrictScene`/`LocationInterior`/`CityMap`：3D 直接踏觸發開選單（舊 3D 版即如此），不再有 2D 進店內景跳圖。

## 元件與改動

### 資料
- **`areas.json`**：3 區 → **2 區**。
  - `shrine` → `name:"神社區"`、`environment: ShrineStreet.tscn`、`default_spawn:{x:0,y:1.2,z:6}`、`bgm: temple_ambient`、`map_pos`（手機移動 app 用）。
  - `armory` → `name:"軍火庫區"`、`environment: ArmoryDistrict.tscn`、`default_spawn:{x:0,y:1.2,z:6}`、`bgm`（沿用戰鬥/緊張 BGM）、`unlock_flag: "armory_unlocked"`。
  - 移除 ximen/wanhua_old/linsen 三筆（其 2D 欄位 `scene_2d`/`scene_spawn`/`edge_portals` 一併不用）。
- **`map_locations.json`**：
  - 5 個現有地點（`old_temple`/`wannian_mall`/`ximen_mrt`/`zen_bbq`/`zuijin_club`）`district` 全改 `"shrine"`，`position_3d` 沿神社街重排（近似值，GPU 截圖時再微調）：
    - `old_temple`（主線/存檔 hub）→ 街尾神社前，`{x:0,z:-26}`，半徑 3.0。
    - `wannian_mall`（鄭媽佛具店 shop）→ `{x:-5,z:-8}`。
    - `ximen_mrt`（化緣/阿明/阿蕊）→ `{x:5,z:-4}`。
    - `zen_bbq`（食破戒/阿忠/David）→ `{x:-5,z:-18}`。
    - `zuijin_club`（Cherry/采馬）→ `{x:5,z:-16}`；**移除其 `unlock_flag: linsen_unlocked`**（舊分區門檻，收區後失效，否則永不出現）。`available_periods` 維持（時段顯示邏輯不變）。
  - 各地點 `actions`/支線/`available_periods`/`name` 內容**全留**。`scene_pos`/`interior_2d`/`scene_file` 欄位留著無妨（新流程不讀）。
  - **新增 `armory_worker`**：`district:"armory"`、`name:"鐵叔"`、`actions:["armory_npc"]`、`position_3d:{x:-4,z:-16}`、`trigger_radius:2.5`、`available_periods:[0,1,2,3]`。
- **`main_quests.json`**：`ch01_ares` 的 `c1_intel` 階段加 `"set_flag": "armory_unlocked"`（與既有 `dialogue` 並存，比照 `c1_demolition` 的 cutscene+set_flag）。
- **`GameManager`**：`player.current_area` 預設值改 `"shrine"`（存/讀檔沿用既有欄位）。

### 程式
- **`MapScreen.tscn`**：根 `Control` → `Node`；移除 `DistrictScene`/`LocationInterior`/`CityMap` 節點；新增空 `World`（Node3D）；保留 `HUD`。
- **`MapScreen.gd`** 改寫：
  - `_ready`：讀 `areas.json`/`map_locations.json` → 決定 `current_area`（fallback `shrine`）→ instantiate 該區 `environment` 場景進 `$World` → `_spawn_triggers()`（過濾 `district==current_area`，每筆 `LocationTrigger.tscn` instantiate、`setup(id,data)`、加進 `$World`、`player_entered` 連到開選單）→ 依 `pending_arrival`/`default_spawn` 定位 Player（取 `$World` 內 group `player` 的節點）→ `AudioManager.switch_bgm(area.bgm)` → `_update_hud()`。
  - `_on_trigger_entered(id)`：`_current_loc=id`；開動作選單 `hud.show_action_menu(name, actions, perform_action)`（沿用既有 HUD 介面）。
  - `perform_action`：**照搬現版**，僅新增一個 case：
    - `"armory_npc"`：`get_flag("ares_purified")` 為真 → `Dialogic.start("armory_worker_freed")`，且**首次**發謝禮（`if not get_flag("armory_worker_thanked"): GameManager.add_item(...) / set_flag("armory_worker_thanked")`，防重複對話刷道具）；否則 → `Dialogic.start("armory_worker_locked")`。比照 `cherry_dialogue` 用 `ResourceLoader.exists` 防呆。
  - `travel_to(area_id)`：**保留 public**（手機移動 app 呼叫）：設 `current_area` → `SceneRouter.go_to_map()` 重載。移除 `city.district_selected`/`edge_to`/`request_city_map` 的接線（隨 2D 節點退役）。
  - 環境查無/檔不存在 → fallback `push_warning` + 載 `ShrineStreet.tscn`，避免黑畫面。
- **`TravelApp`（手機移動）**：確認其區清單讀 `areas.json`（2 區自動生效）、目的地走 `current_area`+`go_to_map()`（或 `MapScreen.travel_to`）；捷運/計程車落點邏輯對齊新 area/location id。**規劃時先讀 `TravelApp.gd` 確認，再決定是否需小改。**
- **退役（不刪檔）**：`DistrictScene`/`LocationInterior`/`CityMap`/`Hd2dStreet`/`Hd2dPlayer`/`XimenStreet`/`PlaceholderArea` 相關場景與腳本——新流程不引用即可，留檔備查。

### 對話（新增 2 支短 timeline）
- **`dialogue/armory_worker_locked.dtl`**：鐵叔低頭搬彈藥箱，對招呼充耳不聞，只「……」、別過臉示意快走（旁白 1–2 行 + 一句「……」）。
- **`dialogue/armory_worker_freed.dtl`**：阿瑞斯已倒，枷鎖斷。鐵叔抬頭道謝——原是鑄神社梵鐘/佛具的匠人，被擄來改鑄兵器，如今能回去鑄鐘。給**一句線索**（萬神殿其他神仍在各區作惡，鋪後續主線）。**謝禮（金瘡藥）由 `armory_npc` case 程式發、`armory_worker_thanked` flag 守一次**（見上「程式」），不靠 dtl 內 `[signal]`，避免重播刷取。
- 兩支需註冊進 Dialogic 的 `dtl_directory`（比照既有 26 支 `.dtl`）。

## 鐵叔（軍火庫 NPC）角色設定
- **身分**：原鑄造神社梵鐘、佛具的老鑄匠；阿瑞斯軍火庫把他擄來逼鑄兵器彈藥。低頭做工、不敢出聲（戰神耳目）。呼應神社/佛具主題與「超渡的不只是神、還有被神壓迫的人」。
- **打倒阿瑞斯前**：`armory_worker_locked` —「……」，別過臉。
- **打倒阿瑞斯後**（`ares_purified`）：`armory_worker_freed` — 道謝 + 線索 + 小謝禮。

## 資料流
1. 開遊戲/讀檔 → `current_area`（預設 `shrine`）。
2. `SceneRouter.go_to_map()` → `MapScreen._ready` 依 `current_area` instantiate 區場景 + 灑該區 triggers + 定位 Player + 切 BGM。
3. 玩家走 3D 街、踏觸發球 → `player_entered` → 動作選單 → `perform_action`（既有流程）。
4. 主線 `c1_intel` 跑完 → `armory_unlocked=true` → 手機移動 app 開始列出軍火庫。
5. 手機移動選軍火庫 → `travel_to("armory")` → `go_to_map()` 重載（回到 2，已在 armory）。
6. 軍火庫踏鐵叔觸發 → `armory_npc` → 依 `ares_purified` 播 locked/freed。

## 行為決策 / 邊界
- **起始區＝神社區**。`old_temple`（神社）為主線/存檔 hub。
- **相機**沿用各場景自帶 CameraRig（offset (0,4.6,7.2)/pitch −16），per-area 已內建，不另設。
- **時間推進**：`perform_action` 既有「每動作 advance_time(1)」慣例維持（含與鐵叔對話）。
- **`pending_arrival`（計程車落點）**：沿用既有機制，落點 area 不符時改用 `default_spawn`。
- 軍火庫未解鎖（`armory_unlocked` 未設）→ 手機移動 app 不列出（沿用 `unlock_flag` 過濾）。

## 測試
- **headless（邏輯）** `test/TestMapScreen3D.tscn`（或沿用既有測試命名）：
  - `current_area=shrine` → `$World` 掛 ShrineStreet、只灑 shrine 的 5 個 trigger、Player 落在 default_spawn。
  - `travel_to("armory")` 重載 → `$World` 換 ArmoryDistrict、只灑 armory 的 `armory_worker`。
  - `armory_npc`：`ares_purified=false` → 解析到 `armory_worker_locked`；`=true` → `armory_worker_freed`（驗分歧函式，不必真跑 Dialogic）。
  - `armory_unlocked` 未設時 armory 不在手機可移動清單。
  - 全專案 `--editor --quit` 無 parse error。
- **windowed 截圖（視覺）**：神社區 3D 街、第三人稱水墨、踏觸發顯示動作選單、HUD 在最上層、travel 到軍火庫後鐵叔在場。存 PNG 自檢（沿用 `--path D:/monk/MONK <scene> -- smoke` + grep `_SAVED` + Read 圖）。
- **回歸**：`TestMainQuest`/`TestDemoScope`/`TestMenuSystem`/`TestShop` ALL PASS（`perform_action`/主線/手機/商店未破）。

## YAGNI（本輪不做）
- 街尾出口走到底切區（用手機移動）。
- 軍火庫除鐵叔外的其他互動點 / Boss 巢自由探索（Boss 戰仍由主線 `continue_story` 帶）。
- 神社區/軍火庫的美術精修（場景已驗證；觸發點落位 GPU 微調屬收尾）。
- 刪除退役的 2D/舊 3D 檔（先留備查）。
- 多區重構成 per-area 獨立 gameplay 腳本（單一 MapScreen 協調者足矣）。

---

## 實作後更新（2026-06-22，已執行完成）
plan `2026-06-20-mapscreen-3d-ink-wiring` 已就地在 `hd2d-exploration` 執行完畢（未 commit）。與本設計的差異／補充：
- **鐵叔從「純旁白、不需 .dch」升級為 2 態 VN 立繪**（使用者 2026-06-22 決定）：建 `dialogue/TieShu.dch`（portrait `locked`/`freed`），2 支 .dtl 鐵叔台詞改成 `TieShu (locked/freed):` 角色發話（VN SPEAKER 模式跳左下大胸像）。2 張厚塗立繪（鎖前駝背/鎖後抬頭）**交 Codex 生**，落點規格＝`specs/2026-06-22-tieshu-portrait-handoff.md`；圖未到前 runtime 僅顯示空白立繪（不 crash、不影響 parse/測試）。
- **HUD label 加深色描邊**：TimeLabel/StatsLabel 近白字在亮水墨背景糊掉，加 `font_outline`（outline_size 6）才可讀。
- **MainQuestManager 早已支援 stage `set_flag`**（免改）；`c1_intel` 加 `set_flag: armory_unlocked` 即生效。
- **回歸修正**：`TestMenuSystem` L293 斷言 `pending area=='wanhua_old'`→收區後 old_temple 屬 shrine，改 `'shrine'`。`battle_art` 的 district→bg 有 fallback ximen，shrine 不破。
- **退役 2D 測試已刪**：TestMapData2D/TestDistrictScene/TestCityMap/TestInterior/TestMap2D/TestMapArea/CaptureMap2D/CaptureMapAll（DistrictScene/CityMap/LocationInterior 場景檔留備查未刪）。
- **驗證**：`TestMapScreen3D` headless PASS（環境/觸發 5+1/鐵叔分歧）；TestMainQuest/TestDemoScope/TestMenuSystem/TestShop/TestCh1Expansion 全 ALL PASS；windowed `_mapscreen3d_shot.png` 確認水墨神社街+無戒+HUD。⚠`TestRunner` 仍是 windowed smoke（戰鬥段 headless 卡＝既有問題，非本次）。
