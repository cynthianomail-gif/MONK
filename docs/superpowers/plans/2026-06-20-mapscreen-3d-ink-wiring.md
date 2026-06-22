# MapScreen 接回 3D 水墨探索 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把兩個已驗證的 3D 水墨可走場景（`ShrineStreet`/`ArmoryDistrict`）接進正式遊戲流程，讓 `SceneRouter.go_to_map()` 進到的 `MapScreen` 就是可走 3D 水墨街、能踏觸發開動作選單、能用手機「移動」app 在兩區往返，所有後端邏輯（`perform_action`/HUD/存檔/主線/商店/成就）留用。

**Architecture:** `MapScreen` 由 2D Control 協調者改寫成 3D 宿主（根 Node＋`$World`），`_ready` 依 `current_area` instantiate 區場景（自帶 Player+CameraRig+水墨）到 `$World`，再依 `map_locations.json` 灑現成的 `LocationTrigger`（Area3D 球體），觸發 → 開選單 → 照搬 `perform_action`。世界收成 2 區（`shrine`/`armory`），軍火庫放條件 NPC「鐵叔」（`ares_purified` 前「…」、後道謝＋金瘡藥）。退役 2D 的 DistrictScene/Interior/CityMap。

**Tech Stack:** Godot 4.5（GDScript、CharacterBody3D、Area3D、Dialogic 2、JSON 資料表）。

**驗證慣例（本專案特性，全程適用）：**
- 跑法（在 `D:/monk` 下執行）：`./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK <scene>`。
- **GDScript parse error 時視窗版會卡死不報錯** → 先跑 `--headless` 版，parse error 幾秒印出。
- 邏輯測試慣例：`extends Node`，`_ready()` 內跑斷言，過了 `print("TEST PASS: …")`＋`get_tree().quit(0)`，失敗 `push_error("TEST FAIL: …")`＋`quit(1)`。
- **判定雷**：grep 結果**必須同時看 `TEST FAIL` 與 `SCRIPT ERROR`**——有 SCRIPT ERROR 卻仍印 PASS＝假綠。
- 截圖驗證：windowed 跑、grep `_SAVED`、再 `Read` 圖自檢；shader GLSL 錯只在 windowed 現形。
- 新 `.dtl` 要在 `project.godot` 的 `dtl_directory` 加條目並 `--import` 才會被 `Dialogic.start()` 解析到。

---

### Task 1: 資料層改成 2 區 + 軍火庫解鎖掛點

**Files:**
- Modify: `data/areas.json`（整檔重寫成 2 區）
- Modify: `data/map_locations.json`（整檔重寫：5 地點歸 shrine＋新增 armory_worker）
- Modify: `data/main_quests.json`（`c1_intel` 加 `set_flag`）
- Modify: `src/autoloads/GameManager.gd`（`current_area` 預設 ×2）

- [ ] **Step 1: 重寫 `data/areas.json`**

整檔換成：

```json
{
  "shrine": {
    "name": "神社區",
    "bgm": "temple_ambient",
    "environment": "res://src/screens/MapScreen/environments/ShrineStreet.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 6.0}
  },
  "armory": {
    "name": "軍火庫區",
    "bgm": "ximen_night",
    "unlock_flag": "armory_unlocked",
    "environment": "res://src/screens/MapScreen/environments/ArmoryDistrict.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 6.0}
  }
}
```

- [ ] **Step 2: 重寫 `data/map_locations.json`**

整檔換成（5 地點 `district` 全 `shrine`、`position_3d` 沿街排、`zuijin_club` 移除 unlock_flag；新增 `armory_worker`）：

