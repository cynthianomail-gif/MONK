# HD-2D 探索原型（西門街）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改變遊戲既有半寫實厚塗美術的前提下，做出一個獨立可走的「HD-2D（八方旅人式）」西門街原型——厚塗 2D 立板擺進真 3D 景深、固定 3/4 俯角相機、移軸景深後製——驗證觀感滿意後才談擴張與接 MapScreen。

**Architecture:** 一個程式化世界建構器 `Hd2dStreet`（Node3D）建：地面、近/遠兩排「整張矩形厚塗建築立板」（QuadMesh 直立、面向相機、`UNSHADED` 保畫風）、遠景背板、WorldEnvironment（FILMIC tonemap＋glow），最後疊上電影感後製（`CameraAttributesPractical` 移軸景深＋暈影 shader）與氛圍（雨/霧/霓虹 OmniLight 光池）。主角＝Y-billboard `Sprite3D`（重用既有 wujie 厚塗 sprite）由 `Hd2dPlayer`（CharacterBody3D）驅動，相機重用既有 `CameraRig`（group fallback 抓 player）。原型在獨立 `Hd2dProto` 場景組裝，日後整段塞進 MapScreen 的 SubViewport（本計畫不含）。

**Tech Stack:** Godot 4.5 **Forward+**、GDScript。重用素材：`assets/3d/environments/ximen/bldg_01..12.png`（768×1376 整棟厚塗立板）、`ground_wet.png`（1024×1024 無縫濕柏油）、`assets/2d/characters/wujie/sprite/`（idle_0＋walk_0..7，256×384）。驗證沿用既有 headless `Test*` ＋視窗 `Capture*` 雙軌。

---

## 美術鐵則（最高優先，貫穿每個 task）

所有 HD-2D 視覺元素**一律重用既有半寫實厚塗素材**，與全遊戲 2D 美術統一。**不得**改成 cel/描邊/low-poly/卡通色塊。立板用 `SHADING_MODE_UNSHADED` 正是為了讓厚塗畫面原汁原味呈現、不被 3D 燈光打平。

## 環境前置與通用指令

- 引擎：Forward+（已設定，DOF/glow 只有 GPU 視窗看得到，headless 只能驗腳本/節點/屬性）。
- 視窗版執行檔：`tools/godot/Godot_v4.5-stable_win64.exe`
- console/headless 執行檔：`tools/godot/Godot_v4.5-stable_win64_console.exe`
- 專案路徑：`D:/monk/MONK`
- **每次新增 `.gd`/`.tscn`/素材後**，先跑一次匯入讓 Godot 認得（避免「runtime 不自動匯入」雷）：
  ```bash
  tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import
  ```
- git 已就緒（branch `master`，baseline checkpoint `109e9d7`）。每個 task 結束 commit。

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `src/screens/MapScreen/environments/Hd2dStreet.gd` | Create | HD-2D 世界建構器（Node3D）：環境/地面/建築立板/背板/後製/氛圍。可獨立、可日後進 SubViewport。 |
| `src/screens/MapScreen/Hd2dPlayer.gd` | Create | 主角控制器（CharacterBody3D）：Y-billboard Sprite3D＋idle/walk 幀循環＋翻面＋相對相機移動。 |
| `src/screens/MapScreen/CameraRig.gd` | Reuse（不改） | 固定 3/4 俯角跟隨相機；既有 group fallback 抓 player（避開 NodePath 載入掉值雷）。 |
| `test/Hd2dProto.gd` + `.tscn` | Create | 可走原型組裝（street＋player＋CameraRig＋HUD），對應 `StreetProto` 角色。 |
| `test/CaptureHd2d.gd` + `.tscn` | Create | 視窗自動截圖：載入 Hd2dProto→等 180 frame→存 `_hd2d_shot.png`→quit。對應 `CaptureProto`。 |
| `test/TestHd2dStreet.gd` + `.tscn` | Create | headless 結構驗證：建構器有 Ground/Buildings/WorldEnvironment、後製 camera_attributes、氛圍節點。 |
| `test/TestHd2dPlayer.gd` + `.tscn` | Create | headless 主角驗證：Sprite3D 存在＋billboard＋in group＋走動切幀＋位移。 |

設計原則：世界建構器（環境）與主角/相機分離——環境可整段重用進 MapScreen SubViewport，主角活在環境內。沿用既有 `XimenStreet.gd`／`StreetProto.gd` 的組裝慣例，但元件是直立 billboard/立板而非盒體。

## Tunables 速查（迭代時調這些）

