# 鄭媽佛具店 · 道具＋背包＋戰鬥道具 設計 spec

日期：2026-06-17
關聯：[[project-build-status]]、[[project-monk-game]]、[[project-phone-apps]]（金幣經濟＝計程車/捷運/打工）、[[project-skill-learning-system]]（同期經書習得）。
既有 spec：`2026-06-14-menu-system-design.md`（暗金×黑 UI 風格、overlay 慣例）。

## 願景與範圍

接上 `MapScreen.perform_action` 兩個死按鈕之一的 **`shop`**（萬年大樓·鄭媽佛具店，目前 toast「此功能尚未實作」）。`zheng_ma` 支線完成時已設 `zheng_ma_shop_unlocked` 旗標、cross_effect 講好賣**護身符／業障結晶**——把這個鉤子兌現成可玩的循環：**賺金幣（打工/化緣/支線/戰鬥）→ 鄭媽店買消耗道具 → 戰鬥中用**，給金幣一個有意義的去處（目前只花在計程車/捷運），並讓戰鬥更耐打。

**範圍邊界（拍板）：**
- 道具**主要在戰鬥中用**（加「道具」指令），複用 `SkillExecutor`/`Combatant` 既有效果機制。
- 商店**只買不賣**（DEMO，YAGNI）。
- 道具**自我施放、消耗一回合、不選敵、不觸發 One More**（連擊）。
- 商店要先完成鄭媽支線（`zheng_ma_shop_unlocked`）才開。
- 只做系統＋鄭媽店一間；不做裝備槽/被動裝備（純消耗品）。
- 不動既有 `perform_action` 的「每個地圖動作推進一時段」慣例——開商店**同樣推進一時段**（與 save/rest 一致）。

## 現況（已探查確認）

- `MapScreen.perform_action(action)`（`src/screens/MapScreen/MapScreen.gd:90`）：開頭 `hud.hide_action_menu()` + `GameManager.advance_time(1)`，再 `match action`。`"shop", "skill_learn":` 共用 toast「此功能尚未實作」（line 123-124）。`shop` 動作掛在 `map_locations.json` 萬年大樓（line 13）。
- **全專案無道具/背包系統**（grep `inventory`/`items`/`add_item` 在 src 無命中）。`GameManager.player` 是 Dictionary，SaveManager 整包存→新欄位自動持久化。`GameManager` 有 `spend_gold(v)->bool`（line 105，不足回 false）/`add_gold`/`add_karma`/`add_merit`/`heal`。
- 戰鬥效果機制（`SkillExecutor.gd`）：護盾＝`caster.add_buff("golden_body", shield_value, duration)`（傷害結算時於 `_apply_damage` 吸收，line 107-111）；回血＝`caster.heal(value)`；淨化＝`status.clear_negative(caster)`；加業障＝`GameManager.add_karma(value)`。
- 戰鬥玩家回合（`BattleManager.gd`）：`_begin_player_turn()` → `ui.show_skill_menu(available_skills())`。`BattleUI.show_skill_menu(skill_ids)`（`BattleUI.gd:71`）把技能列成 VBox 按鈕。非弱點技能結算＝`_process_result` 走 `_enemy_turn()`。`player_combatant` 為 `Combatant`，戰末 `_victory`/`_defeat` 會 `GameManager.player.current_hp = player_combatant.current_hp` 同步回存檔。
- overlay 慣例（`MenuShell.gd`）：CanvasLayer/Control `process_mode = ALWAYS`、`get_tree().paused = true`、`cancel` 關閉、程式建暗金×黑框（`GOLD/NEAR_BLACK`）。

## 架構（5 元件，各自獨立、介面清楚）

