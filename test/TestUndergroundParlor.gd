extends Node
## 地下遊藝場房間結構 smoke test（headless）：
## 1) 場景能載入不崩、玩家在 group "player"
## 2) 4 個 LocationTrigger（3 賭具＋出口）id 齊全
##    （打擊籠/保齡球 2026-07-03 搬到神社街當店家，不再是這個房間的一部分）
## 3) 四面牆擋得住玩家（探針往東推不出房）

const EXPECT_IDS := [
	"darts_minigame", "roulette_minigame", "blackjack_minigame", "leave_parlor",
]

func _ready() -> void:
	var env := (load("res://src/screens/MapScreen/environments/UndergroundParlor.tscn") as PackedScene).instantiate()
	add_child(env)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1) 玩家存在
	if get_tree().get_first_node_in_group("player") == null:
		return _fail("場景內找不到 player")

	# 2) 觸發點 4 個且 id 齊全
	var trigs := get_tree().get_nodes_in_group("location_trigger")
	if trigs.size() != 4:
		return _fail("應 4 個觸發點（3 賭具＋出口），實 %d" % trigs.size())
	var ids: Array = []
	for t in trigs:
		ids.append(String(t.location_id))
	for want in EXPECT_IDS:
		if want not in ids:
			return _fail("缺觸發點 %s（實有 %s）" % [want, str(ids)])

	# 3) 牆擋人：探針從房中心往 +X（東牆 x=5.0）推 90 個 physics frame
	var probe := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	probe.add_child(cs)
	add_child(probe)
	probe.global_position = Vector3(0.0, 1.0, 0.5)
	for i in 90:
		probe.velocity = Vector3(9.0, 0.0, 0.0)
		probe.move_and_slide()
		await get_tree().physics_frame
	if probe.global_position.x > 5.1:
		return _fail("探針穿出東牆：x=%.2f（應 <5.1）" % probe.global_position.x)

	print("TEST PASS: 地下遊藝場 房間+4 觸發點+牆 OK（探針 x=%.2f）" % probe.global_position.x)
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
