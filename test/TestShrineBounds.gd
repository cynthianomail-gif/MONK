extends Node
## 驗證 L 形神社街的隱形邊界牆會擋住玩家（不能走進空曠虛空）。
## 放一個 CharacterBody3D 探針，往東牆(x=5.5)推 → 應被擋在牆內。

func _ready() -> void:
	var env := (load("res://src/screens/MapScreen/environments/ShrineStreet.tscn") as PackedScene).instantiate()
	add_child(env)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var probe := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	probe.add_child(cs)
	add_child(probe)
	probe.global_position = Vector3(3.5, 1.0, -10.0)

	# 持續往 +X（東牆方向）推 90 個 physics frame
	for i in 90:
		probe.velocity = Vector3(9.0, 0.0, 0.0)
		probe.move_and_slide()
		await get_tree().physics_frame

	# 東牆在 x=5.5，探針半徑 0.4 → 應停在 ~5.1 附近，絕不該越過 5.6
	if probe.global_position.x > 5.6:
		return _fail("玩家穿過東邊界牆：x=%.2f（應 <5.6）" % probe.global_position.x)

	print("TEST PASS: 邊界牆擋住玩家 OK（x=%.2f）" % probe.global_position.x)
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