- 相機：`Hd2dProto` 內 `camera_offset = (0, 10, 8)`、`camera_pitch_deg = -34`、`fov = 50`。
- 立板：`Hd2dStreet` 內 `NEAR_ROW_Z = -9`、`FAR_ROW_Z = -22`、`NEAR_SIDE_X = 7`、`STREET_W = 16`、`STREET_LEN = 40`。
- 移軸景深（`CameraAttributesPractical`）：`dof_blur_far_distance = 16`、`dof_blur_near_distance = 7`、`dof_blur_amount = 0.12`。
- glow：`glow_hdr_threshold = 1.25`（避免 bloom floor 抬白）。tonemap：`TONE_MAPPER_FILMIC`（避開 ACES 把霓虹去飽和成白）。

---

### Task 1: Hd2dStreet 建構器骨架 — 環境＋地面（headless 可驗）

**Files:**
- Create: `src/screens/MapScreen/environments/Hd2dStreet.gd`
- Create: `test/TestHd2dStreet.gd`
- Create: `test/TestHd2dStreet.tscn`

- [ ] **Step 1: 先寫 headless 失敗測試**

`test/TestHd2dStreet.gd`：
```gdscript
extends Node
## headless 結構驗證 Hd2dStreet：環境/地面（Task 1）→ 建築（Task 2）
## → 後製 camera_attributes（Task 5）→ 氛圍（Task 6）逐 task 擴充。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn

const Hd2dStreet := preload("res://src/screens/MapScreen/environments/Hd2dStreet.gd")

func _ready() -> void:
	var street := Hd2dStreet.new()
	get_tree().root.add_child(street)
	for i in 3:
		await get_tree().process_frame

	var ground := street.get_node_or_null("Ground")
	if ground == null or not (ground is MeshInstance3D):
		return _fail("無 Ground MeshInstance3D")

	var we := _find_we(street)
	if we == null:
		return _fail("無 WorldEnvironment")
	if we.environment == null:
		return _fail("WorldEnvironment.environment 為 null")
	if not we.environment.glow_enabled:
		return _fail("glow 未開")

	print("TEST PASS: Hd2dStreet 環境＋地面＋glow OK")
	get_tree().quit(0)

func _find_we(n: Node) -> WorldEnvironment:
	for c in n.get_children():
		if c is WorldEnvironment:
			return c
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
```

`test/TestHd2dStreet.tscn`：
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/TestHd2dStreet.gd" id="1"]