```json
{
  "ximen_mrt": {
    "name": "櫻木町站 6 號出口", "district": "shrine",
    "scene_pos": {"x": 0.28, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/ximen_mrt.png",
    "actions": ["beggar_minigame", "random_encounter", "quest_ah_ming", "quest_rei"],
    "available_periods": [1, 2, 3], "bgm": "ximen_night",
    "position_3d": {"x": 5.0, "y": 0.0, "z": -4.0}, "trigger_radius": 2.5,
    "scene_file": "res://assets/3d/environments/ximen_mrt.glb"
  },
  "wannian_mall": {
    "name": "萬年大樓", "district": "shrine",
    "scene_pos": {"x": 0.66, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/wannian_mall.png",
    "actions": ["shop", "greed_break_trigger", "quest_zheng_ma", "quest_jie"],
    "available_periods": [0, 1, 2], "bgm": "ximen_day",
    "position_3d": {"x": -5.0, "y": 0.0, "z": -8.0}, "trigger_radius": 3.0,
    "scene_file": "res://assets/3d/environments/wannian_mall.glb"
  },
  "zen_bbq": {
    "name": "禪味燒肉", "district": "shrine",
    "scene_pos": {"x": 0.35, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/zen_bbq.png",
    "actions": ["food_break_trigger", "rest", "quest_ah_zhong", "quest_david"],
    "available_periods": [2, 3], "bgm": "wanhua_night",
    "position_3d": {"x": -5.0, "y": 0.0, "z": -18.0}, "trigger_radius": 2.0,
    "scene_file": "res://assets/3d/environments/zen_bbq.glb"
  },
  "zuijin_club": {
    "name": "紫醉金迷俱樂部", "district": "shrine",
    "scene_pos": {"x": 0.55, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/zuijin_club.png",
    "actions": ["cherry_dialogue", "lust_break_trigger", "quest_cherry_debt", "quest_cai_ma"],
    "available_periods": [3], "bgm": "linsen_night",
    "position_3d": {"x": 5.0, "y": 0.0, "z": -16.0}, "trigger_radius": 2.5,
    "scene_file": "res://assets/3d/environments/zuijin_club.glb"
  },
  "old_temple": {
    "name": "荒廢神社", "district": "shrine",
    "scene_pos": {"x": 0.70, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/old_temple.png",
    "actions": ["main_quest", "save", "job_switch", "rest", "quest_grandma", "quest_lao_wang"],
    "available_periods": [0, 1, 2, 3], "bgm": "temple_ambient",
    "position_3d": {"x": 0.0, "y": 0.0, "z": -26.0}, "trigger_radius": 3.0,
    "scene_file": "res://assets/3d/environments/old_temple.glb"
  },
  "armory_worker": {
    "name": "鐵叔", "district": "armory",
    "actions": ["armory_npc"], "unlock_flag": "armory_unlocked",
    "available_periods": [0, 1, 2, 3], "bgm": "ximen_night",
    "position_3d": {"x": -4.0, "y": 0.0, "z": -16.0}, "trigger_radius": 2.5
  }
}
```

- [ ] **Step 3: `main_quests.json` 的 `c1_intel` 加 `set_flag`**

把 `ch01_ares.stages` 裡這行：

```json
      {"id": "c1_intel", "desc": "了塵聚焦阿瑞斯，指點幾位知情或需援手的人，傳無戒一招羅漢拳。", "dialogue": "main_ch1_intel"},
```

改成（加 `set_flag`，比照 `c1_demolition` 的 cutscene+set_flag 並存）：

```json
      {"id": "c1_intel", "desc": "了塵聚焦阿瑞斯，指點幾位知情或需援手的人，傳無戒一招羅漢拳。", "dialogue": "main_ch1_intel", "set_flag": "armory_unlocked"},
```

- [ ] **Step 4: 確認 `MainQuestManager` 會處理 stage 的 `set_flag`**

Run: `grep -n "set_flag" MONK/src/systems/MainQuestManager.gd`
Expected: 有處理 stage `set_flag` 的程式（讀到 `stage.get("set_flag")` / `GameManager.set_flag(...)`）。schema 註解列了 `set_flag` 為合法 stage 欄位、`c1_demolition` 已在用，故應已支援。**若沒有**，在跑 stage 的迴圈加：`if stage.has("set_flag"): GameManager.set_flag(String(stage.set_flag), true)`（放在該 stage 動作執行後）。

- [ ] **Step 5: `GameManager` 的 `current_area` 預設改 shrine（兩處）**

`src/autoloads/GameManager.gd` 第 24 行附近（`var player` 宣告內）：

```gdscript
	"current_area": "ximen",
```
→
```gdscript
	"current_area": "shrine",
```

以及 `new_game()` 內（第 172 行附近）同一行 `"current_area": "ximen",` → `"current_area": "shrine",`（兩處都要改；`new_game` 內 `last_position` 維持 `{"x":0.0,"y":1.2,"z":6.0}`）。

- [ ] **Step 6: JSON parse 健檢**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --check-only --script res://src/autoloads/GameManager.gd 2>&1 | grep -aiE "error" | head`
Expected: 無輸出。並用任一工具確認三個 JSON 合法（無尾逗號）。

- [ ] **Step 7: Commit**

```bash
git add MONK/data/areas.json MONK/data/map_locations.json MONK/data/main_quests.json MONK/src/autoloads/GameManager.gd
git commit -m "feat(map3d): 探索世界收成 2 區(神社/軍火庫)+軍火庫解鎖掛點"
```

---

### Task 2: 鐵叔對話（2 支 .dtl）＋註冊

**Files:**
- Create: `dialogue/armory_worker_locked.dtl`
- Create: `dialogue/armory_worker_freed.dtl`
- Modify: `project.godot`（`dtl_directory` 加 2 條目）

