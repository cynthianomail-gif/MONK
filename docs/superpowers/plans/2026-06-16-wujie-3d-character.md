# 無戒 3D 角色 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把地圖玩家從膠囊佔位換成正牌 3D 苦行無戒（待機＋走路），接上現有 `PlayerController`，站進西門街。

---

## ✅ 完成記錄（2026-06-16）

全部 Phase 完成並驗證（headless `TestPlayer3D` PASS ＋ 視窗截圖：idle 正/背、walk solo＋實機跟隨）。實作與計畫的差異（皆為改進）：

1. **多了 remesh 一步：** `multi_image_to_3d` 出來 405k 面，超過 rig 上限 300k → 先 `meshy_remesh` 到 30k 三角面再綁骨（+5cr）。
2. **idle 改用程式生成（不花 meshy_animate 3cr）：** rig 只附 walk/run、無 idle，且 Meshy 無 MCP 可列 action_id。改在 `PlayerAnimTree._make_idle` 用 `Animation` rotation track 把 `LeftArm`/`RightArm` 各繞 **local RIGHT 軸 +90°** → 雙臂自然垂於體側（`IdleSignTest` 實測 down90 最自然；BACK 軸是錯的，會往上甩）。
3. **檔名：** 模型存成 `assets/3d/characters/wujie/wujie_walk.glb`（非計畫的 `wujie_ascetic.glb`），`Player.tscn` 已對應。
4. **`PlayerAnimTree` 強化：** _ready 先 `await process_frame`（同幀解析不到 GLB 子樹）；`model_path` export 失效時 fallback 抓 `get_parent()`；加 `_make_opaque()` 修 Meshy 透明材質 bug（玩家也會中，跟道具同雷）。
5. **修了計畫沒預期的 CameraRig bug：** `MapScreen.tscn` 的 `target_path=NodePath("../Player")` 在 SceneRouter 載入時會掉值（resolved=null），相機卡原點不跟隨、玩家被框到畫面外。改 `CameraRig._acquire_target()` 以 **`"player"` group** 為備援、每幀補抓。舊膠囊剛好在原點附近才沒爆出來。
6. **預設背對相機：** `PlayerController._ready` 設 `model.rotation.y = PI`（第三人稱慣例；移動時 atan2 接管朝向）。

剩餘可選 polish（非阻擋）：walk clip 帶 root motion，實機快走時身體可能每步微衝（目前肉眼尚可接受）；要鎖腳再設 `root_motion_track` 或剝掉 hip 位移。

下方 checkbox 為原計畫追蹤，內容已依上述差異實作。

---

**Architecture:** 先用非 Meshy 服務生全身正/背 T-pose 參考圖（人工關卡）→ Meshy `multi_image_to_3d`→`rig`→`animate(idle)` 出綁骨動畫 GLB → Godot 用 `Player.tscn`＋自動建混合樹的 `PlayerAnimTree.gd` 接上 PlayerController，換掉 MapScreen 的膠囊。

**Tech Stack:** Godot 4.5 / GDScript；Meshy MCP（image-to-3d/rig/animate）；higgsfield 或 magnific 影像生成（參考圖）。

**設計來源：** `docs/superpowers/specs/2026-06-16-wujie-3d-character-design.md`

---

## 前置說明

- **Godot：** `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`，專案 `D:/monk/MONK`。
- **版控：** 專案不在 git 下；commit 步驟為選用 checkpoint。
- **兩道關卡（鐵則）：**
  1. **人工關卡**：Phase 1 參考圖生完，**先給使用者看、點頭才進 Phase 2**（才開始花 Meshy）。
  2. **成本關卡**：每個 Meshy 付費呼叫前，依 Meshy 規則報成本、等確認（本計畫已預估，執行時再覆述）。
