# MapScreen 分區場景切換 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把已完成的西門霓虹街原型接進正式遊戲，讓 `SceneRouter.go_to_map()` 進到的 `MapScreen` 依「目前區域」載入真環境（西門街）或灰佔位，並用手機選單在區域間快速移動。

**Architecture:** 單一 `MapScreen.tscn`（常駐 Player/CameraRig/HUD ＋空 `Environment` 持有節點），依 `GameManager.player.current_area` 熱抽換環境子節點；觸發點依 `district` 過濾；快速移動＝設 `current_area`＋spawn 後 `SceneRouter.go_to_map()` 重載。

**Tech Stack:** Godot 4.5 / GDScript；JSON 資料（`JsonLoader`）；既有 autoload（GameManager、SaveManager、SceneRouter、AudioManager）。

**設計來源：** `docs/superpowers/specs/2026-06-16-mapscreen-area-switch-design.md`

---

## 前置說明

- **執行環境：** Godot 在 `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`，專案根 `D:/monk/MONK`。
- **版控：** 此專案目前**不在 git 下**（`D:\monk` 非 repo）。各 Task 末的 commit 步驟為**選用 checkpoint**；若要版本紀錄，先在 `D:\monk\MONK` 執行 `git init`。否則跳過 commit 步驟。
- **測試方式（Godot 無 pytest）：** 邏輯用 headless 測試腳本 `test/TestMapArea.gd`（載場景、檢查節點/狀態、印 `TEST PASS`/`push_error`＋`quit` 碼）；視覺用視窗截圖自檢。新資源跑前先 `--import --headless`。
- 每次改 `.gd` 後，至少跑一次相關 headless 場景確認無 `SCRIPT ERROR`/`Parse Error`。

---

## 檔案結構

新增：
- `data/areas.json` — 區域表（區→環境/spawn/bgm/解鎖）
- `src/screens/MapScreen/environments/XimenStreet.tscn` — 包現有 `XimenStreet.gd`
- `src/screens/MapScreen/environments/PlaceholderArea.tscn` — 灰地板＋光＋天空（自 `MapScreen.tscn` 抽出）
- `src/ui/menu/pages/FastTravelApp.gd` — 手機「移動」頁
- `test/TestMapArea.gd` / `test/TestMapArea.tscn` — headless 驗證

修改：
- `src/autoloads/GameManager.gd` — player 加 `current_area`
- `src/screens/MapScreen/CameraRig.gd` — 加 `camera_pitch_deg` export
- `src/screens/MapScreen/MapScreen.tscn` — 移除內建 Floor/Env/Sun、加 `Environment`、設相機 offset
- `src/screens/MapScreen/MapScreen.gd` — 環境載入＋觸發過濾＋spawn＋bgm＋`travel_to`
- `src/ui/menu/MenuShell.gd` — 手機加「移動」頁
- `data/map_locations.json` — ximen 兩觸發點座標改進街內
- `test/TestRunner.gd` — 觸發數預期改為「目前區域」

---

## Task 1: 區域資料表 areas.json

**Files:**
- Create: `data/areas.json`

- [ ] **Step 1: 建立 areas.json**

```json
{
  "ximen": {
    "name": "西門町",
    "environment": "res://src/screens/MapScreen/environments/XimenStreet.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 6.0},
    "bgm": "ximen_night"
  },
  "wanhua_old": {
    "name": "萬華舊區",
    "environment": "res://src/screens/MapScreen/environments/PlaceholderArea.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 0.0},
    "bgm": "temple_ambient"
  },
  "linsen": {
    "name": "林森商圈",
    "environment": "res://src/screens/MapScreen/environments/PlaceholderArea.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 0.0},
    "bgm": "linsen_night",
    "unlock_flag": "linsen_unlocked"
  }
}
```

- [ ] **Step 2: 驗證 JSON 合法**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --check-only --script res://test/TestMapArea.gd`（此時 TestMapArea 尚未建，先用下行替代）
替代驗證：用 Godot headless 啟一個 eval——直接進 Task 8 寫 TestMapArea 時會載入它；本步只需肉眼確認 JSON 括號/逗號正確。