- [ ] **Step 1: 建 `dialogue/armory_worker_locked.dtl`**

（純旁白＋「……」，不需角色資源 .dch）

```
灰色廠房深處，機油與火藥的氣味嗆人。一名駝背的老工人正吃力地搬著彈藥箱，腳踝上的鐵鍊叮噹作響。
你上前出聲。老人卻像沒聽見，只把頭壓得更低。
「……」
他飛快地往四下瞥了一眼，眼神示意你快走——這裡的牆，有戰神的耳朵。
```

- [ ] **Step 2: 建 `dialogue/armory_worker_freed.dtl`**

（旁白＋「」引語給鐵叔、`Wujie (calm)` 用既有角色；謝禮由程式發、此處只敘事）

```
廠房的鐵門大開，外頭透進久違的天光。那名老工人怔怔站著，腳踝上的鐵鍊，已經斷了。
他抬起頭，渾濁的眼裡有淚。
「師父……是您把那尊煞神超渡了？」老人聲音抖著，「我這雙手，本是替神社鑄鐘的。是他，逼我改鑄殺人的傢伙……」
Wujie (calm): 鍊既已斷，施主便回去鑄你的鐘吧。鐘聲一響，這廠房的戾氣，也就散了。
老人從懷裡摸出一帖隨身的金瘡藥，硬塞進無戒手裡。
「您往後的路還長。萬神殿……不只一尊神。聽說城裡別的角頭，背後也站著那樣的東西。師父，多保重。」
無戒合十。鐵叔最後望了一眼這座囚了他的廠房，頭也不回地走進天光。
```

- [ ] **Step 3: `project.godot` 的 `dtl_directory` 加 2 條目**

在 `directories/dtl_directory={` 區塊（第 49 行起）的開頭、`"cherry_first_meeting"` 那行**之前**插入：

```
"armory_worker_freed": "res://dialogue/armory_worker_freed.dtl",
"armory_worker_locked": "res://dialogue/armory_worker_locked.dtl",
```

- [ ] **Step 4: import 讓 Dialogic 認得新 timeline**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "error|armory_worker" | head`
Expected: 無 error；`dialogue/armory_worker_*.dtl` 被匯入。

- [ ] **Step 5: 驗證可解析**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --check-only --script res://addons/dialogic/Core/DialogicResourceUtil.gd 2>&1 | grep -aiE "error" | head`（或於 Task 5 的測試內 `assert(ResourceLoader.exists("res://dialogue/armory_worker_freed.dtl"))`）
Expected: 無 error。

- [ ] **Step 6: Commit**

```bash
git add MONK/dialogue/armory_worker_locked.dtl MONK/dialogue/armory_worker_freed.dtl MONK/dialogue/armory_worker_locked.dtl.import MONK/dialogue/armory_worker_freed.dtl.import MONK/project.godot
git commit -m "feat(map3d): 軍火庫鐵叔對話(locked/freed)+dtl 註冊"
```

---

### Task 3: `MapScreen.tscn` 改成 3D 宿主

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.tscn`（整檔重寫：根 Control→Node、移除 2D 子節點、加 `World`、保留 `HUD` 全子樹）

- [ ] **Step 1: 整檔重寫 `MapScreen.tscn`**

（保留原 HUD 全部子節點/屬性逐字；只換根型別、移除 DistrictScene/LocationInterior/CityMap、加 World）

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/screens/MapScreen/MapScreen.gd" id="1"]
[ext_resource type="Script" path="res://src/screens/MapScreen/MapHUD.gd" id="3"]

[node name="MapScreen" type="Node"]
script = ExtResource("1")

[node name="World" type="Node3D" parent="."]

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("3")

[node name="TimeLabel" type="Label" parent="HUD"]
unique_name_in_owner = true
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -440.0
offset_top = 24.0
offset_right = -24.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(0.961, 0.961, 0.941, 1)
theme_override_font_sizes/font_size = 30
text = "第 1 天 ｜ 上午"
horizontal_alignment = 2

[node name="StatsLabel" type="Label" parent="HUD"]
unique_name_in_owner = true
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 24.0
offset_top = -200.0
offset_right = 460.0
offset_bottom = -24.0
theme_override_colors/font_color = Color(0.961, 0.961, 0.941, 1)
theme_override_font_sizes/font_size = 24
text = "無戒"

[node name="InteractionPrompt" type="Label" parent="HUD"]
unique_name_in_owner = true
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -350.0
offset_top = -150.0
offset_right = 350.0
offset_bottom = -100.0
theme_override_colors/font_color = Color(0.224, 1, 0.078, 1)
theme_override_font_sizes/font_size = 30
text = "[E] 進入"
horizontal_alignment = 1

[node name="ActionMenu" type="PanelContainer" parent="HUD"]
unique_name_in_owner = true
anchors_preset = 6
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_left = -480.0
offset_top = -320.0
offset_right = -40.0
offset_bottom = 320.0
grow_horizontal = 0
grow_vertical = 2

[node name="Margin" type="MarginContainer" parent="HUD/ActionMenu"]
layout_mode = 2
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="VBox" type="VBoxContainer" parent="HUD/ActionMenu/Margin"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="MenuTitle" type="Label" parent="HUD/ActionMenu/Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.843, 0, 1)
theme_override_font_sizes/font_size = 28
text = "地點"
horizontal_alignment = 1

[node name="MenuButtons" type="VBoxContainer" parent="HUD/ActionMenu/Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 8

[node name="Toast" type="Label" parent="HUD"]
unique_name_in_owner = true
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -400.0
offset_top = 110.0
offset_right = 400.0
offset_bottom = 160.0
theme_override_colors/font_color = Color(1, 0.843, 0, 1)
theme_override_font_sizes/font_size = 26
text = "存檔完成"
horizontal_alignment = 1
```