### ① 道具資料 `data/items.json`（單一真相源）
```jsonc
{
  "heal_salve":    {"name": "金瘡藥",   "price": 150, "effect": {"kind": "heal",   "value": 200},
                    "desc": "外傷藥膏，戰鬥中回復 HP 200。"},
  "karma_crystal": {"name": "業障結晶", "price": 250, "effect": {"kind": "karma",  "value": 40},
                    "desc": "凝結的怨念，立即補業障 40，催動羅漢拳等業障技。"},
  "amulet":        {"name": "護身符",   "price": 350, "effect": {"kind": "shield", "value": 250, "duration": 3},
                    "desc": "鄭媽開光的符，金身護盾吸收下次傷害（上限 250）。"}
}
```
`effect.kind ∈ {heal, karma, merit, shield, cleanse}`（DEMO 用到 heal/karma/shield；merit/cleanse 預留，schema 一致）。商店與戰鬥都讀此檔。

### ② 背包：`GameManager.player.inventory: Dictionary`（`{item_id: count}`）
- 加進 `player` 預設與 `new_game()`（皆 `"inventory": {}`）。SaveManager 整包存玩家 dict → 自動持久化、不需另接存檔。
- 三個 helper（`GameManager.gd`）：
  - `add_item(id: String, n := 1) -> void`：`inventory[id] = item_count(id) + n`。
  - `item_count(id: String) -> int`：`int(inventory.get(id, 0))`。
  - `consume_item(id: String) -> bool`：有則 `-1`（歸 0 則 erase）回 true，無則 false。

### ③ 商店 `src/ui/menu/ShopScreen.gd`（純 .gd overlay）
> **實作定案（2026-06-17）：用 `CanvasLayer`（非本節原寫的 Control）＋ `layer = 100`。** HUD 是 CanvasLayer（預設 layer 1），純 Control 子節點會被 HUD 蓋住；仿 MenuShell 用 CanvasLayer 才能浮在 HUD 上。
- 仿 `MenuShell`：`process_mode = ALWAYS`、開啟暫停地圖、`cancel` 關閉、程式建暗金框。`_ready` 讀 `items.json` 建 UI。
- 版面：左＝道具清單按鈕（名／價／「持有 ×N」）；右＝詳情（名/說明/效果文字/價）＋「購買」鈕。
- 購買：`_on_buy(id)` → 若 `GameManager.spend_gold(price)` 成功 → `GameManager.add_item(id)` → 刷新該列持有數＋頂部金幣；金幣不足則購買鈕 disabled（`spend_gold` 不會誤扣，回 false 已防）。
- 由 `MapScreen` `shop` 動作開（見 ⑤）。

### ④ 戰鬥「道具」指令
- `BattleUI.show_skill_menu`：在技能按鈕**最上方插一顆「🎒 道具」鈕**；按下 → `_show_item_menu()`（複用同一 `skill_buttons` 容器，列出 `inventory` 中**持有數>0 的消耗道具**＋數量；空背包則「道具」鈕 `disabled`）。選一個道具 → `manager.player_use_item(id)`；另給「← 返回」回技能選單。
- `BattleManager.player_use_item(item_id)`：限 `PLAYER_TURN`；`consume_item` 成功後 `_apply_item_effect(effect)` → log → **消耗回合 `_enemy_turn()`**（道具非弱點、不 One More、不選敵）。
- `BattleManager._apply_item_effect(effect: Dictionary)`：依 `kind` 套用——
  - `heal`：`player_combatant.heal(value)`
  - `karma`：`GameManager.add_karma(value)`
  - `merit`：`GameManager.add_merit(value)`
  - `shield`：`player_combatant.add_buff("golden_body", value, effect.get("duration", 3))`
  - `cleanse`：`status.clear_negative(player_combatant)`
- 封印（seal）等狀態**不擋道具**（道具非技能消耗）。

### ⑤ 地圖動作接線（`MapScreen.perform_action`）
- 把 `"shop", "skill_learn":` 合併 stub 拆開。`"shop":`
  - 若 `not GameManager.get_flag("zheng_ma_shop_unlocked")` → `hud.show_toast("鄭媽的店還沒開")` 返回。
  - 否則 `add_child(SHOP_SCREEN.new())`（暫停地圖）。**實作定案：ShopScreen 是純 `.gd`（非 `.tscn`），故 `preload(".gd")` + `.new()`（非 `.instantiate()`）；並加防重複開店守門（`get_node_or_null("ShopScreen")`，仿 `_open_main_menu`）。**
