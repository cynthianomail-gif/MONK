# 3D 探索 NPC（Phase 1：6 可見 NPC）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans（或 subagent-driven-development）task-by-task。步驟用 `- [ ]`。

**Goal:** 在 3D 探索世界 6 個地點各放一個可見、套水墨、會輕微呼吸的 3D NPC（走近＝現有 LocationTrigger 流程不變）。

**Architecture:** 新 `NpcFigure`(Node3D) 載 Meshy GLB→修材質→程式搖擺；`LocationTrigger` 見 `map_locations` 的 `npc_model` 欄就掛一個 NpcFigure。NPC GLB 由 Meshy image-to-3d ←現有 okami 正面立繪生（先 1 隻驗、再批量）。保留 Meshy 貼圖（靠場景描邊給墨邊），不套平塗 toon。

**Tech Stack:** Godot 4.5（Node3D、GLTF、ShaderMaterial）、Meshy MCP（image-to-3d）、Python/PIL（裁圖源）。

**驗證慣例：** 跑法 `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK <scene>`；parse error 先 `--headless` 抓；windowed 才看得到 shader/描邊；新素材先 `--import`；grep 同時看 `TEST FAIL` 與 `SCRIPT ERROR`。**Meshy 任何生成前先報價＋等使用者確認（Meshy 規則）。**

---

### Task 1: `NpcFigure` 元件 + 缺檔優雅略過

**Files:**
- Create: `src/screens/MapScreen/npc_figure.gd`
- Create: `test/TestNpcFigure.gd` / `.tscn`

- [ ] **Step 1: 建 `npc_figure.gd`**

```gdscript
extends Node3D
## 探索世界站立 NPC：載 Meshy GLB → 修透明材質+消光 → 程式呼吸搖擺(免綁骨)。
## 保留 Meshy 貼圖(源自 okami 立繪、本身水墨味)，靠場景螢幕空間描邊給墨邊。
## ponytail: 不套 ink_toon 平塗(會把 6 NPC 變同色灰、認不出)；要與主角平塗一致再改 _matte→toon。

const NPC_DIR := "res://assets/3d/characters/npcs/"

var _t := 0.0
var _model: Node3D = null

## model_name = GLB 檔名(無副檔)，如 "liaochen"；缺檔則優雅略過(待 Meshy 生成)。
func setup(model_name: String) -> void:
	var path := NPC_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("NpcFigure: 模型不存在 %s(先略過)" % path)
		return
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	_fix_materials(_model)

## 修 Meshy base-color alpha→整模型透明 雷；消光成 matte ink。保留貼圖(albedo_texture)。
func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in n:
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var b := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				b.albedo_color.a = 1.0
				b.roughness = 1.0
				b.metallic = 0.0
				b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, b)
	for c in node.get_children():
		_fix_materials(c)

func _process(delta: float) -> void:
	if _model == null:
		return
	_t += delta
	_model.rotation.z = sin(_t * 1.2) * 0.012
	_model.position.y = sin(_t * 1.6) * 0.02
```

- [ ] **Step 2: 建 `test/TestNpcFigure.gd`**

```gdscript
extends Node
## NpcFigure：缺檔優雅略過(不 crash、_model null)、元件可實例化。
func _ready() -> void:
	var NF := load("res://src/screens/MapScreen/npc_figure.gd")
	if NF == null: return _fail("npc_figure.gd 載入失敗")
	var fig: Node3D = NF.new()
	add_child(fig)
	fig.setup("definitely_missing_model")
	await get_tree().process_frame
	if fig.get("_model") != null: return _fail("缺檔應略過、_model 應為 null")
	print("TEST PASS: NpcFigure 缺檔優雅略過")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
```

