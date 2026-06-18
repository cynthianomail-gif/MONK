# 手機選單 app 設計 spec — 移動／105 打工／設定（選單階段 2）

> ✅ **已實作並驗證 ALL PASS（2026-06-17）**，依 plan `../plans/2026-06-16-phone-apps.md` subagent-driven 8 task 全跑完。實作結果＋latent 待辦見記憶 [[project-phone-apps]] 與 `PROJECT_STATUS.md`。

日期：2026-06-16
關聯：[[project-build-status]]、[[project-monk-game]]、前作 spec `2026-06-14-menu-system-design.md`（階段 1：MenuShell＋經書）。

## 願景與範圍
補完手機（入世）裝置的剩餘 app。沿用 `MenuShell` 既有外殼與 `MenuDevice` 頁面契約（每頁＝一個 `Control`，外殼只管頁籤）。**DEMO 範圍＝第一章**，不引入未來章節內容。

**頁籤變更**：手機目前 `任務 / 情報 / 移動 / 其他(佔位)` → 改為 **`任務 / 情報 / 移動 / 打工 / 設定`**（5 頁）。
- `任務`(QuestsApp)、`情報`(IntelApp) 不動。
- `移動`：升級現有免費 FastTravelApp ＝ **捷運＋計程車兩區塊合一**（使用者拍板：合併，不拆成兩個獨立頁籤）。
- `打工`：新增 105 打工板。
- `設定`：新增；取代 `其他` 佔位。

## A. 移動 app（TravelApp，取代 FastTravelApp）
單一頁面，上下兩區塊：

### 🚇 捷運（cheap + 慢）
- 目的地＝3 個**區中心**：列 `areas.json` 中已解鎖區（沿用既有 `unlock_flag` 過濾），目前所在區的鈕 disabled 標「（目前）」。
- 成本：**5 金**（`MAINTENANCE`：常數 `MRT_FARE=5`），**耗 1 時段**（`GameManager.advance_time(1)`）。
- 行為：`spend_gold(5)` 成功 → `advance_time(1)` → 解除選單暫停 → `map.travel_to(area_id)`（沿用既有：內部 `go_to_map` 換場、連選單一起釋放）。金不夠：鈕 disabled 或按下顯示「金幣不足」提示，不扣款不移動。

### 🚕 計程車（expensive + 快）
- 目的地＝任一**已解鎖、當前可用地點**：列 `map_locations.json`，依 `unlock_flag`（解鎖）＋ `available_periods`（含當前 `player.period`）過濾。標所屬區名。
- 成本：**30 金**（`TAXI_FARE=30`），**不耗時**。
- 行為：`spend_gold(30)` 成功 → 設 `GameManager.pending_arrival = {"area": <該地點 district>, "x": <該地點 scene_pos.x>}` → 解除暫停 → `map.travel_to(該地點 district)`。地圖重載後讀 `pending_arrival` 把無戒生在該地點門口（見 §D）。金不夠同上。
- 註：DEMO 不做距離計費（YAGNI），統一車資；常數易調。

## B. 105 打工 app（JobApp）
- 打工板列**兩工**：`端湯（soup_carry）`、`化緣（beggar_challenge）`。木魚節奏＝街頭藝人對話觸發，不進板（沿用既有定調）。
- 每工成本：**耗 1 時段**（`advance_time(1)`），無金錢門檻。
- 行為：選工 → 解除暫停 → `advance_time(1)` → `SceneRouter.go_to_minigame(id)`。獎勵走小遊戲既有 intrinsic（gold/merit/karma 由 `finish_minigame` 套用），打工板不另給 context 獎勵（context 留空）。
- 板上每工顯示名稱＋一句說明＋「耗 1 時段」標註。

## C. 設定 app（SettingsApp）＋ SettingsManager
### SettingsManager（新 autoload）
- 檔：`src/autoloads/SettingsManager.gd`。存讀 `user://settings.cfg`（`ConfigFile`，**獨立於存檔**＝全域偏好，不隨 SaveManager 走）。
- 鍵與預設：`master_vol=1.0`、`bgm_vol=1.0`、`sfx_vol=1.0`（linear 0~1）、`fullscreen=false`、`text_speed=1.0`（倍率，0.5~2.0）。
- API：`get_setting(key)`、`set_setting(key,val)`（即時套用＋寫檔）、`apply_all()`。
- `apply_all()`（開機於 `_ready` 呼叫一次）：套音量 bus、視窗模式、Dialogic 文字速度。
- autoload 順序：排在 AudioManager 之後（apply 音量需 bus 已建）。

