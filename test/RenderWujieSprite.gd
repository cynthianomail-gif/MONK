extends Node
## 把 3D 無戒渲成側面 idle/walk 透明 PNG。
## 跑法（視窗）：Godot_..._win64.exe --path D:/monk/MONK res://test/RenderWujieSprite.tscn
const GLB := "res://assets/3d/characters/wujie/wujie_walk.glb"
const OUT := "res://assets/2d/characters/wujie/sprite/"
const WALK_FRAMES := 8
const SIZE := Vector2i(256, 384)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var world := Node3D.new(); vp.add_child(world)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-30, -35, 0); key.light_energy = 1.3; world.add_child(key)
	var amb := WorldEnvironment.new(); var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1,1,1); e.ambient_light_energy = 0.7
	amb.environment = e; world.add_child(amb)
	var model: Node3D = (load(GLB) as PackedScene).instantiate(); world.add_child(model)
	await get_tree().process_frame
	_opaque(model)
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	var sk := _find(model, "Skeleton3D") as Skeleton3D
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.2
	cam.position = Vector3(3.0, 0.9, 0.0); cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0), Vector3.UP)
	world.add_child(cam); cam.make_current()
	var walk := _walk_name(ap)
	ap.play(walk); ap.seek(0.0, true)
	for f in WALK_FRAMES:
		var t := (float(f) / WALK_FRAMES) * ap.get_animation(walk).length
		ap.seek(t, true)
		await get_tree().process_frame
		_recenter(model, sk)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + "walk_%d.png" % f)
		print("RENDER walk_%d" % f)
	ap.seek(0.0, true); await get_tree().process_frame; _recenter(model, sk)
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "idle_0.png")
	print("RENDER_SPRITE_DONE")
	get_tree().quit(0)

func _recenter(model: Node3D, sk: Skeleton3D) -> void:
	if sk == null: return
	var hips := sk.find_bone("Hips")
	if hips < 0: hips = 0
	var gp := (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	model.position.x -= gp.x
	model.position.z -= gp.z

func _opaque(n: Node) -> void:
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					var col: Color = m.albedo_color; col.a = 1.0; m.albedo_color = col
func _all(n: Node, a: Array = []) -> Array:
	a.append(n)
	for c in n.get_children(): _all(c, a)
	return a
func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
func _walk_name(ap: AnimationPlayer) -> String:
	for c in ap.get_animation_list():
		if String(c).to_lower().contains("walk"): return String(c)
	return ap.get_animation_list()[0]