- [ ] **Step 3 (選用): Commit**

```bash
git add data/areas.json
git commit -m "feat(map): add areas.json area registry"
```

---

## Task 2: GameManager 加 current_area

**Files:**
- Modify: `src/autoloads/GameManager.gd:13-24`（player 預設 dict）、`:128-141`（new_game）

- [ ] **Step 1: player 預設 dict 加 current_area**

把 `src/autoloads/GameManager.gd` 的 player 預設值（第 13-24 行）改為（新增最後一欄）：

```gdscript
var player: Dictionary = {
	"name": "無戒",
	"max_hp": MAX_HP, "current_hp": MAX_HP,
	"merit": 0, "karma": 0, "gold": 1000,
	"job": "ascetic",
	"skills_unlocked": ["basic_punch", "wooden_fish"],
	"day": 1, "period": 0,
	"flags": {},
	"completed_quests": [],
	"active_quests": {},
	"last_position": {"x": 0.0, "y": 0.0, "z": 0.0},
	"current_area": "ximen"
}
```

- [ ] **Step 2: new_game 也設 current_area＋起始西門街**

把 `new_game()`（第 128-141 行）改為：

```gdscript
## 新遊戲：重置玩家狀態。本輪起始＝西門町（看真街）；破廟真環境做好後可改回 hub。
func new_game() -> void:
	player = {
		"name": "無戒",
		"max_hp": MAX_HP, "current_hp": MAX_HP,
		"merit": 0, "karma": 0, "gold": 1000,
		"job": "ascetic",
		"skills_unlocked": ["basic_punch", "wooden_fish"],
		"day": 1, "period": 0,
		"flags": {},
		"completed_quests": [],
		"active_quests": {},
		"last_position": {"x": 0.0, "y": 1.2, "z": 6.0},
		"current_area": "ximen"
	}
```

- [ ] **Step 3: 驗證無語法錯**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --quit`
Expected: 啟動到關閉無 `SCRIPT ERROR`/`Parse Error`（ObjectDB leaked 警告可忽略）。

- [ ] **Step 4 (選用): Commit**

```bash
git add src/autoloads/GameManager.gd
git commit -m "feat(map): track current_area in player state"
```

---

## Task 3: CameraRig 過肩 pitch export

**Files:**
- Modify: `src/screens/MapScreen/CameraRig.gd`

- [ ] **Step 1: 加 export pitch、套用取代寫死 -50**

把 `src/screens/MapScreen/CameraRig.gd` 全檔改為：

```gdscript
extends Node3D

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var camera_pitch_deg: float = -12.0
@export var follow_speed: float = 0.08

@onready var camera: Camera3D = $Camera3D
@onready var _target: Node3D = get_node_or_null(target_path)

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_pitch_deg
	if _target:
		global_position = _target.global_position

func _physics_process(_delta: float) -> void:
	if _target:
		global_position = global_position.lerp(_target.global_position, follow_speed)
```

- [ ] **Step 2 (選用): Commit**

```bash
git add src/screens/MapScreen/CameraRig.gd
git commit -m "feat(map): expose CameraRig pitch as export"
```

---

## Task 4: 環境場景檔（XimenStreet.tscn ＋ PlaceholderArea.tscn）

**Files:**
- Create: `src/screens/MapScreen/environments/XimenStreet.tscn`
- Create: `src/screens/MapScreen/environments/PlaceholderArea.tscn`

- [ ] **Step 1: XimenStreet.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/screens/MapScreen/environments/XimenStreet.gd" id="1"]

[node name="XimenStreet" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 2: PlaceholderArea.tscn（搬自 MapScreen.tscn 的 Floor/Env/Sun）**

```
[gd_scene load_steps=5 format=3]

[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.05, 0.05, 0.09, 1)
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.6, 0.75, 1)

[sub_resource type="BoxShape3D" id="floor_shape"]
size = Vector3(80, 1, 80)

