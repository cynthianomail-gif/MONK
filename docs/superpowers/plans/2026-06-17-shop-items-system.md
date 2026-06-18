# 鄭媽佛具店：道具＋背包＋戰鬥道具系統 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `MapScreen` 的死按鈕 `shop`（萬年大樓·鄭媽佛具店）兌現成可玩循環——賺金幣 → 鄭媽店買消耗道具 → 戰鬥中用，給金幣一個有意義的去處並讓戰鬥更耐打。

**Architecture:** 五個獨立元件、介面清楚：① `data/items.json` 單一真相源（id→{name,price,effect,desc}）；② 背包 `GameManager.player.inventory:{id:count}` + 三個 helper（隨 SaveManager 整包存讀，自動持久化）；③ `ShopScreen.gd` 暗金 overlay（仿 MenuShell，只買不賣）；④ 戰鬥「🎒 道具」指令（複用 `Combatant.heal`/`add_buff`、`GameManager.add_karma`、`StatusEffects.clear_negative`）；⑤ `MapScreen` shop 動作開店 + `zheng_ma_shop_unlocked` gate。道具效果走既有戰鬥效果機制，**不動 SkillExecutor**。

**Tech Stack:** Godot 4.5 / GDScript；資料驅動 JSON（`data/items.json`）；autoload（GameManager / JsonLoader / AudioManager / SaveManager）；既有戰鬥系統（BattleManager / Combatant / StatusEffects）；程式建構的暗金×黑 overlay（仿 `MenuShell`）；自製 headless 測試場景（`test/TestShop.tscn`）。

**關聯 spec:** `MONK/docs/superpowers/specs/2026-06-17-shop-items-design.md`

---

## 前置慣例（每個 task 都適用）

**專案不在 git 下。** 本計畫**不含 git commit 步驟**；每個 task 的「收尾」＝跑 `TestShop` headless 套件確認 `SHOP_TEST: ALL PASS`。

**測試跑法（標準指令）：**

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```

判定：輸出含 `SHOP_TEST: ALL PASS`。
（headless teardown 退碼非 0 屬引擎 bug，**以印出的字串為準，不看 exit code**。audio/driver 警告可忽略，只在意 `SCRIPT ERROR` / `FAIL:`。）

**編輯器 parse 檢查（腳本/JSON 改動後，最後一個 task 必跑）：**

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" --editor --quit
```

判定：無 `SCRIPT ERROR` / `Parse Error` / JSON 解析錯誤。

