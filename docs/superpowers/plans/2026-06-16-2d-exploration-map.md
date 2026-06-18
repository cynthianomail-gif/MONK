# 2D 探索地圖（楓谷式）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把探索地圖從 3D 改成 2D 楓谷式（城市地圖→橫向捲動街景→地點內景），沿用所有後端，畫風維持半寫實厚塗。

**Architecture:** `MapScreen` 由 Node3D 改建為 Control 協調者，持有三個子層（`DistrictScene` 捲動街景 / `LocationInterior` 內景 / `CityMap` 選區）＋沿用的 `MapHUD`。資料驅動：`areas.json`/`map_locations.json` 加 2D 欄位。角色 sprite 從既有 3D 模型渲染。先用佔位色塊把系統跑通＋測試，最後置換正式美術。

**Tech Stack:** Godot 4.5 / GDScript；既有 `GameManager`/`SceneRouter`/`Dialogic`/`MapHUD`；美術用 magnific/freepik（額度多者）生成、3D→2D sprite 用視窗截圖渲染。

**設計來源：** `docs/superpowers/specs/2026-06-16-2d-exploration-map-design.md`

---

## 前置說明

- **Godot：** `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`（headless/console）與 `Godot_v4.5-stable_win64.exe`（視窗截圖），專案 `D:/monk/MONK`。
- **版控：** 專案不在 git 下；每個 Task 的「Commit」步驟為**選用 checkpoint**（可略）。
- **測試＝** headless 場景檢查（root Node＋腳本，印 `TEST PASS:`／`push_error`＋`quit(碼)`）＋視窗截圖 Read 自檢。**新資源/新圖跑前先 `--import --headless`**（runtime exe 不會自動匯入）。
- **既有 MapScreen.gd 後端方法**（`perform_action`、`_pick_enemy`、`_on_achievement_unlocked`、`_drain_pending_achievements`、`_toast_achievement`、`_update_hud`、`_open_main_menu`）在改建後**原封不動保留**；本計畫只改「3D 前端」相關部分，各 Task 明列保留/替換。
- **退役不刪：** `XimenStreet.gd`、3D `Player.tscn`/`CameraRig.gd`/`LocationTrigger.*`、Meshy 道具 GLB——從地圖流程拔掉、檔案留著。
- **✅ 本計畫已實作並驗證完成（系統 Phase 0–2 + 美術 Phase 3）。** ⚠ **街景於 2026-06-16 二版改為「平面立面＋2 倍長（6036×1344）」**，做法見 spec「## 二版更新」：正交平面立面（prompt 嚴禁 "mild depth"）、reference-guided 延續段＋`tools/stitch_street.py` 拼接、`test/CaptureMapAll.tscn` 驗證。Phase 3 下方關於街景視角/寬度的舊步驟以 spec 二版為準。

---

## 檔案結構

新增：
- `src/screens/MapScreen/DistrictScene.gd` + `.tscn` — 橫向捲動街景層
- `src/screens/MapScreen/Wujie.gd` — 2D 無戒（AnimatedSprite2D，程式建 SpriteFrames）
- `src/screens/MapScreen/Portal.gd` + `Portal.tscn` — 傳送點（地點型/邊界型，可點可走近）
- `src/screens/MapScreen/LocationInterior.gd` + `.tscn` — 地點內景層
- `src/screens/MapScreen/CityMap.gd` + `.tscn` — 城市地圖選區層
- `test/RenderWujieSprite.gd` + `.tscn` — 從 3D 模型渲 idle/walk 透明 PNG
- `test/TestMap2D.gd` + `.tscn` — headless 邏輯驗證
- `test/CaptureMap2D.gd` + `.tscn` — 視窗截圖
- `test/CaptureMapAll.gd` + `.tscn` —（二版）視窗截圖全區/內景/城市地圖各一張供美術自檢
- `tools/stitch_street.py` —（二版）長街拼接：色彩匹配＋均場校正＋交叉淡入
- `assets/2d/characters/wujie/sprite/` — 渲出的 sprite PNG（idle/walk frames）
- `assets/2d/map/` — `city_map.png`、`scenes/*.png`（街景＝二版 6036×1344 平面長街）、`interiors/*.png`（Phase 3 生成）

修改：
- `data/areas.json` — 每區加 `scene_2d`/`scene_spawn`/`map_pos`/`edge_portals`
- `data/map_locations.json` — 每地點加 `scene_pos`/`interior_2d`
- `src/screens/MapScreen/MapScreen.gd` — 改建為 Control 協調者
- `src/screens/MapScreen/MapScreen.tscn` — 改建為 Control 根

不動：`MapHUD.gd`/`MapHUD` 場景、`perform_action` 行為、`travel_to` 介面、`data/enemies.json`。

---

## Phase 0 — 資料模型 + 角色 sprite

### Task 1: 資料加 2D 欄位

**Files:**
- Modify: `data/areas.json`
- Modify: `data/map_locations.json`
- Create: `test/TestMapData2D.gd`, `test/TestMapData2D.tscn`

- [ ] **Step 1: 寫驗證測試（先失敗）**

`test/TestMapData2D.tscn`：
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestMapData2D.gd" id="1"]
[node name="TestMapData2D" type="Node"]
script = ExtResource("1")
```
`test/TestMapData2D.gd`：
```gdscript
extends Node
## 驗證 areas/locations 已加 2D 欄位，型別正確。
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var locs: Dictionary = JsonLoader.load_json("res://data/map_locations.json")
	for aid in areas:
		var a: Dictionary = areas[aid]
		for k in ["scene_2d", "scene_spawn", "map_pos"]:
			if not a.has(k): return _fail("area %s 缺 %s" % [aid, k])
		if not (a.scene_spawn.has("x") and a.scene_spawn.has("y")): return _fail("area %s scene_spawn 缺 x/y" % aid)
	for lid in locs:
		var l: Dictionary = locs[lid]
		for k in ["scene_pos", "interior_2d"]:
			if not l.has(k): return _fail("loc %s 缺 %s" % [lid, k])
		if not (l.scene_pos.has("x") and l.scene_pos.has("y")): return _fail("loc %s scene_pos 缺 x/y" % lid)
	print("TEST PASS: 2D 地圖資料欄位齊全")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `D:/monk/tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMapData2D.tscn`
Expected: `TEST FAIL: area ximen 缺 scene_2d`（quit 1）。

- [ ] **Step 3: 改 areas.json**

