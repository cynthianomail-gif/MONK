# 3D 水墨神社街・獨立可玩場景 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `test/OkamiShaderTest.gd` 的水墨 3D look-dev 正式化成一個獨立、可走動的成品場景（玩家 3D 無戒沿神社街走、相機跟隨、全程水墨 shader）。

**Architecture:** 沿用既有 `XimenStreet` 模式＝程式化環境腳本（`extends Node3D`）＋薄 `.tscn`＋shader 抽成 `.gdshader` 檔。環境腳本程式建街；`.tscn` 掛 Player 與 CameraRig；描邊後處理 quad 在執行期掛到當前相機。

**Tech Stack:** Godot 4.5（GDScript、spatial/canvas shader、CharacterBody3D、Forward+）。

**驗證慣例（本專案特性，全程適用）：**
- 跑法：windowed＝`./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK <scene> -- smoke`（在 `D:/monk` 下執行）。
- **GDScript parse error 時視窗版會卡死不報錯** → 先跑 `--headless` 版同指令，parse error 幾秒印出。
- render 後**務必 grep log 確認 `_SAVED` 字樣**，再 `Read` 圖自檢；**不可只看 exit code＋讀圖**（壞時讀到舊圖誤判）。
- shader GLSL 錯誤只在 windowed（GPU）才現形，headless dummy renderer 不編 shader。
- `var x := [字面陣列][索引]` 推不出型別＝parse error → 用 `var x: Color = …`。

---

### Task 1: 4 個水墨 shader 抽成 `.gdshader` 檔

**Files:**
- Create: `assets/shaders/okami/ink_toon.gdshader`
- Create: `assets/shaders/okami/ink_ground.gdshader`
- Create: `assets/shaders/okami/ink_outline.gdshader`
- Create: `assets/shaders/okami/ink_paper.gdshader`
- Create: `test/_ShaderLoadCheck.gd`

- [ ] **Step 1: 建 `ink_toon.gdshader`**

內容＝`test/OkamiShaderTest.gd` 的 `_build_toon_shader()` 裡 `_toon_shader.code = """ … """` 三引號之間那段 GLSL，原封不動（從 `shader_type spatial;` 那行到 `light()` 函式結尾的 `}`）。不要含 GDScript 包裝、不要含開頭換行。

- [ ] **Step 2: 建 `ink_ground.gdshader`**

內容＝`_build_ground_shader()` 裡 `_ground_shader.code = """ … """` 之間的 GLSL（`shader_type spatial;` 起，到 `light()` 結尾）。

- [ ] **Step 3: 建 `ink_outline.gdshader`**

內容＝`_build_ink_outline()` 裡 `sh.code = """ … """` 之間的 GLSL（`shader_type spatial;` `render_mode unshaded…` 起，到 `fragment()` 結尾）。

- [ ] **Step 4: 建 `ink_paper.gdshader`**

內容＝`_build_paper_overlay()` 裡 `sh.code = """ … """` 之間的 GLSL（`shader_type canvas_item;` 起，到 `fragment()` 結尾）。

- [ ] **Step 5: 建載入檢查 `test/_ShaderLoadCheck.gd`**

```gdscript
extends SceneTree
## headless shader 載入檢查：godot --headless --script res://test/_ShaderLoadCheck.gd
func _init() -> void:
	var paths := [
		"res://assets/shaders/okami/ink_toon.gdshader",
		"res://assets/shaders/okami/ink_ground.gdshader",
		"res://assets/shaders/okami/ink_outline.gdshader",
		"res://assets/shaders/okami/ink_paper.gdshader",
	]
	for p in paths:
		assert(ResourceLoader.exists(p), "MISSING: " + p)
		var sh := load(p) as Shader
		assert(sh != null, "NOT A SHADER: " + p)
	print("SHADERS_OK ", paths.size())
	quit()
```

- [ ] **Step 6: 跑檢查**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --script res://test/_ShaderLoadCheck.gd 2>&1 | grep -aiE "SHADERS_OK|SCRIPT ERROR|MISSING|assert"`
Expected: `SHADERS_OK 4`（無 assert/parse error）

