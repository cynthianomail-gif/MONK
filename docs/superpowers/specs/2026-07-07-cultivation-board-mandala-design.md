# 修行盤重設計：曼荼羅法輪盤（2026-07-07）

## 背景

使用者：「點擊技能的樹目前長得很怪，參考著名 JRPG 作法優化。」
現況截圖 `_cap_overhaul_board.png` 確認的問題：

1. **盤面縮在畫面左上 1/4**，右下大片空灰（佈局中心/半徑沒吃滿版面）。
2. **節點是無名小圈**，不點開不知道是什麼。
3. **同系節點角度亂跳**（`atk_1`=0°、`atk_2`=120°、`atk_3`=0°），「壹→貳→參」的
   requires 連線橫穿盤面亂繞，樹的脈絡感全無。
4. 連線細到幾乎看不見；詳情面板是一條大半空白的黑柱。

### 使用者拍板（2026-07-07，視覺稿確認）

- **方向＝曼荼羅法輪盤**（FF13 水晶盤放射脈絡 × FFX 晶球盤環狀板面）。
- **範圍＝只優化修行盤**：經書 19 招不併入（習得流程留在 SkillsPage 不動）；
  盤上 3 個技能節點與經書維持現有資料交集（grant_skill），不重構解鎖系統。
- 視覺稿：對話中 SVG mockup（cultivation_board_mandala_mockup），本 spec 據此落字。

## 涉及檔案

- `data/cultivation_board.json` — 只改佈局欄位（angle_deg／新增 radius），
  **cost/requires/effect/unlock_flag/名稱描述一律不動**。
- `src/ui/menu/pages/BoardApp.gd` — 佈局與繪製全面重做（仍純 _draw，不新增圖片素材）。
- `src/autoloads/CultivationBoard.gd` — 原則上不動（四態判定/解鎖邏輯不變）；
  若 BoardApp 需要新查詢 helper 才加。

## 設計

### 1. 資料佈局：四脈放射（改 cultivation_board.json）

角度慣例依 BoardApp 現行極座標換算為準（實作前先確認 0° 對應方向，下表以
「螢幕方位」描述意圖）：

| 脈 | 方位 | 節點鏈（由內而外） |
|---|---|---|
| 剛（金剛力） | 上 | atk_1 → atk_2 → atk_3 → atk_4 → atk_5 → master_atk |
| 體（金身） | 右 | hp_1 → hp_2 → hp_3 → hp_4 → hp_5 → master_hp |
| 迅（疾風步） | 下 | spd_1 → spd_2 → spd_3 → spd_4 → master_spd |
| 柔（羅漢身） | 左 | def_1 → def_2 → def_3 → def_4 → def_5 → master_def |

- **同鏈同角度、半徑遞增**。同一 ring 內有多個同鏈節點（如 atk_1/atk_2 都在
  ring1），改用**每節點自帶 `radius` 欄位**（新增，選填）：BoardApp 佈局時
  `radius` 優先於 ring 預設半徑。ring 欄位保留＝解鎖分層/師鎖 flag 判定不變。
- 半徑序列（1080p 基準，實作可微調）：壹 100、貳 155、參 210、肆 260、伍 310、
  師鎖環 380。核心 core 半徑 0。
- **技能節點＝旁枝**：從前置節點斜出 ~25–35°、半徑略外推——
  skill_vajra_fist 掛 atk_1（上偏左）、skill_stillness 掛 hp_1（右偏下）、
  skill_beggars_stride 掛 spd_1（下偏左）。
- **匯流被動居兩脈之間**：passive_iron_will（requires atk_3+def_4）放上左對角
  ~r240；passive_one_more_edge（requires spd_3+hp_3）放下右對角 ~r240；
  master_passive（印可）放師鎖環上兩被動之間的對角位。
- 佈局驗收基準：任何 requires 連線不得穿過無關節點；同脈連線是一條直線。

### 2. 繪製重做（BoardApp.gd）

- **滿版置中**：盤面中心＝盤區（扣掉右側面板後的區域）正中；
  整體 scale 依視窗高度自動算，讓師鎖環＋外圈標籤剛好吃滿（修現況縮左上 bug 的根因）。
- **節點形狀編碼**：
  - 屬性 stat＝圓（r13）
  - 技能 skill＝菱形（rotated square，明顯大一號）
  - 匯流被動 passive＝同心雙圓
  - 師鎖環節點＝紫虛線圓（沿用現有 _draw_dashed_circle）
  - core＝大金圓＋「本心」字樣
- **四態視覺**（沿用現有色語彙，加強）：
  - 已解鎖：朱紅實心＋金框；沿途連線亮金加粗（3px）
  - 可解鎖：金框＋**呼吸脈動**（外圈 arc 以 Tween 循環縮放/淡出；available 節點常駐）
  - 未達前置：灰框灰字；連線灰細（1.5px）
  - 師鎖：紫虛線；連往師鎖環的線用虛線
- **名字常駐**：每節點旁 12–14px 名字，顏色隨狀態；上下脈標籤靠右排、
  左脈靠左排（text-anchor end）、右脈上下交錯，避免壓線。
- **師鎖環**：r380 紫虛線整圈＋環頂標語「了塵傳・師鎖環（完成師父試煉開啟）」。
- **選中**：暖白外圈（沿用）＋節點微放大。
- 保留：長按 E 充能弧、_bloom_node 解鎖綻放、點選查詳情。
- 不做：平移/縮放（27 節點 1080p 塞得下）；圖片素材（維持純 _draw）。

### 3. 詳情面板收緊

固定結構由上而下：類型 badge（技能/屬性/被動/師鎖，金底）→ 節點名（22px）→
描述 → 分隔線 → 花費（右對齊金字）→ 前置清單（達成 ✓ 綠／未達 ✗ 灰，逐條）→
充能進度條＋「按住 [E] 灌注解鎖」→ 分隔線 → **圖例常駐**（四態＋形狀說明）。
面板高度包內容即可，不再撐整條黑柱。

## 驗收條件

1. cultivation_board.json：僅 angle_deg 變動＋新增 radius 欄位；
   diff 證明 cost/requires/effect/unlock_flag/name/desc 零變動。
2. 四脈直線：headless 測試斷言每條鏈的節點換算座標共線（同角度）、半徑嚴格遞增、
   全部節點落在視窗內、盤面中心位於盤區中心 ±10px。
3. 節點形狀/名字/四態/脈動/師鎖環如第 2 節（GPU 截圖親驗）。
4. 既有測試零新增 FAIL（含 CultivationBoard 相關測試與 TestMenuSystem 等，
   改動前先跑基準）。解鎖流程行為不變：長按 E 解鎖、道行扣款、grant_skill 技能
   節點照常入經書。
5. GPU 截圖交付：`_cap_board_v2_full.png`（全盤四態）＋
   `_cap_board_v2_selected.png`（選中一個可解鎖技能節點含面板）。
6. 不 commit；不留舊佈局殘碼。

## 不在範圍（明列）

- 經書 SkillsPage 改版／19 招併盤（使用者明確拍板不做）。
- 平移縮放、圖片素材、經書外殼正式美術（MenuShell 佔位框另案）。