**回歸（最後一個 task 跑）：** `TestMenuSystem` 仍 `MENU_TEST: ALL PASS`、`TestCh1Expansion` 仍 `CH1_EXPANSION_TEST: ALL PASS`。

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestCh1Expansion.tscn
```

---

## File Structure

| 檔案 | 動作 | 責任 |
|------|------|------|
| `data/items.json` | 新增 | 3 道具單一真相源（id→{name,price,effect:{kind,value,duration?},desc}）。 |
| `src/autoloads/GameManager.gd` | 修改 | `player` 預設 + `new_game()` 加 `"inventory": {}`；新增 `add_item`/`item_count`/`consume_item`/`_ensure_inventory`。 |
| `src/screens/BattleScreen/BattleManager.gd` | 修改 | 新增 `player_use_item(item_id)` + `_apply_item_effect(effect)`。 |
| `src/screens/BattleScreen/BattleUI.gd` | 修改 | `show_skill_menu` 頂端插「🎒 道具」鈕；新增 `_has_usable_items`/`_show_item_menu`/`_on_item_pressed`；`_ready` 載入 `items.json`。 |
| `src/ui/menu/ShopScreen.gd` | 新增 | 商店 overlay（CanvasLayer，仿 MenuShell；左清單右詳情 + 購買鈕）。 |
| `src/screens/MapScreen/MapScreen.gd` | 修改 | `shop`/`skill_learn` 合併 stub 拆開；`shop` gate + 開店；`SHOP_SCREEN` preload。 |
| `test/TestShop.gd` + `test/TestShop.tscn` | 新增 | headless 測試：資料/背包/戰鬥道具/UI 煙霧/購買/gate。 |

**不動：** `SkillExecutor.gd`（只複用效果機制）、`StatusEffects.gd`、`SaveManager.gd`（inventory 隨 player dict 自動存讀）、所有 `.dtl`、`skill_learn` 動作（留後續，見缺口 #11）。

### 與 spec 的兩處實作層調整（已確認，寫進「備註」回同步 spec）
1. **ShopScreen 用 `CanvasLayer` 而非 spec 寫的「Control」**：HUD 是 CanvasLayer，純 Control 子節點會被 HUD 蓋住；仿 `MenuShell` 用 `CanvasLayer` + `layer = 100` 才能蓋在 HUD 之上。
2. **`MapScreen` 用 `SHOP_SCREEN.new()` 而非 spec 寫的 `.instantiate()`**：ShopScreen 是純 `.gd`（非 `.tscn`），用 `preload(".gd")` + `.new()`（同 SkillsPage 等頁面慣例）。

---

## Task 1: 道具資料 `items.json` + 測試骨架 + 資料測試

**Files:**
- Create: `data/items.json`
- Create: `test/TestShop.gd`
- Create: `test/TestShop.tscn`

- [ ] **Step 1: 建測試骨架 `test/TestShop.gd`（含資料測試）**

Create `test/TestShop.gd`：

```gdscript
extends Node
## headless 測試：鄭媽佛具店道具系統（資料 / 背包 / 戰鬥道具 / UI 煙霧 / 購買 / gate）。
## 跑法：
##   & "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
## 判定：輸出含 SHOP_TEST: ALL PASS（headless teardown 退碼非 0 屬引擎 bug，以字串為準）。

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_items_data()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_items_data() -> void:
	var items: Dictionary = JsonLoader.load_json("res://data/items.json")
	_check(items.size() == 3, "items.json 有 3 道具 (got %d)" % items.size())
	for id in ["heal_salve", "karma_crystal", "amulet"]:
		_check(items.has(id), "items.json 有 %s" % id)
		var d: Dictionary = items.get(id, {})
		_check(d.has("name") and int(d.get("price", 0)) > 0, "%s 有 name+price" % id)
		_check(d.get("effect", {}).has("kind"), "%s effect 有 kind" % id)
	_check(items.get("amulet", {}).get("effect", {}).get("kind", "") == "shield", "amulet effect.kind == shield")
```

- [ ] **Step 2: 建測試場景 `test/TestShop.tscn`**

Create `test/TestShop.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/TestShop.gd" id="1"]

