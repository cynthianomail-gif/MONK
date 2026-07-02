# Codex 生圖 handoff — 軍火庫地下遊藝場 5 個小遊戲美術（共 12 張）

日期：2026-07-02
給：Codex（場景/道具美術生成）
落點：`MONK/assets/art_direction/new_ink_shrine_style/minigames/parlor/`（新資料夾，跟既有 minigames 圖分開放，方便管理）

## 背景設定（先讀，決定整體美術基調）

這 5 個小遊戲（飛鏢/輪盤/21點/棒球/保齡球）要包成同一個地點：**軍火庫區的地下遊藝場**——萬神殿集團暗地經營的賭場/遊藝間，黑吃黑諷刺點（正派反派表面辦企業，私下開賭場）。

**美術基調沿用 ArmoryDistrict 既有調性，不是神社街的水墨基調**：暗鋼鐵色調、紅燈籠暖光、鐵皮/工業感、略帶頹廢的地下賭場氛圍。**不要用神社街那種淺墨平靜的畫風**。

參考既有場景圖鎖住方向：
- `D:\monk\_art_review\_armory_district_okami_test.png`（軍火庫街景基調）
- `D:\monk\_art_review\_ares_armory_okami_v3.png`（軍火庫氛圍/光色）
- `D:\monk\MONK\assets\2d\backgrounds\bg_battle_ares_forge.png`（軍火庫戰鬥背景，暗調+暖光參考）
- `D:\monk\MONK\_armory_scene_shot.png`（引擎內實拍，鋼鐵灰調+紅燈籠+暖光窗口，最準的顏色參考）

風格關鍵字（每張都要帶）：**大神 okami 水墨/厚塗風格、暗鋼鐵冷色底+暖橘/紅局部光、game-ready、與現有軍火庫美術同一條線，不可畫風漂移**。

## 輸出檔格式（比照既有慣例）

背景類（無需去背，直接矩形圖）：RGB，長邊 ≥ 2048px，16:9 或接近。
道具/物件類（需要疊在遊戲畫面上、可能會動/旋轉）：**透明底 PNG(RGBA)**，主體置中，四周留適當邊距方便程式抓 AABB。

每個「需去背」項目請比照既有雙檔慣例出 2 檔：
```
<name>_source_chromakey.png   # 綠幕/純色底生成原檔
<name>_game_ready.png         # 去背透明成品
```
背景類只需 1 檔（`<name>_bg.png`，不用去背）。

---

## 要生什麼（12 張，5 個小遊戲＋1 張共用背景）

### 0. 共用場景基調（1 張，最優先，決定其他 11 張的光色）
| 檔名 | 說明 |
|---|---|
| `parlor_bg_wide.png` | 遊藝場室內全景：暗鋼鐵牆+紅燈籠+霓虹招牌(可寫意漢字招牌如「賭」「遊藝」)+多台賭具錯落佈置的氛圍圖。當作五個小遊戲的共用視覺定調，之後個別遊戲背景可從這張延伸裁切/重繪局部。16:9，RGB，不用去背。 |

### 1. 飛鏢（2 張，需去背）
| 檔名 | 說明 |
|---|---|
| `darts_board_game_ready.png` | 標靶正面，掛在鐵皮牆上，油污做舊質感，靶心明顯（判定用）。含 source_chromakey 版。 |
| `darts_dart_game_ready.png` | 單支飛鏢，小物件，會被拋出用（尾羽+針頭清楚）。含 source_chromakey 版。 |

### 2. 輪盤（2 張，需去背）
| 檔名 | 說明 |
|---|---|
| `roulette_wheel_top_game_ready.png` | 輪盤俯視圖，含數字格（0-36 或簡化版），會用程式旋轉，**正圓、置中**方便旋轉不跑位。含 source_chromakey 版。 |
| `roulette_ball_game_ready.png` | 小白球，含 source_chromakey 版。 |
| 桌面/下注格用程式畫格線+文字，不用生 |  |

### 3. 21點（2 張，需去背）
| 檔名 | 說明 |
|---|---|
| `card_back_game_ready.png` | 卡背設計，統一花紋（可帶遊藝場 logo/水墨紋樣），矩形直式標準撲克牌比例。含 source_chromakey 版。 |
| `card_frame_blank_game_ready.png` | 空白卡面框（邊框+底紋，**中央留白**），點數/花色之後用程式疊文字，**不要生 52 張牌**——省生圖量、之後改動靈活。含 source_chromakey 版。 |

### 4. 棒球（打擊場式，3 張，需去背）
| 檔名 | 說明 |
|---|---|
| `batting_bg.png` | 打擊籠背景：鐵網圍籠+投球機，軍火庫工業風。不用去背，16:9。 |
| `baseball_ball_game_ready.png` | 球，含 source_chromakey 版。 |
| `batting_hands_game_ready.png` | 第一人稱雙手持棒視角，**沿用既有「第一人稱手部」構圖**（參考 `minigame_first_person_wujie_hands_game_ready.png` 的視角/裁切），只是手上换成球棒。含 source_chromakey 版。 |

### 5. 保齡球（3 張，需去背）
| 檔名 | 說明 |
|---|---|
| `bowling_lane_bg.png` | 球道背景，第一人稱往球瓶方向看的視角，軍火庫風格球道。不用去背，16:9。 |
| `bowling_pin_game_ready.png` | 單支球瓶（程式會複製排列成 10 支），含 source_chromakey 版。 |
| `bowling_ball_game_ready.png` | 球，含 source_chromakey 版。 |

---

## 優先順序建議

若要分批生，建議順序：
1. `parlor_bg_wide.png`（先定調，其他都靠它抓光色）
2. 飛鏢 2 張（最簡單，先跑通一輪去背/接引擎流程）
3. 剩下輪盤/21點/棒球/保齡球 9 張

## 交回後我（Claude）會做

拿到 `game_ready` 透明檔＋背景圖後，比照既有 `MinigameBase` 框架（見 `OfferingToss.gd` 的作法）接進 5 個新小遊戲場景，換掉目前規劃中的純程式幾何佔位、接 `map_npcs.json` 在軍火庫區加對應互動點。先丟 1-2 張看風格對不對齊，再補其餘的也可以。

---

### 附：非 Codex 工作（記著就好，不用生圖）
- 5 個小遊戲的邏輯/計分/場景組裝＝我寫程式，不需要美術。
- 麻將/象棋/德州撲克三個高複雜度候補，這輪先不做，之後真要做再另開 handoff。
