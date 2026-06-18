extends Node
## 一次試多組「手臂下垂」旋轉：對每組 (axis,deg) 設 LeftArm(+deg)/RightArm(-deg) pose→固定相機渲染。
## 存 _pose_<axis><deg>.png 多張，比對哪組讓 T-pose 手臂自然垂到身側。
## 跑法：Godot_..._console.exe --path D:/monk/MONK res://test/PoseTest.tscn

# [標籤, 左臂deg, 右臂deg]，皆繞 Z(BACK)
const TRIES := [["Lp_Rp", 75.0, 75.0], ["Ln_Rn", -75.0, -75.0], ["Lp80_Rn80", 80.0, -80.0], ["Ln_Rp", -75.0, 75.0]]

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.85)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-40, 35, 0); key.light_energy = 1.1; root.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.position = Vector3(0.9, 1.05, 3.4)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	root.add_child(cam); cam.make_current()

	for t in TRIES:
		var label: String = t[0]
		var ldeg: float = t[1]
		var rdeg: float = t[2]
		var inst := (load("res://assets/3d/characters/wujie/wujie_walk.glb") as PackedScene).instantiate()
		root.add_child(inst)
		await get_tree().process_frame
		for n in _all(inst):
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var mi := n as MeshInstance3D
				for s in mi.mesh.get_surface_count():
					var m = mi.mesh.surface_get_material(s)
					if m is BaseMaterial3D:
						m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
						var c: Color = m.albedo_color; c.a = 1.0; m.albedo_color = c
		var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
		if ap: ap.stop()
		var sk := _find(inst, "Skeleton3D") as Skeleton3D
		var ax := Vector3.BACK
		_set_arm(sk, "LeftArm", ax, ldeg)
		_set_arm(sk, "RightArm", ax, rdeg)
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var fn := "res://_pose_%s.png" % label
		get_tree().root.get_viewport().get_texture().get_image().save_png(fn)
		print("POSE_SAVED ", fn)
		inst.queue_free()
		await get_tree().process_frame
	print("POSE_BATCH_DONE")
	get_tree().quit(0)

func _set_arm(sk: Skeleton3D, bone: String, ax: Vector3, deg: float) -> void:
	if sk == null: return
	var idx := sk.find_bone(bone)
	if idx < 0:
		print("NO BONE ", bone); return
	sk.set_bone_pose_rotation(idx, Quaternion(ax.normalized(), deg_to_rad(deg)))

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
