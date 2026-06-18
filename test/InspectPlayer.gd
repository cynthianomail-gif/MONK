extends Node
## 實例化 Player.tscn，傾印節點樹 + 找得到的 AnimationPlayer/Skeleton/clips，
## 用來查 PlayerAnimTree「缺 AnimationPlayer/Skeleton」的原因。

func _ready() -> void:
	var ps: PackedScene = load("res://src/screens/MapScreen/Player.tscn")
	var p: Node = ps.instantiate()
	add_child(p)
	await get_tree().process_frame
	print("=== TREE ===")
	_dump(p, 0)
	print("=== FIND ===")
	var ap := _find(p, "AnimationPlayer")
	var sk := _find(p, "Skeleton3D")
	print("AnimationPlayer: ", ap)
	print("Skeleton3D: ", sk)
	if ap:
		print("clips: ", ap.get_animation_list())
		print("ap.root_node: ", ap.root_node, " -> ", ap.get_node(ap.root_node))
	get_tree().quit(0)

func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d), n.name, "  [", n.get_class(), "]")
	for c in n.get_children():
		_dump(c, d + 1)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