- [ ] **Step 2: 確認沒被 import 卡住**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "error|MapScreen" | head`
Expected: 無 error（此步 `MapScreen.gd` 尚未改、可能與舊 .gd 的 `@onready $DistrictScene` 不符；只看 import/解析錯，下個 Task 改 .gd 後再整體驗。允許此步暫不完整綠，重點是 .tscn 格式合法）。

- [ ] **Step 3: Commit**

```bash
git add MONK/src/screens/MapScreen/MapScreen.tscn
git commit -m "feat(map3d): MapScreen.tscn 改 3D 宿主(根 Node+World，退役 2D 子節點)"
```

---

### Task 4: 改寫 `MapScreen.gd`（3D 協調者）＋ HUD 標籤 ＋ TravelApp 落點

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.gd`（整檔重寫）
- Modify: `src/screens/MapScreen/MapHUD.gd`（`ACTION_LABELS` 加 2 條）
- Modify: `src/ui/menu/pages/TravelApp.gd`（`_pay_taxi` 落點帶 loc）

- [ ] **Step 1: 整檔重寫 `MapScreen.gd`**

```gdscript
extends Node
## 3D 水墨探索協調者：依 current_area instantiate 區場景到 $World，灑 LocationTrigger，
## 沿用所有後端（perform_action / HUD / 存檔 / 主線 / 商店 / 成就）。

const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")
const SHOP_SCREEN := preload("res://src/ui/menu/ShopScreen.gd")
const LOCATION_TRIGGER := preload("res://src/screens/MapScreen/LocationTrigger.tscn")

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD

var _areas: Dictionary = {}
var _locations: Dictionary = {}
var _current_area: String = ""
var _current_loc: String = ""

func _ready() -> void:
	_areas = JsonLoader.load_json("res://data/areas.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_current_area = String(GameManager.player.get("current_area", "shrine"))
	GameManager.time_advanced.connect(_on_time_advanced)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	_drain_pending_achievements()
	_load_area(_current_area)
	_update_hud()

## 載入區環境 + 灑該區觸發點 + 定位玩家 + 切 BGM。
func _load_area(area_id: String) -> void:
	_current_area = area_id
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	for c in world.get_children():
		c.queue_free()
	var env_path: String = String(area.get("environment", ""))
	if not ResourceLoader.exists(env_path):
		push_warning("MapScreen: 區 %s 環境不存在(%s)，fallback ShrineStreet" % [area_id, env_path])
		env_path = "res://src/screens/MapScreen/environments/ShrineStreet.tscn"
	var env: Node = load(env_path).instantiate()
	world.add_child(env)
	_spawn_triggers(env, area_id)
	_place_player(area)
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))

## 依 map_locations.json 灑該區（且已解鎖）的觸發點。
## ponytail: 不按時段過濾觸發點(taxi 清單已有時段過濾)；要時段限定探索再加 available_periods 檢查。
func _spawn_triggers(env: Node, area_id: String) -> void:
	for id in _locations:
		var l: Dictionary = _locations[id]
		if String(l.get("district", "")) != area_id:
			continue
		if l.has("unlock_flag") and not GameManager.get_flag(l.unlock_flag):
			continue
		var trig: Area3D = LOCATION_TRIGGER.instantiate()
		env.add_child(trig)
		trig.setup(id, l)
		trig.player_entered.connect(_on_trigger_entered.bind(id))
		trig.player_exited.connect(_on_trigger_exited.bind(id))

## 落點優先序：計程車 pending_arrival.loc → 戰後 last_position(同區非原點) → default_spawn。
func _place_player(area: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	player.global_position = _spawn_position(area)

func _spawn_position(area: Dictionary) -> Vector3:
	# 1) 計程車落點：到該地點門口（position_3d 往街頭退一點，避免一生成就觸發）
	if not GameManager.pending_arrival.is_empty() \
			and String(GameManager.pending_arrival.get("area", "")) == _current_area:
		var loc_id: String = String(GameManager.pending_arrival.get("loc", ""))
		GameManager.pending_arrival = {}
		if _locations.has(loc_id):
			var p: Dictionary = _locations[loc_id].get("position_3d", {})
			var r: float = float(_locations[loc_id].get("trigger_radius", 2.5))
			return Vector3(float(p.get("x", 0.0)), 1.2, float(p.get("z", 0.0)) + r + 1.0)
	GameManager.pending_arrival = {}
	# 2) 戰後返回：last_position（travel_to 已把它清成原點 → 快速移動會落 default_spawn）
	var lp: Dictionary = GameManager.player.get("last_position", {})
	var lpv := Vector3(float(lp.get("x", 0.0)), float(lp.get("y", 0.0)), float(lp.get("z", 0.0)))
	if lpv != Vector3.ZERO:
		return lpv
	# 3) 預設落點
	var ds: Dictionary = area.get("default_spawn", {"x": 0.0, "y": 1.2, "z": 6.0})
	return Vector3(float(ds.get("x", 0.0)), float(ds.get("y", 1.2)), float(ds.get("z", 6.0)))

func _on_trigger_entered(id: String) -> void:
	_current_loc = id
	var loc: Dictionary = _locations.get(id, {})
	hud.show_action_menu(String(loc.get("name", id)), loc.get("actions", []), perform_action)

func _on_trigger_exited(id: String) -> void:
	if _current_loc == id:
		hud.hide_action_menu()

## 快速移動（手機移動 app 呼叫）：設目的區、清舊位(快速移動落區中心)、重載。
func travel_to(area_id: String) -> void:
	GameManager.player.current_area = area_id
	GameManager.player.last_position = {"x": 0.0, "y": 0.0, "z": 0.0}
	SceneRouter.go_to_map()

## 鐵叔對話 timeline（依阿瑞斯是否已超渡分歧）；抽成函式供測試。
func armory_npc_timeline() -> String:
	return "armory_worker_freed" if GameManager.get_flag("ares_purified") else "armory_worker_locked"

## SceneRouter 戰前呼叫，存玩家位置供戰後返回。
func get_player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_open_main_menu()

func _on_time_advanced(_p: int) -> void:
	_update_hud()

# === 動作分派（沿用舊版，新增 armory_npc；random_encounter 用 _current_loc）===

func perform_action(action: String) -> void:
	hud.hide_action_menu()
	GameManager.advance_time(1)
	match action:
		"main_quest":
			MainQuestManager.continue_story()
		"random_encounter":
			var dist: String = _locations[_current_loc].district
			EventBus.random_encounter_triggered.emit(dist)
			SceneRouter.go_to_battle(_pick_enemy(dist))
		"cherry_dialogue":
			if ResourceLoader.exists("res://dialogue/cherry_first_meeting.dtl"):
				Dialogic.start("cherry_first_meeting")
			else:
				hud.show_toast("Cherry 對話尚未製作")
		"armory_npc":
			var tl := armory_npc_timeline()
			if tl == "armory_worker_freed" and not GameManager.get_flag("armory_worker_thanked"):
				GameManager.add_item("heal_salve", 1)
				GameManager.set_flag("armory_worker_thanked", true)
			if ResourceLoader.exists("res://dialogue/%s.dtl" % tl):
				Dialogic.start(tl)
		"food_break_trigger":
			BreakVowSystem.try_trigger("food")
		"greed_break_trigger":
			BreakVowSystem.try_trigger("greed")
		"lust_break_trigger":
			BreakVowSystem.try_trigger("lust")
		"beggar_minigame":
			SceneRouter.go_to_minigame("beggar_challenge")
		"save":
			_store_position()
			SaveManager.save_game()
			AudioManager.play_sfx("save_done")
			hud.show_toast("存檔完成")
		"job_switch":
			hud.open_job_menu()
		"rest":
			GameManager.heal(150)
			hud.show_toast("休息片刻，恢復了體力")
		"shop":
			if not GameManager.get_flag("zheng_ma_shop_unlocked"):
				hud.show_toast("鄭媽的店還沒開")
			else:
				if get_node_or_null("ShopScreen") == null:
					var shop_overlay: CanvasLayer = SHOP_SCREEN.new()
					shop_overlay.name = "ShopScreen"
					add_child(shop_overlay)
		_:
			if action.begins_with("quest_"):
				QuestManager.trigger_action(action, _current_loc)
				hud.show_toast("支線對話尚未製作")
	_update_hud()

func _store_position() -> void:
	GameManager.player.current_area = _current_area
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var p := player.global_position
		GameManager.player.last_position = {"x": p.x, "y": p.y, "z": p.z}

func _pick_enemy(dist: String) -> String:
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	var pool: Array = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if e.get("district", "") != dist:
			continue
		if e.has("time_restriction") and GameManager.player.period not in e.time_restriction:
			continue
		pool.append(id)
	if pool.is_empty():
		return "street_punk"
	return pool[randi() % pool.size()]

func _on_achievement_unlocked(id: String) -> void:
	_toast_achievement(id)
	AchievementSystem.pending_toasts.erase(id)

func _drain_pending_achievements() -> void:
	for id in AchievementSystem.pending_toasts:
		_toast_achievement(id)
	AchievementSystem.pending_toasts.clear()

func _toast_achievement(id: String) -> void:
	var label: String = id
	for a in AchievementSystem.get_all():
		if a.id == id:
			label = String(a.name)
			break
	hud.show_toast("十二因緣 · %s　已證" % label)

func _update_hud() -> void:
	hud.set_time(GameManager.player.day, GameManager.TIME_PERIODS[GameManager.player.period])
	hud.update_stats()

func _open_main_menu() -> void:
	if get_node_or_null("MenuShell") != null:
		return
	if Dialogic.current_timeline != null:
		return
	add_child(MENU_SHELL.instantiate())
```