- [ ] **Step 3: 建 `test/TestNpcFigure.tscn`**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestNpcFigure.gd" id="1"]
[node name="TestNpcFigure" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: 跑**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestNpcFigure.tscn 2>&1 | grep -aiE "TEST PASS|TEST FAIL|SCRIPT ERROR"`
Expected: `TEST PASS: NpcFigure 缺檔優雅略過`，無 SCRIPT ERROR。

- [ ] **Step 5: Commit**（待使用者指示再 commit；先做完驗證）

---

### Task 2: `LocationTrigger` 掛 NpcFigure + `map_locations` 加 `npc_model`

**Files:**
- Modify: `src/screens/MapScreen/LocationTrigger.gd`
- Modify: `data/map_locations.json`（6 地點加 `npc_model`）

- [ ] **Step 1: `LocationTrigger.gd` 的 `setup` 末尾掛 NpcFigure**

在 `setup(id, data)` 既有內容（設 position/shape/NameLabel）之後加：

```gdscript
	if data.has("npc_model") and String(data.get("npc_model", "")) != "":
		var NF := load("res://src/screens/MapScreen/npc_figure.gd")
		var fig: Node3D = NF.new()
		fig.name = "NpcFigure"
		add_child(fig)
		fig.setup(String(data.npc_model))
		fig.rotation.y = float(data.get("npc_facing_deg", 180.0)) * 0.0174533  # 預設面向 -Z(街心/玩家來向)，可per-loc調
```

（NpcFigure 是觸發球 Area3D 的子節點＝站在觸發點中心；Meshy 正面預設 +Z，預設轉 180° 面向玩家來向。）

- [ ] **Step 2: `map_locations.json` 6 地點加 `npc_model`**

各地點物件加一欄（值＝Task 4/5 產的 GLB 檔名）：
- `old_temple` 加 `"npc_model": "liaochen"`
- `wannian_mall` 加 `"npc_model": "zheng_ma"`
- `ximen_mrt` 加 `"npc_model": "ah_ming"`
- `zen_bbq` 加 `"npc_model": "ah_zhong"`
- `zuijin_club` 加 `"npc_model": "cherry"`
- `armory_worker` 加 `"npc_model": "tie_shu"`

（例：`"old_temple": { …現有… , "npc_model": "liaochen" }`）

- [ ] **Step 3: JSON 健檢 + headless 回歸（GLB 尚未生 → NpcFigure 優雅略過、觸發點照常）**

Run: `python -c "import json; json.load(open('data/map_locations.json',encoding='utf-8')); print('OK')"`
Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestMapScreen3D.tscn 2>&1 | grep -aiE "TEST PASS|TEST FAIL|SCRIPT ERROR"`
Expected: JSON OK；`TEST PASS: MapScreen 3D 接線 OK`（觸發點數仍 5/1，NpcFigure 因 GLB 缺而略過、不影響）。

- [ ] **Step 4: Commit**（待指示）

---

### Task 3: 佔位 GLB 視覺驗證（花 Meshy 前先證明整合會渲染）

**Files:** 暫時操作，無永久新檔。

- [ ] **Step 1: 放一個現有 GLB 當佔位**

Run: `cp MONK/assets/3d/characters/wujie/wujie_walk.glb MONK/assets/3d/characters/npcs/liaochen.glb`（先建 `npcs/` 目錄：`mkdir -p MONK/assets/3d/characters/npcs`）
（用主角模型暫充了塵，只為驗證「LocationTrigger 掛 NpcFigure→站在神社→修材質→搖擺」這條整合鏈。）

- [ ] **Step 2: import + windowed 截圖**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error"`（無輸出）
Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureMapScreen3D.tscn -- smoke 2>&1 | grep -aiE "CAP_MAP3D_SAVED|SHADER ERROR"`
Read `MONK/_mapscreen3d_shot.png`：確認**有一個 3D 人形站在神社街某觸發點**、套到場景描邊、會在原地（截圖看不出搖擺但不該 crash）。

- [ ] **Step 3: 移除佔位**

Run: `rm MONK/assets/3d/characters/npcs/liaochen.glb`
（整合鏈已證明可渲染；接下來換真 Meshy 模型。）

---

### Task 4: Meshy 生第 1 隻 NPC（報價→確認→驗品質）

**Files:**
- Create: `assets/3d/characters/npcs/tie_shu.glb`（+貼圖）
- 來源：`assets/art_direction/new_ink_shrine_style/characters/game_ready/tie_shu_locked_front_ares_red_game_ready.png`（⚠ 若只有 bust、無全身→改用其他已確認有全身的角色當第 1 隻，如 `liaochen_front_game_ready.png`）

- [ ] **Step 1: 確認來源全身圖存在**

Run: `python -c "from PIL import Image; print(Image.open('MONK/assets/art_direction/new_ink_shrine_style/characters/game_ready/tie_shu_locked_front_ares_red_game_ready.png').size)"`
Expected: 印出尺寸(全身比例，高>寬明顯)。若檔不存在→第 1 隻改用 `liaochen_front_game_ready.png`。

- [ ] **Step 2: 報價並等使用者確認**

`meshy_check_balance` 已知 657。image-to-3d 約 15-30cr/隻。**向使用者報「生 1 隻 ~X credits」並等同意**後才呼叫。

- [ ] **Step 3: Meshy image-to-3d**

呼叫 `meshy_image_to_3d`：`image_url/輸入`＝該全身立繪、`target_formats:["glb"]`、紋理開、`should_remesh` 預設、**不 rig**（靜態）。`meshy_get_task_status` 輪詢到完成 → `meshy_download_model`(glb) 存 `assets/3d/characters/npcs/tie_shu.glb`（或 liaochen.glb）。

- [ ] **Step 4: 單體截圖驗品質**

`--import` 後，沿用 `test/CapturePropSolo`（吃 `-- res://assets/3d/characters/npcs/<name>.glb`）中性背景 3/4 近拍 → Read 圖：確認**比例像人、朝向、材質非全透明、水墨立繪轉 3D 可接受**。不行→調 image-to-3d 參數或換來源圖重生（再報價）。

- [ ] **Step 5: 擺進神社街看實機（用 Task 2 的 npc_model 對應該角色）**

windowed 跑 `CaptureMapScreen3D -- smoke` → Read `_mapscreen3d_shot.png`：NPC 站神社街、套場景描邊、消光、搖擺不 crash。**此時決定材質方向**：保留貼圖夠好 → 維持；若太突兀/想跟主角平塗一致 → 在 NpcFigure 改套 ink_toon（記於 spec 的可調點）。

- [ ] **Step 6: Commit**（待指示）

---

### Task 5: Meshy 批量生其餘 5 隻

**Files:** Create `assets/3d/characters/npcs/{liaochen,zheng_ma,ah_ming,ah_zhong,cherry}.glb`（扣掉第 1 隻已生的）

- [ ] **Step 1: 報價並等確認**

5 隻 × ~15-30cr ≈ 75-150cr。**報總價、等使用者同意**。

- [ ] **Step 2: 逐隻 image-to-3d + download**

來源立繪→GLB 檔名對應（spec 表）：
- `liaochen_front_game_ready.png` → `liaochen.glb`
- `zheng_ma_front_ares_red_game_ready.png` → `zheng_ma.glb`
- `ah_ming_front_ares_red_game_ready.png` → `ah_ming.glb`
- `ah_zhong_front_ares_red_game_ready.png` → `ah_zhong.glb`
- `cherry_geisha_front_game_ready.png` → `cherry.glb`
（同 Task 4 流程：image-to-3d glb 靜態→get_task_status→download 到 `npcs/`。）

- [ ] **Step 3: 各單體截圖快驗**（CapturePropSolo 逐一），明顯壞的重生（報價）。

- [ ] **Step 4: Commit**（待指示）

---

### Task 6: 全 6 隻接線 + 總驗 + 同步

**Files:**
- Modify: `MONK/PROJECT_STATUS.md`、記憶 `project-3d-environment`/`MEMORY.md`

- [ ] **Step 1: `--import` 全收**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error"`（無輸出）

- [ ] **Step 2: headless 回歸**

Run（逐一）：`TestNpcFigure`／`TestMapScreen3D`／`TestMainQuest`／`TestDemoScope`
Expected: 全 PASS、無 SCRIPT ERROR。

- [ ] **Step 3: windowed 全景截圖**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/CaptureMapScreen3D.tscn -- smoke 2>&1 | grep -aiE "CAP_MAP3D_SAVED|SHADER ERROR"`
Read `_mapscreen3d_shot.png`：神社街看到 NPC（如街尾了塵/店口鄭媽）站著、水墨、搖擺。（軍火庫鐵叔另截：需 current_area=armory，可加一個 capture 變體或手動驗。）

- [ ] **Step 4: 更新 PROJECT_STATUS + 記憶**

`project-3d-environment` 加「探索世界已放 6 可見 3D NPC(NpcFigure+image-to-3d，保貼圖+場景描邊+程式搖擺)」；`PROJECT_STATUS` 探索段同步；`MEMORY.md` hook 一行。

- [ ] **Step 5: Commit**（待指示）

---

## 完工驗收
1. ✅ 6 地點各站一個可見 3D NPC、走近觸發＝原流程不變。（Task 2,4,5,6）
2. ✅ NPC 套水墨（保貼圖+場景描邊）、輕微呼吸搖擺。（Task 1,4）
3. ✅ GLB 缺檔時優雅略過、不破遊戲。（Task 1,2）
4. ✅ headless 回歸 PASS、windowed 截圖自檢過、Meshy 每次生成有報價確認。（Task 3-6）

## YAGNI / 範圍外（Phase 2 另計）
- 主角無戒重做（待 Codex okami T-pose 正背圖 → multi-image→rig→重接 AnimTree）。
- NPC 綁骨/走動；VN 對話框改 3D；全 12 NPC；一地多 NPC；阿瑞斯放探索。
