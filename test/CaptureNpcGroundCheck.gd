extends Node
## 診斷工具（2026-07-10 沉地/懸空 QC 修正）：對 map_npcs.json 每個帶 npc_model 的點與
## map_enemies.json 每個敵人，載入其 GLB，計算未修正前的合併局部 AABB（bottom=aabb.position.y、
## height=aabb.size.y）。地面頂面全域慣例＝y=0.0（ShrineStreet/ArmoryDistrict 兩區地面 slab
## 皆 position.y=-0.1、size.y=0.2，頂面在 0）；NPC/敵人 position_3d.y 也一律寫 0.0。
## 若模型 bottom 顯著偏離 0（例如 Meshy 原點在腰部/胸口而非腳底），該模型放在 y=0 就會沉入地板
## 或懸空。純唯讀診斷，不寫檔、不改場景。
## 跑：Godot..._console.exe --headless --path D:/monk/MONK res://test/CaptureNpcGroundCheck.tscn -- smoke

const NPC_FIGURE := preload("res://src/screens/MapScreen/npc_figure.gd")

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var npcs: Dictionary = JsonLoader.load_json("res://data/map_npcs.json")
	print("=== NPC models RAW GLB (map_npcs.json, 修正前的原始模型 AABB) ===")
	for id in npcs:
		if String(id).begins_with("_"):
			continue
		var l: Dictionary = npcs[id]
		var model_name := String(l.get("npc_model", ""))
		if model_name == "":
			continue
		_check("res://assets/3d/characters/npcs/%s.glb" % model_name, "%s (%s)" % [id, l.get("name", "")])
	print("=== Enemy models (map_enemies.json，未動，僅比對用) ===")
	var enemies: Dictionary = JsonLoader.load_json("res://data/map_enemies.json")
	for district in enemies:
		if String(district).begins_with("_"):
			continue
		for e in (enemies[district] as Array):
			var model_name: String = String(e.get("model", e.get("enemy_id", "")))
			_check("res://assets/3d/characters/enemies/%s.glb" % model_name, "%s/%s" % [district, e.get("enemy_id", "")])
	print("=== NPC models THROUGH NpcFigure.setup()（套用貼地修正後，經 fig 實際擺放路徑）===")
	for id in npcs:
		if String(id).begins_with("_"):
			continue
		var l: Dictionary = npcs[id]
		var model_name := String(l.get("npc_model", ""))
		if model_name == "":
			continue
		_check_via_figure(id, l, model_name)
	print("NPC_GROUND_CHECK_DONE")
	get_tree().quit()

## 完整跑 LocationTrigger→NpcFigure 的真實擺放路徑（含 fig 掛在 trig 位置），
## 量測修正後 NpcFigure 底下模型的世界 AABB 最低點，應貼近 trig 的世界 y（目前資料皆 0.0）。
func _check_via_figure(id: String, l: Dictionary, model_name: String) -> void:
	var p: Dictionary = l.get("position_3d", {"x": 0.0, "y": 0.0, "z": 0.0})
	var trig := Node3D.new()
	trig.position = Vector3(p.x, p.y, p.z)
	add_child(trig)
	var fig: Node3D = NPC_FIGURE.new()
	trig.add_child(fig)
	fig.setup(model_name)
	var world_aabb := _merged_aabb(fig)
	var expected_ground: float = p.y
	var delta: float = world_aabb.position.y - expected_ground
	var flag := "" if absf(delta) < 0.02 else "  <== STILL OFF (%.3f)" % delta
	print("  %-28s world_bottom=%.3f expected_ground=%.3f%s" % [id, world_aabb.position.y, expected_ground, flag])
	trig.queue_free()

func _check(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		print("  [MISSING] %s -> %s" % [label, path])
		return
	var inst := (load(path) as PackedScene).instantiate()
	var root := Node3D.new()
	add_child(root)
	root.add_child(inst)
	var aabb := _merged_aabb(inst)
	var bottom := aabb.position.y
	var height := aabb.size.y
	var flag := ""
	if absf(bottom) > 0.15:
		flag = "  <== SINK/FLOAT RISK (bottom != 0)"
	print("  %-28s bottom=%.3f height=%.3f top=%.3f%s" % [label, bottom, height, bottom + height, flag])
	root.queue_free()

func _merged_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var a := mi.global_transform * mi.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		for c in n.get_children():
			stack.append(c)
	return aabb
