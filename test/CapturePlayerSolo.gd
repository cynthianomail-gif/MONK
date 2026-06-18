extends Node
## 單獨實例化正式 Player.tscn（會跑 PlayerAnimTree：生成 idle + 不透明修復），
## 自動框全身、播待機，存圖確認 3D 無戒在遊戲裡長怎樣。

func _ready() -> void:
	var world := Node3D.new()
	get_tree().root.call_deferred("add_child", world)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.4
	world.add_child(key)

	var p: Node3D = (load("res://src/screens/MapScreen/Player.tscn") as PackedScene).instantiate()
	# 關掉物理控制，純展示（避免重力把它往下掉出視野）
	p.set_physics_process(false)
	world.add_child(p)
	# 等 PlayerAnimTree 延幀初始化 + idle 上身
	for i in 30:
		await get_tree().process_frame

	var cam := Camera3D.new()
	cam.fov = 50
	world.add_child(cam)
	cam.make_current()
	_frame_cam(cam, _find(p, "Skeleton3D") as Skeleton3D)

	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_player_solo.png")
	print("SOLO_IDLE_SAVED")

	# 切到走路（blend=1）驗證 walk clip 播得出來
	var at := p.get_node_or_null("AnimationTree") as AnimationTree
	if at:
		at.set("parameters/blend/blend_amount", 1.0)
	for i in 25:
		await get_tree().process_frame
	_frame_cam(cam, _find(p, "Skeleton3D") as Skeleton3D)  # walk clip 可能帶位移，重新框
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_player_walk.png")
	print("SOLO_WALK_SAVED")
	get_tree().quit(0)

func _frame_cam(cam: Camera3D, sk: Skeleton3D) -> void:
	if sk == null: return
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for i in sk.get_bone_count():
		var pp := (sk.global_transform * sk.get_bone_global_pose(i)).origin
		lo = lo.min(pp); hi = hi.max(pp)
	var c := (lo + hi) * 0.5
	var h: float = max(hi.y - lo.y, 1.0)
	var dist: float = h * 1.4 + 1.0
	cam.position = Vector3(c.x, c.y, c.z + dist)
	cam.look_at_from_position(cam.position, c, Vector3.UP)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
