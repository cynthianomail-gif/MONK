# 端湯小遊戲改版：2D 俯視限時送味增湯 — 設計

日期：2026-06-24
狀態：設計核可（待寫實作計畫）
關聯：`src/screens/Minigames/MinigameBase.gd`（result 契約 id/score/win/gold/merit/karma、`make_result`/`finish`）、`SceneRouter.go_to_minigame("soup_carry")`→`SoupCarry.tscn`、`src/ui/menu/pages/JobApp.gd`（105 打工入口）、okami 俯視美術 `assets/art_direction/new_ink_shrine_style/minigames/`。

## 目標
把現行「端湯**上塔**」（滑鼠傾斜碗、爬 10 層）整個換成 **2D 俯視限時送桌**：玩家操作無戒在壽司店端味增湯，限時內盡量送更多桌，依送達時的灑出量結算收入。**保留同 minigame id `soup_carry`、同 `SoupCarry.tscn`、同 MinigameBase 整合**，只改玩法。

## 決策（與使用者確認）
1. 視角＝**2D 俯視、整張地圖一個畫面**（2752×1536 地圖 fit 進畫面，不捲動相機）。
2. 操作＝**WASD/方向鍵八向移動**（舊版滑鼠傾斜廢除）。
3. **晃動由玩家加速/急停/急轉驅動**（非原始速度）＝核心技巧是規劃平滑路線、轉角放慢；設 deadzone，平穩移動幾乎不晃。
4. v1 範圍＝核心 ＋ **緩步鍵** ＋ **濕滑地板區**；**不做移動 NPC 顧客**（之後再加）。
5. 淨收入 → **result.gold**（`finish`→`SceneRouter.finish_minigame` 自動套獎勵）。
6. 一局 **75 秒**。

## 架構（元件、各自單一職責）
重寫 `SoupCarry.gd`（extends MinigameBase）；**純邏輯抽成可測函式**（沿用現有 SoupCarry/step_physics 模式）。
- **玩家移動**：Sprite2D（俯視端湯無戒）＋ 速度/加速度（八向、加速/減速）＋ 緩步鍵（按住 = 慢速上限 + 晃動大減）。`player_acceleration` 每幀算出供晃動用。
- **湯模型（純邏輯）**：`soup_amount`(初 100)、`soup_slosh`、`soup_velocity`、`collision_penalty`。
- **桌/障礙/濕滑區**：4–6 張桌（靜態）、靜態障礙（椅/吧台角）、1–2 塊濕滑地板區（Area2D，踩到調 slosh_factor）。位置對齊 Codex 地圖的吧台/桌位/走道。
- **目標系統**：隨機指定目標桌（HUD 箭頭/高亮）；送達該桌（玩家進入桌的互動範圍）→ 結算 → 回出餐口拿下一碗 → 指定下一桌。
- **計時/HUD/總結算**：75s 倒數、遊戲中 HUD、結束總結算畫面。

## 湯晃動（數值模擬，不做流體）
```
soup_velocity += player_acceleration.length() * slosh_factor   # 急停/急轉=加速度大→晃大
soup_velocity *= damping                                       # 逐漸衰減
soup_slosh    += soup_velocity
if abs(soup_slosh) > spill_threshold:
    spill = (abs(soup_slosh) - spill_threshold) * spill_rate
    soup_amount -= spill                                       # clamp >= 0
```
- **deadzone**：加速度小於某值幾乎不加 velocity（平穩走安全）。
- **緩步鍵**：按住 → 移動速度上限降低 + `soup_velocity` 衰減加快/slosh_factor 降 → 過彎窄路的工具，犧牲時間。
- **濕滑區**：在 Area2D 內 → slosh_factor 加大（控制變難）。
- **碰撞**（撞桌/障礙/牆）：`soup_velocity += bump`、`collision_penalty += 10`。
- 視覺：碗 sprite 依 soup_slosh 傾斜 ＋ **晃動 meter（綠/黃/紅）**＝玩家即時看到快灑了好放慢（可玩性關鍵）。

## 送達結算（照使用者 spec）
```
spill_percent = 100 - soup_amount
base = 100
penalty = spill_percent
if spill_percent >= 70:   payout = 0; failed_count += 1
elif spill_percent >= 40: payout = base*0.5 - penalty
else:                     payout = base - penalty
if spill_percent <= 5:    payout += 20                 # 完美 bonus
# 連續 3 碗 spill_percent < 10：payout += 50（streak 繼續累積，每滿 3 給一次）
payout = max(payout - collision_penalty, 0)            # 收入不低於 0
```
每送一碗後重置 `soup_amount=100`/`soup_slosh`/`soup_velocity`/`collision_penalty`，指定下一桌。

## 結算畫面
顯示：送達碗數、作廢碗數、總灑出%（平均或總和）、碰撞扣款、bonus 合計、**淨收入**、評價文字：
- 淨收入 ≥700：神之端湯 ｜ ≥500：穩如老僧 ｜ ≥300：勉強上工 ｜ <300：湯比業障還重

淨收入 → `make_result({score: 淨收入, win: 淨收入>=300, gold: 淨收入, merit: ...})`（merit 給小量或 0，依評價）。

## 美術
- 背景＝`minigame_sushi_shop_topdown_map_concept.png`（2752×1536，吧台/桌位/中央走道）fit 螢幕。
- 玩家＝`minigame_wujie_topdown_carry_soup_game_ready.png`（1254×1254 透明，3/4 俯視端湯）；移動時可水平翻面表示左右。
- 桌/障礙/濕滑區先用地圖上的視覺位置 + 程式 Area2D/CollisionShape 對位（第一版可用半透明 placeholder 框標示互動範圍，不另做美術）。

## 測試
- **純邏輯單元測**（headless，extends Node，沿用 SoupCarry 測試風格）：①晃動 step：大加速度連續幾幀 → soup_amount 下降；平穩 → 幾乎不降。②結算 payout：各門檻（<5/ <40/ 40-70/ >=70）算對、完美 bonus、streak +50、collision_penalty 扣到 0 不負。③總結算 tally 正確。
- **windowed 截圖**：地圖 + 無戒 + 碗 + HUD（時間/收入/目標/湯量/晃動 meter）渲染正常、無 SHADER/SCRIPT ERROR。
- **回歸**：`TestMenuSystem`（JobApp 改描述後仍 ALL PASS）、minigame 啟動/結束流程（`finish`→回地圖）。

## 整合
- `JobApp.gd` 的 soup_carry 描述「把熱湯端上塔頂…」→「限時把味增湯送上桌，別灑出來」。
- `finish(result)` 走既有 MinigameBase→SceneRouter 流程，gold=淨收入自動入袋。

## YAGNI（v1 不做）
- 移動 NPC 顧客（動態障礙/路徑，之後再加）。
- 真實流體（數值模擬即可）。
- 複雜動畫（碗傾斜 sprite + 晃動 meter 足矣）。
- 多關卡/難度曲線（單局 75s）。