> 註：`_pick_enemy` 用的 `enemies.json` 的 `district` 仍是舊區名（ximen 等）；本輪 `random_encounter` 在神社區會落空 → fallback `street_punk`（不擋流程）。敵人 district 對齊新區屬另案，不在本計畫範圍。

- [ ] **Step 2: `MapHUD.gd` 的 `ACTION_LABELS` 加 2 條**

在 `const ACTION_LABELS: Dictionary = {` 內加入（放在開頭即可）：

```gdscript
	"main_quest":          "繼續修行（主線）",
	"armory_npc":          "與鐵叔搭話",
```

- [ ] **Step 3: `TravelApp.gd` 的計程車落點帶 loc（additive，不破舊測試）**

`src/ui/menu/pages/TravelApp.gd` 的 `_pay_taxi`，把：

```gdscript
	GameManager.pending_arrival = {"area": String(loc.get("district", "")), "x": float(sp.get("x", 0.5))}
```
改成（保留 x、加 loc；3D MapScreen 讀 loc）：
```gdscript
	GameManager.pending_arrival = {"area": String(loc.get("district", "")), "x": float(sp.get("x", 0.5)), "loc": loc_id}
```

- [ ] **Step 4: headless parse 健檢**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --check-only --script res://src/screens/MapScreen/MapScreen.gd 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error|error" | head`
Expected: 無輸出。

