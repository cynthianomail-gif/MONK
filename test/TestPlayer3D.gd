extends Node
## 驗證 Player.tscn：AnimationTree 自動建出 idle↔walk 混合樹（含 blend 參數）、
## 生成 idle clip、PlayerController 能驅動位移。
## PlayerAnimTree._ready 會延一幀建樹，故檢查前先等數幀。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestPlayer3D.tscn

func _ready() -> void:
	await get_tree().process_frame
	var p := (load("res://src/screens/MapScreen/Player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	# 等 PlayerAnimTree 延幀初始化
	for i in 5:
		await get_tree().process_frame

	var at := p.get_node_or_null("AnimationTree") as AnimationTree
	if at == null: return _fail("無 AnimationTree")
	if at.tree_root == null: return _fail("AnimationTree.tree_root 未建（clip 偵測失敗？）")
	var v = at.get("parameters/blend/blend_amount")
	if v == null: return _fail("無 parameters/blend/blend_amount")

	# idle clip 應已生成在模型的 AnimationPlayer
	var ap := _find_ap(p)
	if ap == null: return _fail("模型無 AnimationPlayer")
	if not ap.get_animation_list().has("idle_gen"):
		return _fail("idle_gen 未生成，clips=%s" % str(ap.get_animation_list()))

	# 模擬移動：設 velocity 跑一次 physics，確認會位移
	var before: Vector3 = p.global_position
	p.velocity = Vector3(3, 0, 0)
	p.call("move_and_slide")
	if p.global_position.distance_to(before) <= 0.0:
		return _fail("move_and_slide 未位移")

	print("TEST PASS: Player3D AnimationTree＋blend＋idle_gen＋位移 OK")
	get_tree().quit(0)

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r: return r
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
