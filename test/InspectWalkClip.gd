extends Node
## 查 walk clip 的 loop_mode / length / 軌道數（診斷「腳不會動」）。

func _ready() -> void:
	var inst := (load("res://assets/3d/characters/wujie/wujie_walk.glb") as PackedScene).instantiate()
	add_child(inst)
	await get_tree().process_frame
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	if ap == null:
		print("NO AP"); get_tree().quit(1); return
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		print("CLIP '", name, "' len=", a.length, " loop=", a.loop_mode, " tracks=", a.get_track_count())
	get_tree().quit(0)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
