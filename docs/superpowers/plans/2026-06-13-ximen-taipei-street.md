# 西門商圈垂直切片 — 可走的卡通台北街景 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「西門商圈」做成一塊資料驅動、可自由走動、一看就是台北的卡通街區，並驗證「模組街道組裝 + 分區場景 + 區間移動 + 互動點」整套管線，全程用 placeholder 幾何體即可在 Godot 跑。

**Architecture:** 街道 = 資料（`data/streets/*.json` + `data/street_kit.json`），由 `StreetBuilder` 在執行期生成幾何與碰撞。每個分區是一個套用通用 `DistrictScreen.gd` 的場景；`SceneRouter.go_to_district()` 負責分區間切換並還原各區玩家位置。地標與零件之後由 Meshy `.glb` 替換 placeholder，零程式改動。

**Tech Stack:** Godot 4.5（Forward+）、GDScript、JSON 資料檔。沿用既有 autoloads（GameManager / SceneRouter / AudioManager / EventBus）與 `JsonLoader` 靜態工具、`LocationTrigger` 場景、`MapHUD`。

---

## 測試方式（重要前置說明）

本專案沒有單元測試框架，沿用既有 `test/TestStep1.tscn` 的「場景式煙霧測試」做法：一個掛在 root 的測試腳本，印出 `PASS/FAIL` 並 `get_tree().quit()`。

**每個「執行測試」步驟的做法（由執行者在 Godot 內操作）：**
1. 在 Godot 編輯器開啟 `test/TestStreetSlice.tscn`
2. 按 **F6**（執行當前場景）
3. 看 **Output** 面板：成功會印出該任務對應的 `... PASS`；失敗印出 `... FAIL: <原因>`

若環境有 Godot 執行檔，亦可用無頭模式：
`"<godot 執行檔>" --headless --path "D:/monk/MONK" res://test/TestStreetSlice.tscn`

每個任務在 `test/TestStreetSlice.gd` 內新增一個 `test_*()` 函式，並在 `_run()` 依序呼叫。先寫測試（此時會 FAIL 或解析錯誤）→ 實作 → 再跑（PASS）→ commit。

---

## 檔案結構

**新增**
- `data/street_kit.json` — 模組零件登記表（含 placeholder 尺寸/顏色/碰撞型別 + Meshy prompt）
- `data/streets/ximen.json` — 西門街道布局
- `data/streets/wanhua_old.json` — 萬華 stub 布局
- `data/streets/linsen.json` — 林森北 stub 布局
- `src/screens/MapScreen/StreetBuilder.gd` — 街道組裝器（`class_name StreetBuilder`）
- `src/screens/MapScreen/DistrictScreen.gd` — 通用分區控制器（由 `MapScreen.gd` 一般化而來）
- `src/screens/MapScreen/districts/XimenDistrict.tscn` — 西門場景
- `src/screens/MapScreen/districts/WanhuaDistrict.tscn` — 萬華 stub 場景
- `src/screens/MapScreen/districts/LinsenDistrict.tscn` — 林森北 stub 場景
- `test/TestStreetSlice.tscn` / `test/TestStreetSlice.gd` — 本切片煙霧測試

**修改**
- `src/autoloads/GameManager.gd` — 新增 `current_district` / `district_positions` 與輔助函式
- `src/autoloads/SceneRouter.gd` — 新增 `go_to_district()` + `DISTRICTS`，`go_to_map()` 改路由到目前分區
- `src/screens/MapScreen/MapHUD.gd` — 新增區間移動的選單標籤
- `src/screens/BattleScreen/BattleManager.gd:259-267` — 戰敗重生改用分區位置
- `data/meshy_prompts/environments.json` — 精修地標 prompt（與模組相容）

**刪除（遷移後）**
- `src/screens/MapScreen/MapScreen.gd`
- `src/screens/MapScreen/MapScreen.tscn`

> **Placeholder 美術備註：** 本專案目前**沒有**自製 Toon Shader 檔（`.gdshader` 僅 Dialogic 內建）。placeholder 一律用 `StandardMaterial3D` 平塗色塊（與現有 `MapScreen.tscn` 的 Floor/Player 一致）。Toon 風格等 Meshy `.glb` 進場時再套，不在本切片範圍。

---

## Task 1：街道零件表與西門布局資料

**Files:**
- Create: `data/street_kit.json`
- Create: `data/streets/ximen.json`
- Create: `data/streets/wanhua_old.json`
- Create: `data/streets/linsen.json`
- Create: `test/TestStreetSlice.gd`
- Create: `test/TestStreetSlice.tscn`

- [ ] **Step 1：建立零件表 `data/street_kit.json`**

每筆零件含：`category`、`size`（placeholder 方塊尺寸，公尺）、`color`（placeholder 色，hex）、`collision`（`box` 或 `none`）、`mesh`（先留空字串，未來填 `.glb` 路徑）、`meshy_prompt`（供使用者生成資產）。