- **定版一致性來源：** `assets/2d/portraits/wujie/_LOCKED_base_reference.jpg`（光頭、灰綠袍＋白內襟、半寫實厚塗）。
- 測試＝Godot headless 場景檢查（印 PASS/`push_error`＋quit 碼）＋視窗截圖；新資源跑前先 `--import --headless`。

---

## 檔案結構

新增：
- `assets/2d/portraits/wujie/3d_ref/front.png`、`back.png` — 全身 T-pose 參考圖
- `assets/3d/characters/wujie/wujie_ascetic.glb`(+貼圖) — 綁骨＋動畫模型
- `src/screens/MapScreen/PlayerAnimTree.gd` — 掛在 AnimationTree 上，_ready 從 GLB 自動建 idle↔walk 混合樹
- `src/screens/MapScreen/Player.tscn` — 可重用玩家（PlayerController＋碰撞＋MeshRoot[GLB]＋AnimationTree）
- `test/TestPlayer3D.gd`／`.tscn` — headless 驗證
- `test/CapturePlayer.gd`／`.tscn` — 視窗截圖

修改：
- `src/screens/MapScreen/MapScreen.tscn` — inline Player 子樹換成 instance `Player.tscn`

不動：`PlayerController.gd`（已相容：讀 `$MeshRoot`＋選用 `$AnimationTree` 的 `parameters/blend/blend_amount`）。

---

## Phase 1 — 全身 T-pose 參考圖（非 Meshy）

### Task 1: 生正面＋背面 T-pose 苦行無戒，使用者把關

**Files:**
- Create: `assets/2d/portraits/wujie/3d_ref/front.png`, `back.png`

- [ ] **Step 1: 載入影像生成工具**

Run（ToolSearch）：`select:mcp__57288706-76d4-4e47-afdb-e3d38bf99f72__generate_image`（higgsfield）或 `select:mcp__464e2494-0830-44dd-9fc6-94355317269b__images_generate`（magnific）。把 `_LOCKED_base_reference.jpg` 經各服務的上傳/匯入流程設為角色參考（higgsfield：`media_upload_widget`/`media_import_url`；magnific：library/references）。

- [ ] **Step 2: 生正面全身 T-pose**

Prompt 要點（沿用定版畫風）：
```
Full-body T-pose character reference of the SAME monk as the reference image:
shaved head, olive-grey Buddhist robe with white inner collar, semi-realistic
painted style. Standing straight, FRONT view, arms extended horizontally (T-pose),
legs slightly apart, bare feet visible, neutral expression. Plain flat light-grey
background, even lighting, full body head-to-feet in frame, no crop, no props.
```
參數：直幅（如 9:16 或 3:4）、單人、全身入框。存正面結果。

- [ ] **Step 3: 生背面全身 T-pose（與正面一致）**

同上，改 `BACK view (facing away), same robe and proportions`，其餘相同。存背面結果。

- [ ] **Step 4: 自我檢視**

Read 兩張圖，確認：①是同一個無戒（臉/光頭/灰綠袍＋白內襟）②全身、含腳③T-pose 手臂外展④乾淨背景。不符就改 prompt 重生（這步不花 Meshy，多生幾張挑）。

- [ ] **Step 5: 存到 3d_ref/ 並請使用者過目（人工關卡）**

把選定的正/背圖存成 `assets/2d/portraits/wujie/3d_ref/front.png`、`back.png`。**把兩張貼給使用者看、明確等「OK 送 Meshy」再進 Phase 2。**

- [ ] **Step 6 (選用): Commit**

```bash
git add assets/2d/portraits/wujie/3d_ref/front.png assets/2d/portraits/wujie/3d_ref/back.png
git commit -m "feat(char): wujie full-body T-pose 3D reference (front/back)"
```

---

## Phase 2 — Meshy 3D（花 credit，每步先報成本確認）

### Task 2: multi_image_to_3d → 綁骨 → 待機動畫 → 下載 GLB

**Files:**
- Create: `assets/3d/characters/wujie/wujie_ascetic.glb`(+貼圖)