- [ ] **Step 7: Commit**

```bash
git add MONK/assets/shaders/okami MONK/test/_ShaderLoadCheck.gd
git commit -m "feat(shrine-street): 抽出 4 個水墨 .gdshader + 載入檢查"
```

---

### Task 2: `ShrineStreet.gd` 環境builder（建街＋地面碰撞＋描邊掛載＋玩家上墨 helper）

**Files:**
- Create: `src/screens/MapScreen/environments/ShrineStreet.gd`
- Reference（讀，不改）：`test/OkamiShaderTest.gd`（建街函式來源）、`src/screens/MapScreen/PlayerAnimTree.gd`（`_make_opaque` 走訪法參考）

- [ ] **Step 1: 建 `ShrineStreet.gd` 骨架＋shader preload＋材質 helper**

```gdscript
extends Node3D
## 程式化「水墨神社街」環境（幾何盒體＋水墨 shader，不貼 AI 圖）。
## 在 _ready 動態建：env/光、石板地面、兩排店家（屋頂/三件套/木格/掛看板）、
## 石燈籠、鳥居、遠景杉林、幟＋道具、和紙層。RNG 固定種子＝可重現。
## 描邊後處理 quad 執行期掛到當前相機；_apply_ink() 把玩家 mesh 套水墨 toon。

const TOON_SHADER := preload("res://assets/shaders/okami/ink_toon.gdshader")
const GROUND_SHADER := preload("res://assets/shaders/okami/ink_ground.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/okami/ink_outline.gdshader")
const PAPER_SHADER := preload("res://assets/shaders/okami/ink_paper.gdshader")

func _toon_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	return m
```

- [ ] **Step 2: 從 `OkamiShaderTest.gd` 移植建街函式（逐字，僅去掉舊 shader 來源）**

把下列函式**原封不動**從 `test/OkamiShaderTest.gd` 複製進 `ShrineStreet.gd`：
`_box`、`_roof`、`_build_env`、`_build_street`、`_build_torii`、`_build_lanterns`、`_build_stone_lanterns`、`_build_backdrop`、`_build_props`、`_build_paper_overlay`。

**不要**複製：`_build_toon_shader`、`_build_ground_shader`（改用上面的 preload const）、`_build_monk`（玩家改用 GLB）、`_build_ink_outline`（改寫見 Step 4）、`_smoke`、`_ready`、`_cam`/`_toon_shader`/`_ground_shader` 成員、`_toon_mat`/`_ground_mat`（已在 Step 1 用 preload 版取代）。

注意 `_build_street` 裡的地面那段現在是手刻 `ground` MeshInstance＋`_ground_mat()`——保留，但 Step 3 會在其後加碰撞體。

- [ ] **Step 3: `_build_street` 地面加 StaticBody 碰撞**

在 `_build_street()` 建完 `ground` MeshInstance（`material_override = _ground_mat()`、`root.add_child(ground)`）之後，緊接著加：

```gdscript
	var floor_body := StaticBody3D.new()
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 70)
	cshape.shape = box
	floor_body.add_child(cshape)
	floor_body.position = Vector3(0, -0.1, -12)
	root.add_child(floor_body)
```

- [ ] **Step 4: 描邊掛載函式（取代 `_build_ink_outline`）**

```gdscript
## 把螢幕空間描邊 quad 掛到「當前作用中的相機」。延一幀呼叫，
## 確保 CameraRig（或測試相機）已 make_current。
func _attach_outline_to_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	mi.extra_cull_margin = 16384.0
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.render_priority = 100
	mi.material_override = mat
	cam.add_child(mi)
	mi.position = Vector3(0, 0, -0.5)
```

- [ ] **Step 5: 玩家上墨函式**

```gdscript
## 把玩家所有 mesh 換成水墨 toon。用 material_override 整個取代材質＝
## 順帶繞過 Meshy GLB base-color alpha 透明 bug（toon mat 本身不透明）。
## 延幀呼叫（GLB 子樹要一幀才建好）。
func _apply_ink(node: Node) -> void:
	for c in node.get_children():
		_apply_ink(c)
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _toon_mat(Color(0.30, 0.27, 0.24))
```

