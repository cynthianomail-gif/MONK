# 2D 探索地圖（楓谷式）設計

**日期：** 2026-06-16
**狀態：** ✅ 已實作並驗證（系統 Phase 0–2 + 美術 Phase 3 全 9 張）。街景於 2026-06-16 二版改為**平面立面＋2 倍長**（見文末「## 二版更新」附註，取代 §設計決策 5 與 §美術資產 中關於街景視角/寬度的舊描述）。
**取代：** 3D 探索地圖（西門街 `XimenStreet.gd` + 3D `Player`/`CameraRig`/3D `LocationTrigger`）在地圖流程中的角色。

---

## 目標

把「探索地圖」從 3D 改成 **2D 橫向捲動、楓之谷式**的點選/走動地圖，**畫風維持本作半寫實厚塗**（非楓谷 Q 版）。戰鬥、對話、立繪、選單、過場、存檔等**既有 2D 系統與所有後端邏輯完全沿用**，只換掉探索的前端表現。

## 動機

3D 街景的房子是「平面貼圖貼盒子」，在過肩鏡頭下一看就假；此問題經 ~8 版迭代仍不滿意，屬方向與使用者強項（2D AI 美術）不合，且有效能負擔。改 2D 後：發揮厚塗強項、從根本消滅「假房子」、順手解決卡頓。

## 設計決策（與使用者逐項確認）

1. **點選式手繪地圖**，採 **混合 C**：城市地圖（選區）→ 區街景（走動）→ 地點內景（互動）。
2. **走過去 sprite**：點地點傳送點 → 無戒走過去 → 觸發。角色 sprite 由本專案既有 3D 模型**渲染成 2D**（idle + walk）。
3. **一張定調圖/區 + 時段指示**：街景不隨時段換圖，用程式調色（日夜 tint）+ 熱點依 `available_periods` 顯隱。
4. **全 3 區**街景都做（林森街景畫好，但遊戲內仍鎖到 `linsen_unlocked`）。
5. **楓谷式長地圖**：街景橫向捲動（比一個畫面寬），相機跟隨無戒。每區 **2–3 個傳送點**。
6. **傳送點兩種**：①地點入口（→ 傳送到該地內景再互動）②街尾邊界傳送點（→ 隔壁區）。換區另有城市地圖快速移動，兩者並存。
7. **地點內景 = 靜態背景圖 + 站樁 + 行動選單/對話**（不在內景裡自由走；日後可升級為可走）。
8. **美術以剩餘額度較多的服務生成**（目前 magnific/freepik ~41k ≫ higgsfield ~18 → 主力 magnific），生成前人工把關。角色 sprite 從 3D 模型渲。

---

## 架構：三層導覽

```
城市地圖（點選選區，林森鎖）
   │ 選區
   ▼
區街景（橫向捲動長街，無戒走動）
   │  ├─ 地點傳送點 ──► 地點內景（行動選單/對話）──離開──► 回街景
   │  └─ 邊界傳送點 ──► 隔壁區街景
   ▼
（城市地圖鈕：街景任意處可叫出城市地圖快速移動）
```

進入點 `SceneRouter.go_to_map()` 不變。預設顯示 `current_area` 的街景。

---

## 節點樹（MapScreen 由 Node3D 改建為 2D Control）

```
MapScreen (Control, 全螢幕)            ← 協調者，保留所有後端邏輯
├─ DistrictScene (Control)            ← 街景層（預設顯示）
│   ├─ Camera2D                       ← 跟隨無戒、夾在地圖邊界
│   ├─ Background (TextureRect)        ← 該區 scene_2d 寬幅厚塗長街
│   ├─ Portals (Node2D)               ← 由 current_area 的傳送點建（地點+邊界）
│   ├─ Wujie (AnimatedSprite2D)        ← idle/walk，沿地面走動
│   └─ TimeTint (CanvasModulate/ColorRect) ← 依時段調色
├─ LocationInterior (Control)         ← 地點內景層（進地點時顯示，否則隱藏）
│   ├─ Background (TextureRect)        ← 該地 interior_2d
│   ├─ Wujie (Sprite2D/AnimatedSprite2D) ← 站樁
│   └─ LeaveButton                    ← 離開 → 回街景
├─ CityMap (Control)                  ← 城市地圖層（預設隱藏）
│   ├─ Background (TextureRect)        ← city_map 圖
│   └─ DistrictPins (Node2D)          ← 各區圖釘（鎖區 disabled+鎖圖示）
└─ HUD (CanvasLayer)                  ← 沿用現有 MapHUD（時段/數值/行動選單/toast/提示）
```