```json
{
  "storefront_tall": {
    "category": "building", "size": {"x": 5.0, "y": 9.0, "z": 4.0},
    "color": "#2e3a55", "collision": "box", "mesh": "",
    "meshy_prompt": "narrow 4-story Taipei street building with arcade ground floor (qilou), stacked metal shop signs, window grilles, AC units, low poly cartoon stylized game asset, flat back"
  },
  "storefront_mid": {
    "category": "building", "size": {"x": 5.0, "y": 6.0, "z": 4.0},
    "color": "#3a3050", "collision": "box", "mesh": "",
    "meshy_prompt": "3-story old Taipei shophouse with tiled facade, roll-up metal door, hanging signboards, low poly cartoon stylized game asset, flat back"
  },
  "storefront_short": {
    "category": "building", "size": {"x": 5.0, "y": 4.5, "z": 4.0},
    "color": "#28354d", "collision": "box", "mesh": "",
    "meshy_prompt": "small 2-story Taipei storefront, betel nut stand vibe, neon edge, low poly cartoon stylized game asset, flat back"
  },
  "sign_stack": {
    "category": "sign", "size": {"x": 1.2, "y": 2.4, "z": 0.3},
    "color": "#e23b3b", "collision": "none", "mesh": "",
    "meshy_prompt": "vertical stacked Taiwanese shop signboards with Chinese characters, neon and painted metal, low poly cartoon game prop"
  },
  "sign_neon": {
    "category": "sign", "size": {"x": 2.2, "y": 0.8, "z": 0.2},
    "color": "#1aa3a3", "collision": "none", "mesh": "",
    "meshy_prompt": "horizontal glowing neon shop sign Chinese characters, low poly cartoon game prop"
  },
  "lantern": {
    "category": "prop", "size": {"x": 0.5, "y": 0.7, "z": 0.5},
    "color": "#d0202a", "collision": "none", "mesh": "",
    "meshy_prompt": "red paper lantern hanging, low poly cartoon game prop"
  },
  "motorcycle": {
    "category": "prop", "size": {"x": 0.8, "y": 1.1, "z": 2.0},
    "color": "#4a4a52", "collision": "box", "mesh": "",
    "meshy_prompt": "parked scooter motorcycle Taiwan street, low poly cartoon game prop"
  },
  "food_stall": {
    "category": "prop", "size": {"x": 2.4, "y": 2.2, "z": 1.6},
    "color": "#caa23b", "collision": "box", "mesh": "",
    "meshy_prompt": "Taiwan night market food stall cart with awning and steam, low poly cartoon game prop"
  },
  "trash_pile": {
    "category": "prop", "size": {"x": 1.0, "y": 0.8, "z": 1.0},
    "color": "#555560", "collision": "none", "mesh": "",
    "meshy_prompt": "street recycling bags and clutter pile, low poly cartoon game prop"
  },
  "arcade_column": {
    "category": "structure", "size": {"x": 0.6, "y": 3.0, "z": 0.6},
    "color": "#6a6a72", "collision": "box", "mesh": "",
    "meshy_prompt": "concrete arcade pillar qilou column, low poly cartoon game prop"
  }
}
```

- [ ] **Step 2：建立西門布局 `data/streets/ximen.json`**

最上層為 Dictionary（`JsonLoader.load_json` 只接受 Dictionary 頂層）。`locations` 用既有 `map_locations.json` 的 id；`travel` 描述區間移動點。

```json
{
  "ground": {"length": 70.0, "width": 14.0, "color": "#26262e"},
  "spawn": {"x": 0.0, "y": 0.0, "z": 28.0},
  "locations": ["ximen_mrt", "wannian_mall"],
  "travel": {
    "id": "ximen_transit",
    "name": "搭計程車前往其他區",
    "pos": {"x": 0.0, "y": 0.0, "z": -30.0},
    "radius": 2.5,
    "destinations": ["wanhua_old", "linsen"]
  },
  "props": [
    {"kit": "storefront_tall",  "pos": {"x": -6.5, "y": 0.0, "z": 18.0}, "rot_y": 90},
    {"kit": "storefront_mid",   "pos": {"x": -6.5, "y": 0.0, "z": 10.0}, "rot_y": 90},
    {"kit": "storefront_short", "pos": {"x": -6.5, "y": 0.0, "z": 2.0},  "rot_y": 90},
    {"kit": "storefront_mid",   "pos": {"x": -6.5, "y": 0.0, "z": -6.0}, "rot_y": 90},
    {"kit": "storefront_tall",  "pos": {"x": -6.5, "y": 0.0, "z": -16.0},"rot_y": 90},
    {"kit": "storefront_mid",   "pos": {"x": 6.5,  "y": 0.0, "z": 16.0}, "rot_y": -90},
    {"kit": "storefront_tall",  "pos": {"x": 6.5,  "y": 0.0, "z": 6.0},  "rot_y": -90},
    {"kit": "storefront_short", "pos": {"x": 6.5,  "y": 0.0, "z": -4.0}, "rot_y": -90},
    {"kit": "storefront_mid",   "pos": {"x": 6.5,  "y": 0.0, "z": -14.0},"rot_y": -90},
    {"kit": "sign_stack", "pos": {"x": -3.6, "y": 3.0, "z": 18.0}, "rot_y": 90},
    {"kit": "sign_stack", "pos": {"x": -3.6, "y": 2.6, "z": 2.0},  "rot_y": 90},
    {"kit": "sign_neon",  "pos": {"x": 3.6,  "y": 3.4, "z": 6.0},  "rot_y": -90},
    {"kit": "sign_neon",  "pos": {"x": -3.6, "y": 4.2, "z": -16.0},"rot_y": 90},
    {"kit": "lantern", "pos": {"x": -3.4, "y": 2.6, "z": 10.0}, "rot_y": 0},
    {"kit": "lantern", "pos": {"x": -3.4, "y": 2.6, "z": -6.0}, "rot_y": 0},
    {"kit": "lantern", "pos": {"x": 3.4,  "y": 2.6, "z": -4.0}, "rot_y": 0},
    {"kit": "motorcycle", "pos": {"x": -2.6, "y": 0.0, "z": 22.0}, "rot_y": 0},
    {"kit": "motorcycle", "pos": {"x": -1.6, "y": 0.0, "z": 22.2}, "rot_y": 0},
    {"kit": "motorcycle", "pos": {"x": 2.6,  "y": 0.0, "z": -20.0},"rot_y": 180},
    {"kit": "motorcycle", "pos": {"x": 1.6,  "y": 0.0, "z": -20.2},"rot_y": 180},
    {"kit": "food_stall", "pos": {"x": 3.2,  "y": 0.0, "z": 12.0}, "rot_y": -90},
    {"kit": "trash_pile", "pos": {"x": -3.0, "y": 0.0, "z": -12.0},"rot_y": 0},
    {"kit": "arcade_column", "pos": {"x": -4.2, "y": 0.0, "z": 14.0}, "rot_y": 0},
    {"kit": "arcade_column", "pos": {"x": -4.2, "y": 0.0, "z": 0.0},  "rot_y": 0},
    {"kit": "arcade_column", "pos": {"x": 4.2,  "y": 0.0, "z": 10.0}, "rot_y": 0}
  ]
}
```

