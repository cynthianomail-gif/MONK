# 西門商圈垂直切片 — 可走的卡通台北街景

**日期：** 2026-06-13
**專案：** 《和尚逆天》Monk Go Rogue
**狀態：** 設計已核准，待寫實作計畫

---

## 1. 目標

做出一塊「一看就是台北」的可走街區 —— **西門商圈**（含「捷運西門站 6 號出口」與「萬年商業大樓」兩個既有地點）。

此切片的用途是**驗證整套地圖管線**：

1. 資料驅動的模組街道組裝
2. 區間移動（分區街景之間切換）
3. 街上的互動點（沿用既有 LocationTrigger）

並且必須**用 placeholder 幾何體即可在 Godot 走動測試** —— 不依賴任何 Meshy 資產就能跑。之後把真實 `.glb` 換進來時，**不需要改任何程式碼**，只改資產清單路徑。

---

## 2. 已確定的設計決策（brainstorm 結論）

| 決策 | 選擇 | 理由 |
|------|------|------|
| 還原程度 | **風格化連續街區**（卡通台北） | 符合既有 toon shader 風格；在「像台北」與「獨立開發可行」間最平衡 |
| 空間結構 | **分區街景 + 區間移動**（人中之龍式） | 貼合 GDD 三區（西門/萬華/林森北）獨立氛圍設定；規模可控、記憶體友善 |
| 製作管線 | **混合**：Meshy 出地標 + 模組零件填街 | 善用 Meshy 單棟強項，用模組零件解決「整條街」難題，零件三區可重用 |
| 本輪範圍 | **西門垂直切片** | 風險最低、最快看到成果；驗證管線後再複製到其他兩區 |

---

## 3. 架構與組件

### 3.1 資料驅動街道組裝器 `StreetBuilder.gd`

- 位置：`src/screens/MapScreen/StreetBuilder.gd`
- 職責：讀取一份街道布局 JSON，沿街自動實例化「店面模組 + 招牌 + 道具（機車/攤販/燈籠等）」。
- 原則：**街道 = 資料**，而非手工擺放的節點。三區共用同一個組裝器，只換布局資料。
- 輸入：街道布局檔（見 3.4）+ 零件清單（見 3.3）。
- 輸出：一個 StreetRoot 子樹（含視覺體與靜態碰撞）。

### 3.2 零件清單 `data/street_kit.json`

- 登記所有可用的模組與道具，每個項目對應一個 scene/mesh 路徑。
- **placeholder 階段**：路徑指向程式生成或簡易的 toon 方塊/平面。
- **資產到位後**：把路徑改成 Meshy 生成的 `.glb` 即可，零程式改動。
- 每個項目附帶：類別、預設尺寸、碰撞型別、對應的 Meshy prompt（供使用者生成）。

### 3.3 「台北味」零件庫

讓街道像台北的關鍵不是建築本身，而是堆滿的細節。零件庫至少包含：

- **結構類**：店面模組（含騎樓柱 arcade）、樓層立面
- **招牌類**：層疊鐵皮招牌、直式招牌、霓虹招牌
- **窗飾類**：鐵窗（窗花）、冷氣機、頂樓水塔
- **街道道具**：成排停放的機車、路邊攤（滷味/小吃）、紅燈籠、電線桿與電線、雜物/資源回收堆、紅白塑膠椅

每個零件在 `street_kit.json` 中各有一筆，並附 Meshy prompt。

### 3.4 街道布局檔 `data/streets/ximen.json`

- 描述西門商圈這條街的：街段（segments）、每段使用哪些店面模組、招牌堆疊、道具擺放點與位置/旋轉、地點觸發點落在哪、區間移動點位置。
- 由 `StreetBuilder` 讀取生成。

### 3.5 西門 District 場景

- 位置：`src/screens/MapScreen/districts/XimenDistrict.tscn`（Node3D）
- 內容：
  - `StreetRoot` — 由 StreetBuilder 在 `_ready` 組裝
  - Player 出生點
  - 兩個既有 LocationTrigger：捷運西門站 6 號出口、萬年商業大樓（資料來自 `map_locations.json`）
  - 區間移動點（見 3.6）
  - 該區專屬：DirectionalLight/環境、BGM（`ximen_night` / `ximen_day`）、霧氣氛圍