- `"skill_learn":` 維持原 toast（**本案不處理**，留給後續；避免擴張）。

## 持久化
`inventory` 在 `player` dict 內，隨 `SaveManager` 整包存讀。讀檔覆寫 `player` 時 inventory 一併還原。無獨立存檔程式。

## 測試（headless，擴充或新建）
新建 `test/TestShop.tscn`/`.gd`（`SHOP_TEST: ALL PASS`）或併入 `TestMenuSystem`：
- **資料**：`items.json` 載入、3 道具有 name/price/effect.kind。
- **背包**：`add_item`/`item_count`/`consume_item`（增、減、歸零 erase、空背包 consume 回 false）。
- **購買**：金幣足→`spend_gold` 扣款+入袋；金幣不足→不扣、不入袋。
- **戰鬥道具**：建 BattleManager（或直接測 `_apply_item_effect`）——heal 加 HP、karma 加業障、shield 上 `golden_body` buff；`player_use_item` 後該道具數量 -1 且狀態轉 `ENEMY_TURN`（或 log）。
- **gate**：未設 `zheng_ma_shop_unlocked` 時 shop 動作不開店（純函式或旗標判斷可測；overlay 本身用煙霧）。
- **煙霧**：`ShopScreen.new()` 實例化不崩、購買 helper 可呼叫。
- 既有 `TestMenuSystem`/`TestCh1Expansion`/`TestMainQuest` 回歸 ALL PASS；`--editor --quit` 無 parse/JSON error。

## 風險／邊界
- **開商店推進一時段**：沿用 `perform_action` 既有慣例（與 save/rest 同），不特例化；若日後嫌耗時段再調。
- **道具回合中用 = 自我施放**：不需選敵 UI，避開目標選擇複雜度；攻擊型投擲道具不在 DEMO 範圍（YAGNI）。
- **heal 上限**：`Combatant.heal` 受 `max_hp` 夾；karma/merit 受 `add_karma`/`add_merit` 的 MAX 夾（業障滿值會觸發 `karma_maxed_once`→可能讓 `karma_rebound` 變可學，屬合理副作用）。
- **shield buff 與技能共用 `golden_body`**：道具與大悲咒護罩疊加＝後者覆寫前者 buff（`add_buff` 行為），DEMO 可接受。
- **舊存檔無 `inventory` 鍵**：`item_count`/helper 用 `inventory.get(id,0)`，且讀檔的 player 若缺 inventory→`player.get("inventory", {})` 防呆（讀檔還原時若舊檔無此鍵，需在存取點容錯；實作時 helper 先 `if not player.has("inventory"): player.inventory = {}`）。

## 檔案清單
**新增：**
- `data/items.json` — 3 道具資料。
- `src/ui/menu/ShopScreen.gd` — 商店 overlay。
- `test/TestShop.tscn` + `test/TestShop.gd`（或併入 TestMenuSystem）。

**修改：**
- `src/autoloads/GameManager.gd` — `player`/`new_game` 加 `inventory`；新 `add_item`/`item_count`/`consume_item`。
- `src/screens/BattleScreen/BattleUI.gd` — 「🎒 道具」鈕＋道具子選單。
- `src/screens/BattleScreen/BattleManager.gd` — `player_use_item`＋`_apply_item_effect`。
- `src/screens/MapScreen/MapScreen.gd` — `shop` 動作開店＋gate；`SHOP_SCREEN` preload。

**不動：** `.dtl`、`skill_learn` 動作（留後續）、SkillExecutor 效果邏輯（只複用不改）。

## 備註
專案不在 git 下，略過「commit 設計文件」步驟（與既有流程一致）。實作後依 [[feedback-sync-docs-memory]] 同步 PROJECT_STATUS（🟡 缺口移除 shop stub）與記憶 `project-build-status`。