- [ ] **Step 3：建立 stub 布局 `data/streets/wanhua_old.json`**

```json
{
  "ground": {"length": 30.0, "width": 12.0, "color": "#2a2620"},
  "spawn": {"x": 0.0, "y": 0.0, "z": 10.0},
  "locations": ["zen_bbq", "old_temple"],
  "travel": {
    "id": "wanhua_transit",
    "name": "搭計程車前往其他區",
    "pos": {"x": 0.0, "y": 0.0, "z": -12.0},
    "radius": 2.5,
    "destinations": ["ximen", "linsen"]
  },
  "props": [
    {"kit": "storefront_short", "pos": {"x": -5.5, "y": 0.0, "z": 4.0}, "rot_y": 90},
    {"kit": "lantern", "pos": {"x": -2.8, "y": 2.4, "z": 4.0}, "rot_y": 0}
  ]
}
```

- [ ] **Step 4：建立 stub 布局 `data/streets/linsen.json`**

```json
{
  "ground": {"length": 30.0, "width": 12.0, "color": "#201a2a"},
  "spawn": {"x": 0.0, "y": 0.0, "z": 10.0},
  "locations": ["zuijin_club"],
  "travel": {
    "id": "linsen_transit",
    "name": "搭計程車前往其他區",
    "pos": {"x": 0.0, "y": 0.0, "z": -12.0},
    "radius": 2.5,
    "destinations": ["ximen", "wanhua_old"]
  },
  "props": [
    {"kit": "sign_neon", "pos": {"x": -5.0, "y": 3.0, "z": 4.0}, "rot_y": 90}
  ]
}
```

- [ ] **Step 5：建立測試骨架 `test/TestStreetSlice.gd`（先放 Task 1 的資料驗證）**

```gdscript
extends Node

## 西門切片煙霧測試。掛在 root，依序跑各任務的 test_*，全過印 STREET TEST PASS。

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	test_data_files()
	print("STREET TEST PASS")
	get_tree().quit(0)

func test_data_files() -> void:
	var kit: Dictionary = JsonLoader.load_json("res://data/street_kit.json")
	_assert(kit.has("storefront_tall"), "street_kit 缺 storefront_tall")
	_assert(kit.storefront_tall.has("size"), "零件缺 size")
	var street: Dictionary = JsonLoader.load_json("res://data/streets/ximen.json")
	_assert(not street.is_empty(), "ximen.json 讀取失敗")
	_assert(street.props.size() >= 10, "ximen 道具數不足")
	_assert(street.travel.destinations.size() == 2, "ximen travel 目的地數錯誤")
	print("  test_data_files OK")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("STREET TEST FAIL: %s" % msg)
		get_tree().quit(1)
```

- [ ] **Step 6：建立測試入口場景 `test/TestStreetSlice.tscn`**

仿 `test/TestStep1.tscn`：一個 Node 掛載一段把 TestRunner 推到 root 的腳本。最簡單做法是直接讓場景根節點掛 `TestStreetSlice.gd`。用文字寫入：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test/TestStreetSlice.gd" id="1"]