[node name="TestHd2dStreet" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: 失敗（`Hd2dStreet.gd` 不存在 → preload 解析錯誤 / 載入失敗）。

- [ ] **Step 3: 寫 Hd2dStreet 環境＋地面最小實作**

`src/screens/MapScreen/environments/Hd2dStreet.gd`：
```gdscript
extends Node3D
## HD-2D 西門街世界建構器（八方旅人式）：厚塗 2D 立板擺進真 3D 景深。
## 本節點只建「世界」：環境、地面、建築立板、遠景背板、後製、氛圍。
## 固定俯角相機與主角由外部組裝（見 test/Hd2dProto.gd）。
## 美術鐵則：一律重用既有半寫實厚塗素材，立板 UNSHADED 保畫風，不得改畫風。
## 可獨立放進原型場景，日後整段塞進 MapScreen 的 SubViewport。

const TEX_DIR := "res://assets/3d/environments/ximen/"

# 街道沿 -Z 縱深延伸；玩家在 z≈0，相機在 +Z 高處俯看 -Z（箱庭縱深）。
const STREET_LEN := 40.0      # 地面長度（Z）
const STREET_W := 16.0        # 地面寬度（X）
const FAR_ROW_Z := -22.0      # 遠景建築排（壓暗）
const NEAR_ROW_Z := -9.0      # 近景建築排（街兩側）
const NEAR_SIDE_X := 7.0      # 近排建築離街心的 X

var _bldgs: Array = []        # 整棟厚塗建築立板貼圖 bldg_01..12
var _ground_tex: Texture2D

func _ready() -> void:
	for i in range(1, 13):
		var t := _load(TEX_DIR + "bldg_%02d.png" % i)
		if t: _bldgs.append(t)
	_ground_tex = _load(TEX_DIR + "ground_wet.png")
	_build_environment()
	_build_ground()
	# 建築/背板＝Task 2；後製＝Task 5；氛圍＝Task 6

func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# ── 基礎環境：暖夜霓虹、FILMIC tonemap、glow（後製細調在 Task 5）──
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.10)        # 深暖夜（非死黑）
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC      # 避開 ACES 把霓虹去飽和成白
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.25                          # 抬高閾值，避免 bloom floor 抬白

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# 柔和主光（立板 UNSHADED 不吃光，主要照地面與日後 lit 元件）
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.8, 0.82, 1.0)
	sun.light_energy = 0.45
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = false
	add_child(sun)

# ── 地面：無縫濕柏油平面，roughness 0.34 吃霓虹反射，含碰撞讓主角站得住 ──
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(STREET_W, STREET_LEN)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_tex
	mat.albedo_color = Color(1.4, 1.4, 1.55)               # >1 提亮過暗柏油，霓虹光暈鋪得開
	mat.uv1_scale = Vector3(STREET_W / 3.2, STREET_LEN / 3.2, 1)
	mat.metallic = 0.0
	mat.roughness = 0.34                                    # 濕亮但非全鏡面
	mat.metallic_specular = 0.5
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	add_child(mi)

	# 地面碰撞（單一平面盒）
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(STREET_W + 8.0, 1.0, STREET_LEN + 8.0)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)
```

- [ ] **Step 4: 跑測試確認通過**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: stdout 含 `TEST PASS: Hd2dStreet 環境＋地面＋glow OK`，exit 0。
（注意「SCRIPT ERROR 仍印 PASS」雷：確認輸出**沒有** `SCRIPT ERROR`／`TEST FAIL`／`push_error` 字樣才算過。）

- [ ] **Step 5: Commit**

```bash
git add src/screens/MapScreen/environments/Hd2dStreet.gd test/TestHd2dStreet.gd test/TestHd2dStreet.tscn
git commit -m "feat(hd2d): Hd2dStreet builder skeleton — environment + ground"
```

---

### Task 2: 建築景深層 — 近/遠兩排厚塗立板＋遠景背板（spec 建置步驟 1 的內容）

**Files:**
- Modify: `src/screens/MapScreen/environments/Hd2dStreet.gd`（新增 `_build_buildings`、`_build_backdrop`、`_add_plate`；`_ready` 呼叫）
- Modify: `test/TestHd2dStreet.gd`（加 Buildings 立板數驗證）

- [ ] **Step 1: 擴充 headless 測試（先失敗）**

在 `test/TestHd2dStreet.gd` 的 `we` 檢查通過後、`print("TEST PASS...")` 之前插入：
```gdscript
	var buildings := street.get_node_or_null("Buildings")
	if buildings == null:
		return _fail("無 Buildings 節點")
	if buildings.get_child_count() < 4:
		return _fail("Buildings 立板不足：%d" % buildings.get_child_count())
	for c in buildings.get_children():
		if not (c is MeshInstance3D):
			return _fail("Buildings 子節點非 MeshInstance3D：%s" % c)
```
並把 PASS 訊息改成：
```gdscript
	print("TEST PASS: Hd2dStreet 環境＋地面＋建築立板(%d)＋glow OK" % buildings.get_child_count())
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST FAIL: 無 Buildings 節點`。

- [ ] **Step 3: 實作建築立板＋背板**

在 `Hd2dStreet.gd` 的 `_ready()`，於 `_build_ground()` 後加：
```gdscript
	_build_buildings()
	_build_backdrop()
```

在 `_build_ground()` 之後新增三個方法：
```gdscript
# ── 建築景深層：近排（街兩側）＋遠排（壓暗）＝箱庭縱深。──
# 立板＝直立 QuadMesh，法線朝 +Z（面向相機），UNSHADED 保厚塗畫風，
# 整張矩形（原型先不去背）。高度隨機、寬度依貼圖比例避免拉伸。
func _build_buildings() -> void:
	if _bldgs.is_empty():
		return
	var parent := Node3D.new()
	parent.name = "Buildings"
	add_child(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260618

	# 遠排：橫跨 X 的一道燈海樓牆，壓暗讀成遠景
	var far_x := -STREET_W * 0.5
	while far_x <= STREET_W * 0.5:
		var h := rng.randf_range(13.0, 18.0)
		_add_plate(parent, _bldgs[rng.randi() % _bldgs.size()],
			Vector3(far_x, h * 0.5, FAR_ROW_Z), h, 0.6)
		far_x += rng.randf_range(6.0, 8.0)

	# 近排：左右各擺幾棟，中央留街給主角走（|x| < ~4 不放）
	for side in [-1.0, 1.0]:
		var n := rng.randi_range(2, 3)
		for i in n:
			var h2 := rng.randf_range(9.0, 15.0)
			var z := NEAR_ROW_Z + rng.randf_range(-5.0, 5.0)
			var x := side * (NEAR_SIDE_X + rng.randf_range(-0.6, 1.6))
			_add_plate(parent, _bldgs[rng.randi() % _bldgs.size()],
				Vector3(x, h2 * 0.5, z), h2, 1.0)

# 單張立板：直立 QuadMesh、面向 +Z、UNSHADED；dim<1 壓暗（遠景）。
func _add_plate(parent: Node3D, tex: Texture2D, pos: Vector3, height: float, dim: float) -> void:
	var aspect := float(tex.get_width()) / float(tex.get_height())   # 768/1376≈0.558
	var q := QuadMesh.new()
	q.size = Vector2(height * aspect, height)                        # QuadMesh 預設立在 XY 平面、法線 +Z
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(dim, dim, dim)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	parent.add_child(mi)

# ── 遠景背板：街盡頭一片壓暗燈海，填掉黑洞、讓街像繼續延伸。──
func _build_backdrop() -> void:
	if _bldgs.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(STREET_W * 2.5, 26.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _bldgs[_bldgs.size() - 1]
	m.albedo_color = Color(0.4, 0.4, 0.5)            # 壓暗＝遠景
	m.uv1_scale = Vector3(4, 2, 1)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	mi.mesh = q
	mi.position = Vector3(0, 11.0, FAR_ROW_Z - 8.0)
	add_child(mi)
```

- [ ] **Step 4: 跑測試確認通過**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST PASS: Hd2dStreet 環境＋地面＋建築立板(N)＋glow OK`（N≥4），無 SCRIPT ERROR，exit 0。

- [ ] **Step 5: Commit**

```bash
git add src/screens/MapScreen/environments/Hd2dStreet.gd test/TestHd2dStreet.gd
git commit -m "feat(hd2d): building depth layers (near/far rows) + backdrop"
```

---

### Task 3: 原型場景＋固定 3/4 相機＋截圖工具 → 第一個視覺關卡（spec 步驟 1：「讀起來像有深度的街？」）

**Files:**
- Create: `test/Hd2dProto.gd`
- Create: `test/Hd2dProto.tscn`
- Create: `test/CaptureHd2d.gd`
- Create: `test/CaptureHd2d.tscn`

本 task 先**不放主角**（spec 步驟 1＝固定相機看箱庭縱深）。`CameraRig` 抓不到 player 時停在原點、以 offset 俯看街道，正好給靜態箱庭視角。

- [ ] **Step 1: 寫原型組裝場景**

`test/Hd2dProto.gd`：
```gdscript
extends Node3D
## HD-2D 西門街原型：可走場景（方向鍵移動）。
## 重用 Hd2dStreet（世界）＋CameraRig（固定 3/4 俯角跟隨）。
## 主角在 Task 4 加入；Task 3 先驗固定相機的箱庭縱深。
## 跑法：Godot res://test/Hd2dProto.tscn（要 GPU 視窗才看得到 glow/DOF）。

const Hd2dStreet := preload("res://src/screens/MapScreen/environments/Hd2dStreet.gd")
const CameraRig := preload("res://src/screens/MapScreen/CameraRig.gd")

func _ready() -> void:
	var street := Hd2dStreet.new()
	street.name = "Hd2dStreet"
	add_child(street)

	var rig := CameraRig.new()
	rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 50.0
	rig.add_child(cam)
	# 固定 3/4 俯角；offset 先設好再 add_child，讓 CameraRig._ready 套用。
	rig.set("camera_offset", Vector3(0.0, 10.0, 8.0))
	rig.set("camera_pitch_deg", -34.0)
	add_child(rig)

	var hud := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "HD-2D 西門街原型　·　方向鍵移動"
	lbl.position = Vector2(28, 24)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	hud.add_child(lbl)
	add_child(hud)
```

`test/Hd2dProto.tscn`：
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/Hd2dProto.gd" id="1"]

[node name="Hd2dProto" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 2: 寫視窗截圖工具**

`test/CaptureHd2d.gd`：
```gdscript
extends Node
## 視窗版自動截圖：載入 HD-2D 原型→等畫面穩定→存 PNG→退出。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
## DOF/glow/霓虹只有 GPU 視窗渲得出來，故用「視窗版」非 --headless。

func _ready() -> void:
	var proto: Node = load("res://test/Hd2dProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	for i in 180:                          # 等場景建好＋粒子/霧/DOF 收斂
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_hd2d_shot.png")
	print("HD2D_SHOT_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
```

`test/CaptureHd2d.tscn`：
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/CaptureHd2d.gd" id="1"]

[node name="CaptureHd2d" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 匯入＋截圖**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import
tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
```
Expected: 開一個視窗數秒後自動關閉，stdout 含 `HD2D_SHOT_DONE <寬>x<高>`，產生 `D:/monk/MONK/_hd2d_shot.png`。

- [ ] **Step 4: 視覺自檢（spec 步驟 1 關卡）**

用 Read 工具開 `MONK/_hd2d_shot.png`，對照判準：**讀起來像「有深度的街」嗎？**——近排立板較大較前、遠排較小較暗、背板收尾，地面往縱深延伸。
- 過 → 進 Step 5。
- 不過 → 調 Tunables（相機 `camera_offset`/`camera_pitch_deg`/`fov`、立板 `NEAR_ROW_Z`/`FAR_ROW_Z`/`NEAR_SIDE_X`/高度範圍），重跑 Step 3-4 迭代。
- 把這張圖給使用者看一眼確認方向（成功判準最終是使用者的眼睛）。

- [ ] **Step 5: Commit**

```bash
git add test/Hd2dProto.gd test/Hd2dProto.tscn test/CaptureHd2d.gd test/CaptureHd2d.tscn
git commit -m "feat(hd2d): playable proto scene + fixed 3/4 camera + capture tool"
```

---

### Task 4: 主角 billboard＋相機跟隨（spec 步驟 2：「視差/景深、站位、走動翻面對？」）

**Files:**
- Create: `src/screens/MapScreen/Hd2dPlayer.gd`
- Create: `test/TestHd2dPlayer.gd`
- Create: `test/TestHd2dPlayer.tscn`
- Modify: `test/Hd2dProto.gd`（加入主角）

- [ ] **Step 1: 寫 headless 主角測試（先失敗）**

`test/TestHd2dPlayer.gd`：
```gdscript
extends Node
## headless 驗證 Hd2dPlayer：有 Y-billboard Sprite3D、加入 player group、
## 設了 velocity 跑 physics 會位移、移動時切到 walk 幀。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestHd2dPlayer.tscn

const Hd2dPlayer := preload("res://src/screens/MapScreen/Hd2dPlayer.gd")

func _ready() -> void:
	var p := Hd2dPlayer.new()
	get_tree().root.add_child(p)
	for i in 3:
		await get_tree().process_frame

	if not p.is_in_group("player"):
		return _fail("主角未加入 player group")
	var spr := _find_sprite(p)
	if spr == null:
		return _fail("無 Sprite3D")
	if spr.billboard != BaseMaterial3D.BILLBOARD_FIXED_Y:
		return _fail("Sprite3D 非 BILLBOARD_FIXED_Y")
	if spr.texture == null:
		return _fail("Sprite3D 無貼圖")

	# 位移：設水平 velocity 跑一次 physics
	var before: Vector3 = p.global_position
	p.velocity = Vector3(3, 0, 0)
	p.call("move_and_slide")
	if p.global_position.distance_to(before) <= 0.0:
		return _fail("move_and_slide 未位移")

	print("TEST PASS: Hd2dPlayer billboard sprite＋group＋位移 OK")
	get_tree().quit(0)

func _find_sprite(n: Node) -> Sprite3D:
	for c in n.get_children():
		if c is Sprite3D:
			return c
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
```

`test/TestHd2dPlayer.tscn`：
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/TestHd2dPlayer.gd" id="1"]

[node name="TestHd2dPlayer" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dPlayer.tscn
```
Expected: 失敗（`Hd2dPlayer.gd` 不存在）。

- [ ] **Step 3: 寫 Hd2dPlayer 實作**

`src/screens/MapScreen/Hd2dPlayer.gd`：
```gdscript
extends CharacterBody3D
## HD-2D 主角：CharacterBody3D ＋ Y-billboard Sprite3D。
## 方向鍵相對相機移動，移動時循環 walk 幀、靜止顯示 idle，依水平位移翻面。
## 重用既有厚塗 wujie sprite（256×384），UNSHADED 保畫風。

const SPRITE_DIR := "res://assets/2d/characters/wujie/sprite/"
const SPEED := 5.0
const GRAVITY := -20.0
const PLAYER_HEIGHT := 2.0     # 世界高度（公尺）；pixel_size 由此與貼圖高度反推
const WALK_FPS := 10.0

var _idle: Texture2D
var _walk: Array = []
var _sprite: Sprite3D
var _cam_basis := Basis.IDENTITY
var _anim_t := 0.0

func _ready() -> void:
	add_to_group("player")
	_idle = load(SPRITE_DIR + "idle_0.png") as Texture2D
	for i in 8:
		var t := load(SPRITE_DIR + "walk_%d.png" % i) as Texture2D
		if t: _walk.append(t)

	_sprite = Sprite3D.new()
	_sprite.name = "Sprite3D"
	_sprite.texture = _idle
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y    # 直立、繞 Y 面向相機
	_sprite.shaded = false                                  # 厚塗自帶光影，不吃 3D 燈
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD      # 硬邊去背、免透明排序
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _idle:
		_sprite.pixel_size = PLAYER_HEIGHT / float(_idle.get_height())
	_sprite.position = Vector3(0, PLAYER_HEIGHT * 0.5, 0)   # 腳在 y=0
	add_child(_sprite)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = PLAYER_HEIGHT
	col.shape = cap
	col.position = Vector3(0, PLAYER_HEIGHT * 0.5, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_basis = Basis(Vector3.UP, cam.global_rotation.y)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var dir := _cam_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	if dir.length() > 0.1:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if absf(dir.x) > 0.01:
			_sprite.flip_h = dir.x < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	move_and_slide()
	_update_frame(delta)

func _update_frame(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	if moving and not _walk.is_empty():
		_anim_t += delta * WALK_FPS
		_sprite.texture = _walk[int(_anim_t) % _walk.size()]
	else:
		_anim_t = 0.0
		if _idle:
			_sprite.texture = _idle
```

- [ ] **Step 4: 跑測試確認通過**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dPlayer.tscn
```
Expected: `TEST PASS: Hd2dPlayer billboard sprite＋group＋位移 OK`，無 SCRIPT ERROR，exit 0。

- [ ] **Step 5: 把主角接進原型場景**

在 `test/Hd2dProto.gd` 頂部加 const：
```gdscript
const Hd2dPlayer := preload("res://src/screens/MapScreen/Hd2dPlayer.gd")
```
在 `_ready()` 中 `add_child(street)` 之後、建立 `rig` 之前插入：
```gdscript
	var player := Hd2dPlayer.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)
```
（`CameraRig` 會透過 `player` group 自動抓到並開始跟隨。）

- [ ] **Step 6: 截圖＋視覺自檢（spec 步驟 2 關卡）**

```bash
tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
```
用 Read 開 `MONK/_hd2d_shot.png`，判準：**主角厚塗 sprite 站在街上、比例/站位對、相機把他納入框、與立板的視差/景深讀得出來嗎？** 走動翻面與切幀無法從單張靜圖驗，需實機跑一次（`Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/Hd2dProto.tscn`，方向鍵走幾步看 walk 循環與左右翻面）。
- 不過 → 調 `PLAYER_HEIGHT`、相機 offset/pitch、主角起始位置；若 sprite 預設朝向不符，調 `flip_h` 邏輯。重跑迭代。
- 給使用者看一眼。

- [ ] **Step 7: Commit**

```bash
git add src/screens/MapScreen/Hd2dPlayer.gd test/TestHd2dPlayer.gd test/TestHd2dPlayer.tscn test/Hd2dProto.gd
git commit -m "feat(hd2d): billboard player (wujie sprite) + camera follow"
```

---

### Task 5: 電影感後製 — 移軸景深＋glow 細調＋暈影（spec 步驟 3：「精緻箱庭非紙板？」）

⚠ **引擎重點**：Godot 4.5 的景深（DOF）在 `CameraAttributesPractical`，**不在** Environment（spec 原文寫「Environment DOF」是舊認知）。透過 `WorldEnvironment.camera_attributes` 掛上即對所有渲染此環境的相機生效（含日後 SubViewport）。暈影 Godot 4 Environment 無內建，用全螢幕 ColorRect shader 疊。

**Files:**
- Modify: `src/screens/MapScreen/environments/Hd2dStreet.gd`（新增 `_apply_cinematic`、`_build_vignette`；`_ready` 呼叫）
- Modify: `test/TestHd2dStreet.gd`（驗 camera_attributes＋DOF）

- [ ] **Step 1: 擴充 headless 測試（先失敗）**

在 `test/TestHd2dStreet.gd` 的 glow 檢查後插入：
```gdscript
	if we.camera_attributes == null or not (we.camera_attributes is CameraAttributesPractical):
		return _fail("無 CameraAttributesPractical（移軸景深未掛）")
	var ca := we.camera_attributes as CameraAttributesPractical
	if not ca.dof_blur_far_enabled or not ca.dof_blur_near_enabled:
		return _fail("DOF 遠/近模糊未啟用")
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST FAIL: 無 CameraAttributesPractical（移軸景深未掛）`。

- [ ] **Step 3: 實作後製**

在 `Hd2dStreet.gd` 的 `_ready()`，於 `_build_backdrop()` 後加：
```gdscript
	_apply_cinematic()
	_build_vignette()
```

新增方法（放在 `_build_backdrop` 之後）：
```gdscript
# ── 電影感後製：移軸景深（tilt-shift 微縮）＋tonemap 微調。──
# 焦平面鎖在主角距離附近（相機 offset≈(0,10,8)→主角約 12~13m），
# 前後景模糊＝箱庭微縮感（HD-2D 最關鍵的一步）。
func _apply_cinematic() -> void:
	var we := _world_env()
	if we == null:
		return
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 16.0
	ca.dof_blur_far_transition = 4.0
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 7.0
	ca.dof_blur_near_transition = 3.0
	ca.dof_blur_amount = 0.12
	we.camera_attributes = ca
	# tonemap 微調（保持 FILMIC，略提對比讓霓虹更跳）
	we.environment.tonemap_exposure = 1.05

func _world_env() -> WorldEnvironment:
	for c in get_children():
		if c is WorldEnvironment:
			return c
	return null

# ── 暈影：全螢幕 ColorRect 徑向暗角 shader（Environment 無內建 vignette）。──
func _build_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.name = "VignetteLayer"
	cl.layer = 50
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" + \
		"uniform float strength = 0.55;\n" + \
		"uniform float radius = 0.75;\n" + \
		"void fragment() {\n" + \
		"	float d = distance(SCREEN_UV, vec2(0.5));\n" + \
		"	float v = smoothstep(radius, radius - 0.45, d);\n" + \
		"	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - v) * strength);\n" + \
		"}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	cl.add_child(rect)
	add_child(cl)
```

- [ ] **Step 4: 跑測試確認通過**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST PASS: ...建築立板(N)＋glow OK`，無 SCRIPT ERROR/TEST FAIL，exit 0。

- [ ] **Step 5: 截圖＋視覺自檢（spec 步驟 3 關卡，**反覆迭代**）**

```bash
tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
```
Read `MONK/_hd2d_shot.png`，判準：**移軸景深把街變成「精緻箱庭微縮」而非「紙板」嗎？** 主角清晰、前後景柔焦、霓虹有 glow 不抬白、暗角收邊。
- 調整旋鈕直到對味：DOF `dof_blur_*_distance`/`dof_blur_amount`（焦平面與模糊強度）、glow `glow_hdr_threshold`/`glow_intensity`、`tonemap_exposure`、暈影 `strength`/`radius`。每改一次重跑本 step。
- 守三戒：自發光壓低、用 FILMIC（非 ACES）、glow 閾值別讓 bloom floor 抬白。
- 給使用者看，這是觀感成敗的關鍵步。

- [ ] **Step 6: Commit**

```bash
git add src/screens/MapScreen/environments/Hd2dStreet.gd test/TestHd2dStreet.gd
git commit -m "feat(hd2d): cinematic post — tilt-shift DOF + glow tune + vignette"
```

---

### Task 6: 氛圍 — 雨＋遠景霾＋霓虹 omni 光池（spec 步驟 4）

**Files:**
- Modify: `src/screens/MapScreen/environments/Hd2dStreet.gd`（新增 `_build_atmosphere`；`_ready` 呼叫）
- Modify: `test/TestHd2dStreet.gd`（驗雨粒子＋霓虹 omni）

- [ ] **Step 1: 擴充 headless 測試（先失敗）**

在 `test/TestHd2dStreet.gd` 的 DOF 檢查後插入：
```gdscript
	var atmo := street.get_node_or_null("Atmosphere")
	if atmo == null:
		return _fail("無 Atmosphere 節點")
	var has_rain := false
	var omni := 0
	for c in atmo.get_children():
		if c is GPUParticles3D: has_rain = true
		if c is OmniLight3D: omni += 1
	if not has_rain:
		return _fail("無 GPUParticles3D 雨")
	if omni < 2:
		return _fail("霓虹 OmniLight 不足：%d" % omni)
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST FAIL: 無 Atmosphere 節點`。

- [ ] **Step 3: 實作氛圍**

在 `Hd2dStreet.gd` 的 `_ready()` 末尾加：
```gdscript
	_build_atmosphere()
```

新增方法（放在 `_build_vignette` 之後）：
```gdscript
# ── 氛圍：薄遠景霾＋雨＋霓虹 omni 光池（打在 lit 濕地面成光暈）。──
func _build_atmosphere() -> void:
	var atmo := Node3D.new()
	atmo.name = "Atmosphere"
	add_child(atmo)

	# 薄霾（不要厚 noir 霧，街要看得清）
	var we := _world_env()
	if we:
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.30, 0.34, 0.5)
		we.environment.fog_density = 0.0018
		we.environment.fog_aerial_perspective = 0.2
		we.environment.fog_sky_affect = 0.0

	# 霓虹 omni 光池：沿街幾盞冷暖交錯，打濕地面成縱向光暈
	var cols := [Color(1.0, 0.5, 0.7), Color(0.4, 0.8, 1.0), Color(1.0, 0.7, 0.4), Color(0.6, 0.5, 1.0)]
	var zs := [-4.0, -12.0, -20.0]
	for i in zs.size():
		for side in [-1.0, 1.0]:
			var omni := OmniLight3D.new()
			omni.light_color = cols[(i * 2 + int(side > 0)) % cols.size()]
			omni.light_energy = 2.0
			omni.omni_range = 7.5
			omni.position = Vector3(side * (NEAR_SIDE_X - 1.5), 2.2, zs[i])
			atmo.add_child(omni)

	# 雨（細長 quad、淡冷色、不 billboard＝垂直線，免層疊糊白）
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 600
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-STREET_W, -2, -STREET_LEN), Vector3(STREET_W * 2, 30, STREET_LEN * 2))
	p.position = Vector3(0, 16, -8)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 1.5
	pm.gravity = Vector3(0, -40, 0)
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(STREET_W * 0.5, 1, STREET_LEN * 0.5)
	p.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.5)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.6, 0.68, 0.82, 0.14)
	streak.material = rm
	p.draw_pass_1 = streak
	atmo.add_child(p)
```

- [ ] **Step 4: 跑測試確認通過**

```bash
tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn
```
Expected: `TEST PASS`，無 SCRIPT ERROR/TEST FAIL，exit 0。

- [ ] **Step 5: 截圖＋視覺自檢（spec 步驟 4）**

```bash
tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
```
Read `MONK/_hd2d_shot.png`，判準：**雨/霾/霓虹光池讓街「活」起來、濕地面有縱向光暈、整體氛圍到位、但沒糊白嗎？**
- 雨太濃/糊白 → 降 `amount`/`albedo alpha`；霧太厚 → 降 `fog_density`；光太爆 → 降 omni `light_energy` 或 glow。
- 給使用者看。

- [ ] **Step 6: Commit**

```bash
git add src/screens/MapScreen/environments/Hd2dStreet.gd test/TestHd2dStreet.gd
git commit -m "feat(hd2d): atmosphere — rain + haze + neon light pools"
```

---

### 最終關卡：使用者實機驗收（spec §8 成功判準）

- [ ] **實機走一遍**
```bash
tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/Hd2dProto.tscn
```
請使用者方向鍵走西門街，判準：**有明顯景深＋運鏡＋箱庭精緻感、且不覺得「假」？**
- **過關** → 同步文件＋記憶（更新 `project-2d-map`／`project-3d-environment`／本計畫狀態、PROJECT_STATUS），再**另開計畫**做 Phase 2（接 MapScreen ＋ 其他場景轉 HD-2D）。
- **不過** → 回頭調整對應 task，或與使用者重議路線（2.5D 視差／風格化 low-poly）。

---

## Phase 2（原型過關後另開計畫，本計畫不執行）— spec 步驟 5

接 MapScreen 西門區：把 `Hd2dStreet` 放進 `SubViewport`，`西門 DistrictScene` 改用 `SubViewportContainer`，MapHUD（2D）疊上層；地點觸發/傳送點/存檔沿用既有 2D 流程。需另驗：輸入/滑鼠事件穿透、解析度、MapHUD 疊層、`current_scene` 脫鉤（見 `project-mapscreen-areas` driver 測試雷）。**待使用者對原型簽核後另寫計畫。**

---

## Self-Review（對照 spec 自檢）

**1. Spec coverage：**
- §2 美術鐵則 → 立板/sprite 全 `UNSHADED` 重用既有厚塗素材，貫穿每 task 的鐵則段。✅
- §4.1 場景樹（Ground/Backdrop/Buildings/Player/CameraRig/WorldEnvironment）→ Task 1-4 全建出（Player/Camera 在 Hd2dProto 組裝，環境可獨立進 SubViewport）。✅
- §4.2 SubViewport 整合 → Phase 2（明確標示原型過關後另開計畫）。✅
- §5.1 元件（Ground/立板/Player/CameraRig）→ Task 1/2/4，CameraRig 重用 group fallback。✅
- §5.2 WorldEnvironment（DOF/glow/tonemap/暈影/霧/雨）→ Task 5（DOF＋glow＋tonemap＋暈影）＋Task 6（霧＋雨＋霓虹）。✅（已修正：DOF 改用 `CameraAttributesPractical`。）
- §6 資產重用＋`--import` 前置 → 全程重用 bldg/ground/wujie，通用指令段含 `--import`。✅
- §7 建置順序 1→5 → Task 2-3(步驟1)/Task 4(步驟2)/Task 5(步驟3)/Task 6(步驟4)/Phase 2(步驟5)，每步 GPU 截圖自檢。✅
- §8 驗證＋成功判準 → Capture* 截圖 Read 自檢＋最終使用者實機驗收。✅
- §9 風險（掠角糊白/CameraRig NodePath/Meshy/`--import`/SubViewport）→ 立板面向相機非掃掠角、重用 CameraRig group fallback、主角用 2D sprite 免 Meshy、`--import` 入通用指令、SubViewport 列 Phase 2。✅

**2. Placeholder scan：** 每個 code step 都是完整可貼程式碼；指令含預期輸出；無 TBD/「實作 X」/「類似 Task N」。✅

**3. Type consistency：** 節點名一致（`Ground`/`Buildings`/`WorldEnvironment`/`Atmosphere`/`Sprite3D`/`Player`/`CameraRig`/`Camera3D`）；`Hd2dStreet` 的 `_world_env()` 與測試 `_find_we()` 都以 `WorldEnvironment` 型別搜；`CameraRig` 的 export（`camera_offset`/`camera_pitch_deg`）與 Hd2dProto 的 `set(...)` 鍵名相符；`Hd2dPlayer` 的 `_sprite`/`velocity`/group `player` 與測試斷言一致。✅
