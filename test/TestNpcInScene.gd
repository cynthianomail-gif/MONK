extends Node
## 確認神社區 11 個 NPC 模型真的被置入場景(NpcFigure._model 載到；npc_alms 無模型)。
func _ready() -> void:
	GameManager.new_game()
	var ms := (load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene).instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var trigs := get_tree().get_nodes_in_group("location_trigger")
	var with_npc := 0
	for t in trigs:
		var fig: Node = t.get_node_or_null("NpcFigure")
		if fig != null and fig.get("_model") != null:
			with_npc += 1
			print("  NPC @ %s  pos=%s" % [t.location_id, str(t.global_position)])
	if with_npc != 11:
		push_error("TEST FAIL: 神社區應 11 個 NPC 模型，實 %d" % with_npc); get_tree().quit(1); return
	print("TEST PASS: 神社區 11 個 NPC 模型已置入")
	get_tree().quit(0)