[node name="TestStreetSlice" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 7：執行測試**

在 Godot 開 `test/TestStreetSlice.tscn` 按 F6。
Expected：Output 出現
```
  test_data_files OK
STREET TEST PASS
```

- [ ] **Step 8：Commit**

```bash
git add data/street_kit.json data/streets/ test/TestStreetSlice.gd test/TestStreetSlice.tscn
git commit -m "feat(map): add street kit registry and Ximen layout data + test scaffold"
```

---

## Task 2：StreetBuilder 街道組裝器

**Files:**
- Create: `src/screens/MapScreen/StreetBuilder.gd`
- Modify: `test/TestStreetSlice.gd`

- [ ] **Step 1：在 `test/TestStreetSlice.gd` 新增 `test_builder()` 並於 `_run()` 呼叫**

在 `_run()` 的 `test_data_files()` 後加一行 `test_builder()`，並新增函式：

```gdscript
func test_builder() -> void:
	var root := Node3D.new()
	add_child(root)
	var builder := StreetBuilder.new()
	var summary: Dictionary = builder.build(root, "ximen")
	_assert(summary.ground == true, "未建立地面")
	_assert(summary.props_built >= 10, "道具生成數不足：%d" % summary.props_built)
	_assert(root.has_node("Ground"), "Ground 節點不存在")
	var spawn: Vector3 = builder.get_spawn("ximen")
	_assert(spawn.is_equal_approx(Vector3(0, 0, 28)), "spawn 位置錯誤：%s" % str(spawn))
	root.queue_free()
	print("  test_builder OK")
```

- [ ] **Step 2：執行測試確認 FAIL**

按 F6。Expected：解析/執行錯誤（`StreetBuilder` 尚未定義）或 `STREET TEST FAIL`。

- [ ] **Step 3：實作 `src/screens/MapScreen/StreetBuilder.gd`**

```gdscript
class_name StreetBuilder
extends RefCounted

## 資料驅動街道組裝器：讀 data/streets/<id>.json 與 data/street_kit.json，
## 在指定 root 之下生成地面、店面、招牌、道具（含 placeholder 幾何與碰撞）。
## 零件 mesh 欄位為空時用 placeholder 方塊；填入 .glb 路徑後自動改用該資產。

const KIT_PATH: String = "res://data/street_kit.json"
const STREET_FMT: String = "res://data/streets/%s.json"

var _kit: Dictionary = {}

func _init() -> void:
	_kit = JsonLoader.load_json(KIT_PATH)

## 把街道建到 root 之下，回傳 {ground: bool, props_built: int}
func build(root: Node3D, street_id: String) -> Dictionary:
	var street: Dictionary = JsonLoader.load_json(STREET_FMT % street_id)
	var summary: Dictionary = {"ground": false, "props_built": 0}
	if street.is_empty():
		push_warning("StreetBuilder: 找不到街道資料 %s" % street_id)
		return summary
	_build_ground(root, street.get("ground", {}))
	summary.ground = true
	for entry in street.get("props", []):
		var node := _make_prop(entry)
		if node != null:
			root.add_child(node)
			summary.props_built += 1
	return summary

func get_spawn(street_id: String) -> Vector3:
	var street: Dictionary = JsonLoader.load_json(STREET_FMT % street_id)
	var s: Dictionary = street.get("spawn", {"x": 0.0, "y": 0.0, "z": 0.0})
	return Vector3(s.x, s.y, s.z)

func _build_ground(root: Node3D, g: Dictionary) -> void:
	var length: float = g.get("length", 60.0)
	var width: float = g.get("width", 12.0)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 1.0, length)
	col.shape = shape
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 1.0, length)
	mesh.material = _make_material(g.get("color", "#2a2a30"))
	mi.mesh = mesh
	mi.position = Vector3(0, -0.5, 0)
	body.add_child(mi)
	root.add_child(body)

func _make_prop(entry: Dictionary) -> Node3D:
	var kit_id: String = entry.get("kit", "")
	var part: Dictionary = _kit.get(kit_id, {})
	if part.is_empty():
		push_warning("StreetBuilder: 未知零件 %s" % kit_id)
		return null
	var size: Dictionary = part.get("size", {"x": 1.0, "y": 1.0, "z": 1.0})
	var sv := Vector3(size.x, size.y, size.z)
	var holder := Node3D.new()
	holder.name = kit_id
	var pos: Dictionary = entry.get("pos", {"x": 0.0, "y": 0.0, "z": 0.0})
	holder.position = Vector3(pos.x, pos.y, pos.z)
	holder.rotation_degrees.y = entry.get("rot_y", 0.0)

	var mesh_path: String = part.get("mesh", "")
	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var res: Resource = load(mesh_path)
		if res is PackedScene:
			holder.add_child((res as PackedScene).instantiate())
		elif res is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = res
			holder.add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sv
		box.material = _make_material(part.get("color", "#888888"))
		mi.mesh = box
		mi.position = Vector3(0, sv.y * 0.5, 0)
		holder.add_child(mi)

	if part.get("collision", "none") == "box":
		var cbody := StaticBody3D.new()
		var ccol := CollisionShape3D.new()
		var cshape := BoxShape3D.new()
		cshape.size = sv
		ccol.shape = cshape
		ccol.position = Vector3(0, sv.y * 0.5, 0)
		cbody.add_child(ccol)
		holder.add_child(cbody)
	return holder

func _make_material(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	return m
```

- [ ] **Step 4：執行測試確認 PASS**

按 F6。Expected：
```
  test_data_files OK
  test_builder OK
STREET TEST PASS
```

- [ ] **Step 5：Commit**

```bash
git add src/screens/MapScreen/StreetBuilder.gd test/TestStreetSlice.gd
git commit -m "feat(map): add data-driven StreetBuilder with placeholder geometry"
```

---

## Task 3：GameManager 分區位置狀態

**Files:**
- Modify: `src/autoloads/GameManager.gd`
- Modify: `test/TestStreetSlice.gd`

- [ ] **Step 1：在 `test/TestStreetSlice.gd` 新增 `test_district_state()` 並於 `_run()` 呼叫**

```gdscript
func test_district_state() -> void:
	_assert(GameManager.player.has("current_district"), "player 缺 current_district")
	_assert(GameManager.player.has("district_positions"), "player 缺 district_positions")
	GameManager.set_district_position("ximen", Vector3(1, 0, 2))
	var got: Vector3 = GameManager.get_district_position("ximen", Vector3.ZERO)
	_assert(got.is_equal_approx(Vector3(1, 0, 2)), "分區位置存取錯誤：%s" % str(got))
	var fallback: Vector3 = GameManager.get_district_position("nope", Vector3(9, 9, 9))
	_assert(fallback.is_equal_approx(Vector3(9, 9, 9)), "預設位置錯誤")
	print("  test_district_state OK")
```

- [ ] **Step 2：執行測試確認 FAIL**

按 F6。Expected：`STREET TEST FAIL: player 缺 current_district` 或函式未定義錯誤。

- [ ] **Step 3：修改 `src/autoloads/GameManager.gd`**

把 `player` 字典中的這行：

```gdscript
	"last_position": {"x": 0.0, "y": 0.0, "z": 0.0}
```

改為：

```gdscript
	"current_district": "ximen",
	"district_positions": {}
```

並在檔案結尾（`get_flag` 之後）新增兩個輔助函式：

```gdscript
func set_district_position(district: String, pos: Vector3) -> void:
	player.district_positions[district] = {"x": pos.x, "y": pos.y, "z": pos.z}

func get_district_position(district: String, default: Vector3) -> Vector3:
	var d: Dictionary = player.district_positions.get(district, {})
	if d.is_empty():
		return default
	return Vector3(d.x, d.y, d.z)
```

- [ ] **Step 4：執行測試確認 PASS**

按 F6。Expected：`  test_district_state OK` 出現在 PASS 之前。

- [ ] **Step 5：Commit**

```bash
git add src/autoloads/GameManager.gd test/TestStreetSlice.gd
git commit -m "feat(state): track current_district and per-district player positions"
```

---

## Task 4：DistrictScreen 通用控制器 + 西門場景

**Files:**
- Create: `src/screens/MapScreen/DistrictScreen.gd`
- Create: `src/screens/MapScreen/districts/XimenDistrict.tscn`
- Modify: `test/TestStreetSlice.gd`

- [ ] **Step 1：在 `test/TestStreetSlice.gd` 新增 `test_ximen_scene()` 並於 `_run()` 呼叫**

此測試載入西門場景、等其 `_ready` 完成、檢查觸發點數量（2 個地點 + 1 個移動點 = 3）與玩家存在。

```gdscript
func test_ximen_scene() -> void:
	var packed: PackedScene = load("res://src/screens/MapScreen/districts/XimenDistrict.tscn")
	_assert(packed != null, "XimenDistrict.tscn 載入失敗")
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(GameManager.player.current_district == "ximen", "未設定 current_district=ximen")
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	_assert(triggers.size() >= 3, "西門觸發點不足（應含2地點+1移動點）：%d" % triggers.size())
	_assert(scene.has_node("Player"), "場景缺 Player")
	scene.queue_free()
	await get_tree().process_frame
	print("  test_ximen_scene OK")
```

- [ ] **Step 2：執行測試確認 FAIL**

按 F6。Expected：`XimenDistrict.tscn 載入失敗` 或 `DistrictScreen` 未定義。

- [ ] **Step 3：實作 `src/screens/MapScreen/DistrictScreen.gd`**

由 `MapScreen.gd` 一般化而來：改用 `district_id`/`street_id`、用 `StreetBuilder` 建街、依 `district` 欄位過濾地點、加入區間移動點、改用 `district_positions` 還原位置、新增 `travel_` 動作分支。

```gdscript
extends Node3D

## 通用分區街景控制器。各分區場景設定 district_id / street_id。
## 負責：組裝街道、放置地點觸發點與區間移動點、還原玩家位置、互動選單。

const TRIGGER_SCENE := preload("res://src/screens/MapScreen/LocationTrigger.tscn")
const STREET_FMT: String = "res://data/streets/%s.json"

@export var district_id: String = "ximen"
@export var street_id: String = "ximen"

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var _locations: Dictionary = {}
var _current_loc: String = ""
var _in_trigger: bool = false

func _ready() -> void:
	GameManager.player.current_district = district_id
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	var builder := StreetBuilder.new()
	builder.build(self, street_id)
	_build_location_triggers()
	_build_travel_point()
	_update_hud()
	GameManager.time_advanced.connect(_on_time_advanced)
	_restore_player_position(builder)
	AudioManager.switch_bgm(_district_bgm())

func _district_bgm() -> String:
	match district_id:
		"ximen": return "ximen_night"
		"wanhua_old": return "wanhua_night"
		"linsen": return "linsen_night"
	return "temple_ambient"

func _build_location_triggers() -> void:
	for id in _locations.keys():
		var loc: Dictionary = _locations[id]
		if loc.get("district", "") != district_id:
			continue
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
			continue
		var t := TRIGGER_SCENE.instantiate()
		t.setup(id, loc)
		t.player_entered.connect(_on_entered.bind(id))
		t.player_exited.connect(_on_exited)
		add_child(t)

func _build_travel_point() -> void:
	var street: Dictionary = JsonLoader.load_json(STREET_FMT % street_id)
	var travel: Dictionary = street.get("travel", {})
	if travel.is_empty():
		return
	var loc: Dictionary = {
		"name": travel.get("name", "前往其他區"),
		"position_3d": travel.get("pos", {"x": 0.0, "y": 0.0, "z": 0.0}),
		"trigger_radius": travel.get("radius", 2.5),
		"actions": []
	}
	for dest in travel.get("destinations", []):
		loc.actions.append("travel_" + dest)
	var tid: String = travel.get("id", "transit")
	_locations[tid] = loc
	var t := TRIGGER_SCENE.instantiate()
	t.setup(tid, loc)
	t.player_entered.connect(_on_entered.bind(tid))
	t.player_exited.connect(_on_exited)
	add_child(t)

func _restore_player_position(builder: StreetBuilder) -> void:
	player.global_position = GameManager.get_district_position(
		district_id, builder.get_spawn(street_id))

func _input(event: InputEvent) -> void:
	if _in_trigger and event.is_action_pressed("interact"):
		_open_menu(_current_loc)

func _on_entered(id: String) -> void:
	_in_trigger = true
	_current_loc = id
	hud.show_prompt("[E] %s" % _locations[id].name)
	EventBus.location_entered.emit(id)

func _on_exited() -> void:
	_in_trigger = false
	_current_loc = ""
	hud.hide_prompt()
	hud.hide_action_menu()
	EventBus.location_exited.emit()

func _open_menu(id: String) -> void:
	var loc: Dictionary = _locations[id]
	hud.show_action_menu(loc.name, loc.actions, perform_action)

func perform_action(action: String) -> void:
	hud.hide_action_menu()
	if action.begins_with("travel_"):
		_store_position()
		SceneRouter.go_to_district(action.replace("travel_", ""))
		return
	GameManager.advance_time(1)
	match action:
		"random_encounter":
			var district: String = _locations[_current_loc].get("district", district_id)
			EventBus.random_encounter_triggered.emit(district)
			SceneRouter.go_to_battle(_pick_enemy(district))
		"cherry_dialogue":
			if ResourceLoader.exists("res://dialogue/cherry_first_meeting.dtl"):
				Dialogic.start("cherry_first_meeting")
			else:
				hud.show_toast("Cherry 對話尚未製作（Step 7）")
		"food_break_trigger":
			BreakVowSystem.try_trigger("food")
		"greed_break_trigger":
			BreakVowSystem.try_trigger("greed")
		"lust_break_trigger":
			BreakVowSystem.try_trigger("lust")
		"beggar_minigame":
			SceneRouter.go_to_minigame("beggar_challenge")
			hud.show_toast("化緣小遊戲尚未實作（Step 9）")
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
		"shop", "skill_learn":
			hud.show_toast("此功能尚未實作")
		_:
			if action.begins_with("quest_"):
				QuestManager.trigger_action(action, _current_loc)
				hud.show_toast("支線對話尚未製作（Step 7）")
	_update_hud()

func get_player_position() -> Vector3:
	return player.global_position

func _store_position() -> void:
	GameManager.set_district_position(district_id, player.global_position)

func _pick_enemy(district: String) -> String:
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	var pool: Array = []
	for id in enemies.keys():
		var e: Dictionary = enemies[id]
		if e.get("district", "") != district:
			continue
		if e.has("time_restriction") and GameManager.player.period not in e.time_restriction:
			continue
		pool.append(id)
	if pool.is_empty():
		return "street_punk"
	return pool[randi() % pool.size()]

func _on_time_advanced(_p: int) -> void:
	_update_hud()
	for t in get_tree().get_nodes_in_group("location_trigger"):
		var loc: Dictionary = _locations.get(t.location_id, {})
		t.visible = GameManager.player.period in loc.get("available_periods", [0, 1, 2, 3])

func _update_hud() -> void:
	hud.set_time(GameManager.player.day, GameManager.TIME_PERIODS[GameManager.player.period])
	hud.update_stats()
```

- [ ] **Step 4：建立 `src/screens/MapScreen/districts/XimenDistrict.tscn`**

複製既有 `MapScreen.tscn` 的節點結構（WorldEnvironment / Sun / Player / CameraRig / HUD），但**移除 Floor**（地面改由 StreetBuilder 生成），根節點換 `DistrictScreen.gd` 並設 `district_id`/`street_id`。用文字寫入：

```
[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://src/screens/MapScreen/DistrictScreen.gd" id="1"]
[ext_resource type="Script" path="res://src/screens/MapScreen/PlayerController.gd" id="2"]
[ext_resource type="Script" path="res://src/screens/MapScreen/CameraRig.gd" id="3"]
[ext_resource type="Script" path="res://src/screens/MapScreen/MapHUD.gd" id="4"]

[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.05, 0.05, 0.09, 1)
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.6, 0.75, 1)

[sub_resource type="CapsuleShape3D" id="player_shape"]
radius = 0.4
height = 1.8

[sub_resource type="StandardMaterial3D" id="player_mat"]
albedo_color = Color(0.85, 0.55, 0.2, 1)

[sub_resource type="CapsuleMesh" id="player_mesh"]
material = SubResource("player_mat")
radius = 0.4
height = 1.8

[node name="XimenDistrict" type="Node3D"]
script = ExtResource("1")
district_id = "ximen"
street_id = "ximen"

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.5736, 0.8192, 0, -0.8192, 0.5736, 0, 20, 0)
shadow_enabled = true

[node name="Player" type="CharacterBody3D" parent="." groups=["player"]]
script = ExtResource("2")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("player_shape")

[node name="MeshRoot" type="Node3D" parent="Player"]

[node name="BodyMesh" type="MeshInstance3D" parent="Player/MeshRoot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("player_mesh")

[node name="CameraRig" type="Node3D" parent="." node_paths=PackedStringArray("target_path")]
script = ExtResource("3")
target_path = NodePath("../Player")

[node name="Camera3D" type="Camera3D" parent="CameraRig"]
current = true

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("4")

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

- [ ] **Step 5：執行測試確認 PASS**

按 F6。Expected：`  test_ximen_scene OK`。

> 註：此時直接執行 `XimenDistrict.tscn`（F6）亦可看到 placeholder 街景並走動，但 BGM/SceneRouter 完整流程在 Task 5 才接好。

- [ ] **Step 6：Commit**

```bash
git add src/screens/MapScreen/DistrictScreen.gd src/screens/MapScreen/districts/XimenDistrict.tscn test/TestStreetSlice.gd
git commit -m "feat(map): add generalized DistrictScreen and Ximen district scene"
```

---

## Task 5：分區路由 + 區間移動 + stub 場景

**Files:**
- Modify: `src/autoloads/SceneRouter.gd`
- Modify: `src/screens/MapScreen/MapHUD.gd`
- Modify: `src/screens/BattleScreen/BattleManager.gd:259-267`
- Create: `src/screens/MapScreen/districts/WanhuaDistrict.tscn`
- Create: `src/screens/MapScreen/districts/LinsenDistrict.tscn`
- Modify: `test/TestStreetSlice.gd`

- [ ] **Step 1：在 `test/TestStreetSlice.gd` 新增 `test_travel()` 並於 `_run()` 呼叫**

驗證 `go_to_district` 切到萬華 stub、`current_district` 更新、stub 場景觸發點存在。

```gdscript
func test_travel() -> void:
	SceneRouter.go_to_district("wanhua_old")
	var scene: Node = await _wait_for_scene("WanhuaDistrict")
	_assert(scene != null, "未切換到 WanhuaDistrict")
	_assert(GameManager.player.current_district == "wanhua_old", "current_district 未更新")
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	_assert(triggers.size() >= 2, "萬華 stub 觸發點不足：%d" % triggers.size())
	print("  test_travel OK")

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null
```

> 註：`test_travel` 會切換 `current_scene`，故必須是 `_run()` 中**最後一個**測試（其後直接印 PASS、quit）。把 `test_travel()` 放在 `print("STREET TEST PASS")` 前一行，並改為 `await test_travel()`；`_run()` 內所有含 `await` 的呼叫都要加 `await`。

`_run()` 最終樣貌：

```gdscript
func _run() -> void:
	await get_tree().process_frame
	test_data_files()
	test_builder()
	test_district_state()
	await test_ximen_scene()
	await test_travel()
	print("STREET TEST PASS")
	get_tree().quit(0)
```

- [ ] **Step 2：執行測試確認 FAIL**

按 F6。Expected：`未切換到 WanhuaDistrict`（route 與 stub 尚未建立）。

- [ ] **Step 3：修改 `src/autoloads/SceneRouter.gd`**

移除 `MAP_SCENE` 常數行，新增 `DISTRICTS`；改寫 `go_to_map`、新增 `go_to_district`、改 `_store_player_position` 用分區位置。

刪除這行：
```gdscript
const MAP_SCENE:      String = "res://src/screens/MapScreen/MapScreen.tscn"
```

新增常數（放在其他 const 附近）：
```gdscript
const DISTRICTS: Dictionary = {
	"ximen":      "res://src/screens/MapScreen/districts/XimenDistrict.tscn",
	"wanhua_old": "res://src/screens/MapScreen/districts/WanhuaDistrict.tscn",
	"linsen":     "res://src/screens/MapScreen/districts/LinsenDistrict.tscn",
}
```

把：
```gdscript
func go_to_map() -> void:
	await _change_scene(MAP_SCENE, Transition.INK_SPLASH)
```
改為：
```gdscript
func go_to_map() -> void:
	await go_to_district(GameManager.player.current_district)

func go_to_district(district_id: String) -> void:
	if not DISTRICTS.has(district_id):
		push_warning("SceneRouter: 未知分區 %s，改用 ximen" % district_id)
		district_id = "ximen"
	GameManager.player.current_district = district_id
	await _change_scene(DISTRICTS[district_id], Transition.INK_SPLASH)
```

把 `_store_player_position` 內這行：
```gdscript
		GameManager.player.last_position = {"x": pos.x, "y": pos.y, "z": pos.z}
```
改為：
```gdscript
		GameManager.set_district_position(GameManager.player.current_district, pos)
```

- [ ] **Step 4：修改 `src/screens/BattleScreen/BattleManager.gd` 戰敗重生（第 265 行附近）**

把：
```gdscript
	GameManager.player.last_position = {"x": -18.0, "y": 0.0, "z": 4.0}
```
改為（戰敗回到萬華古廟所在分區）：
```gdscript
	GameManager.player.current_district = "wanhua_old"
	GameManager.set_district_position("wanhua_old", Vector3(-18.0, 0.0, 4.0))
```

- [ ] **Step 5：修改 `src/screens/MapScreen/MapHUD.gd` 新增區間移動標籤**

`ACTION_LABELS` 字典中新增三筆（放在結尾 `}` 前，注意前一筆要補逗號）：
```gdscript
	"travel_ximen":      "→ 西門商圈",
	"travel_wanhua_old": "→ 萬華舊區",
	"travel_linsen":     "→ 林森北路",
