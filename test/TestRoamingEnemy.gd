extends Node
## 驗證路上漫遊敵人：載模型、閒晃留在巡邏區、玩家近則追、追到 emit caught_player。

const ROAMING_ENEMY := preload("res://src/screens/MapScreen/RoamingEnemy.gd")

func _ready() -> void:
	# 假玩家（group "player"），先放遠處避免一生成就被追。
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3(50, 0, 50)

	var data := {
		"enemy_id": "street_punk", "model": "street_punk",
		"patrol_center": {"x": 0.0, "z": 0.0}, "patrol_radius": 4.0
	}
	var enemy: Node3D = ROAMING_ENEMY.new()
	add_child(enemy)
	enemy.setup(data)

	var caught := [false, ""]
	enemy.caught_player.connect(func(id): caught[0] = true; caught[1] = id)

	# 1) 模型載入（GLB 存在）
	if enemy.get_child_count() == 0:
		return _fail("敵人模型未載入（street_punk.glb 應存在）")

	# 2) 閒晃：跑一陣子仍應留在巡邏區附近（home±radius+緩衝）、且未誤觸發
	for i in 90:
		await get_tree().physics_frame
	var d_home := enemy.global_position.distance_to(Vector3.ZERO)
	if d_home > 6.5:
		return _fail("閒晃跑出巡邏區太遠：%.1f" % d_home)
	if caught[0]:
		return _fail("玩家在遠處卻誤觸發遭遇戰")

	# 3) 追擊＋追到：玩家貼上去 → 應 emit caught_player("street_punk")
	player.global_position = enemy.global_position + Vector3(0.5, 0, 0.5)
	var fired := false
	for i in 120:
		await get_tree().physics_frame
		if caught[0]:
			fired = true
			break
	if not fired:
		return _fail("玩家貼身卻沒觸發遭遇戰")
	if caught[1] != "street_punk":
		return _fail("caught_player 帶錯 enemy_id：%s" % caught[1])

	print("TEST PASS: 路上漫遊敵人（載入/閒晃/追擊/觸發）OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