- [ ] **Step 6: `_ready`（建世界＋延幀掛描邊）**

```gdscript
func _ready() -> void:
	_build_env(self)
	_build_street(self)
	_build_torii(self)
	_build_lanterns(self)
	_build_stone_lanterns(self)
	_build_backdrop(self)
	_build_props(self)
	_build_paper_overlay()
	# 描邊要等相機 make_current（CameraRig 在自己的 _ready 才設）→ 延幀
	_attach_outline_deferred()
	print("SHRINE_STREET ready")

func _attach_outline_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_attach_outline_to_camera()
```

注意：移植來的建街函式簽名是 `_build_xxx(root: Node3D)`；這裡傳 `self` 當 root（原本傳的是動態建立的 `root`，效果相同）。`_build_paper_overlay()` 無參數（建 CanvasLayer 加到 `self`）——確認移植版內是 `add_child(layer)`，若原文是 `add_child` 即 OK。

- [ ] **Step 7: headless parse 檢查**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --check-only --script res://src/screens/MapScreen/environments/ShrineStreet.gd 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error|error" | head`
Expected: 無輸出（parse 乾淨）

- [ ] **Step 8: Commit**

```bash
git add MONK/src/screens/MapScreen/environments/ShrineStreet.gd
git commit -m "feat(shrine-street): ShrineStreet 環境builder（shader 抽檔版＋地面碰撞＋描邊掛載）"
```

---

### Task 3: 環境靜態截圖驗證（固定相機，無玩家）

**Files:**
- Create: `test/CaptureShrineStreet.gd`
- Create: `test/CaptureShrineStreet.tscn`

- [ ] **Step 1: 建 `CaptureShrineStreet.gd`**

```gdscript
extends Node
## 環境截圖驗證（自帶固定相機，先不放玩家）。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureShrineStreet.tscn -- smoke
const SHRINE := preload("res://src/screens/MapScreen/environments/ShrineStreet.gd")

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	var shrine := SHRINE.new()
	root.add_child(shrine)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	root.add_child(cam)
	cam.position = Vector3(0.0, 4.2, 6.0)
	cam.look_at(Vector3(0, 1.6, -16.0), Vector3.UP)
	print("CAP_SHRINE ready")
	if OS.get_cmdline_user_args().has("smoke"):
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_shot.png")
		print("CAP_SHRINE_SAVED _shrine_shot.png ", img.get_width(), "x", img.get_height())
		get_tree().quit()
```

- [ ] **Step 2: 建 `CaptureShrineStreet.tscn`**

一個 Node 根、掛 `CaptureShrineStreet.gd`。可手寫 `.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/CaptureShrineStreet.gd" id="1"]
[node name="CaptureShrineStreet" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: headless 先過 parse/邏輯**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/CaptureShrineStreet.tscn -- smoke 2>&1 | grep -aiE "CAP_SHRINE|SHRINE_STREET|SCRIPT ERROR|Parse Error" | head`
Expected: `SHRINE_STREET ready` 與 `CAP_SHRINE ready`（無 parse error）