```

- [ ] **Step 6：建立萬華 stub 場景 `src/screens/MapScreen/districts/WanhuaDistrict.tscn`**

複製 Task 4 Step 4 的整段 `.tscn` 內容，只改最上方根節點三行：
```
[node name="WanhuaDistrict" type="Node3D"]
script = ExtResource("1")
district_id = "wanhua_old"
street_id = "wanhua_old"
```
（其餘節點、SubResource、ext_resource 全部相同。）

- [ ] **Step 7：建立林森北 stub 場景 `src/screens/MapScreen/districts/LinsenDistrict.tscn`**

同樣複製，根節點改為：
```
[node name="LinsenDistrict" type="Node3D"]
script = ExtResource("1")
district_id = "linsen"
street_id = "linsen"
```

> 註：`zuijin_club` 在 `map_locations.json` 有 `unlock_flag: linsen_unlocked`，未解鎖時林森北沒有地點觸發點，只有移動點 —— 屬預期行為。

- [ ] **Step 8：執行測試確認 PASS**

按 F6。Expected：依序印出 `test_data_files OK`…`test_travel OK` 後 `STREET TEST PASS`。

- [ ] **Step 9：Commit**

```bash
git add src/autoloads/SceneRouter.gd src/screens/MapScreen/MapHUD.gd src/screens/BattleScreen/BattleManager.gd src/screens/MapScreen/districts/WanhuaDistrict.tscn src/screens/MapScreen/districts/LinsenDistrict.tscn test/TestStreetSlice.gd
git commit -m "feat(map): add district routing, zone travel, and stub districts"
```

---

## Task 6：精修地標 Meshy prompt（與模組相容）

**Files:**
- Modify: `data/meshy_prompts/environments.json`

- [ ] **Step 1：更新西門兩個地標 prompt，加入「平整背面、可貼街、比例一致」描述**

把 `ximen_mrt` 與 `wannian_mall` 兩筆的 `prompt` 改為（其餘欄位不動）：

`ximen_mrt`：
```
"prompt": "Taipei MRT Ximen Station exit 6 at night, single street-facing structure with flat back for street placement, metallic railings, neon Chinese signs, wet pavement reflections, convenience store, consistent human scale, low poly cartoon stylized game asset",
```

`wannian_mall`：
```
"prompt": "Ximending Wannian retro 5-story commercial building, single street-facing facade with flat back for street placement, glowing electronics and toy shop signs, neon, escalator glass, consistent human scale, low poly cartoon stylized game asset",
```

- [ ] **Step 2：Commit**

```bash
git add data/meshy_prompts/environments.json
git commit -m "chore(assets): refine Ximen landmark Meshy prompts for street compatibility"
```

---

## Task 7：遷移舊煙霧測試、移除舊 MapScreen、最終驗收

**Files:**
- Modify: `test/TestRunner.gd`
- Delete: `src/screens/MapScreen/MapScreen.gd`
- Delete: `src/screens/MapScreen/MapScreen.gd.uid`
- Delete: `src/screens/MapScreen/MapScreen.tscn`

- [ ] **Step 1：更新 `test/TestRunner.gd` 以符合分區結構**

`go_to_map()` 現在會載入 `XimenDistrict`（預設 `current_district`），場景名不再是 `MapScreen`。修改三處：

把第 12-16 行：
```gdscript
	print("TEST: 切換至 MapScreen")
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		_fail("MapScreen 未載入")
		return