---

## 腳本與職責

| 腳本 | 類型 | 職責 |
|---|---|---|
| `MapScreen.gd`（改） | Control | 載 areas/locations、HUD、時段、成就、選單、`perform_action`、`travel_to`、存檔（全留）。新增狀態切換：`show_district(area)`／`enter_location(id)`／`leave_location()`／`show_city_map()`。把舊的「載 3D 環境/建 3D 觸發/spawn 3D 玩家」換成「載街景圖/建傳送點/擺 Wujie」 |
| `DistrictScene.gd`（新） | Control | `setup(area, locations, period)`：設背景、擺無戒於 `scene_spawn`、建傳送點（依時段+解鎖閘門）、設 Camera2D 邊界與時段 tint。輸入：方向鍵自由左右走、點空地走過去、點傳送點走過去並觸發、走近+互動鍵觸發。發 `location_entered(id)`／`edge_to(area)`／`request_city_map()` |
| `Wujie.gd`（新） | AnimatedSprite2D | `walk_to(x)`/`stop()`；播 `idle`/`walk`；依方向 `flip_h`；到達發 `arrived`；依 y 微調 `scale`（景深） |
| `Portal.gd`（新） | Node2D/Control | 擺在 `scene_pos` 的傳送點（地點型或邊界型）；發光圖示+名稱；依 `available_periods`/`unlock_flag` 顯隱；無戒走到/走近發出 `triggered(payload)`。取代 3D `LocationTrigger` |
| `LocationInterior.gd`（新） | Control | `open(location)`：設 interior_2d 背景、站樁無戒、開該地行動選單（沿用 `MapHUD.show_action_menu(...)`/`perform_action`）；「離開」→ `MapScreen.leave_location()` |
| `CityMap.gd`（新） | Control | 依 areas 建區圖釘（鎖區 disabled+鎖圖示）；按下發 `district_selected(area)` → `travel_to` |
| `MapHUD.gd`（沿用） | CanvasLayer | 不動 |

**單元邊界：** DistrictScene 只管街景與走動、不知道內景長相；LocationInterior 只管單一地點互動；CityMap 只管選區；三者透過 signal 與 MapScreen 溝通，MapScreen 持有共用後端。各自可單獨測試。

---

## 資料模型（沿用既有 JSON，加欄位；舊 3D 欄位保留不用）

### `areas.json` 每區新增
- `scene_2d`：街景圖路徑，如 `res://assets/2d/map/scenes/ximen_street.png`
- `scene_spawn`：`{x, y}` 無戒進場位置（0~1，跨整張長地圖寬）
- `map_pos`：`{x, y}` 該區在城市地圖的圖釘位置（0~1）
- `edge_portals`：`[{"to": "<area_id>", "x": 0.96}]` 邊界傳送點（0~1 位置）
- 保留：`name`、`bgm`、`unlock_flag`
- 退役保留：`environment`、`default_spawn`

城市地圖圖檔：常數 `res://assets/2d/map/city_map.png`（單張，以常數帶入）。

### `map_locations.json` 每地點新增
- `scene_pos`：`{x, y}` 傳送點在該區長街的位置（0~1，跨整張地圖寬）＝同時是走路目標
- `interior_2d`：內景圖路徑，如 `res://assets/2d/map/interiors/old_temple.png`
- 保留：`name`、`district`、`actions`、`available_periods`、`unlock_flag`、`bgm`
- 退役保留：`position_3d`、`trigger_radius`、`scene_file`

座標一律 **0~1 正規化** → 不綁解析度，依背景實際尺寸換算像素。

### 存檔/狀態
- 探索位置 = `current_area`（已在 `GameManager.player.current_area`）。舊 `last_position` xyz 退役。
- 讀檔 → 載 `current_area` 街景、無戒置於 `scene_spawn`。

---