[sub_resource type="StandardMaterial3D" id="floor_mat"]
albedo_color = Color(0.35, 0.35, 0.38, 1)

[sub_resource type="BoxMesh" id="floor_mesh"]
material = SubResource("floor_mat")
size = Vector3(80, 1, 80)

[node name="PlaceholderArea" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.5736, 0.8192, 0, -0.8192, 0.5736, 0, 20, 0)
shadow_enabled = true

[node name="Floor" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
shape = SubResource("floor_shape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
mesh = SubResource("floor_mesh")
```

- [ ] **Step 3: 匯入並驗證可載入**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import`
Expected: 看到 `XimenStreet.tscn`、`PlaceholderArea.tscn` 被匯入，無錯誤。

- [ ] **Step 4 (選用): Commit**

```bash
git add src/screens/MapScreen/environments/XimenStreet.tscn src/screens/MapScreen/environments/PlaceholderArea.tscn
git commit -m "feat(map): area environment scenes (ximen + placeholder)"
```

---

## Task 5: MapScreen.tscn 重構（移除內建環境、加 Environment 持有節點、相機 offset）

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.tscn`

- [ ] **Step 1: 改 header load_steps**

把第 1 行 `[gd_scene load_steps=12 format=3]` 改為：

```
[gd_scene load_steps=8 format=3]
```

- [ ] **Step 2: 刪除 4 個用不到的 sub_resource**

刪掉以下整段（原第 8-22 行的 `env` / `floor_shape` / `floor_mat` / `floor_mesh`）：

```
[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.05, 0.05, 0.09, 1)
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.6, 0.75, 1)

[sub_resource type="BoxShape3D" id="floor_shape"]
size = Vector3(80, 1, 80)

[sub_resource type="StandardMaterial3D" id="floor_mat"]
albedo_color = Color(0.35, 0.35, 0.38, 1)

[sub_resource type="BoxMesh" id="floor_mesh"]
material = SubResource("floor_mat")
size = Vector3(80, 1, 80)
```

（保留 `player_shape` / `player_mat` / `player_mesh` 三個 sub_resource 不動。）

- [ ] **Step 3: 刪除 WorldEnvironment / Sun / Floor 節點，改加 Environment 持有節點**

刪掉這段（原第 39-54 行的 WorldEnvironment、Sun、Floor 整棵）：

```
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.5736, 0.8192, 0, -0.8192, 0.5736, 0, 20, 0)
shadow_enabled = true