[node name="TestShop" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 跑測試確認 FAIL（items.json 尚未存在）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: 輸出 `SHOP_TEST: HAS FAILURES`，含 `FAIL: items.json 有 3 道具 (got 0)`（JsonLoader 找不到檔回空 dict）。

- [ ] **Step 4: 建 `data/items.json`（純 JSON，無註解）**

Create `data/items.json`：

```json
{
	"heal_salve": {
		"name": "金瘡藥",
		"price": 150,
		"effect": { "kind": "heal", "value": 200 },
		"desc": "外傷藥膏，戰鬥中回復 HP 200。"
	},
	"karma_crystal": {
		"name": "業障結晶",
		"price": 250,
		"effect": { "kind": "karma", "value": 40 },
		"desc": "凝結的怨念，立即補業障 40，催動羅漢拳等業障技。"
	},
	"amulet": {
		"name": "護身符",
		"price": 350,
		"effect": { "kind": "shield", "value": 250, "duration": 3 },
		"desc": "鄭媽開光的符，金身護盾吸收下次傷害（上限 250）。"
	}
}
```

> 注意：`JsonLoader` 用 `JSON.parse_string`，**不接受 `//` 或 `/* */` 註解**。spec 的 jsonc 範例僅供說明，實檔須為純 JSON。

- [ ] **Step 5: 跑測試確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

---

## Task 2: 背包模型（GameManager）

**Files:**
- Modify: `src/autoloads/GameManager.gd:13-25`（player 預設）、`src/autoloads/GameManager.gd:130-143`（new_game）、新增 helper
- Modify: `test/TestShop.gd`

- [ ] **Step 1: 在 `TestShop.gd` 加背包測試函式**

在 `test/TestShop.gd` 末端新增：

```gdscript
func _test_inventory() -> void:
	var gm := GameManager
	gm.player.inventory = {}
	_check(gm.item_count("heal_salve") == 0, "空背包 count 0")
	gm.add_item("heal_salve")
	gm.add_item("heal_salve", 2)
	_check(gm.item_count("heal_salve") == 3, "add_item 累加 = 3 (got %d)" % gm.item_count("heal_salve"))
	_check(gm.consume_item("heal_salve"), "consume_item 有貨回 true")
	_check(gm.item_count("heal_salve") == 2, "consume 後 = 2")
	gm.player.inventory = { "amulet": 1 }
	_check(gm.consume_item("amulet"), "consume 最後一個回 true")
	_check(gm.item_count("amulet") == 0 and not gm.player.inventory.has("amulet"), "歸 0 即 erase 鍵")
	_check(not gm.consume_item("amulet"), "空貨 consume 回 false")
	# 舊存檔無 inventory 鍵：helper 防呆
	gm.player.erase("inventory")
	_check(gm.item_count("heal_salve") == 0, "缺 inventory 鍵 → count 0（不崩）")
	gm.add_item("karma_crystal")
	_check(gm.item_count("karma_crystal") == 1, "缺鍵時 add_item 自建 inventory")
	gm.player.inventory = {}
```

並在 `_ready()` 的 `_test_items_data()` 後插入呼叫：

```gdscript
	_test_items_data()
	_test_inventory()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
```

- [ ] **Step 2: 跑測試確認 FAIL（helper 尚未存在）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: 含 `SCRIPT ERROR` 或 `FAIL`（`GameManager` 無 `item_count`/`add_item`/`consume_item` 方法 → 呼叫失敗）。

- [ ] **Step 3: `player` 預設 dict 加 inventory 鍵**

`src/autoloads/GameManager.gd`，把預設 `player`（約 13-25 行）的 `"current_area": "ximen"` 改成多一行 inventory：

找：
```gdscript
	"last_position": {"x": 0.0, "y": 0.0, "z": 0.0},
	"current_area": "ximen"
}
```
改成：
```gdscript
	"last_position": {"x": 0.0, "y": 0.0, "z": 0.0},
	"current_area": "ximen",
	"inventory": {}
}
```

- [ ] **Step 4: `new_game()` 同步加 inventory 鍵**

`src/autoloads/GameManager.gd` 的 `new_game()`（約 130-143 行），找：
```gdscript
		"last_position": {"x": 0.0, "y": 1.2, "z": 6.0},
		"current_area": "ximen"
	}
```
改成：
```gdscript
		"last_position": {"x": 0.0, "y": 1.2, "z": 6.0},
		"current_area": "ximen",
		"inventory": {}
	}
```

- [ ] **Step 5: 新增背包 helper（接在 `add_gold` 之後，約 113 行後）**

`src/autoloads/GameManager.gd`，在 `add_gold(...)` 函式之後新增：

```gdscript
# ─── 背包 / 道具 ───────────────────────────────────────
## 舊存檔可能無 inventory 鍵 → 存取前確保存在（belt-and-suspenders；
## load_game 以預設 player 為底合併，預設已含 inventory:{}，此處再防呆）。
func _ensure_inventory() -> void:
	if not player.has("inventory") or typeof(player.inventory) != TYPE_DICTIONARY:
		player["inventory"] = {}

func item_count(id: String) -> int:
	_ensure_inventory()
	return int(player.inventory.get(id, 0))  # JSON 讀回是 float，int() 夾正

func add_item(id: String, n: int = 1) -> void:
	_ensure_inventory()
	player.inventory[id] = item_count(id) + n
	stat_changed.emit("inventory", player.inventory)

func consume_item(id: String) -> bool:
	_ensure_inventory()
	var c: int = item_count(id)
	if c <= 0:
		return false
	if c <= 1:
		player.inventory.erase(id)
	else:
		player.inventory[id] = c - 1
	stat_changed.emit("inventory", player.inventory)
	return true
```

- [ ] **Step 6: 跑測試確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

---

## Task 3: 戰鬥道具效果（BattleManager）

**Files:**
- Modify: `src/screens/BattleScreen/BattleManager.gd`（在 `force_victory` 前、`_set_state` 後新增兩函式）
- Modify: `test/TestShop.gd`

- [ ] **Step 1: 在 `TestShop.gd` 加戰鬥道具測試函式**

在 `test/TestShop.gd` 末端新增：

```gdscript
func _test_battle_items() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	# _apply_item_effect: heal
	battle.player_combatant.current_hp = 100
	battle._apply_item_effect({ "kind": "heal", "value": 200 })
	_check(battle.player_combatant.current_hp == 300, "heal 道具 +200 (got %d)" % battle.player_combatant.current_hp)
	# karma
	GameManager.player.karma = 0
	battle._apply_item_effect({ "kind": "karma", "value": 40 })
	_check(GameManager.player.karma == 40, "karma 道具 +40 (got %d)" % GameManager.player.karma)
	# shield → golden_body buff
	battle._apply_item_effect({ "kind": "shield", "value": 250, "duration": 3 })
	_check(battle.player_combatant.has_buff("golden_body"), "shield 道具上 golden_body buff")
	# player_use_item：消耗 + 套效果 + 轉 ENEMY_TURN
	GameManager.player.inventory = { "heal_salve": 1 }
	battle.state = battle.State.PLAYER_TURN
	battle.player_combatant.current_hp = 100
	battle.player_use_item("heal_salve")
	_check(GameManager.item_count("heal_salve") == 0, "player_use_item 消耗道具")
	_check(battle.player_combatant.current_hp == 300, "player_use_item 套用 heal")
	_check(battle.state == battle.State.ENEMY_TURN, "player_use_item → ENEMY_TURN")
	await get_tree().create_timer(0.8).timeout   # 讓 _enemy_turn 在 live 節點上跑完再 free
	# 非 PLAYER_TURN：不消耗
	GameManager.player.inventory = { "heal_salve": 1 }
	battle.state = battle.State.ENEMY_TURN
	battle.player_use_item("heal_salve")
	_check(GameManager.item_count("heal_salve") == 1, "非 PLAYER_TURN 時 player_use_item 不消耗")
	battle.queue_free()
	GameManager.player.inventory = {}
	GameManager.player.karma = 0
	await get_tree().process_frame
```

並在 `_ready()` 的 `_test_inventory()` 後插入呼叫（注意 `await`）：

```gdscript
	_test_inventory()
	await _test_battle_items()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
```

- [ ] **Step 2: 跑測試確認 FAIL（`player_use_item`/`_apply_item_effect` 尚未存在）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: 含 `SCRIPT ERROR`（BattleManager 無 `_apply_item_effect`/`player_use_item`）。

> 若 `setup("street_punk")` 本身在 headless 報 `SCRIPT ERROR`（首次 headless 實例化戰鬥場景），停下排查；EnemyPanel 為純程式 UI、無貼圖載入，理論上安全。退路：改測 `_apply_item_effect` 時手動 `var battle = ...new()` 後手動指派 `player_combatant = Combatant.from_player()` 並 `add_child` 一個 StatusEffects——但優先讓 `setup` 路徑通。

- [ ] **Step 3: 在 `BattleManager.gd` 新增道具函式**

`src/screens/BattleScreen/BattleManager.gd`，在 `_set_state(...)` 函式之後、`force_victory()` 之前新增：

```gdscript
# ─── 道具（戰鬥中使用）─────────────────────────────────
## 玩家回合使用消耗道具：自我施放、消耗一回合、不選敵、不觸發 One More。
func player_use_item(item_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	var items: Dictionary = JsonLoader.load_json("res://data/items.json")
	var data: Dictionary = items.get(item_id, {})
	if data.is_empty():
		return
	if not GameManager.consume_item(item_id):
		return
	_apply_item_effect(data.get("effect", {}))
	battle_log.emit("使用「%s」" % data.get("name", item_id))
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_enemy_turn()  # 道具消耗一回合 → 進敵方回合

## 依 effect.kind 套用——複用既有戰鬥效果機制（不經 SkillExecutor）。
func _apply_item_effect(effect: Dictionary) -> void:
	match effect.get("kind", ""):
		"heal":
			player_combatant.heal(int(effect.get("value", 0)))
		"karma":
			GameManager.add_karma(int(effect.get("value", 0)))
		"merit":
			GameManager.add_merit(int(effect.get("value", 0)))
		"shield":
			player_combatant.add_buff("golden_body", float(effect.get("value", 0)), int(effect.get("duration", 3)))
		"cleanse":
			status.clear_negative(player_combatant)
```

- [ ] **Step 4: 跑測試確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

---

## Task 4: 戰鬥「🎒 道具」指令（BattleUI）

**Files:**
- Modify: `src/screens/BattleScreen/BattleUI.gd:30-46`（`_ready` 載 items）、`:71-85`（`show_skill_menu`）、新增子選單函式
- Modify: `test/TestShop.gd`

- [ ] **Step 1: 在 `TestShop.gd` 加 UI 煙霧測試函式**

在 `test/TestShop.gd` 末端新增：

```gdscript
func _find_button(container: Node, text: String) -> Button:
	for c in container.get_children():
		if c is Button and String(c.text) == text:
			return c
	return null

func _test_battle_ui_items() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	var ui = battle.get_node("BattleUI")
	# 空背包：道具鈕 disabled
	GameManager.player.inventory = {}
	ui.show_skill_menu(battle.available_skills())
	await get_tree().process_frame
	var item_btn := _find_button(ui.skill_buttons, "🎒 道具")
	_check(item_btn != null and item_btn.disabled, "空背包道具鈕 disabled")
	# 有道具：道具鈕 enabled，子選單列出該道具 + 返回
	GameManager.player.inventory = { "heal_salve": 2 }
	ui.show_skill_menu(battle.available_skills())
	await get_tree().process_frame
	item_btn = _find_button(ui.skill_buttons, "🎒 道具")
	_check(item_btn != null and not item_btn.disabled, "有道具時道具鈕 enabled")
	ui._show_item_menu()
	await get_tree().process_frame
	_check(_find_button(ui.skill_buttons, "金瘡藥 ×2") != null, "子選單列出 金瘡藥 ×2")
	_check(_find_button(ui.skill_buttons, "← 返回") != null, "子選單有返回鈕")
	battle.queue_free()
	GameManager.player.inventory = {}
	await get_tree().process_frame
```

並在 `_ready()` 的 `await _test_battle_items()` 後插入呼叫：

```gdscript
	await _test_battle_items()
	await _test_battle_ui_items()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
```

- [ ] **Step 2: 跑測試確認 FAIL（道具鈕/子選單尚未存在）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: 含 `FAIL: 空背包道具鈕 disabled`（找不到「🎒 道具」鈕）或 `SCRIPT ERROR`（無 `_show_item_menu`）。

- [ ] **Step 3: `BattleUI._ready` 載入 items.json**

`src/screens/BattleScreen/BattleUI.gd`，在 `var _pending_skill: String = ""`（約 28 行）之後新增成員：

```gdscript
var _items: Dictionary = {}
```

在 `_ready()` 開頭（`skill_menu.visible = false` 之前）新增：

```gdscript
	_items = JsonLoader.load_json("res://data/items.json")
```

- [ ] **Step 4: `show_skill_menu` 頂端插入「🎒 道具」鈕**

`src/screens/BattleScreen/BattleUI.gd` 的 `show_skill_menu`，找：

```gdscript
func show_skill_menu(skill_ids: Array) -> void:
	for c in skill_buttons.get_children():
		c.queue_free()
	for id in skill_ids:
```
改成（在清空後、技能迴圈前插入道具鈕）：

```gdscript
func show_skill_menu(skill_ids: Array) -> void:
	for c in skill_buttons.get_children():
		c.queue_free()
	var item_btn := Button.new()
	item_btn.text = "🎒 道具"
	item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_btn.disabled = not _has_usable_items()
	item_btn.pressed.connect(_show_item_menu)
	skill_buttons.add_child(item_btn)
	for id in skill_ids:
```

- [ ] **Step 5: 新增子選單函式（接在 `_first_alive_index()` 之後）**

`src/screens/BattleScreen/BattleUI.gd`，在 `_first_alive_index()` 函式之後新增：

```gdscript
# ─── 道具子選單 ────────────────────────────────────────
func _has_usable_items() -> bool:
	for id in GameManager.player.get("inventory", {}):
		if GameManager.item_count(id) > 0 and _items.has(id):
			return true
	return false

func _show_item_menu() -> void:
	for c in skill_buttons.get_children():
		c.queue_free()
	for id in GameManager.player.get("inventory", {}):
		var count: int = GameManager.item_count(id)
		if count <= 0 or not _items.has(id):
			continue
		var data: Dictionary = _items[id]
		var btn := Button.new()
		btn.text = "%s ×%d" % [data.get("name", id), count]
		btn.tooltip_text = data.get("desc", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_pressed.bind(id))
		skill_buttons.add_child(btn)
	var back := Button.new()
	back.text = "← 返回"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(func() -> void: show_skill_menu(manager.available_skills()))
	skill_buttons.add_child(back)
	skill_menu.visible = true

func _on_item_pressed(item_id: String) -> void:
	skill_menu.visible = false
	manager.player_use_item(item_id)
```

- [ ] **Step 6: 跑測試確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

---

## Task 5: 商店 overlay（ShopScreen.gd）

**Files:**
- Create: `src/ui/menu/ShopScreen.gd`
- Modify: `test/TestShop.gd`

- [ ] **Step 1: 在 `TestShop.gd` 加購買測試函式**

在 `test/TestShop.gd` 末端新增：

```gdscript
func _test_shop_purchase() -> void:
	var shop = load("res://src/ui/menu/ShopScreen.gd").new()
	shop.set("pause_game", false)   # 測試不暫停 tree
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	_check(is_instance_valid(shop), "ShopScreen 實例化不崩")
	# 金幣足：扣款 + 入袋
	GameManager.player.gold = 1000
	GameManager.player.inventory = {}
	shop._on_buy("heal_salve")   # price 150
	_check(GameManager.player.gold == 850, "買 heal_salve 扣 150 (got %d)" % GameManager.player.gold)
	_check(GameManager.item_count("heal_salve") == 1, "買後入袋 1")
	# 金幣不足：不扣、不入袋
	GameManager.player.gold = 100
	shop._on_buy("amulet")   # price 350
	_check(GameManager.player.gold == 100, "不足: 金幣不變")
	_check(GameManager.item_count("amulet") == 0, "不足: 未入袋")
	shop.close()
	GameManager.player.gold = 1000
	GameManager.player.inventory = {}
	await get_tree().process_frame
```

並在 `_ready()` 的 `await _test_battle_ui_items()` 後插入呼叫：

```gdscript
	await _test_battle_ui_items()
	await _test_shop_purchase()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
```

- [ ] **Step 2: 跑測試確認 FAIL（ShopScreen 尚未存在）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: 含 `SCRIPT ERROR`（`load(".../ShopScreen.gd")` 回 null → `.new()` 失敗）。

- [ ] **Step 3: 建 `src/ui/menu/ShopScreen.gd`**

Create `src/ui/menu/ShopScreen.gd`：

```gdscript
extends CanvasLayer
## 鄭媽佛具店：消耗道具商店 overlay（只買不賣，DEMO）。
## 仿 MenuShell：layer=100、process_mode ALWAYS、暫停地圖、cancel 關閉、暗金×黑框。
## 由 MapScreen 的 shop 動作開啟（已 gate zheng_ma_shop_unlocked）。時段推進由
## MapScreen.perform_action 開頭統一處理，本檔不碰時間。

const GOLD := Color(0.788, 0.659, 0.38)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 0.97)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.55, 0.52, 0.46)
const PRICE_COL := Color(0.85, 0.78, 0.5)
const ITEMS_PATH := "res://data/items.json"

@export var pause_game: bool = true   # 測試時設 false

var _items: Dictionary = {}
var _rows: Dictionary = {}        # item_id -> Button
var _detail_box: VBoxContainer
var _gold_label: Label
var _selected: String = ""

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_game:
		get_tree().paused = true
	_items = JsonLoader.load_json(ITEMS_PATH)
	_build()

func close() -> void:
	if pause_game:
		get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		close()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -720; panel.offset_top = -410
	panel.offset_right = 720; panel.offset_bottom = 410
	panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# 標題列：店名 + 金幣
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "鄭媽佛具店"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", PRICE_COL)
	header.add_child(_gold_label)

	root.add_child(_hsep())

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 24)
	root.add_child(hb)

	# 左：道具清單
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for id in _items:
		list.add_child(_item_row(id))

	# 右：詳情
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _frame_style(NEAR_BLACK, GOLD.darkened(0.3), 1))
	hb.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_detail_box)

	# 底部提示
	var hint := Label.new()
	hint.text = "Esc 離開"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 20)
	root.add_child(hint)

	_refresh_gold()
	_show_detail("")

func _item_row(id: String) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 22)
	var iid: String = id
	btn.pressed.connect(func() -> void: _select(iid))
	_rows[id] = btn
	_style_row(id)
	return btn

func _style_row(id: String) -> void:
	var btn: Button = _rows[id]
	var d: Dictionary = _items[id]
	btn.text = "%s　%d 金　(持有 ×%d)" % [d.get("name", id), int(d.get("price", 0)), GameManager.item_count(id)]
	btn.add_theme_color_override("font_color", WARM)

func _select(id: String) -> void:
	_selected = id
	_show_detail(id)

func _show_detail(id: String) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	if id == "":
		var hint := Label.new()
		hint.text = "選擇左側道具以檢視詳情。"
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 22)
		_detail_box.add_child(hint)
		return
	var d: Dictionary = _items[id]
	_add_label(d.get("name", id), 34, GOLD)
	var desc := _add_label(d.get("desc", ""), 22, WARM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(640, 0)
	_add_label("價格：%d 金" % int(d.get("price", 0)), 22, PRICE_COL)
	_add_label("持有：×%d" % GameManager.item_count(id), 20, DIM)
	var buy := Button.new()
	buy.text = "購買"
	buy.add_theme_font_size_override("font_size", 24)
	buy.disabled = GameManager.player.gold < int(d.get("price", 0))
	var iid: String = id
	buy.pressed.connect(func() -> void: _on_buy(iid))
	_detail_box.add_child(buy)

func _on_buy(id: String) -> void:
	var price: int = int(_items[id].get("price", 0))
	if not GameManager.spend_gold(price):
		return
	GameManager.add_item(id)
	AudioManager.play_sfx("gold_collect")
	_style_row(id)
	_refresh_gold()
	_show_detail(id)

func _refresh_gold() -> void:
	_gold_label.text = "金幣：%d" % GameManager.player.gold

func _add_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_detail_box.add_child(l)
	return l

func _frame_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	return sb

func _hsep() -> Control:
	var line := ColorRect.new()
	line.color = GOLD.darkened(0.4)
	line.custom_minimum_size = Vector2(0, 2)
	return line
```

- [ ] **Step 4: 跑測試確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

---

## Task 6: 地圖動作接線 + gate（MapScreen）+ 收尾驗證

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.gd:4`（preload）、`:123-124`（stub 拆開）
- Modify: `test/TestShop.gd`

- [ ] **Step 1: 在 `TestShop.gd` 加 gate 測試函式**

在 `test/TestShop.gd` 末端新增：

```gdscript
func _test_shop_gate() -> void:
	# gate 判定為純旗標：未設 → 視為未開店；設了 → 開店
	GameManager.player.flags.erase("zheng_ma_shop_unlocked")
	_check(not GameManager.get_flag("zheng_ma_shop_unlocked"), "無旗標時 shop gate 關閉")
	GameManager.set_flag("zheng_ma_shop_unlocked", true)
	_check(GameManager.get_flag("zheng_ma_shop_unlocked"), "設旗標後 shop gate 開啟")
	# MapScreen preload 了 ShopScreen 腳本（接線存在性）
	var ms_script := load("res://src/screens/MapScreen/MapScreen.gd")
	_check(ms_script != null, "MapScreen.gd 可載入（含 SHOP_SCREEN preload，無 parse error）")
```

並在 `_ready()` 的 `await _test_shop_purchase()` 後插入呼叫：

```gdscript
	await _test_shop_purchase()
	_test_shop_gate()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
```

- [ ] **Step 2: 跑測試確認目前狀態（gate 旗標測試會過，preload 測試僅驗證可載入）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`（gate 為純旗標、MapScreen.gd 目前即可載入）。
> 此 task 的真正接線（按下 shop 開店）無法 headless 單測（MapScreen 需 DistrictScene 等全套），以 parse 檢查 + 手動 GPU 抽驗為準（見最後步驟）。

- [ ] **Step 3: `MapScreen` 加 ShopScreen preload**

`src/screens/MapScreen/MapScreen.gd`，找（約第 4 行）：

```gdscript
const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")
```
改成：

```gdscript
const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")
const SHOP_SCREEN := preload("res://src/ui/menu/ShopScreen.gd")
```

- [ ] **Step 4: 拆開 `shop` / `skill_learn` 合併 stub**

`src/screens/MapScreen/MapScreen.gd` 的 `perform_action`，找（約 123-124 行）：

```gdscript
			"shop", "skill_learn":
				hud.show_toast("此功能尚未實作")
```
改成：

```gdscript
			"shop":
				if not GameManager.get_flag("zheng_ma_shop_unlocked"):
					hud.show_toast("鄭媽的店還沒開")
				else:
					add_child(SHOP_SCREEN.new())  # ShopScreen 為純 .gd（CanvasLayer），用 .new()
			"skill_learn":
				hud.show_toast("此功能尚未實作")  # 本案不處理，留後續（缺口 #11）
```

> 注意：`perform_action` 開頭已 `GameManager.advance_time(1)`，故開店（含 gate 未開的 toast 路徑）**沿用「每個地圖動作推進一時段」慣例**——spec 明定不特例化。

- [ ] **Step 5: 跑 TestShop 確認 PASS**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
```
Expected: `SHOP_TEST: ALL PASS`。

- [ ] **Step 6: parse 檢查（腳本/JSON 改動）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" --editor --quit
```
Expected: 無 `SCRIPT ERROR` / `Parse Error` / JSON 解析錯誤。

- [ ] **Step 7: 回歸測試（確認沒弄壞既有系統）**

Run:
```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestCh1Expansion.tscn
```
Expected: `MENU_TEST: ALL PASS` 且 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 8: 文件 + 記憶同步（依 [[feedback-sync-docs-memory]]）**

實作全綠後：
1. `PROJECT_STATUS.md`：缺口 #10（shop stub）移除 / 標完成。
2. spec `2026-06-17-shop-items-design.md`：把③「Control」改註記為「CanvasLayer（仿 MenuShell，需蓋 HUD）」、⑤ `.instantiate()` 改 `.new()`（與本計畫一致）。
3. 記憶 `project_build_status` + `project_shop_system`：狀態改「已實作並驗證 ALL PASS」，附 headless 結果與雷點。
4. 記憶 `project_phone_apps`：金幣去處新增「鄭媽店」一筆（選擇性）。

- [ ] **Step 9（手動 GPU 抽驗，非 headless）**

實機跑（非 headless，GUI）抽驗，非自動化：
- 設 `zheng_ma_shop_unlocked` 後到萬年大樓按「鄭媽佛具店」→ 開店、暗金 UI、左清單右詳情、金幣顯示正確。
- 金不足時購買鈕 disabled；買得起→扣款、持有數 +1、頂部金幣即時更新。
- 進戰鬥按「🎒 道具」→ 列出持有道具 → 選金瘡藥回血、護身符上護盾、業障結晶補業障；用後該道具 -1、進敵方回合。
- 空背包時戰鬥「道具」鈕為 disabled。

---

## Self-Review（對照 spec 的覆蓋檢查）

- **spec ① items.json**：Task 1 建檔 + 資料測試。✅（jsonc 註解已改純 JSON）
- **spec ② 背包 inventory + 3 helper**：Task 2，含舊存檔無鍵防呆（`_ensure_inventory`）、JSON float→int 夾正。✅
- **spec ③ ShopScreen overlay**：Task 5，左清單右詳情 + 購買鈕 + 金幣不足 disabled。✅（Control→CanvasLayer 已說明理由）
- **spec ④ 戰鬥道具指令**：Task 3（`player_use_item`/`_apply_item_effect`，限 PLAYER_TURN、消耗一回合、heal/karma/merit/shield/cleanse）+ Task 4（🎒 道具鈕 + 子選單 + 空背包 disabled + 返回）。✅
- **spec ⑤ MapScreen 接線 + gate**：Task 6（preload + 拆 stub + gate toast「鄭媽的店還沒開」+ skill_learn 維持原 toast）。✅
- **持久化**：inventory 在 player dict 內，SaveManager 整包 `JSON.stringify(player)` 存、load 以預設（含 inventory:{}）為底合併 → 自動持久化、舊檔安全。無獨立存檔程式。✅
- **測試**：Task 1-6 覆蓋資料 / 背包（增減歸零空貨防呆）/ 購買（足/不足）/ 戰鬥道具（heal/karma/shield + 消耗 + 轉 ENEMY_TURN + 非回合不消耗）/ gate / 煙霧（ShopScreen 實例化、道具子選單）。✅
- **method 名一致性**：`add_item`/`item_count`/`consume_item`/`_ensure_inventory`、`player_use_item`/`_apply_item_effect`、`_has_usable_items`/`_show_item_menu`/`_on_item_pressed`、`_on_buy`/`_style_row`/`_refresh_gold`/`_item_row`——跨 task 一致。✅
- **placeholder 掃描**：無 TBD/「適當處理」；每個 code step 均含完整程式。✅

## 風險／邊界（沿用 spec）
- **首次 headless 實例化 BattleScreen**：EnemyPanel 為純程式 UI（無貼圖載入）、`setup` 只讀 JSON + 建 UI，理論安全；若報錯見 Task 3 Step 2 退路。
- **gated 店仍耗一時段**：`advance_time` 在 `perform_action` 開頭、對所有動作生效——spec 明定不特例化，可接受。
- **shield buff 與大悲咒護罩共用 `golden_body`**：後者覆寫前者（`add_buff` 行為），DEMO 接受。
- **heal/karma/merit 夾值**：`Combatant.heal` 受 max_hp 夾、`add_karma`/`add_merit` 受 MAX 夾（業障滿→`karma_maxed_once` 副作用合理）。
- **封印(seal)不擋道具**：道具非技能消耗，`player_use_item` 不檢查 seal。
```