```json
{
  "ximen": {
    "name": "西門町",
    "scene_2d": "res://assets/2d/map/scenes/ximen_street.png",
    "scene_spawn": {"x": 0.12, "y": 0.82},
    "map_pos": {"x": 0.24, "y": 0.42},
    "edge_portals": [{"to": "wanhua_old", "x": 0.97}],
    "bgm": "ximen_night",
    "environment": "res://src/screens/MapScreen/environments/XimenStreet.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 6.0}
  },
  "wanhua_old": {
    "name": "萬華舊區",
    "scene_2d": "res://assets/2d/map/scenes/wanhua_street.png",
    "scene_spawn": {"x": 0.10, "y": 0.82},
    "map_pos": {"x": 0.52, "y": 0.60},
    "edge_portals": [{"to": "ximen", "x": 0.03}, {"to": "linsen", "x": 0.97}],
    "bgm": "temple_ambient",
    "environment": "res://src/screens/MapScreen/environments/PlaceholderArea.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 0.0}
  },
  "linsen": {
    "name": "林森商圈",
    "scene_2d": "res://assets/2d/map/scenes/linsen_street.png",
    "scene_spawn": {"x": 0.10, "y": 0.82},
    "map_pos": {"x": 0.78, "y": 0.34},
    "edge_portals": [{"to": "wanhua_old", "x": 0.03}],
    "bgm": "linsen_night",
    "unlock_flag": "linsen_unlocked",
    "environment": "res://src/screens/MapScreen/environments/PlaceholderArea.tscn",
    "default_spawn": {"x": 0.0, "y": 1.2, "z": 0.0}
  }
}
```

- [ ] **Step 4: 改 map_locations.json**

每地點加 `scene_pos`（0~1 跨整張長街）與 `interior_2d`：
```json
{
  "ximen_mrt": {
    "name": "捷運西門站 6 號出口", "district": "ximen",
    "scene_pos": {"x": 0.28, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/ximen_mrt.png",
    "actions": ["beggar_minigame", "random_encounter", "quest_ah_ming", "quest_rei"],
    "available_periods": [1, 2, 3], "bgm": "ximen_night",
    "position_3d": {"x": -5.2, "y": 0.0, "z": -20.0}, "trigger_radius": 2.5,
    "scene_file": "res://assets/3d/environments/ximen_mrt.glb"
  },
  "wannian_mall": {
    "name": "萬年商業大樓", "district": "ximen",
    "scene_pos": {"x": 0.66, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/wannian_mall.png",
    "actions": ["shop", "greed_break_trigger", "quest_zheng_ma", "quest_jie"],
    "available_periods": [0, 1, 2], "bgm": "ximen_day",
    "position_3d": {"x": 5.2, "y": 0.0, "z": 2.0}, "trigger_radius": 3.0,
    "scene_file": "res://assets/3d/environments/wannian_mall.glb"
  },
  "zen_bbq": {
    "name": "禪味燒肉", "district": "wanhua_old",
    "scene_pos": {"x": 0.35, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/zen_bbq.png",
    "actions": ["food_break_trigger", "rest", "quest_ah_zhong", "quest_david"],
    "available_periods": [2, 3], "bgm": "wanhua_night",
    "position_3d": {"x": -15.0, "y": 0.0, "z": 10.0}, "trigger_radius": 2.0,
    "scene_file": "res://assets/3d/environments/zen_bbq.glb"
  },
  "zuijin_club": {
    "name": "紫醉金迷公關俱樂部", "district": "linsen",
    "scene_pos": {"x": 0.55, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/zuijin_club.png",
    "actions": ["cherry_dialogue", "lust_break_trigger", "quest_cherry_debt", "quest_cai_ma"],
    "available_periods": [3], "unlock_flag": "linsen_unlocked", "bgm": "linsen_night",
    "position_3d": {"x": 25.0, "y": 0.0, "z": -18.0}, "trigger_radius": 2.5,
    "scene_file": "res://assets/3d/environments/zuijin_club.glb"
  },
  "old_temple": {
    "name": "破舊古廟", "district": "wanhua_old",
    "scene_pos": {"x": 0.70, "y": 0.80}, "interior_2d": "res://assets/2d/map/interiors/old_temple.png",
    "actions": ["main_quest", "save", "job_switch", "rest", "skill_learn", "quest_grandma", "quest_lao_wang"],
    "available_periods": [0, 1, 2, 3], "bgm": "temple_ambient",
    "position_3d": {"x": -18.0, "y": 0.0, "z": 8.0}, "trigger_radius": 3.0,
    "scene_file": "res://assets/3d/environments/old_temple.glb"
  }
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `Godot --headless --path D:/monk/MONK res://test/TestMapData2D.tscn`
Expected: `TEST PASS: 2D 地圖資料欄位齊全`。

- [ ] **Step 6 (選用): Commit** — `feat(map): add 2D fields to areas/locations`

---

### Task 2: 從 3D 模型渲 無戒 idle/walk sprite

**Files:**
- Create: `test/RenderWujieSprite.gd`, `test/RenderWujieSprite.tscn`
- Output: `assets/2d/characters/wujie/sprite/idle_0.png`, `walk_0.png`..`walk_7.png`

- [ ] **Step 1: 寫渲染腳本**

要點：SubViewport 透明背景＋固定側相機；逐格推進 walk 動畫；**每格把模型水平/縱深位移歸零**（抵銷 walk root motion，sprite 才對齊）；裁切存透明 PNG。沿用既有 `wujie_walk.glb`、`PlayerAnimTree` 的不透明修復精神（材質設不透明）。
`test/RenderWujieSprite.tscn`：
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/RenderWujieSprite.gd" id="1"]
[node name="RenderWujieSprite" type="Node"]
script = ExtResource("1")
```
`test/RenderWujieSprite.gd`：
```gdscript
extends Node
## 把 3D 無戒渲成側面 idle/walk 透明 PNG。
## 跑法（視窗）：Godot_..._win64.exe --path D:/monk/MONK res://test/RenderWujieSprite.tscn
const GLB := "res://assets/3d/characters/wujie/wujie_walk.glb"
const OUT := "res://assets/2d/characters/wujie/sprite/"
const WALK_FRAMES := 8
const SIZE := Vector2i(256, 384)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var world := Node3D.new(); vp.add_child(world)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-30, -35, 0); key.light_energy = 1.3; world.add_child(key)
	var amb := WorldEnvironment.new(); var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1,1,1); e.ambient_light_energy = 0.7
	amb.environment = e; world.add_child(amb)
	var model: Node3D = (load(GLB) as PackedScene).instantiate(); world.add_child(model)
	await get_tree().process_frame
	_opaque(model)
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	var sk := _find(model, "Skeleton3D") as Skeleton3D
	# 側面相機（看 +X 方向＝模型側面）
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.0
	cam.position = Vector3(3.0, 0.9, 0.0); cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0), Vector3.UP)
	world.add_child(cam); cam.make_current()
	# idle：停在 rest，手臂用 PlayerAnimTree 同法垂下（這裡簡化：直接停 walk 第 0 格當 idle 也可，先存 walk 第 0 格為 idle）
	var walk := _walk_name(ap)
	ap.play(walk); ap.seek(0.0, true)
	for f in WALK_FRAMES:
		var t := (float(f) / WALK_FRAMES) * ap.get_animation(walk).length
		ap.seek(t, true)
		await get_tree().process_frame
		_recenter(model, sk)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + "walk_%d.png" % f)
		print("RENDER walk_%d" % f)
	# idle = walk 第 0 格（站姿）
	ap.seek(0.0, true); await get_tree().process_frame; _recenter(model, sk); await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "idle_0.png")
	print("RENDER_SPRITE_DONE")
	get_tree().quit(0)

