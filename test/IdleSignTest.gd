extends Node
## 用「動畫軌」路徑（跟正式 _make_idle 同法）測 LeftArm/RightArm 各 sign 組合，
## 找出雙臂都自然下垂的組合。自動依骨架 global 位置框相機。

const GLB := "res://assets/3d/characters/wujie/wujie_walk.glb"
const DEG := 90.0
# label, axis, left_deg_scale, right_deg_scale  — 雙臂同號 +RIGHT 下垂，試角度
const TRIES := [
	["down90", Vector3.RIGHT, 1.0, 1.0],
	["down80", Vector3.RIGHT, 80.0/90.0, 80.0/90.0],
	["down72", Vector3.RIGHT, 72.0/90.0, 72.0/90.0],
]

func _ready() -> void:
	var world := Node3D.new()
	get_tree().root.call_deferred("add_child", world)
	await get_tree().process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.7
	env.environment = e; world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0); key.light_energy = 1.3
	world.add_child(key)
	var cam := Camera3D.new(); cam.fov = 50; world.add_child(cam)

	for t in TRIES:
		var label: String = t[0]
		var ax: Vector3 = t[1]
		var ls: float = t[2]
		var rs: float = t[3]
		var inst := (load(GLB) as PackedScene).instantiate()
		world.add_child(inst)
		await get_tree().process_frame
		_opaque(inst)
		var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
		var sk := _find(inst, "Skeleton3D") as Skeleton3D
		var clip := _build_idle(ap, sk, ax, ls, rs)
		ap.play(clip)
		for i in 8: await get_tree().process_frame
		_frame_cam(cam, sk)
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://_idle_%s.png" % label)
		print("IDLE_SAVED ", label)
		inst.queue_free()
		await get_tree().process_frame
	print("IDLE_SIGN_DONE")
	get_tree().quit(0)

func _build_idle(ap: AnimationPlayer, sk: Skeleton3D, ax: Vector3, ls: float, rs: float) -> String:
	var anim := Animation.new(); anim.length = 1.0; anim.loop_mode = Animation.LOOP_LINEAR
	var base := ap.get_node(ap.root_node)
	var skp := String(base.get_path_to(sk))
	var signs := {"LeftArm": ls, "RightArm": rs}
	for bone in signs.keys():
		if sk.find_bone(bone) < 0: continue
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, "%s:%s" % [skp, bone])
		anim.rotation_track_insert_key(tr, 0.0, Quaternion(ax.normalized(), deg_to_rad(DEG * signs[bone])))
	if not ap.has_animation_library(""): ap.add_animation_library("", AnimationLibrary.new())
	ap.get_animation_library("").add_animation("idle_gen", anim)
	return "idle_gen"

func _frame_cam(cam: Camera3D, sk: Skeleton3D) -> void:
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for i in sk.get_bone_count():
		var p := (sk.global_transform * sk.get_bone_global_pose(i)).origin
		lo = lo.min(p); hi = hi.max(p)
	var c := (lo + hi) * 0.5
	var h: float = max(hi.y - lo.y, 1.0)
	var dist: float = h * 1.4 + 1.0
	cam.position = Vector3(c.x, c.y, c.z + dist)
	cam.look_at_from_position(cam.position, c, Vector3.UP)

func _opaque(n: Node) -> void:
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					var col: Color = m.albedo_color; col.a = 1.0; m.albedo_color = col

func _all(n: Node, acc: Array = []) -> Array:
	acc.append(n)
	for c in n.get_children(): _all(c, acc)
	return acc

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