## 美術資產（生成前人工把關）

| # | 資產 | 數量 | 來源 |
|---|---|---|---|
| 1 | 城市地圖 | 1 | magnific/freepik，厚塗風新梵市地圖，3 區 |
| 2 | 區街景（寬幅長街） | 3 | magnific/freepik，側視寬幅厚塗：西門霓虹夜／萬華舊廟暗街／林森紅燈夜。約 2–3 個畫面寬（生寬幅或接段）。留地面帶+傳送點空間 |
| 3 | 地點內景 | 5 | magnific/freepik：捷運西門站／萬年商業大樓／禪味燒肉／紫醉金迷俱樂部／破舊古廟 |
| 4 | 無戒 sprite | 1 套 | 從既有 3D 模型 `wujie_walk.glb` 渲透明 PNG：`idle` 幾格 + `walk` 循環 ~6–8 格，側/三分臉一套、左右翻面 |

**sprite 渲染工具：** 沿用 `CapturePlayerSolo` 那套（透明背景 + 正交側相機 + 逐格走 walk 動畫），輸出序列 PNG → 組 `SpriteFrames` 資源。

**畫面數：** 9 張畫 + 1 套 sprite。林森街景/內景畫好但遊戲內鎖到解鎖。

---

## 時段表現
- HUD 沿用顯示天數/時段。
- 傳送點依 `available_periods` 顯隱（沿用 `_on_time_advanced` 邏輯，改作用在 2D 傳送點）。
- 日夜 tint：街景上一層 `CanvasModulate`/`ColorRect`，`modulate` 依 period 調（如上午暖、夜深藍），連 `GameManager.time_advanced`。不另外畫圖。

---

## 流程細節
- **進地圖**：`go_to_map` → `_ready` 載資料 → `show_district(current_area)` → 建傳送點、擺無戒、設 bgm、HUD、補播成就。
- **走進地點傳送點**：無戒走到 → `DistrictScene.location_entered(id)` → `MapScreen.enter_location(id)` → 顯示 `LocationInterior`（隱街景）→ 內景開該地行動選單 → `perform_action`（可能進戰鬥/小遊戲/過場/對話，或留內景）。「離開」→ 回街景原傳送點。
- **走進邊界傳送點**：→ `MapScreen.travel_to(adjacent_area)`（設 current_area → `go_to_map` 重載新區街景）。
- **城市地圖鈕**：街景叫出 `CityMap` → 選區 → `travel_to(area)`。
- **鎖區/鎖點**：城市地圖鎖區 disabled+鎖圖示；鎖定地點（`unlock_flag` 未開）不建傳送點；點鎖區跳 toast。

---

## 退役但保留（不刪檔）
`XimenStreet.gd`、3D `Player.tscn`/`CameraRig.gd`/3D `LocationTrigger`、Meshy 道具 GLB —— 從地圖流程拔掉、檔案留著（故事地標日後仍可能用 Meshy 單物件）。3D 無戒模型轉為 2D sprite 來源。

---

## 防呆 / 錯誤處理
- 圖檔缺（scene_2d/interior_2d/city_map）→ 佔位色塊 + `push_warning`（沿用現有 `_load_environment` 佔位精神）。
- `scene_pos`/`scene_spawn`/`map_pos` 缺 → 預設位置 + warning。
- 鎖區/鎖點 → 隱藏或點了跳 toast。
- 走路中再點別處 → 改道。

---

## 測試
- **Headless `TestMap2D`**：MapScreen 載入；`DistrictScene` 依「區+時段」建出正確傳送點（開放/解鎖閘門）；邊界傳送點 → `travel_to` 換區；`location_entered` → `enter_location` 接線；`CityMap` 鎖區閘門；`LocationInterior` 開出對應 `actions`；`perform_action` 路由（煙霧）。沿用既有測試場景模式（root Node + 腳本，印 PASS/`push_error`+quit）。
- **視窗截圖**：城市地圖 + 3 街景（傳送點+Wujie+時段 tint）+ 走路測試（點傳送點→走過去→進內景）+ 各內景。沿用「視窗 exe 自動截圖 → Read PNG 自我檢查」流程。新圖跑前先 `--import --headless`。

---

