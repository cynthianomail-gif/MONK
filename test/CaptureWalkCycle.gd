extends Node
## 單體 Player.tscn 走路循環檢查：blend=1，在多個時間點拍照（都跨過舊定格點 1.07s），
## 每張重新框相機，併成對照表，確認腳會連續循環（不再定格）。

var _world: Node3D
var _cam: Camera3D
var _p: Node3D
var _shots: Array = []

func _ready() -> void:
	_world = Node3D.new()
	get_tree().root.call_deferred("add_child", _world)
	await get_tree().process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.7
	env.environment = e; _world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0); key.light_energy = 1.3
	_world.add_child(key)
	_cam = Camera3D.new(); _cam.fov = 50; _world.add_child(_cam); _cam.make_current()

	_p = (load("res://src/screens/MapScreen/Player.tscn") as PackedScene).instantiate()
	_p.set_physics_process(false)   # 原地走，不被重力/移動帶走
	_world.add_child(_p)
	for i in 8: await get_tree().process_frame
	var at := _p.get_node_or_null("AnimationTree") as AnimationTree
	if at: at.set("parameters/blend/blend_amount", 1.0)

	# 取樣時間點（秒）：都遠超 1.07s 定格點，含整數倍循環邊界
	var times := [0.4, 0.7, 1.0, 1.3, 1.6, 1.9]
	var elapsed := 0.0
	var ti := 0
	while ti < times.size():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed >= times[ti]:
			_frame_cam(_cam, _find(_p, "Skeleton3D") as Skeleton3D)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var fn := "res://_wc_%d.png" % ti
			get_viewport().get_texture().get_image().save_png(fn)
			print("WC_SHOT ", ti, " t=", elapsed)
			ti += 1
	print("WALKCYCLE_DONE")
	get_tree().quit(0)

func _frame_cam(cam: Camera3D, sk: Skeleton3D) -> void:
	if sk == null: return
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for i in sk.get_bone_count():
		var pp := (sk.global_transform * sk.get_bone_global_pose(i)).origin
		lo = lo.min(pp); hi = hi.max(pp)
	var c := (lo + hi) * 0.5
	var h: float = max(hi.y - lo.y, 1.0)
	var dist: float = h * 1.3 + 1.0
	cam.position = Vector3(c.x, c.y, c.z + dist)
	cam.look_at_from_position(cam.position, c, Vector3.UP)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