- [ ] **Step 4: windowed 截圖**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureShrineStreet.tscn -- smoke 2>&1 | grep -aiE "CAP_SHRINE_SAVED|SHADER ERROR" | head`
Expected: `CAP_SHRINE_SAVED _shrine_shot.png 1280x720`，無 SHADER ERROR

- [ ] **Step 5: 自檢圖**

`Read` `MONK/_shrine_shot.png`。確認與 look-dev `_okami3d_shot.png` 等價：屋頂店家、店面暖光＋木格、掛看板、石燈籠、朱紅鳥居、石板地、遠景杉林、描邊乾淨無雜訊、和紙顆粒。若有缺項回 Task 2 對應函式查。

- [ ] **Step 6: Commit**

```bash
git add MONK/test/CaptureShrineStreet.gd MONK/test/CaptureShrineStreet.tscn
git commit -m "test(shrine-street): 環境靜態截圖驗證（固定相機）"
```

---

### Task 4: `ShrineStreet.tscn` ＝ 環境＋玩家＋跟隨相機（玩家上墨）

**Files:**
- Create: `src/screens/MapScreen/environments/ShrineStreet.tscn`
- Modify: `src/screens/MapScreen/environments/ShrineStreet.gd`（`_ready` 末尾呼叫 `_apply_ink` 到玩家）
- Reference（讀，確認節點名/group/spawn）：`src/screens/MapScreen/Player.tscn`、`src/screens/MapScreen/CameraRig.gd`、`src/screens/MapScreen/PlayerController.gd`

- [ ] **Step 1: 確認既有 Player/CameraRig 介面**

讀 `Player.tscn`（確認根節點型別、是否在 group `player`、GLB 子節點路徑）、`CameraRig.gd`（確認它如何抓 target：記憶記載 fallback `get_tree().get_first_node_in_group("player")`、每幀補抓）、`PlayerController.gd`（方向鍵 `ui_*`）。記下 Player 根節點名與初始位置設定方式。

- [ ] **Step 2: 建 `ShrineStreet.tscn`**

根節點 `ShrineStreet`（掛 `ShrineStreet.gd`）＋ instance `Player.tscn` ＋ instance/節點 `CameraRig`。手寫 `.tscn`（依 Step 1 確認的實際路徑與根名調整 `ext_resource` 與 node 名）：

```
[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://src/screens/MapScreen/environments/ShrineStreet.gd" id="1"]
[ext_resource type="PackedScene" path="res://src/screens/MapScreen/Player.tscn" id="2"]
[ext_resource type="Script" path="res://src/screens/MapScreen/CameraRig.gd" id="3"]
[node name="ShrineStreet" type="Node3D"]
script = ExtResource("1")
[node name="Player" parent="." instance=ExtResource("2")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 6)
[node name="CameraRig" type="Node3D" parent="."]
script = ExtResource("3")
```

註：若 `CameraRig` 是場景（`.tscn`）而非純腳本，改用 `PackedScene` instance；若它需要 `target_path` export，依記憶該 export 載入後會掉值、靠 group fallback，故可不設。Player 起點 z=6（街頭，沿 −Z 走進去）。

- [ ] **Step 3: `_ready` 末尾對玩家上墨**

在 `ShrineStreet.gd` 的 `_attach_outline_deferred()`（已延 2 幀）裡，掛描邊後再對玩家上墨：

```gdscript
func _attach_outline_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_attach_outline_to_camera()
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_apply_ink(player)
		print("SHRINE_INK_PLAYER ok")
```

- [ ] **Step 4: 靜態截圖驗證（用場景自己的相機）**

新增暫時的截圖手段：用 `test/CaptureShrineStreet.gd` 不行（它自帶相機）。改寫一個小驗證：建 `test/CaptureShrineScene.gd`（load `ShrineStreet.tscn` 當子場景、等 ~40 幀讓 CameraRig 接管、存 `_shrine_scene_shot.png`、印 `CAP_SCENE_SAVED`）。

```gdscript
extends Node
const SCENE := preload("res://src/screens/MapScreen/environments/ShrineStreet.tscn")
func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if OS.get_cmdline_user_args().has("smoke"):
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_scene_shot.png")
		print("CAP_SCENE_SAVED _shrine_scene_shot.png ", img.get_width(), "x", img.get_height())
		get_tree().quit()
```

配 `test/CaptureShrineScene.tscn`（Node 根掛此腳本，格式同 Task 3 Step 2）。

- [ ] **Step 5: headless 過 parse → windowed 截圖 → 自檢**

Headless：`...console.exe --headless --path D:/monk/MONK res://test/CaptureShrineScene.tscn -- smoke 2>&1 | grep -aiE "SHRINE_STREET|SHRINE_INK_PLAYER|SCRIPT ERROR|Parse Error"`
Expected: `SHRINE_STREET ready` ＋ `SHRINE_INK_PLAYER ok`
Windowed：同上去掉 `--headless`，grep `CAP_SCENE_SAVED|SHADER ERROR`。
`Read` `MONK/_shrine_scene_shot.png`：確認 3D 無戒站在街上、套了水墨 toon（非原 PBR）、被描邊圈到、相機第三人稱框住、風格與環境一致。

- [ ] **Step 6: Commit**

```bash
git add MONK/src/screens/MapScreen/environments/ShrineStreet.tscn MONK/src/screens/MapScreen/environments/ShrineStreet.gd MONK/test/CaptureShrineScene.gd MONK/test/CaptureShrineScene.tscn
git commit -m "feat(shrine-street): ShrineStreet.tscn 接玩家＋跟隨相機＋玩家上墨"
```

---

### Task 5: 走動驗證（模擬方向鍵連拍）

**Files:**
- Create: `test/CaptureShrineWalk.gd`
- Create: `test/CaptureShrineWalk.tscn`

- [ ] **Step 1: 建走動連拍腳本**

```gdscript
extends Node
## 模擬按住 ui_up 數秒，沿途連拍 3 張驗證走動＋相機跟隨＋描邊持續正確。
const SCENE := preload("res://src/screens/MapScreen/environments/ShrineStreet.tscn")
func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 20:
		await get_tree().process_frame
	Input.action_press("ui_up")
	for shot in 3:
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_walk_%d.png" % shot)
		print("CAP_WALK_SAVED _shrine_walk_%d.png" % shot)
	Input.action_release("ui_up")
	get_tree().quit()
```

配 `test/CaptureShrineWalk.tscn`（Node 根掛此腳本）。

- [ ] **Step 2: 跑 windowed 連拍**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureShrineWalk.tscn -- smoke 2>&1 | grep -aiE "CAP_WALK_SAVED|SCRIPT ERROR|SHADER ERROR" | head`
Expected: 三行 `CAP_WALK_SAVED _shrine_walk_0/1/2.png`

- [ ] **Step 3: 自檢三張圖**

`Read` `_shrine_walk_0/1/2.png`。確認：無戒沿街往 −Z 前進（位置有變）、相機跟著移動、描邊每張都正確（不脫鉤、不滿屏雜訊）、走路動畫有播（姿勢有變）。若描邊在移動後脫鉤＝描邊 quad 沒跟到相機，回 Task 2 Step 4 檢查（quad 是否真的 add 到 `get_viewport().get_camera_3d()`）。

- [ ] **Step 4: Commit**

```bash
git add MONK/test/CaptureShrineWalk.gd MONK/test/CaptureShrineWalk.tscn
git commit -m "test(shrine-street): 走動＋相機跟隨連拍驗證"
```

---

### Task 6: 清掉 look-dev、收尾

**Files:**
- Delete: `test/OkamiShaderTest.gd`、`test/OkamiShaderTest.tscn`、`test/OkamiShaderTest.gd.uid`（若有）
- Delete: `MONK/_okami3d_shot.png`（look-dev 輸出，已被 `_shrine_*` 取代）

- [ ] **Step 1: 確認 ShrineStreet 全綠後刪 look-dev**

確認 Task 3/4/5 三組截圖都自檢通過，才刪。

```bash
rm -f MONK/test/OkamiShaderTest.gd MONK/test/OkamiShaderTest.tscn MONK/test/OkamiShaderTest.gd.uid MONK/_okami3d_shot.png
```

- [ ] **Step 2: 確認沒有殘留引用**

Run: `grep -rn "OkamiShaderTest" MONK --include=*.gd --include=*.tscn` → Expected: 無輸出。

- [ ] **Step 3: Commit**

```bash
git add -A MONK/test MONK
git commit -m "chore(shrine-street): 移除被取代的 OkamiShaderTest look-dev"
```

---

## 完工驗收（對齊 spec Acceptance Criteria）
1. ✅ 4 個 `.gdshader` 存在、`ShrineStreet.gd` 用 preload 載、無內嵌 shader 字串。（Task 1–2）
2. ✅ 環境截圖與 look-dev 等價。（Task 3）
3. ✅ 玩家套水墨 toon、被描邊圈到、與環境一致。（Task 4）
4. ✅ 走動連拍：玩家移動、相機跟隨、描邊持續正確。（Task 5）
5. ✅ headless 無 parse error；各驗證腳本印 `_SAVED`。（全程）
```