- [ ] **Step 5: Commit**

```bash
git add MONK/src/screens/MapScreen/MapScreen.gd MONK/src/screens/MapScreen/MapHUD.gd MONK/src/ui/menu/pages/TravelApp.gd
git commit -m "feat(map3d): MapScreen 改 3D 協調者(灑觸發/perform_action 留用/鐵叔分歧)+HUD 標籤+計程車落點"
```

---

### Task 5: headless 接線測試 ＋ 回歸

**Files:**
- Create: `test/TestMapScreen3D.gd`
- Create: `test/TestMapScreen3D.tscn`

- [ ] **Step 1: 建 `test/TestMapScreen3D.gd`**

```gdscript
extends Node
## 驗證 MapScreen 3D 接線：區場景載入、觸發點灑對、鐵叔 flag 分歧。
func _ready() -> void:
	var ms_scene := load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene
	if ms_scene == null: return _fail("MapScreen.tscn missing")
	if not ResourceLoader.exists("res://dialogue/armory_worker_locked.dtl"): return _fail("armory_worker_locked.dtl missing")
	if not ResourceLoader.exists("res://dialogue/armory_worker_freed.dtl"): return _fail("armory_worker_freed.dtl missing")

	# 1) 神社區：載 ShrineStreet + 灑 5 個 shrine 觸發點（不按時段過濾）
	GameManager.new_game()
	var ms := ms_scene.instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Node = ms.get_node("World")
	if world.get_child_count() == 0: return _fail("World 沒載入環境")
	var env: Node = world.get_child(0)
	if not String(env.name).contains("ShrineStreet"): return _fail("shrine 應載 ShrineStreet，實為 %s" % env.name)
	var trigs := get_tree().get_nodes_in_group("location_trigger")
	if trigs.size() != 5: return _fail("神社區應 5 觸發點，實 %d" % trigs.size())
	ms.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# 2) 軍火庫：載 ArmoryDistrict + 1 觸發點（鐵叔）
	GameManager.player.current_area = "armory"
	GameManager.set_flag("armory_unlocked", true)
	var ms2 := ms_scene.instantiate()
	add_child(ms2)
	await get_tree().process_frame
	await get_tree().process_frame
	var env2: Node = ms2.get_node("World").get_child(0)
	if not String(env2.name).contains("ArmoryDistrict"): return _fail("armory 應載 ArmoryDistrict，實為 %s" % env2.name)
	var trigs2 := get_tree().get_nodes_in_group("location_trigger")
	if trigs2.size() != 1: return _fail("軍火庫應 1 觸發點，實 %d" % trigs2.size())

	# 3) 鐵叔 flag 分歧
	if not ms2.has_method("armory_npc_timeline"): return _fail("MapScreen 缺 armory_npc_timeline")
	GameManager.set_flag("ares_purified", false)
	if String(ms2.call("armory_npc_timeline")) != "armory_worker_locked": return _fail("阿瑞斯前應 locked")
	GameManager.set_flag("ares_purified", true)
	if String(ms2.call("armory_npc_timeline")) != "armory_worker_freed": return _fail("阿瑞斯後應 freed")
	ms2.queue_free()

	print("TEST PASS: MapScreen 3D 接線 OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```