- [ ] **Step 1: 報成本並確認**

覆述報價：`multi_image_to_3d`(meshy-6) ~20–30 ＋ `rig` 5 ＋ `animate` 3 ＝ ~28–38 cr（Meshy 餘額先 `meshy_check_balance` 確認 >38）。等使用者「可」。

- [ ] **Step 2: multi_image_to_3d（t-pose、PBR）**

```
mcp__meshy__meshy_multi_image_to_3d(
  file_paths=["D:/monk/MONK/assets/2d/portraits/wujie/3d_ref/front.png",
              "D:/monk/MONK/assets/2d/portraits/wujie/3d_ref/back.png"],
  ai_model="meshy-6", pose_mode="t-pose", topology="triangle",
  target_polycount=25000, enable_pbr=true, should_texture=true,
  target_formats=["glb"], response_format="json")
```
然後 `mcp__meshy__meshy_get_task_status(task_id, task_type="multi-image-to-3d", wait=true)` 等完成，記下 `model task_id`。

- [ ] **Step 3: 綁骨 rig**

載入 schema：ToolSearch `select:mcp__meshy__meshy_rig`。以 Step 2 的 model task_id 為輸入綁骨（t-pose 綁骨品質最好）。`meshy_get_task_status(rig_task_id, task_type="rigging", wait=true)`。記下 rig 輸出的動畫 clip（rig 含 walk/run）。

- [ ] **Step 4: 待機動畫 animate**

載入 schema：ToolSearch `select:mcp__meshy__meshy_animate,mcp__meshy__animation_actions`。用 `animation_actions` 找「idle/breathing/stand」類 clip id，對 rig 後模型 `meshy_animate`（idle）。`meshy_get_task_status(anim_task_id, task_type="animation", wait=true)`。

- [ ] **Step 5: 下載 GLB（含動畫＋貼圖）**

```
mcp__meshy__meshy_download_model(task_id=<最終含動畫的 task>, task_type=<對應>,
  format="glb", include_textures=true,
  save_to="D:/monk/MONK/assets/3d/characters/wujie/wujie_ascetic.glb")
```
若 rig 與 animate 是**兩個分開的 GLB**（walk 在 rig 檔、idle 在 animate 檔），兩個都下載：`wujie_ascetic.glb`（rig，含 walk/run＋骨架網格）＋ `wujie_idle.glb`（animate，含 idle）。Phase 3 會把 idle clip 併進主模型。

- [ ] **Step 6 (選用): Commit**

```bash
git add assets/3d/characters/wujie/
git commit -m "feat(char): wujie rigged+animated 3D model (Meshy)"
```

---

## Phase 3 — Godot 整合（純 code）

### Task 3: 匯入並盤點 GLB（AABB＋骨架＋動畫 clip 名）

**Files:**
- Create: `test/InspectGlb.gd`, `test/InspectGlb.tscn`

- [ ] **Step 1: 寫盤點腳本**

`test/InspectGlb.tscn`：
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/InspectGlb.gd" id="1"]
[node name="InspectGlb" type="Node"]
script = ExtResource("1")
```
`test/InspectGlb.gd`：
```gdscript
extends Node
## 印出 GLB 的合併 AABB、是否有 Skeleton3D、AnimationPlayer 的 clip 名。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/InspectGlb.tscn -- <res 路徑>