[node name="Floor" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
shape = SubResource("floor_shape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
mesh = SubResource("floor_mesh")
```

在 `[node name="MapScreen" type="Node3D"]`（含 `script = ExtResource("1")`）正下方插入：

```
[node name="Environment" type="Node3D" parent="."]
```

- [ ] **Step 4: CameraRig 加 camera_offset**

找到 CameraRig 節點段：

```
[node name="CameraRig" type="Node3D" parent="." node_paths=PackedStringArray("target_path")]
script = ExtResource("3")
target_path = NodePath("../Player")
```

在其下加一行：

```
camera_offset = Vector3(0, 3.4, 5.2)
```

- [ ] **Step 5: 驗證場景可開（headless 載入不報缺資源）**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import`
Expected: 無 `Failed loading resource` / 缺 SubResource 錯誤。

- [ ] **Step 6 (選用): Commit**

```bash
git add src/screens/MapScreen/MapScreen.tscn
git commit -m "refactor(map): swappable Environment holder, over-shoulder camera"
```

---

## Task 6: MapScreen.gd 區域載入＋觸發過濾＋spawn＋travel_to

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.gd:6-21`（節點參照與 _ready）、`:24-33`（_build_triggers）
- Test: `test/TestMapArea.gd`（Task 8 建立並回頭驗證）

- [ ] **Step 1: 加節點參照與區域狀態**

把 `MapScreen.gd` 第 6-11 行：

```gdscript
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD

var _locations: Dictionary = {}
var _current_loc: String   = ""
var _in_trigger: bool      = false
```

改為：

```gdscript
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD
@onready var environment_holder: Node3D = $Environment

const PLACEHOLDER_ENV := "res://src/screens/MapScreen/environments/PlaceholderArea.tscn"

var _areas: Dictionary     = {}
var _locations: Dictionary = {}
var _current_area: String  = ""
var _current_loc: String   = ""
var _in_trigger: bool      = false
```

- [ ] **Step 2: 改寫 _ready（載區域環境＋過濾觸發＋spawn＋bgm）**

把 `_ready()`（原第 13-22 行）改為：

```gdscript
func _ready() -> void:
	_areas = JsonLoader.load_json("res://data/areas.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_current_area = String(GameManager.player.get("current_area", "ximen"))
	_load_environment(_current_area)
	_build_triggers()
	_update_hud()
	GameManager.time_advanced.connect(_on_time_advanced)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	_drain_pending_achievements()  # 補播在過場/戰鬥中（地圖不在場）解的成就
	_spawn_player()
	var area: Dictionary = _areas.get(_current_area, {})
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))
```

- [ ] **Step 3: 加 _load_environment / _spawn_player / travel_to**

在 `_ready()` 之後、`_build_triggers()` 之前插入：

```gdscript
## 依區域把環境 .tscn 掛進 Environment 持有節點（找不到→灰佔位，避免黑畫面）。
func _load_environment(area_id: String) -> void:
	for c in environment_holder.get_children():
		c.queue_free()
	var area: Dictionary = _areas.get(area_id, {})
	var path: String = String(area.get("environment", ""))
	var scene: PackedScene = null
	if path != "" and ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	if scene == null:
		push_warning("MapScreen: 區域 %s 環境載入失敗，改用佔位" % area_id)
		scene = load(PLACEHOLDER_ENV) as PackedScene
	environment_holder.add_child(scene.instantiate())

## 生玩家：用 last_position；若為原點則退回該區 default_spawn。
func _spawn_player() -> void:
	var lp: Dictionary = GameManager.player.last_position
	var pos := Vector3(lp.x, lp.y, lp.z)
	if pos == Vector3.ZERO:
		var area: Dictionary = _areas.get(_current_area, {})
		if area.has("default_spawn"):
			var s: Dictionary = area.default_spawn
			pos = Vector3(s.x, s.y, s.z)
	player.global_position = pos

## 快速移動：設目的區域＋spawn 後重載地圖（沿用既有轉場）。
func travel_to(area_id: String, spawn: Vector3 = Vector3.ZERO) -> void:
	if _areas.is_empty():
		_areas = JsonLoader.load_json("res://data/areas.json")
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	var sp := spawn
	if sp == Vector3.ZERO and area.has("default_spawn"):
		var s: Dictionary = area.default_spawn
		sp = Vector3(s.x, s.y, s.z)
	GameManager.player.last_position = {"x": sp.x, "y": sp.y, "z": sp.z}
	SceneRouter.go_to_map()
```

- [ ] **Step 4: _build_triggers 依區域過濾**

把 `_build_triggers()`（原第 24-33 行）改為：

```gdscript
func _build_triggers() -> void:
	for id in _locations:
		var loc: Dictionary = _locations[id]
		if String(loc.get("district", "")) != _current_area:
			continue
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
			continue
		var t := TRIGGER_SCENE.instantiate()
		t.setup(id, loc)
		t.player_entered.connect(_on_entered.bind(id))
		t.player_exited.connect(_on_exited)
		add_child(t)
```

- [ ] **Step 5: 移除舊的 last_position 直接定位（已被 _spawn_player 取代）**

確認 `_ready` 內**不再**保留原本第 20-21 行的：

```gdscript
	var p: Dictionary = GameManager.player.last_position
	player.global_position = Vector3(p.x, p.y, p.z)
```

（Step 2 的新 `_ready` 已不含這兩行，改呼叫 `_spawn_player()`；若殘留請刪除。）

- [ ] **Step 6: 驗證無語法錯**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --quit`
Expected: 無 `SCRIPT ERROR`/`Parse Error`。（功能驗證在 Task 8。）

- [ ] **Step 7 (選用): Commit**

```bash
git add src/screens/MapScreen/MapScreen.gd
git commit -m "feat(map): per-area environment loading, trigger filter, travel_to"
```

---

## Task 7: map_locations.json 西門觸發點座標進街內

**Files:**
- Modify: `data/map_locations.json:2-8`（ximen_mrt）、`:9-15`（wannian_mall）

- [ ] **Step 1: 改 ximen_mrt 與 wannian_mall 的 position_3d**

把 `ximen_mrt` 的 `position_3d` 從 `{"x": 12.0, "y": 0.0, "z": -8.0}` 改為：

```json
    "position_3d": {"x": -5.2, "y": 0.0, "z": -20.0}, "trigger_radius": 2.5,
```

把 `wannian_mall` 的 `position_3d` 從 `{"x": 8.0, "y": 0.0, "z": -5.0}` 改為：

```json
    "position_3d": {"x": 5.2, "y": 0.0, "z": 2.0}, "trigger_radius": 3.0,
```

（街寬 x±7、長 z±34；這兩點落在左右人行道側、避開 `XimenStreet._build_props` 的道具 z 位。其餘區地點座標不動。）

- [ ] **Step 2 (選用): Commit**

```bash
git add data/map_locations.json
git commit -m "feat(map): place ximen triggers inside the street"
```

---

## Task 8: headless 驗證腳本 TestMapArea

**Files:**
- Create: `test/TestMapArea.gd`, `test/TestMapArea.tscn`

- [ ] **Step 1: 先寫驗證腳本（此時跑會失敗＝尚未全綁好則報錯，全綁好則 PASS）**

`test/TestMapArea.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/TestMapArea.gd" id="1"]

[node name="TestMapArea" type="Node"]
script = ExtResource("1")
```

`test/TestMapArea.gd`：

```gdscript
extends Node
## headless 驗證分區切換：①西門區載入 XimenStreet＋只建 ximen 觸發
## ②travel_to 切到萬華佔位＋換成該區觸發 ③current_area 寫進 player（存檔保得住）。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestMapArea.tscn

func _ready() -> void:
	await get_tree().process_frame
	GameManager.new_game()  # current_area=ximen, spawn 西門

	# ① 進西門
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		return _fail("MapScreen 未載入")
	await get_tree().process_frame
	var env := map.get_node_or_null("Environment")
	if env == null or env.get_child_count() == 0:
		return _fail("Environment 未掛環境")
	if not (env.get_child(0).name.begins_with("XimenStreet")):
		return _fail("西門區未載 XimenStreet，實際=%s" % env.get_child(0).name)
	var ximen_triggers := get_tree().get_nodes_in_group("location_trigger").size()
	print("TEST: 西門觸發數 = %d" % ximen_triggers)
	if ximen_triggers != 2:
		return _fail("西門觸發數應為 2（ximen_mrt+wannian_mall），實得 %d" % ximen_triggers)

	# ② 快速移動到萬華（佔位）
	map.travel_to("wanhua_old")
	map = await _wait_for_scene("MapScreen")
	if map == null:
		return _fail("travel 後 MapScreen 未載入")
	await get_tree().process_frame
	if GameManager.player.current_area != "wanhua_old":
		return _fail("current_area 未更新為 wanhua_old")
	env = map.get_node_or_null("Environment")
	if env == null or env.get_child_count() == 0 or not env.get_child(0).name.begins_with("PlaceholderArea"):
		return _fail("萬華區未載 PlaceholderArea")
	var wanhua_triggers := get_tree().get_nodes_in_group("location_trigger").size()
	print("TEST: 萬華觸發數 = %d" % wanhua_triggers)
	if wanhua_triggers != 2:  # old_temple + zen_bbq
		return _fail("萬華觸發數應為 2（old_temple+zen_bbq），實得 %d" % wanhua_triggers)

	# ③ 存檔→改值→讀檔，current_area 應還原
	SaveManager.save_game()
	GameManager.player.current_area = "ximen"
	SaveManager.load_game()
	if GameManager.player.current_area != "wanhua_old":
		return _fail("讀檔未還原 current_area")

	print("TEST PASS: 分區切換 ①②③ 全通過")
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null

func _fail(msg: String) -> void:
	push_error("TEST FAIL: %s" % msg)
	get_tree().quit(1)
```

- [ ] **Step 2: 先匯入再跑**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import`
Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMapArea.tscn`
Expected: 印出 `TEST PASS: 分區切換 ①②③ 全通過`，離開碼 0。
若失敗：依 `TEST FAIL:` 訊息回頭修對應 Task（環境名/觸發數/current_area）。

- [ ] **Step 3 (選用): Commit**

```bash
git add test/TestMapArea.gd test/TestMapArea.tscn
git commit -m "test(map): headless area-switch verification"
```

---

## Task 9: 手機快速移動頁 FastTravelApp ＋ MenuShell 接線

**Files:**
- Create: `src/ui/menu/pages/FastTravelApp.gd`
- Modify: `src/ui/menu/MenuShell.gd:6-9`（preload）、`:38-43`（phone pages）

- [ ] **Step 1: 建 FastTravelApp 頁**

`src/ui/menu/pages/FastTravelApp.gd`：

```gdscript
extends VBoxContainer
## 手機「移動」頁：列出已解鎖區域，選擇→關選單→MapScreen.travel_to 重載到該區。

const GOLD := Color(0.788, 0.659, 0.38)
const DIM := Color(0.55, 0.52, 0.46)

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var cur: String = String(GameManager.player.get("current_area", ""))
	var title := Label.new()
	title.text = "快速移動"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	for id in areas:
		var area: Dictionary = areas[id]
		if area.has("unlock_flag") and not GameManager.get_flag(area.unlock_flag):
			continue
		var btn := Button.new()
		var here: bool = (id == cur)
		btn.text = "%s%s" % [String(area.get("name", id)), "（目前）" if here else ""]
		btn.add_theme_font_size_override("font_size", 26)
		btn.disabled = here
		var area_id: String = id
		btn.pressed.connect(func() -> void: _travel(area_id))
		add_child(btn)

func _travel(area_id: String) -> void:
	get_tree().paused = false   # 解除選單暫停，讓轉場/重載正常跑
	var map := get_tree().current_scene
	if map and map.has_method("travel_to"):
		map.travel_to(area_id)   # 內部 go_to_map 會換場、連同本選單一起釋放
```

- [ ] **Step 2: MenuShell 接入「移動」頁**

把 `src/ui/menu/MenuShell.gd` 第 6-9 行的 preload 區改為（加一行）：

```gdscript
const SkillsPage := preload("res://src/ui/menu/pages/SkillsPage.gd")
const StatusPage := preload("res://src/ui/menu/pages/StatusPage.gd")
const QuestsApp := preload("res://src/ui/menu/pages/QuestsApp.gd")
const IntelApp := preload("res://src/ui/menu/pages/IntelApp.gd")
const FastTravelApp := preload("res://src/ui/menu/pages/FastTravelApp.gd")
```

把 phone 裝置的 pages（第 38-43 行）改為（在「任務/情報」後、「其他」前插入「移動」）：

```gdscript
			"phone": {"name": "手機", "pages": [
				{"title": "任務", "factory": func() -> Control: return QuestsApp.new()},
				{"title": "情報", "factory": func() -> Control: return IntelApp.new()},
				{"title": "移動", "factory": func() -> Control: return FastTravelApp.new()},
				{"title": "其他", "factory": func() -> Control: return _placeholder()},
			]},
```

- [ ] **Step 3: 驗證無語法錯**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --quit`
Expected: 無 `SCRIPT ERROR`/`Parse Error`。

- [ ] **Step 4 (選用): Commit**

```bash
git add src/ui/menu/pages/FastTravelApp.gd src/ui/menu/MenuShell.gd
git commit -m "feat(map): phone fast-travel page"
```

---

## Task 10: 修正既有 TestRunner 觸發數預期

**Files:**
- Modify: `test/TestRunner.gd:16-22`

- [ ] **Step 1: 把「>=4」改成符合分區後的西門 2 點**

把 `test/TestRunner.gd` 第 17-22 行：

```gdscript
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	print("TEST: 地點觸發器數量 = %d" % triggers.size())
	if triggers.size() < 4:
		_fail("觸發器數量不足")
		return
```

改為：

```gdscript
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	print("TEST: 西門區觸發器數量 = %d" % triggers.size())
	if triggers.size() < 2:
		_fail("西門區觸發器數量不足（應為 ximen_mrt+wannian_mall）")
		return
```

- [ ] **Step 2: 跑既有煙霧測試確認仍綠**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestRunner.gd`
Expected: 仍走到 `TEST PASS: Step 1 + Step 3 驗收流程完整通過`（街頭混混屬 ximen，戰鬥流程不受影響）。

- [ ] **Step 3 (選用): Commit**

```bash
git add test/TestRunner.gd
git commit -m "test(map): expect per-area trigger count"
```

---

## Task 11: 視窗截圖視覺自檢

**Files:**
- Create: `test/CaptureMapArea.gd`, `test/CaptureMapArea.tscn`

- [ ] **Step 1: 截圖腳本（正式流程進地圖，存 PNG）**

`test/CaptureMapArea.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/CaptureMapArea.gd" id="1"]

[node name="CaptureMapArea" type="Node"]
script = ExtResource("1")
```

`test/CaptureMapArea.gd`：

```gdscript
extends Node
## 視窗截圖：走正式流程 go_to_map 進西門區，等街景穩定後存 PNG。
## 跑法（非 headless）：Godot_..._console.exe --path D:/monk/MONK res://test/CaptureMapArea.tscn

func _ready() -> void:
	await get_tree().process_frame
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		push_error("CAP FAIL: MapScreen 未載入")
		get_tree().quit(1)
		return
	for i in 200:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_mapscreen_ximen.png")
	print("MAP_CAP_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null
```

- [ ] **Step 2: 跑視窗截圖**

Run: `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureMapArea.tscn`
Expected: 印 `MAP_CAP_DONE 1280x720`，產出 `D:\monk\MONK\_mapscreen_ximen.png`。

- [ ] **Step 3: 肉眼自檢**

開 `_mapscreen_ximen.png` 確認：①西門霓虹街（非灰地板）②過肩相機（壓低貼街）③人群＋道具在。
若相機太高/太低，調 `MapScreen.tscn` 的 `camera_offset`／`CameraRig.gd` 的 `camera_pitch_deg` 後重跑。

- [ ] **Step 4 (選用): Commit**

```bash
git add test/CaptureMapArea.gd test/CaptureMapArea.tscn
git commit -m "test(map): windowed ximen map capture"
```

---

## Self-Review（撰寫後自查結果）

- **Spec 覆蓋：** 分區切換(Task 5/6)、手機快速移動(Task 9)、只西門真環境其餘佔位(Task 1/4)、CameraRig 過肩(Task 3/5)、current_area 存讀檔(Task 2＋SaveManager 自動序列化整個 player dict，無需改 SaveManager)、ximen 觸發進街(Task 7)、驗證(Task 8/11)。✅
- **回歸：** 分區過濾使 MapScreen 只建目前區觸發 → 既有 `TestRunner`「>=4」會誤判，已用 Task 10 修正。✅
- **無 placeholder：** 各步皆含實際檔案內容/指令/預期輸出。MenuShell 接法已確定（phone 加「移動」頁，非 TBD）。✅
- **型別/名稱一致：** `travel_to(area_id, spawn)`、`_load_environment`、`_spawn_player`、`environment_holder`、`current_area`、`default_spawn`、環境節點名 `XimenStreet`/`PlaceholderArea` 在 Task 6 定義、Task 8 驗證一致。✅
- **SaveManager：** 序列化整個 `GameManager.player`，加 `current_area` 自動含括，故無對應 Task（設計如此）。✅