- [ ] **Step 2: 建 `test/TestMapScreen3D.tscn`**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestMapScreen3D.gd" id="1"]
[node name="TestMapScreen3D" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 先 headless 跑（parse + 邏輯）**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMapScreen3D.tscn 2>&1 | grep -aiE "TEST PASS|TEST FAIL|SCRIPT ERROR|Parse Error"`
Expected: `TEST PASS: MapScreen 3D 接線 OK`，且**無 TEST FAIL／SCRIPT ERROR**。
（若觸發數不符：檢查 `_spawn_triggers` 的 period/unlock 過濾與 map_locations 的 district；若環境名不符：檢查 areas.json 的 environment 路徑。）

- [ ] **Step 4: 回歸既有測試**

Run（逐一）：
```
./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMainQuest.tscn 2>&1 | grep -aiE "TEST PASS|TEST FAIL|SCRIPT ERROR"
./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestDemoScope.tscn 2>&1 | grep -aiE "TEST PASS|TEST FAIL|SCRIPT ERROR"
./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMenuSystem.tscn 2>&1 | grep -aiE "ALL PASS|TEST PASS|TEST FAIL|SCRIPT ERROR"
./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestShop.tscn 2>&1 | grep -aiE "ALL PASS|TEST PASS|TEST FAIL|SCRIPT ERROR"
./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestCh1Expansion.tscn 2>&1 | grep -aiE "ALL PASS|TEST PASS|TEST FAIL|SCRIPT ERROR"
```
Expected: 全 PASS、無 FAIL/SCRIPT ERROR。
（`TestMenuSystem` 若曾斷言 `pending_arrival` 形狀：本計畫保留了 `x`、僅「加」`loc`，故不應破。若仍紅，依其訊息把斷言改成相容 `loc`。）

- [ ] **Step 5: Commit**

```bash
git add MONK/test/TestMapScreen3D.gd MONK/test/TestMapScreen3D.tscn
git commit -m "test(map3d): MapScreen 3D 接線 headless 驗證(環境/觸發/鐵叔分歧)"
```

---

### Task 6: windowed 截圖視覺驗證

**Files:**
- Create: `test/CaptureMapScreen3D.gd`
- Create: `test/CaptureMapScreen3D.tscn`

- [ ] **Step 1: 建 `test/CaptureMapScreen3D.gd`**

```gdscript
extends Node
## windowed 截圖：神社區 3D 街 + 玩家上墨 + HUD。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_mapscreen3d_shot.png")
	print("CAP_MAP3D_SAVED _mapscreen3d_shot.png ", img.get_width(), "x", img.get_height())
	get_tree().quit()
```

- [ ] **Step 2: 建 `test/CaptureMapScreen3D.tscn`**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/CaptureMapScreen3D.gd" id="1"]
[node name="CaptureMapScreen3D" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 跑 windowed 截圖**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureMapScreen3D.tscn -- smoke 2>&1 | grep -aiE "CAP_MAP3D_SAVED|SHADER ERROR|SCRIPT ERROR"`
Expected: `CAP_MAP3D_SAVED _mapscreen3d_shot.png 1280x720`，**無 SHADER ERROR**。

- [ ] **Step 4: 自檢圖**

`Read` `MONK/_mapscreen3d_shot.png`。確認：3D 水墨神社街渲染正常（屋頂店家/石燈籠/鳥居/和紙顆粒/描邊）、無戒在街上且套水墨 toon、HUD（時間/狀態 label）在最上層可見。落空/黑畫面 → 回 Task 4 檢查 `_load_area` 的 instantiate 與 `_place_player`。

- [ ] **Step 5: Commit**

```bash
git add MONK/test/CaptureMapScreen3D.gd MONK/test/CaptureMapScreen3D.tscn
git commit -m "test(map3d): MapScreen 3D windowed 截圖驗證"
```

---

### Task 7: 清理退役 2D 測試 ＋ 同步文件/記憶

**Files:**
- Delete: 2D 期測試（測到已退役元件、會因新資料/節點而紅）
- Modify: `MONK/PROJECT_STATUS.md`
- Modify: 記憶 `project_mapscreen_areas.md` / `project_3d_environment.md` / `MEMORY.md`

- [ ] **Step 1: 刪退役 2D 測試**

這些測試針對已退役的 2D MapScreen 子節點/欄位，新資料下必紅：

```bash
rm -f MONK/test/TestMapData2D.gd MONK/test/TestMapData2D.gd.uid \
      MONK/test/TestDistrictScene.gd MONK/test/TestDistrictScene.gd.uid \
      MONK/test/TestCityMap.gd MONK/test/TestCityMap.gd.uid \
      MONK/test/TestInterior.gd MONK/test/TestInterior.gd.uid \
      MONK/test/TestMap2D.gd MONK/test/TestMap2D.gd.uid \
      MONK/test/CaptureMap2D.gd MONK/test/CaptureMap2D.gd.uid \
      MONK/test/CaptureMapAll.gd MONK/test/CaptureMapAll.gd.uid
# 對應 .tscn 若存在一併刪
rm -f MONK/test/TestMapData2D.tscn MONK/test/TestDistrictScene.tscn MONK/test/TestCityMap.tscn \
      MONK/test/TestInterior.tscn MONK/test/TestMap2D.tscn MONK/test/CaptureMap2D.tscn MONK/test/CaptureMapAll.tscn
```

- [ ] **Step 2: 確認無殘留引用**

Run: `grep -rn "TestMapData2D\|TestDistrictScene\|TestCityMap" MONK --include=*.gd --include=*.tscn`
Expected: 無輸出（`TestRunner.gd` 若列了這些，一併移除該行）。

- [ ] **Step 3: 全專案 import / parse 總驗**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error" | head`
Expected: 無輸出。

- [ ] **Step 4: 更新 PROJECT_STATUS.md**

把「三大缺口①」與「二、已完成·探索地圖」更新為：3D 水墨探索**已接回 MapScreen**（2 區 shrine/armory、觸發點資料驅動、手機移動往返、軍火庫鐵叔條件 NPC），列出仍待 GPU 抽驗（觸發落位/選單手感/鐵叔對話實機）。

- [ ] **Step 5: 更新記憶**

- `project_mapscreen_areas.md`：MapScreen 已從 2D 改回 3D 宿主、收 2 區、灑現成 LocationTrigger、退役 2D 子節點；落點優先序（taxi loc → last_position → default_spawn）、travel_to 清 last_position 防快速移動落舊點。
- `project_3d_environment.md`：ShrineStreet/ArmoryDistrict 已接回遊戲（不再只是獨立場景）。
- `MEMORY.md`：對應 hook 一行更新。

- [ ] **Step 6: Commit**

```bash
git add -A MONK/test MONK/PROJECT_STATUS.md "C:/Users/cynth/.claude/projects/D--monk/memory"
git commit -m "chore(map3d): 清退役 2D 測試 + 同步文件/記憶"
```

---

## 完工驗收（對齊 spec Acceptance Criteria）
1. ✅ `go_to_map()` 進到的 MapScreen ＝ 可走 3D 水墨街（神社區起始）。（Task 3–4, 6）
2. ✅ 踏觸發開動作選單、`perform_action` 全功能留用（主線/商店/存檔/支線/破戒）。（Task 4–5）
3. ✅ 世界＝2 區；手機「移動」app 在 shrine↔armory 往返（armory 解鎖前不列出）。（Task 1, 4）
4. ✅ 軍火庫鐵叔：`ares_purified` 前 locked、後 freed＋一次性金瘡藥。（Task 1–2, 4–5）
5. ✅ headless 無 parse error、接線測試 PASS、既有回歸 PASS；windowed 截圖自檢過。（Task 5–6）
```
