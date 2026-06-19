extends Node3D
## 6 棟新建築白模排 3x2 編號網格，挑要貼圖的。
const DIR := "res://assets/3d/environments/ximen/prototypes/"
const MODELS := [
	["1 霓虹高樓 tower", "ximen_neon_tower_01"],
	["2 KTV娛樂城", "ximen_ktv_building_01"],
	["3 手搖飲 bubbletea", "ximen_bubbletea_shop_01"],
	["4 拉麵店 ramen", "ximen_ramen_shop_01"],
	["5 停車場 parking", "ximen_parking_garage_01"],
	["6 藥妝店 drugstore", "ximen_drugstore_01"],
]
const COLS := 3
const SX := 4.6
const SZ := 5.0
const TARGET := 3.2

func _ready() -> void:
	_env()
	for i in MODELS.size():
		var col := i % COLS
		var row := i / COLS
		var gx := (col - (COLS - 1) / 2.0) * SX
		var gz := row * SZ
		_place(MODELS[i][0], DIR + MODELS[i][1] + ".glb", Vector3(gx, 0, gz))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_new_buildings.png")
	print("NEWB_DONE")
	get_tree().quit()

func _place(label: String, path: String, gp: Vector3) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		print("LOAD FAIL ", path); return
	var inst := ps.instantiate() as Node3D
	add_child(inst)
	var ab := _aabb(inst)
	var md: float = max(ab.size.x, max(ab.size.y, ab.size.z))
	var s: float = TARGET / md if md > 0.001 else 1.0
	inst.scale = Vector3(s, s, s)
	ab = _aabb(inst)
	var c := ab.get_center()
	inst.global_position += Vector3(gp.x - c.x, -ab.position.y, gp.z - c.z)
	var tag := Label3D.new()
	tag.text = label.split(" ")[0]
	tag.font_size = 130
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 0.86, 0.35)
	tag.outline_size = 18
	tag.position = Vector3(gp.x, 3.7, gp.z)
	add_child(tag)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = 1.4; cyl.bottom_radius = 1.4; cyl.height = 0.05
	disc.mesh = cyl
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.16, 0.17, 0.22)
	disc.mesh.surface_set_material(0, dm)
	disc.position = Vector3(gp.x, 0.02, gp.z)
	add_child(disc)

func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.66)
	e.ambient_light_energy = 1.0
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0); sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(28, 22); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.13, 0.14, 0.18)
	ground.mesh.surface_set_material(0, gm)
	ground.position = Vector3(0, 0, SZ * 0.5)
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 56
	cam.position = Vector3(0, 7.5, 11.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.2, SZ * 0.5), Vector3.UP)
	add_child(cam); cam.make_current()

func _aabb(root: Node3D) -> AABB:
	var r := AABB(); var has := false; var st: Array = [root]
	while not st.is_empty():
		var n = st.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			var l: AABB = n.mesh.get_aabb(); var gt: Transform3D = n.global_transform
			for i in 8:
				var cn := l.position + Vector3(l.size.x*float(i&1), l.size.y*float((i>>1)&1), l.size.z*float((i>>2)&1))
				var wp := gt * cn
				if not has: r = AABB(wp, Vector3.ZERO); has = true
				else: r = r.expand(wp)
		for c in n.get_children(): st.append(c)
	return r