```
改為：
```gdscript
	print("TEST: 切換至 XimenDistrict")
	GameManager.player.current_district = "ximen"
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("XimenDistrict")
	if map == null:
		_fail("XimenDistrict 未載入")
		return
```

把第 18-21 行的觸發器數量檢查（西門只有 2 地點 + 1 移動點）：
```gdscript
	if triggers.size() < 4:
		_fail("觸發器數量不足")
		return
```
改為：
```gdscript
	if triggers.size() < 3:
		_fail("觸發器數量不足（西門應為 2 地點 + 1 移動點）")
		return
```

把第 47-50 行勝利後返回檢查：
```gdscript
	map = await _wait_for_scene("MapScreen")
	if map == null:
		_fail("勝利後未返回 MapScreen")
		return
```
改為：
```gdscript
	map = await _wait_for_scene("XimenDistrict")
	if map == null:
		_fail("勝利後未返回 XimenDistrict")
		return
```

- [ ] **Step 2：執行舊煙霧測試確認仍通過**

在 Godot 開 `test/TestStep1.tscn` 按 F6。
Expected：Output 末尾 `TEST PASS: Step 1 + Step 3 驗收流程完整通過`。

- [ ] **Step 3：刪除舊 MapScreen 檔案**

```bash
git rm src/screens/MapScreen/MapScreen.gd src/screens/MapScreen/MapScreen.gd.uid src/screens/MapScreen/MapScreen.tscn
```

確認沒有殘留引用：
```bash
grep -rn "MapScreen.tscn\|MapScreen.gd" src test --include=*.gd --include=*.tscn
```
Expected：無輸出（或僅 `districts/` 路徑與 `DistrictScreen` 無關之命名）。

- [ ] **Step 4：再跑兩個測試場景做最終驗收**

1. `test/TestStreetSlice.tscn` 按 F6 → `STREET TEST PASS`
2. `test/TestStep1.tscn` 按 F6 → `TEST PASS: Step 1 + Step 3 驗收流程完整通過`

人工目視驗收（開 `XimenDistrict.tscn` F6）：
- 看得到 placeholder 街景（兩排建築、招牌、機車、攤販、燈籠）
- 可用方向鍵走完整條街
- 走到「捷運西門站」「萬年大樓」「搭計程車」三點會跳互動提示，按 E 開選單
- 選「→ 萬華舊區」會切到萬華 stub 並可折返

- [ ] **Step 5：Commit**

```bash
git add test/TestRunner.gd
git commit -m "refactor(map): migrate smoke test to district structure, remove legacy MapScreen"
```

---

## 完成定義

- `TestStreetSlice.tscn` 全綠（資料 / Builder / 分區狀態 / 西門場景 / 區間移動）
- `TestStep1.tscn` 仍全綠（戰鬥流程不回歸）
- 西門可走動、三個互動點正常、區間移動可切換並還原位置
- 全程無需任何 Meshy `.glb`（placeholder 即可跑）
- 零件表與布局皆為資料；地標 prompt 已備妥供 Meshy 生成
```