### 3.6 區間移動系統

- 一個「搭車/捷運」互動點。玩家互動後開啟目的地選單，短載入轉場切換到目標 District 場景。
- 記錄並還原**每區各自**的玩家位置（擴充 GameManager.player 的位置儲存為 per-district）。
- 本輪萬華、林森北為 **stub 目的地**：可切換過去，呈現一個最小 placeholder 場景 + 折返點，不需完整街景。
- 實作上擴充既有 `SceneRouter`（新增 `go_to_district(id)`），不另造平行系統。

### 3.7 與現有系統整合

- **重構 MapScreen**：現況是單一 `MapScreen.tscn`（Node3D）載入 `map_locations.json` 全部觸發點。改為每區一個 District 場景，各區只載自己的觸發點。
- `map_locations.json`：每筆地點已有 `district` 欄位，沿用它做分組；新增「該地點屬於哪個 district 場景」的對應（可由 district 欄位推得）。
- **沿用不動**：`LocationTrigger`、互動選單（MapHUD）、`perform_action`、`advance_time`、隨機遭遇、存檔位置邏輯。
- **完全不碰**：戰鬥（BattleScreen）、支線（QuestManager）、對話（Dialogic）。

---

## 4. Placeholder 策略

- 零件清單中所有視覺體先以 **toon-shaded 基本幾何**（方塊、平面、加文字標籤）呈現，讓街道立即可走、可看出布局。
- 既有 Toon Shader 套用到 placeholder，維持視覺一致性。
- 資產替換流程：使用者用 Meshy 生成 `.glb` → 放入 `assets/3d/environments/` 與 `assets/3d/props/` → 修改 `street_kit.json` 對應路徑 → 重開場景即生效。

---

## 5. Meshy 產出（供使用者生成）

- **地標**：精修 `萬年商業大樓`、`捷運西門站 6 號出口` 既有 prompt，使其與模組相容（背面平整、比例一致、適合貼街）。
- **零件**：為 3.3 零件庫每項新增 Meshy prompt，寫入 `data/meshy_prompts/`（環境/道具）。
- 全部標註建議的 `godot_scale` 與 `toon_shader: true`。

---

## 6. 驗收條件

在 Godot 編輯器內：

1. 開啟西門 District 場景，placeholder 街景可見（建築、招牌、機車、攤販、燈籠等沿街排列）。
2. 玩家可自由走動於整條西門街。
3. 走到「捷運西門站」「萬年大樓」兩個觸發點，互動選單正常開啟。
4. 區間移動點可切換到萬華/林森北 stub 場景並折返，玩家位置正確還原。
5. 既有戰鬥/支線/對話入口不受影響。

---

## 7. 範圍邊界（YAGNI）

- 本輪**只做西門**；萬華、林森北僅為 stub 移動目標。
- 不需要任何真實 Meshy 資產即可通過驗收（全靠 placeholder）。
- Meshy prompt 與零件清單一併產出，使用者之後照單生成。
- 不做：無縫開放世界、場景串流、晝夜系統視覺變化（時間系統僅沿用既有氛圍切換）、NPC 走動 AI。

---

## 8. 受影響/新增檔案一覽

**新增**
- `src/screens/MapScreen/StreetBuilder.gd`
- `src/screens/MapScreen/districts/XimenDistrict.tscn`（+ 對應 `.gd`，若需要）
- `data/street_kit.json`
- `data/streets/ximen.json`
- 萬華/林森北 stub District 場景（最小）

**修改**
- `src/screens/MapScreen/MapScreen.gd`（重構為分區載入，或改由 District 場景承接其職責）
- `src/autoloads/SceneRouter.gd`（新增 `go_to_district`）
- `src/autoloads/GameManager.gd`（per-district 位置儲存）
- `data/map_locations.json`（確認 district 分組對應）
- `data/meshy_prompts/environments.json`（精修地標 + 新增零件 prompt）

**不動**
- BattleScreen / QuestManager / Dialogic 相關全部