### AudioManager 補音量 bus
- 新增 `default_bus_layout.tres`：`Master → {BGM, SFX}`（BGM/SFX 為 Master 子匯流排）。於 project.godot `audio/buses/default_bus_layout` 指定。
- AudioManager 場景：`BGMPlayer.bus="BGM"`、`SFXPlayer.bus="SFX"`、`VoicePlayer.bus="SFX"`（語音併 SFX 條，維持使用者要的 3 條滑桿）。
- 新 API：`set_bus_volume_linear(bus_name:String, linear:float)`（`AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear,0,1)))`；0 時設 mute 或 -80dB）、`get_bus_volume_linear(bus_name)`。
- 相容性：`switch_bgm`/`fade_bgm_to` 仍操作 `bgm_player.volume_db`（fade）；bus 音量與 player volume_db **相加**，互不衝突。

### SettingsApp 頁面
- 檔：`src/ui/menu/pages/SettingsApp.gd`。
- 元件：主音量／BGM／SFX 三條 `HSlider`（0~1）即時套 `SettingsManager.set_setting`；全螢幕 `CheckButton`；文字速度 `HSlider`（0.5~2.0）。
- 樣式沿用 MenuShell 暗金×黑佔位風（GOLD/DIM 常數）。

### 文字速度接線
- 套用對象＝Dialogic 對話文字速度（DEMO 文字大宗）。`apply_all()` 依 `text_speed` 設 Dialogic 文字速度（實際 API 於實作期確認：Dialogic 2 經 Text 子系統／設定暴露；以「每字延遲 ÷ 倍率」換算）。
- **過場字幕（StoryCutscene 的打字機 cps）維持電影級固定節奏，不受此設定影響（YAGNI，避免動到開場精調的時間軸）。**

## D. 計程車落點（GameManager + MapScreen + DistrictScene）
- GameManager 加**暫存欄位**（不寫進 player dict、不存檔）：`var pending_arrival: Dictionary = {}`（如 `{"area":"ximen","x":0.66}`）。
- MapScreen `_ready`：`show_district` 後，若 `GameManager.pending_arrival` 非空且 area 與當前區相符 → 取 `x` 傳給 DistrictScene 當 spawn 覆寫，然後 `pending_arrival.clear()`（一次性）。
- DistrictScene：`setup(...)` 或新增 `set_spawn_x(frac)`——把無戒水平生在 `_map_w * frac`（地點 portal 處），y 維持地面帶。捷運（無 pending_arrival）走原 `area.scene_spawn` 預設。
- 邊界：pending area 與實際載入區不符（理論上不會）→ 忽略，走預設 spawn。

## 架構邊界
- 移動／打工／設定頁面只讀寫 GameManager / SettingsManager / SceneRouter，**不反向改 MenuShell**（沿用 `menu_shell` group + `close()` 或既有 `travel_to` 模式）。
- SettingsManager 為單一真相源：所有設定的讀寫與套用集中於此；AudioManager 只提供 bus 音量 setter，不知道「設定」概念。
- 移除舊 `FastTravelApp`（被 TravelApp 取代）與 MenuShell 的 `_placeholder` 其他頁。

## 測試（headless 擴充 `test/TestMenuSystem.tscn`）
- **車資/時間**：捷運成功扣 5 金、period +1；計程車扣 30 金、period 不變、`pending_arrival` 被設；金不足時不扣款。
- **打工**：選工後 period +1（go_to_minigame 在 headless 用存在性判定，不真換場）。
- **SettingsManager**：set→get 往返、寫檔後重讀一致（用臨時 user:// 路徑或讀回驗證）；`apply_all` 後 bus 音量為設定值。
- **AudioManager bus**：`set_bus_volume_linear("BGM",0.5)` → `get_` 約等 0.5（dB↔linear 容差）。
- **smoke**：TravelApp/JobApp/SettingsApp 能 instantiate、MenuShell 手機 5 頁切換不崩。
- 跑法：`Godot --headless res://test/TestMenuSystem.tscn` → `MENU_TEST: ALL PASS`。

## 不做（YAGNI / 範圍外）
- 計程車距離計費、捷運路線圖視覺化。
- 過場字幕受文字速度影響。
- 設定的按鍵重綁、語言切換。
- 手機 app 正式美術圖示（沿用程式佔位；正式圖之後抽換）。