func _recenter(model: Node3D, sk: Skeleton3D) -> void:
	if sk == null: return
	var hips := sk.find_bone("Hips")
	if hips < 0: hips = 0
	var gp := (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	model.position.x -= gp.x
	model.position.z -= gp.z

func _opaque(n: Node) -> void:
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					var col: Color = m.albedo_color; col.a = 1.0; m.albedo_color = col
func _all(n: Node, a: Array = []) -> Array:
	a.append(n)
	for c in n.get_children(): _all(c, a)
	return a
func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
func _walk_name(ap: AnimationPlayer) -> String:
	for c in ap.get_animation_list():
		if String(c).to_lower().contains("walk"): return String(c)
	return ap.get_animation_list()[0]
```

- [ ] **Step 2: 跑渲染**

Run: `D:/monk/tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/RenderWujieSprite.tscn`
Expected: 印 `RENDER walk_0`..`walk_7`、`RENDER_SPRITE_DONE`；`assets/2d/characters/wujie/sprite/` 出現 9 張 PNG。

- [ ] **Step 3: 匯入並 Read 自檢**

Run: `Godot --headless --path D:/monk/MONK --import`
Read `assets/2d/characters/wujie/sprite/walk_0.png` 與 `walk_4.png`：確認①透明背景②側面無戒、袍/光頭可辨③walk_0 與 walk_4 腿姿不同（有步態）。不滿意回 Step 1 調相機 `size`/`position` 或 `WALK_FRAMES`。

- [ ] **Step 4 (選用): Commit** — `feat(char): render 2D wujie idle/walk sprite frames`

---

## Phase 1 — 核心街景系統（佔位圖）

### Task 3: Wujie.gd（2D 角色視覺）

**Files:**
- Create: `src/screens/MapScreen/Wujie.gd`
- Test: `test/TestWujie.gd`, `test/TestWujie.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

`test/TestWujie.tscn`（root Node + 腳本）；`test/TestWujie.gd`：
```gdscript
extends Node
func _ready() -> void:
	var W := load("res://src/screens/MapScreen/Wujie.gd")
	var w: AnimatedSprite2D = W.new()
	add_child(w)
	await get_tree().process_frame
	if w.sprite_frames == null: return _fail("未建 SpriteFrames")
	if not w.sprite_frames.has_animation("walk"): return _fail("無 walk 動畫")
	if not w.sprite_frames.has_animation("idle"): return _fail("無 idle 動畫")
	w.set_walking(true)
	if w.animation != "walk": return _fail("set_walking(true) 未切 walk")
	w.face(-1.0)
	if not w.flip_h: return _fail("face(-1) 未翻面")
	w.set_walking(false)
	if w.animation != "idle": return _fail("set_walking(false) 未回 idle")
	print("TEST PASS: Wujie 動畫/翻面 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `Godot --headless --path D:/monk/MONK res://test/TestWujie.tscn`
Expected: 載入腳本失敗或 `TEST FAIL`。

- [ ] **Step 3: 寫 Wujie.gd**

```gdscript
extends AnimatedSprite2D
## 2D 無戒視覺：_ready 由 sprite PNG 程式建 SpriteFrames；set_walking 切 idle/walk、face 翻面。
## 位移由 DistrictScene 控制（本節點只管外觀）。
const DIR := "res://assets/2d/characters/wujie/sprite/"
const WALK_FRAMES := 8
const FPS := 10.0

func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle"); sf.set_animation_loop("idle", true); sf.set_animation_speed("idle", 1.0)
	var idle_tex := _tex(DIR + "idle_0.png")
	if idle_tex: sf.add_frame("idle", idle_tex)
	sf.add_animation("walk"); sf.set_animation_loop("walk", true); sf.set_animation_speed("walk", FPS)
	for i in WALK_FRAMES:
		var t := _tex(DIR + "walk_%d.png" % i)
		if t: sf.add_frame("walk", t)
	# 缺圖防呆：至少塞一張佔位，避免空動畫
	if sf.get_frame_count("idle") == 0: sf.add_frame("idle", _placeholder())
	if sf.get_frame_count("walk") == 0: sf.add_frame("walk", _placeholder())
	sprite_frames = sf
	play("idle")

func set_walking(on: bool) -> void:
	var want := "walk" if on else "idle"
	if animation != want: play(want)

func face(dir: float) -> void:
	if dir != 0.0: flip_h = dir < 0.0

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path) as Texture2D
	return null

func _placeholder() -> Texture2D:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.46, 0.32, 1.0))
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `Godot --headless --path D:/monk/MONK res://test/TestWujie.tscn`
Expected: `TEST PASS: Wujie 動畫/翻面 OK`。

- [ ] **Step 5 (選用): Commit** — `feat(map): Wujie 2D animated sprite`

---

### Task 4: Portal.gd / Portal.tscn（傳送點）

**Files:**
- Create: `src/screens/MapScreen/Portal.gd`, `src/screens/MapScreen/Portal.tscn`
- Test: `test/TestPortal.gd`, `test/TestPortal.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

`test/TestPortal.gd`：
```gdscript
extends Node
var _got := ""
func _ready() -> void:
	var p := (load("res://src/screens/MapScreen/Portal.tscn") as PackedScene).instantiate()
	add_child(p)
	await get_tree().process_frame
	p.setup_location("old_temple", "破舊古廟")
	if p.kind != "location": return _fail("setup_location kind 錯")
	if p.payload != "old_temple": return _fail("payload 錯")
	p.triggered.connect(func(pl): _got = pl)
	p.trigger()
	if _got != "old_temple": return _fail("trigger 未發 payload")
	p.setup_edge("ximen", "往西門")
	if p.kind != "edge" or p.payload != "ximen": return _fail("setup_edge 錯")
	print("TEST PASS: Portal setup/trigger OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestPortal.tscn`：root Node + 此腳本。

- [ ] **Step 2: 跑測試確認失敗**

Run: `Godot --headless --path D:/monk/MONK res://test/TestPortal.tscn`
Expected: 載入失敗或 `TEST FAIL`。

- [ ] **Step 3: 寫 Portal.tscn**

```
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/Portal.gd" id="1"]
[sub_resource type="CircleShape2D" id="cs"]
radius = 40.0
[node name="Portal" type="Area2D"]
script = ExtResource("1")
input_pickable = true
[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("cs")
[node name="Label" type="Label" parent="."]
offset_left = -60.0
offset_top = -70.0
offset_right = 60.0
offset_bottom = -46.0
horizontal_alignment = 1
[node name="Pin" type="Polygon2D" parent="."]
color = Color(0.224, 1, 0.078, 0.85)
polygon = PackedVector2Array(0, -34, 10, -14, -10, -14)
```

- [ ] **Step 4: 寫 Portal.gd**

```gdscript
extends Area2D
## 傳送點：kind="location"(走進→進內景) 或 "edge"(走進→換區)。可點擊或走近觸發。
signal triggered(payload)        # 點擊/到達時發
signal clicked                   # 純被點（DistrictScene 用來走過去）

@onready var _label: Label = $Label

var kind := ""
var payload := ""
var display := ""

func setup_location(id: String, name: String) -> void:
	kind = "location"; payload = id; display = name; _refresh()

func setup_edge(to_area: String, name: String) -> void:
	kind = "edge"; payload = to_area; display = name; _refresh()

func _refresh() -> void:
	if _label: _label.text = display

func trigger() -> void:
	triggered.emit(payload)

func _input_event(_vp: Object, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
```
（`_refresh` 在 `setup_*` 時 `_label` 可能尚未 ready；故 `_refresh` 判空，並在 `_ready` 補一次。）加：
```gdscript
func _ready() -> void:
	_refresh()
```

- [ ] **Step 5: 跑測試確認通過**

Run: `Godot --headless --path D:/monk/MONK res://test/TestPortal.tscn`
Expected: `TEST PASS: Portal setup/trigger OK`。

- [ ] **Step 6 (選用): Commit** — `feat(map): Portal node (location/edge)`

---

### Task 5: DistrictScene.gd / .tscn（捲動街景層）

**Files:**
- Create: `src/screens/MapScreen/DistrictScene.gd`, `src/screens/MapScreen/DistrictScene.tscn`
- Test: `test/TestDistrictScene.gd`, `test/TestDistrictScene.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

`test/TestDistrictScene.gd`：驗證依「區+時段+解鎖」建出正確傳送點數。
```gdscript
extends Node
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var locs: Dictionary = JsonLoader.load_json("res://data/map_locations.json")
	var ds := (load("res://src/screens/MapScreen/DistrictScene.tscn") as PackedScene).instantiate()
	add_child(ds)
	await get_tree().process_frame
	# 西門町，period 3：2 地點(捷運站/萬年? 萬年僅 0,1,2 → period3 不開) + 1 邊界(往萬華)
	var ximen: Dictionary = areas["ximen"]
	var xlocs := _by_district(locs, "ximen")
	ds.setup(ximen, xlocs, 3)
	await get_tree().process_frame
	# period 3：ximen_mrt(1,2,3 開) 開、wannian_mall(0,1,2) 不開 → 1 地點 + 1 邊界 = 2
	var n := ds.portal_count()
	if n != 2: return _fail("西門 period3 傳送點數應為 2，實得 %d" % n)
	# period 1：兩地點都開 + 1 邊界 = 3
	ds.setup(ximen, xlocs, 1)
	await get_tree().process_frame
	if ds.portal_count() != 3: return _fail("西門 period1 應為 3，實得 %d" % ds.portal_count())
	print("TEST PASS: DistrictScene 傳送點閘門 OK")
	get_tree().quit(0)
func _by_district(locs: Dictionary, d: String) -> Array:
	var out: Array = []
	for id in locs:
		var l: Dictionary = locs[id].duplicate(); l["id"] = id
		if l.district == d: out.append(l)
	return out
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestDistrictScene.tscn`：root Node + 腳本。

- [ ] **Step 2: 跑測試確認失敗**

Run: `Godot --headless --path D:/monk/MONK res://test/TestDistrictScene.tscn`
Expected: 載入失敗或 FAIL。

- [ ] **Step 3: 寫 DistrictScene.tscn**

```
[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/DistrictScene.gd" id="1"]
[ext_resource type="Script" path="res://src/screens/MapScreen/Wujie.gd" id="2"]
[node name="DistrictScene" type="Control"]
layout_mode = 3
anchors_preset = 15
script = ExtResource("1")
[node name="World" type="Node2D" parent="."]
[node name="Background" type="Sprite2D" parent="World"]
centered = false
[node name="Portals" type="Node2D" parent="World"]
[node name="Wujie" type="AnimatedSprite2D" parent="World"]
script = ExtResource("2")
[node name="Camera2D" type="Camera2D" parent="World"]
[node name="TimeTint" type="CanvasModulate" parent="."]
```
（`Background` 用 `Sprite2D`(centered=false) 好取像素尺寸；World 容納可被相機捲動的世界座標物件。）

- [ ] **Step 4: 寫 DistrictScene.gd**

```gdscript
extends Control
## 橫向捲動街景：載背景、擺無戒於 spawn、建傳送點(地點+邊界,依時段/解鎖)、相機跟隨、方向鍵/點擊走動。
signal location_entered(id)
signal edge_to(area_id)
signal request_city_map

const PORTAL := preload("res://src/screens/MapScreen/Portal.tscn")
const WALK_SPEED := 320.0
const ARRIVE_EPS := 8.0
const NEAR := 56.0

@onready var bg: Sprite2D = $World/Background
@onready var portals_root: Node2D = $World/Portals
@onready var wujie: AnimatedSprite2D = $World/Wujie
@onready var cam: Camera2D = $World/Camera2D

var _map_w := 0.0
var _ground_y := 0.0
var _target_x := 0.0
var _auto := false
var _pending: Node = null    # 走到後要 trigger 的傳送點

func setup(area: Dictionary, locations: Array, period: int) -> void:
	var tex := _load_tex(String(area.get("scene_2d", "")))
	var vp := get_viewport_rect().size
	if tex:
		bg.texture = tex
		_map_w = tex.get_width()
		bg.scale = Vector2.ONE
	else:
		# 佔位：純色塊，寬 = 2.5 個畫面
		_map_w = vp.x * 2.5
		bg.texture = _placeholder_tex(int(_map_w), int(vp.y))
	var bh := bg.texture.get_height()
	var sp: Dictionary = area.get("scene_spawn", {"x": 0.1, "y": 0.82})
	wujie.position = Vector2(_map_w * float(sp.x), bh * float(sp.y))
	_ground_y = wujie.position.y
	_target_x = wujie.position.x
	_auto = false; _pending = null
	cam.limit_left = 0; cam.limit_right = int(_map_w)
	cam.limit_top = 0; cam.limit_bottom = int(bh)
	_build_portals(area, locations, period, bh)
	_update_camera()

func portal_count() -> int:
	return portals_root.get_child_count()

func _build_portals(area: Dictionary, locations: Array, period: int, bh: int) -> void:
	for c in portals_root.get_children(): c.queue_free()
	for loc in locations:
		if not (period in loc.get("available_periods", [0,1,2,3])): continue
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag): continue
		var p := PORTAL.instantiate(); portals_root.add_child(p)
		var sp: Dictionary = loc.get("scene_pos", {"x":0.5,"y":0.8})
		p.position = Vector2(_map_w * float(sp.x), bh * float(sp.y))
		p.setup_location(String(loc.id), String(loc.name))
		p.clicked.connect(_walk_to_portal.bind(p))
		p.triggered.connect(func(id): location_entered.emit(id))
	for ep in area.get("edge_portals", []):
		var to_area: String = String(ep.to)
		var p := PORTAL.instantiate(); portals_root.add_child(p)
		p.position = Vector2(_map_w * float(ep.x), bh * 0.80)
		p.setup_edge(to_area, "往 %s" % to_area)
		p.clicked.connect(_walk_to_portal.bind(p))
		p.triggered.connect(func(a): edge_to.emit(a))

func _walk_to_portal(p: Node) -> void:
	_target_x = p.position.x; _auto = true; _pending = p

func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("ui_left"): dir -= 1.0
	if Input.is_action_pressed("ui_right"): dir += 1.0
	if dir != 0.0:
		_auto = false; _pending = null
		wujie.position.x = clampf(wujie.position.x + dir * WALK_SPEED * delta, 0.0, _map_w)
		wujie.face(dir); wujie.set_walking(true)
		_check_near()
	elif _auto:
		var dx := _target_x - wujie.position.x
		if absf(dx) <= ARRIVE_EPS:
			wujie.position.x = _target_x; _auto = false; wujie.set_walking(false)
			if _pending != null: _pending.trigger(); _pending = null
		else:
			var d := signf(dx)
			wujie.position.x += d * WALK_SPEED * delta
			wujie.face(d); wujie.set_walking(true)
	else:
		wujie.set_walking(false)
	wujie.position.y = _ground_y
	_update_camera()

func _check_near() -> void:
	# 自由走時走近傳送點 + 按互動鍵 → 觸發
	if not Input.is_action_just_pressed("interact"): return
	for p in portals_root.get_children():
		if absf(p.position.x - wujie.position.x) <= NEAR:
			p.trigger(); return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 點空地 → 走過去(不觸發)；點傳送點由 Portal._input_event 處理
		var world_x := cam.get_screen_center_position().x - get_viewport_rect().size.x * 0.5 + event.position.x
		_target_x = clampf(world_x, 0.0, _map_w); _auto = true; _pending = null

func _update_camera() -> void:
	cam.position = Vector2(wujie.position.x, bg.texture.get_height() * 0.5 if bg.texture else 0.0)
	if not cam.is_current(): cam.make_current()

func _load_tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path): return load(path) as Texture2D
	return null

func _placeholder_tex(w: int, h: int) -> Texture2D:
	var img := Image.create(maxi(w,1), maxi(h,1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.16, 0.17, 0.22, 1.0))
	# 畫條地面帶
	for y in range(int(h*0.82), h):
		for x in range(w): img.set_pixel(x, y, Color(0.3,0.3,0.34,1.0))
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 5: 跑測試確認通過**

Run: `Godot --headless --path D:/monk/MONK res://test/TestDistrictScene.tscn`
Expected: `TEST PASS: DistrictScene 傳送點閘門 OK`。

- [ ] **Step 6 (選用): Commit** — `feat(map): scrolling DistrictScene with portals + walk`

---

### Task 6: MapScreen 改建為 2D 協調者

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.gd`（改建）
- Modify: `src/screens/MapScreen/MapScreen.tscn`（改建為 Control 根）
- Test: `test/TestMap2D.gd`, `test/TestMap2D.tscn`；`test/CaptureMap2D.gd`, `test/CaptureMap2D.tscn`

- [ ] **Step 1: 改建 MapScreen.tscn**

```
[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/MapScreen.gd" id="1"]
[ext_resource type="PackedScene" path="res://src/screens/MapScreen/DistrictScene.tscn" id="2"]
[ext_resource type="Script" path="res://src/screens/MapScreen/MapHUD.gd" id="3"]
[node name="MapScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
script = ExtResource("1")
[node name="DistrictScene" parent="." instance=ExtResource("2")]
[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("3")
```
（HUD 子節點 TimeLabel/StatsLabel/InteractionPrompt/ActionMenu/Toast 等沿用舊 MapScreen.tscn 內 HUD 區段原樣搬入——複製舊檔 `[node name="TimeLabel" ...]`..`[node name="Toast" ...]` 那幾段到本檔 HUD 下，路徑由 `HUD/...` 維持不變。LocationInterior/CityMap 兩層於 Task 7/8 再加。）

- [ ] **Step 2: 改建 MapScreen.gd（保留後端、換前端）**

完整新檔（後端 `perform_action`/`_pick_enemy`/成就/選單/`_update_hud` 由舊檔原樣保留，下方標 `# === 沿用舊檔，不動 ===` 區塊照抄；新增/替換前端方法給全碼）：
```gdscript
extends Control
## 2D 探索地圖協調者：持有 DistrictScene/(後續)LocationInterior/CityMap + HUD，沿用所有後端。

const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")

@onready var district: Control = $DistrictScene
@onready var hud: CanvasLayer = $HUD

var _areas: Dictionary = {}
var _locations: Dictionary = {}
var _current_area: String = ""
var _current_loc: String = ""

func _ready() -> void:
	_areas = JsonLoader.load_json("res://data/areas.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_current_area = String(GameManager.player.get("current_area", "ximen"))
	district.location_entered.connect(_on_location_entered)
	district.edge_to.connect(_on_edge_to)
	district.request_city_map.connect(show_city_map)
	GameManager.time_advanced.connect(_on_time_advanced)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	_drain_pending_achievements()
	show_district(_current_area)
	hud.update_stats() if hud.has_method("update_stats") else null
	_update_hud()

## 載入某區街景（換區＝設 current_area 再呼叫）。
func show_district(area_id: String) -> void:
	_current_area = area_id
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	district.setup(area, _locs_in(area_id), GameManager.player.period)
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))

func _locs_in(area_id: String) -> Array:
	var out: Array = []
	for id in _locations:
		var l: Dictionary = _locations[id].duplicate(); l["id"] = id
		if String(l.get("district","")) == area_id: out.append(l)
	return out

## 快速移動（沿用介面）：設目的區後重載地圖。
func travel_to(area_id: String, _spawn: Vector3 = Vector3.ZERO) -> void:
	GameManager.player.current_area = area_id
	SceneRouter.go_to_map()

func _on_location_entered(id: String) -> void:
	_current_loc = id
	# Task 7 接 LocationInterior；先暫以行動選單頂替（保證可玩）
	var loc: Dictionary = _locations[id]
	hud.show_action_menu(loc.name, loc.actions, perform_action)

func _on_edge_to(area_id: String) -> void:
	travel_to(area_id)

func show_city_map() -> void:
	pass  # Task 8 實作

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_open_main_menu()

func _on_time_advanced(_p: int) -> void:
	_update_hud()
	district.setup(_areas.get(_current_area, {}), _locs_in(_current_area), GameManager.player.period)

# === 沿用舊檔，不動（從原 MapScreen.gd 原樣搬入）===
# perform_action / _pick_enemy / _on_achievement_unlocked / _drain_pending_achievements
# / _toast_achievement / _update_hud / _open_main_menu
```
實作時把舊 `MapScreen.gd` 的 `perform_action`、`_pick_enemy`、`_on_achievement_unlocked`、`_drain_pending_achievements`、`_toast_achievement`、`_update_hud`、`_open_main_menu` 七個方法**整段複製**到新檔末尾（內容不變）。移除舊檔的 `_load_environment`/`_spawn_player`/`_build_triggers`/`_on_entered`/`_on_exited`/`_open_menu`/`get_player_position`/`_store_position` 及 `@onready player/environment_holder`（3D 專用，已被取代；`_open_menu` 功能併入 `_on_location_entered`）。

- [ ] **Step 3: 寫 headless 測試**

`test/TestMap2D.gd`：
```gdscript
extends Node
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait("MapScreen")
	if map == null: return _fail("MapScreen 未載入")
	await get_tree().process_frame
	var ds := map.get_node_or_null("DistrictScene")
	if ds == null: return _fail("無 DistrictScene")
	if ds.portal_count() <= 0: return _fail("街景無傳送點")
	# 換區
	map.travel_to("wanhua_old")
	var map2: Node = await _wait("MapScreen")
	await get_tree().process_frame
	if String(GameManager.player.current_area) != "wanhua_old": return _fail("travel_to 未換區")
	print("TEST PASS: Map2D 載入/傳送點/換區 OK")
	get_tree().quit(0)
func _wait(n: String, mx := 600) -> Node:
	for i in mx:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == n: return cs
	return null
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestMap2D.tscn`：root Node + 腳本。

- [ ] **Step 4: 匯入 + 跑 headless 測試**

Run: `Godot --headless --path D:/monk/MONK --import`
Run: `Godot --headless --path D:/monk/MONK res://test/TestMap2D.tscn`
Expected: `TEST PASS: Map2D 載入/傳送點/換區 OK`。失敗依訊息回對應 Task。

- [ ] **Step 5: 視窗截圖核對（佔位圖）**

`test/CaptureMap2D.gd`（new_game→go_to_map→等→截圖 `res://_map2d.png`→quit；模式同 Task 2 的視窗跑法）。
Run: `D:/monk/tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureMap2D.tscn`
Read `_map2d.png`：確認①佔位街景（深色塊+地面帶）②無戒 sprite 站在 spawn ③傳送點標籤可見 ④HUD 時段/數值在。再用 `Input.action_press("ui_right")` 版本截一張確認會走+相機捲動（可在 CaptureMap2D 加按鍵模擬，仿 `CaptureWalk`）。

- [ ] **Step 6 (選用): Commit** — `feat(map): rebuild MapScreen as 2D coordinator`

---

## Phase 2 — 三層補齊

### Task 7: LocationInterior（地點內景）

**Files:**
- Create: `src/screens/MapScreen/LocationInterior.gd`, `src/screens/MapScreen/LocationInterior.tscn`
- Modify: `src/screens/MapScreen/MapScreen.tscn`（加 LocationInterior 實例，預設 hidden）
- Modify: `src/screens/MapScreen/MapScreen.gd`（`_on_location_entered`/新增 `leave_location`）
- Test: `test/TestInterior.gd`, `test/TestInterior.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

`test/TestInterior.gd`：驗證 `open(loc)` 後背景設定且發出該地 actions 給回呼。
```gdscript
extends Node
var _menu_title := ""
func _ready() -> void:
	var li := (load("res://src/screens/MapScreen/LocationInterior.tscn") as PackedScene).instantiate()
	add_child(li)
	await get_tree().process_frame
	var loc := {"name":"破舊古廟", "interior_2d":"res://nonexist.png", "actions":["main_quest","save"]}
	var got_actions: Array = []
	li.open(loc, func(title, actions, cb): got_actions = actions)
	if got_actions != ["main_quest","save"]: return _fail("內景未把 actions 交給選單回呼")
	if not li.visible: return _fail("open 後應顯示")
	li.close()
	if li.visible: return _fail("close 後應隱藏")
	print("TEST PASS: LocationInterior open/close OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestInterior.tscn`：root Node + 腳本。

- [ ] **Step 2: 跑測試確認失敗**

Run: `Godot --headless --path D:/monk/MONK res://test/TestInterior.tscn` → 失敗。

- [ ] **Step 3: 寫 LocationInterior.tscn**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/LocationInterior.gd" id="1"]
[node name="LocationInterior" type="Control"]
visible = false
layout_mode = 3
anchors_preset = 15
script = ExtResource("1")
[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
expand_mode = 1
stretch_mode = 6
[node name="Leave" type="Button" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 120.0
offset_bottom = 64.0
text = "離開"
```

- [ ] **Step 4: 寫 LocationInterior.gd**

```gdscript
extends Control
## 地點內景：靜態背景 + 開該地行動選單。離開回街景。
signal left

@onready var bg: TextureRect = $Background
@onready var _leave: Button = $Leave

func _ready() -> void:
	_leave.pressed.connect(close)

## open(loc, menu_cb)：menu_cb(title, actions, perform_cb) 交給外部用 MapHUD 開選單。
func open(loc: Dictionary, menu_cb: Callable, perform_cb: Callable = Callable()) -> void:
	var path := String(loc.get("interior_2d", ""))
	bg.texture = load(path) as Texture2D if (path != "" and ResourceLoader.exists(path)) else _placeholder()
	visible = true
	menu_cb.call(String(loc.get("name","")), loc.get("actions", []), perform_cb)

func close() -> void:
	visible = false
	left.emit()

func _placeholder() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.13, 1.0))
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 5: 接進 MapScreen**

`MapScreen.tscn`：在 HUD 前加（ext_resource 加 LocationInterior.tscn）：
```
[node name="LocationInterior" parent="." instance=ExtResource("4")]
```
`MapScreen.gd`：`@onready var interior := $LocationInterior`；`_ready` 加 `interior.left.connect(leave_location)`；改 `_on_location_entered`：
```gdscript
func _on_location_entered(id: String) -> void:
	_current_loc = id
	district.visible = false
	interior.open(_locations[id], func(title, actions, _cb): hud.show_action_menu(title, actions, perform_action))

func leave_location() -> void:
	hud.hide_action_menu()
	interior.visible = false
	district.visible = true
```

- [ ] **Step 6: 跑測試確認通過 + 回歸**

Run: `Godot --headless --path D:/monk/MONK res://test/TestInterior.tscn` → `TEST PASS`。
Run: `Godot --headless --path D:/monk/MONK res://test/TestMap2D.tscn` → 仍 PASS。

- [ ] **Step 7 (選用): Commit** — `feat(map): location interior layer`

---

### Task 8: CityMap（城市地圖選區）

**Files:**
- Create: `src/screens/MapScreen/CityMap.gd`, `src/screens/MapScreen/CityMap.tscn`
- Modify: `MapScreen.tscn`（加 CityMap 實例 hidden）、`MapScreen.gd`（`show_city_map`/接 `district_selected`）
- Test: `test/TestCityMap.gd`, `test/TestCityMap.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

`test/TestCityMap.gd`：驗證鎖區 disabled、選區發訊號。
```gdscript
extends Node
var _picked := ""
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var cm := (load("res://src/screens/MapScreen/CityMap.tscn") as PackedScene).instantiate()
	add_child(cm); await get_tree().process_frame
	cm.district_selected.connect(func(a): _picked = a)
	cm.setup(areas)            # linsen 未解鎖
	await get_tree().process_frame
	if not cm.is_locked("linsen"): return _fail("林森應為鎖定")
	if cm.is_locked("ximen"): return _fail("西門不應鎖")
	cm.pick("ximen")
	if _picked != "ximen": return _fail("選區未發 district_selected")
	print("TEST PASS: CityMap 鎖區/選區 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestCityMap.tscn`：root Node + 腳本。

- [ ] **Step 2: 跑測試確認失敗** → 載入失敗或 FAIL。

- [ ] **Step 3: 寫 CityMap.tscn**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/CityMap.gd" id="1"]
[node name="CityMap" type="Control"]
visible = false
layout_mode = 3
anchors_preset = 15
script = ExtResource("1")
[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
expand_mode = 1
stretch_mode = 6
[node name="Pins" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
[node name="Close" type="Button" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 120.0
offset_bottom = 64.0
text = "關閉"
```

- [ ] **Step 4: 寫 CityMap.gd**

```gdscript
extends Control
## 城市地圖：依 areas 建區圖釘(鎖區 disabled)，選區發 district_selected。
signal district_selected(area_id)

const CITY_MAP_IMG := "res://assets/2d/map/city_map.png"
@onready var bg: TextureRect = $Background
@onready var pins: Control = $Pins
@onready var _close: Button = $Close

var _locked: Dictionary = {}

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)

func setup(areas: Dictionary) -> void:
	bg.texture = load(CITY_MAP_IMG) as Texture2D if ResourceLoader.exists(CITY_MAP_IMG) else null
	for c in pins.get_children(): c.queue_free()
	_locked.clear()
	for aid in areas:
		var a: Dictionary = areas[aid]
		var locked := a.has("unlock_flag") and not GameManager.get_flag(a.unlock_flag)
		_locked[aid] = locked
		var b := Button.new()
		b.text = String(a.get("name", aid)) + ("（鎖）" if locked else "")
		b.disabled = locked
		var mp: Dictionary = a.get("map_pos", {"x":0.5,"y":0.5})
		b.anchor_left = float(mp.x); b.anchor_top = float(mp.y)
		b.anchor_right = float(mp.x); b.anchor_bottom = float(mp.y)
		b.pressed.connect(pick.bind(aid))
		pins.add_child(b)

func is_locked(area_id: String) -> bool:
	return bool(_locked.get(area_id, false))

func pick(area_id: String) -> void:
	if is_locked(area_id): return
	visible = false
	district_selected.emit(area_id)

func open() -> void:
	visible = true
```

- [ ] **Step 5: 接進 MapScreen**

`MapScreen.tscn`：加 `[node name="CityMap" parent="." instance=ExtResource("5")]`（hidden）。
`MapScreen.gd`：`@onready var city := $CityMap`；`_ready` 加 `city.district_selected.connect(travel_to)`；改：
```gdscript
func show_city_map() -> void:
	city.setup(_areas)
	city.open()
```
並在 DistrictScene 加一顆「地圖」鈕發 `request_city_map`（或在 HUD 加；最小作法：DistrictScene 角落 Button 發 `request_city_map`）。

- [ ] **Step 6: 跑測試 + 回歸**

Run: `Godot --headless --path D:/monk/MONK res://test/TestCityMap.tscn` → `TEST PASS`。
Run: `TestMap2D` 回歸 PASS。

- [ ] **Step 7 (選用): Commit** — `feat(map): city map district selector`

---

### Task 9: 時段調色 + 入口鈕收尾

**Files:**
- Modify: `src/screens/MapScreen/DistrictScene.gd`（時段 tint + 地圖鈕）
- Test: `test/TestTimeTint.gd`, `test/TestTimeTint.tscn`

- [ ] **Step 1: 寫測試（先失敗）**

驗證 `apply_period_tint(p)` 設定 CanvasModulate 顏色隨時段不同。
```gdscript
extends Node
func _ready() -> void:
	var ds := (load("res://src/screens/MapScreen/DistrictScene.tscn") as PackedScene).instantiate()
	add_child(ds); await get_tree().process_frame
	ds.apply_period_tint(0)   # 上午
	var morn: Color = ds.get_node("TimeTint").color
	ds.apply_period_tint(3)   # 夜
	var night: Color = ds.get_node("TimeTint").color
	if morn == night: return _fail("時段未改變調色")
	if night.v >= morn.v: return _fail("夜應比上午暗")
	print("TEST PASS: 時段調色 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
`test/TestTimeTint.tscn`：root Node + 腳本。

- [ ] **Step 2: 跑測試確認失敗**（`apply_period_tint` 不存在）。

- [ ] **Step 3: DistrictScene 加時段調色 + 地圖鈕**

DistrictScene.tscn 加：`[node name="MapBtn" type="Button" parent="."]`（右上角，text="地圖"）。
DistrictScene.gd 加：
```gdscript
@onready var tint: CanvasModulate = $TimeTint
const PERIOD_TINT := [Color(1.0,0.97,0.9), Color(1.0,1.0,1.0), Color(0.95,0.85,0.8), Color(0.55,0.6,0.85)]

func apply_period_tint(period: int) -> void:
	tint.color = PERIOD_TINT[clampi(period, 0, 3)]
```
`_ready` 接 `$MapBtn.pressed.connect(func(): request_city_map.emit())`；`setup()` 末尾呼 `apply_period_tint(period)`。

- [ ] **Step 4: 跑測試 + 回歸**

Run: `Godot --headless --path D:/monk/MONK res://test/TestTimeTint.tscn` → PASS。
Run: `TestMap2D` 回歸 PASS。

- [ ] **Step 5: 視窗截圖整合驗證**

跑 `CaptureMap2D`（視窗），Read：確認①走動+相機捲動②點傳送點→進內景(佔位)→離開回街景③地圖鈕→城市地圖→選區換街景④夜時段畫面偏藍暗。問題回對應 Task。

- [ ] **Step 6 (選用): Commit** — `feat(map): time tint + city-map button`

---

## Phase 3 — 正式美術

### Task 10: 生成並置換手繪美術

**Files:**
- Create: `assets/2d/map/city_map.png`、`assets/2d/map/scenes/{ximen,wanhua,linsen}_street.png`、`assets/2d/map/interiors/{ximen_mrt,wannian_mall,zen_bbq,zuijin_club,old_temple}.png`

- [ ] **Step 1: 確認美術服務額度（用多的）**

載入 schema（ToolSearch）查餘額：`mcp__dacf309a-7000-46b1-b753-b35d7ce3332f__account_balance`（magnific/freepik）與 `mcp__higgsfield__balance`。**用餘額多者**（預期 magnific ~41k ≫ higgsfield）。

- [ ] **Step 2: 生城市地圖（1 張）**

magnific/freepik `images_generate`（或 higgsfield `generate_image`）。prompt 要點：俯瞰風格化「新梵市」夜城地圖、半寫實厚塗、可辨三個區塊（西門/萬華/林森）、留白給圖釘、暗金×黑調性、無文字。存 `assets/2d/map/city_map.png`。Read 自檢；不符重生。

- [ ] **Step 3: 生 3 張寬幅街景**

每張 **寬幅(約 21:9 或更寬)**、側視平視、半寫實厚塗、底部留連續地面帶可走、留傳送點空間、無人物：
- `ximen_street.png`：西門町霓虹夜街
- `wanhua_street.png`：萬華舊區昏暗舊廟市街
- `linsen_street.png`：林森紅燈區夜街
存 `assets/2d/map/scenes/`。Read 自檢（地面帶連續、無明顯接縫/裁切）。

- [ ] **Step 4: 生 5 張地點內景**

半寫實厚塗室內/入口定鏡：捷運站出口/萬年商場內/禪味燒肉店內/紫醉金迷俱樂部內/破舊古廟內。存 `assets/2d/map/interiors/`。Read 自檢。

- [ ] **Step 5: 匯入 + 整合截圖驗證**

Run: `Godot --headless --path D:/monk/MONK --import`
跑 `CaptureMap2D`（視窗），Read：確認街景/內景/城市地圖都換成正式圖、無戒 sprite 與背景比例協調、傳送點落在合理位置（`scene_pos` 對不上就微調 `data/*.json` 座標再截圖）。逐區、逐內景檢查。

- [ ] **Step 6: 人工關卡**

把城市地圖 + 3 街景 + 代表性內景截圖貼給使用者過目，確認畫風/構圖/比例 OK 再收尾（不符回 Step 2–4 重生）。

- [ ] **Step 7 (選用): Commit** — `feat(map): hand-painted city map / street / interior art`

---

## Self-Review

- **Spec 覆蓋：** 三層導覽(Task 5/7/8)、走過去 sprite＋3D→2D 渲染(Task 2/3)、長街捲動＋2–3 傳送點(地點+邊界)(Task 5/9)、內景靜態背景+選單(Task 7)、時段 tint＋period 閘門(Task 5 `_build_portals`/Task 9)、解鎖閘門(Task 5/8)、資料欄位(Task 1)、沿用後端＋退役 3D(Task 6)、美術清單 9 張+sprite(Task 10)。✅
- **無 placeholder：** 各腳本給全碼；測試含實際斷言；資料給完整 JSON；美術 prompt 給要點（外部生成步驟非程式 placeholder）。✅
- **型別/名稱一致：** `DistrictScene.setup(area, locations, period)`/`portal_count()`/`apply_period_tint()`、`Portal.setup_location/setup_edge/trigger/clicked/triggered`、`Wujie.set_walking/face`、`LocationInterior.open/close/left`、`CityMap.setup/is_locked/pick/open/district_selected`、`MapScreen.show_district/travel_to/show_city_map/leave_location` 跨 Task 一致。✅
- **風險內建處理：** 圖缺→佔位(Wujie/DistrictScene/Interior/CityMap 皆有)；走路中改道(_process)；鎖區/鎖點閘門；先佔位跑通系統(Phase 1) 再置換美術(Phase 3)，降低美術阻塞。
- **依賴：** `MapHUD`(`show_action_menu`/`hide_action_menu`/`update_stats`)、`GameManager`(player/period/flags/time_advanced)、`AudioManager.switch_bgm`、`SceneRouter.go_to_map`、`EventBus.achievement_unlocked`、`perform_action` 既有，不改。⚠ 實作 Task 6 時確認 `MapHUD` 這些方法簽名與舊 MapScreen 呼叫一致（原本就在用）。