## 範圍外 / 日後
- 內景可自由走 + NPC 世界 sprite（現為靜態背景+選單）。
- 日/夜兩版街景圖（現為單張+tint）。
- 前景視差層（現為單張背景）。
- 故事地標（破廟/茶攤）改用 Meshy 單物件 3D 嵌入。

---

## 實作分期（細節留待 plan）
1. **系統先行（佔位圖）**：資料欄位 + 2D MapScreen 骨架 + DistrictScene 捲動 + Wujie sprite（渲染）+ 傳送點 + 走動 + Camera2D → headless + 截圖驗證機制（佔位色塊）。
2. **三層補齊**：城市地圖 + 地點內景 + 邊界傳送點 + 時段 tint + 鎖定閘門。
3. **正式美術**：生成（magnific 為主，人工把關）城市地圖/3 街景/5 內景 → 置換佔位 → 截圖迭代。

---

## 二版更新（2026-06-16，街景改平面長街）

Phase 3 美術全 9 張原本一次生成、使用者初步定調 OK。實際在引擎看過後，使用者對**街景視角**提出修正，三張街景重做。本節為定案，**取代** §設計決策 5、§美術資產 #2、§測試「視窗截圖」中關於街景視角與寬度的舊描述；內景（5 張）與城市地圖未受影響。

### 修正內容
1. **視角：斜角透視 → 正交平面立面。** 初版 prompt 用「side elevation **mild depth**」，模型畫成往深處退、有消失點的街道（「站在街口往裡看」），使用者明確打槍「要平面、斜的沒有往前走的感覺」。定案＝**FLAT ORTHOGRAPHIC SIDE ELEVATION（鏡頭正對店面、建築平行畫面、無消失點、街道不退向遠方）**，像楓之谷/2D 平台遊戲城鎮背景。**prompt 嚴禁出現 "mild depth"。**
2. **長度：21:9 → 約 40:9（2 倍長）。** 使用者要求「長一點」。單張生成比例上限只到 21:9（outpaint 也卡 21:9 且在 higgsfield，額度低），故改**拼接**：尺寸定案 **6036×1344**。DistrictScene 用 tex 寬當 `map_w` 自動捲動，變長零程式改動。
3. **無文字。** 招牌一律抽象霓虹色塊/幾何燈管，prompt 重壓 NO letters/words/Chinese characters/numbers/text/logos。
4. **頂部天空帶。** 為利拼接，建築填滿畫面、頂端只留一條平整均勻暗夜帶（無雲/無漸層/無月），讓兩段頂部一致。

### 長街拼接管線（可重用）
1. 生**錨定段**（21:9）。
2. **用錨定段當 `images_generate` 的 reference image（type:image，傳 creation identifier）生「seamless continuation」延續段**——關鍵步驟：獨立亂生兩張曝光/天色對不上、拼不順；reference-guided 才氛圍一致。延續段一次 `count=2`，挑**頂部黑帶有接起來**的（＝使用者驗收點）。
3. **`python tools/stitch_street.py SEG_A SEG_B OUT [overlap] [preview]`**：色彩匹配（mean/std transfer）＋水平均場校正（flat-field，抹平左右亮度/色溫差）＋交叉淡入（預設 overlap 300）→ 輸出 6036×1344。
   - ⚠ 逐像素混合用 **Python+numpy（PIL）**，不要用 PowerShell（LockBits 會回 null 噴錯爆 log）。
- 各區 palette：西門紫青桃／萬華暖琥珀紅燈籠／林森紅粉洋紅。
- review 中間檔放**專案外** `D:/monk/_map_flat_review/`（避免被 Godot 匯入）；舊斜視角版備份在 `_map_flat_review/_old_perspective/`。

### 驗證
新增 `test/CaptureMapAll.gd/.tscn`（驅動 MapScreen 依序 `show_district(ximen/wanhua_old/linsen)`＋`_on_location_entered("old_temple")`＋`show_city_map()`，各存 `res://_cap_*.png`；先 `set_flag("linsen_unlocked",true)` 才看得到林森）。引擎自截確認 3 街平面感正確、無戒腳踩地面帶、捲動距離翻倍。**日後改地圖美術重跑這支即可；runtime exe 不自動匯入，跑前先 `--import --headless`。**