func _ready() -> void:
	var path := "res://assets/3d/characters/wujie/wujie_ascetic.glb"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: path = ua[0]
	var inst := (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	var aabb := AABB()
	var first := true
	var has_skel := false
	var clips: Array = []
	for n in _walk(inst):
		if n is MeshInstance3D:
			var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			aabb = a if first else aabb.merge(a); first = false
		elif n is Skeleton3D:
			has_skel = true
		elif n is AnimationPlayer:
			clips = (n as AnimationPlayer).get_animation_list()
	print("GLB_AABB size=", aabb.size)
	print("GLB_HAS_SKELETON ", has_skel)
	print("GLB_CLIPS ", clips)
	get_tree().quit(0)

func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children(): out.append_array(_walk(c))
	return out
```

- [ ] **Step 2: 匯入＋盤點主模型**

Run: `Godot --headless --path D:/monk/MONK --import`
Run: `Godot --headless --path D:/monk/MONK res://test/InspectGlb.tscn`
Expected: 印出 `GLB_AABB size=(…)`、`GLB_HAS_SKELETON True`、`GLB_CLIPS [...]`。**記下身高(aabb.size.y)與 clip 名**（供 Task 4/5 用）。若有 `wujie_idle.glb` 也跑一次 `-- res://assets/3d/characters/wujie/wujie_idle.glb` 記下 idle clip 名。

- [ ] **Step 3: 確認骨架與走路 clip 存在**

若 `GLB_HAS_SKELETON` 為 False 或無 walk 類 clip → 回 Phase 2 檢查 rig（停下問使用者，別硬接）。

---

### Task 4: PlayerAnimTree.gd（自動建 idle↔walk 混合樹）

**Files:**
- Create: `src/screens/MapScreen/PlayerAnimTree.gd`

- [ ] **Step 1: 寫腳本**

```gdscript
extends AnimationTree
## 掛在 Player/AnimationTree 上：_ready 從模型的 AnimationPlayer 自動建
## idle↔walk 混合樹，暴露 parameters/blend/blend_amount 給 PlayerController。
## 若 idle 在另一支 GLB(idle_glb_path)，先把該 clip 併進模型 AnimationPlayer。

@export var model_path: NodePath          # 指向 MeshRoot 下的 GLB 實例
@export var idle_glb_path: String = ""     # 選填：idle 動畫在另一支 GLB 時填 res 路徑

const WALK_KEYS := ["walk", "walking", "move", "run", "running"]
const IDLE_KEYS := ["idle", "breath", "stand", "rest", "a_pose", "apose", "t_pose", "tpose"]

func _ready() -> void:
	var model := get_node_or_null(model_path)
	var ap := _find_ap(model)
	if ap == null:
		push_warning("PlayerAnimTree: 模型無 AnimationPlayer，動畫停用")
		return
	_merge_idle_if_needed(ap)
	var clips := ap.get_animation_list()
	var walk_name := _pick(clips, WALK_KEYS)
	var idle_name := _pick(clips, IDLE_KEYS)
	if walk_name == "":
		push_warning("PlayerAnimTree: 找不到走路動畫，clips=%s" % str(clips))
		return
	if idle_name == "":
		idle_name = walk_name  # 退路：無 idle 時先用 walk 佔位（站著會動，之後補）
	var bt := AnimationNodeBlendTree.new()
	var ni := AnimationNodeAnimation.new(); ni.animation = idle_name
	var nw := AnimationNodeAnimation.new(); nw.animation = walk_name
	var b := AnimationNodeBlend2.new()
	bt.add_node("idle", ni, Vector2(-260, 0))
	bt.add_node("walk", nw, Vector2(-260, 160))
	bt.add_node("blend", b, Vector2(0, 80))
	bt.connect_node("blend", 0, "idle")
	bt.connect_node("blend", 1, "walk")
	bt.connect_node("output", 0, "blend")
	anim_player = get_path_to(ap)
	tree_root = bt
	active = true

func _merge_idle_if_needed(ap: AnimationPlayer) -> void:
	if idle_glb_path == "" or not ResourceLoader.exists(idle_glb_path):
		return
	var idle_inst := (load(idle_glb_path) as PackedScene).instantiate()
	var idle_ap := _find_ap(idle_inst)
	if idle_ap == null:
		idle_inst.queue_free(); return
	for lib_name in idle_ap.get_animation_library_list():
		var lib: AnimationLibrary = idle_ap.get_animation_library(lib_name)
		var dst := "idle_src" if lib_name == "" else lib_name
		if not ap.has_animation_library(dst):
			ap.add_animation_library(dst, lib.duplicate(true))
	idle_inst.queue_free()

func _find_ap(n: Node) -> AnimationPlayer:
	if n == null: return null
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r: return r
	return null

func _pick(clips: Array, keys: Array) -> String:
	for k in keys:
		for c in clips:
			if String(c).to_lower().contains(k):
				return String(c)
	return ""
```

- [ ] **Step 2: 語法檢查**

Run: `Godot --headless --path D:/monk/MONK --quit`
Expected: 無 `SCRIPT ERROR`/`Parse Error`。

---

### Task 5: Player.tscn（可重用玩家）

**Files:**
- Create: `src/screens/MapScreen/Player.tscn`

- [ ] **Step 1: 建 Player.tscn**

依 Task 3 記下的身高把 `MeshRoot` 縮放到 ~1.8m（`scale = 1.8 / aabb.size.y`，下例先用 1.0，Step 2 校正）。GLB 實例節點命名 `Model`。

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/screens/MapScreen/PlayerController.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/3d/characters/wujie/wujie_ascetic.glb" id="2"]
[ext_resource type="Script" path="res://src/screens/MapScreen/PlayerAnimTree.gd" id="3"]

[sub_resource type="CapsuleShape3D" id="cap"]
radius = 0.4
height = 1.8

[node name="Player" type="CharacterBody3D" groups=["player"]]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("cap")

[node name="MeshRoot" type="Node3D" parent="."]

[node name="Model" parent="MeshRoot" instance=ExtResource("2")]

[node name="AnimationTree" type="AnimationTree" parent="." node_paths=PackedStringArray("model_path")]
script = ExtResource("3")
model_path = NodePath("../MeshRoot/Model")
```
（若 idle 是分開的 GLB，多加一行 `idle_glb_path = "res://assets/3d/characters/wujie/wujie_idle.glb"`。）

- [ ] **Step 2: 校正身高與朝向（用盤點數據）**

依 Task 3 的 `aabb.size.y` 設 `MeshRoot` 的 `transform`（縮放 `1.8/size.y`），確認腳底約在 y=0。若模型正面非 +Z（PlayerController 用 +Z 當前方），在 `Model` 加 `rotation`（如 Y 180）轉正。Run `--import` 後進 Task 6 截圖核對，再回來微調。

---

### Task 6: 換進 MapScreen＋驗證

**Files:**
- Modify: `src/screens/MapScreen/MapScreen.tscn`
- Create: `test/TestPlayer3D.gd`/`.tscn`, `test/CapturePlayer.gd`/`.tscn`

- [ ] **Step 1: MapScreen.tscn 換 Player**

把 `MapScreen.tscn` 內 inline 的 Player 子樹（`[node name="Player" ...]`＋其下 `CollisionShape3D`/`MeshRoot`/`BodyMesh`）整段刪除，改成實例化：在 ext_resource 區加
```
[ext_resource type="PackedScene" path="res://src/screens/MapScreen/Player.tscn" id="5"]
```
並在 `Environment` 節點之後插入
```
[node name="Player" parent="." instance=ExtResource("5")]
```
（`load_steps` 對應 +1；移除原 `player_shape/player_mat/player_mesh` 三個 sub_resource 與 BodyMesh，因已移進 Player.tscn。CameraRig 的 `target_path=NodePath("../Player")` 不變。）

- [ ] **Step 2: headless 驗證**

`test/TestPlayer3D.tscn`：
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestPlayer3D.gd" id="1"]
[node name="TestPlayer3D" type="Node"]
script = ExtResource("1")
```
`test/TestPlayer3D.gd`：
```gdscript
extends Node
## 驗證 Player.tscn：有 AnimationTree＋blend 參數＋tree_root，PlayerController 能驅動位移。
func _ready() -> void:
	await get_tree().process_frame
	var p := (load("res://src/screens/MapScreen/Player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	await get_tree().process_frame
	var at := p.get_node_or_null("AnimationTree") as AnimationTree
	if at == null: return _fail("無 AnimationTree")
	if at.tree_root == null: return _fail("AnimationTree.tree_root 未建（clip 偵測失敗？）")
	var v = at.get("parameters/blend/blend_amount")
	if v == null: return _fail("無 parameters/blend/blend_amount")
	# 模擬移動：直接設 velocity 跑一次 physics，確認會位移
	var before: Vector3 = p.global_position
	p.velocity = Vector3(3, 0, 0)
	p.call("move_and_slide")
	if p.global_position.distance_to(before) <= 0.0: return _fail("move_and_slide 未位移")
	print("TEST PASS: Player3D AnimationTree＋blend＋位移 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```
Run: `Godot --headless --path D:/monk/MONK res://test/TestPlayer3D.tscn`
Expected: `TEST PASS: Player3D AnimationTree＋blend＋位移 OK`。失敗依訊息回對應 Task。

- [ ] **Step 3: 視窗截圖核對**

`test/CapturePlayer.tscn`（同 CaptureMapArea 模式，root Node＋下列腳本）。`test/CapturePlayer.gd`：
```gdscript
extends Node
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = null
	for i in 600:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == "MapScreen": map = cs; break
	if map == null:
		push_error("CAP FAIL"); get_tree().quit(1); return
	for i in 150: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_player3d_ximen.png")
	print("PLAYER_CAP_DONE")
	get_tree().quit(0)
```
Run（非 headless）: `Godot --path D:/monk/MONK res://test/CapturePlayer.tscn`
Read `_player3d_ximen.png`：確認無戒（非膠囊）站西門街、比例正常、面向順、待機姿（非 T-pose 僵姿）。依結果回 Task 5 Step 2 微調縮放/朝向；若站成 T-pose＝idle 沒接上，回 Task 4 看 clip 偵測。

- [ ] **Step 4 (選用): Commit**

```bash
git add src/screens/MapScreen/Player.tscn src/screens/MapScreen/PlayerAnimTree.gd src/screens/MapScreen/MapScreen.tscn test/TestPlayer3D.* test/CapturePlayer.*
git commit -m "feat(char): 3D wujie player in MapScreen with idle/walk blend"
```

---

## Self-Review（撰寫後自查）

- **Spec 覆蓋：** 全身 T-pose 參考圖正/背＋人工關卡(Task1)、multi_image_to_3d＋rig＋animate＋下載(Task2)、AABB/骨架/clip 盤點(Task3)、AnimationTree idle↔walk 對上 `parameters/blend/blend_amount`(Task4)、Player.tscn 縮放/朝向/碰撞(Task5)、MapScreen 換 instance＋驗證＋截圖(Task6)。✅
- **無 placeholder：** clip 名以盤點(Task3)實際值帶入，PlayerAnimTree 用關鍵字自動偵測＝不寫死；idle 分檔的併入有具體碼。Meshy rig/animate 精確參數於執行時 ToolSearch 載 schema（已標明步驟）＝外部工具，非程式 placeholder。✅
- **型別/名稱一致：** `parameters/blend/blend_amount`（Blend2 名 `blend`）↔ PlayerController `_set_blend` 一致；節點名 `MeshRoot`/`Model`/`AnimationTree`、`model_path`/`idle_glb_path` 一致；GLB 路徑 `assets/3d/characters/wujie/wujie_ascetic.glb` 一致。✅
- **風險已內建處理：** 骨架/walk 缺→停下問(Task3.3)；idle 缺→退用 walk 佔位(Task4)；T-pose 僵姿/朝向/比例→截圖回修(Task6.3)。
- **依賴：** PlayerController 不改（既相容）；CameraRig target_path 不變。
