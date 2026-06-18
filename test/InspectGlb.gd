extends Node
## 印 GLB 的 AABB、surface 數、AnimationPlayer clip 名、Skeleton3D 骨骼名。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/InspectGlb.tscn -- <res 路徑>

func _ready() -> void:
	var path := "res://assets/3d/characters/wujie/wujie_walk.glb"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		path = ua[0]
	var inst := (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	var aabb := AABB()
	var first := true
	var clips: Array = []
	var bones: Array = []
	var surfaces := 0
	for n in _all(inst):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var a: AABB = mi.global_transform * mi.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
			if mi.mesh:
				surfaces += mi.mesh.get_surface_count()
		elif n is Skeleton3D:
			var sk := n as Skeleton3D
			for i in sk.get_bone_count():
				bones.append(sk.get_bone_name(i))
		elif n is AnimationPlayer:
			clips = (n as AnimationPlayer).get_animation_list()
	print("GLB_AABB ", aabb.size)
	print("GLB_SURFACES ", surfaces)
	print("GLB_CLIPS ", clips)
	print("GLB_BONES ", bones)
	get_tree().quit(0)

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
