extends Node
## 端湯純邏輯：晃動溢出、各灑出門檻 payout、完美/streak bonus、碰撞扣到 0。
const SC := preload("res://src/screens/Minigames/SoupCarry.gd")

var _ok := true

func _ready() -> void:
	_test_slosh_spills()
	if _ok: _test_payout_thresholds()
	if _ok: _test_perfect_and_streak()
	if _ok: _test_collision_floor()
	if _ok:
		print("ALL PASS: SoupCarry 純邏輯")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _ck(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		push_error("TEST FAIL: %s" % msg)

func _test_slosh_spills() -> void:
	var calm = SC.new()
	for i in 120: calm.step_slosh(1.0 / 60.0, 300.0, false, false)   # 平穩(deadzone 內)
	_ck(calm.soup_amount > 99.0, "平穩移動不該灑(got %.1f)" % calm.soup_amount)
	var wild = SC.new()
	for i in 40: wild.step_slosh(1.0 / 60.0, 4500.0, false, false)   # 猛操作(部分灑、不見底)
	_ck(wild.soup_amount < 99.0 and wild.soup_amount > 1.0, "猛操作該灑(got %.1f)" % wild.soup_amount)
	var steady = SC.new()
	for i in 40: steady.step_slosh(1.0 / 60.0, 4500.0, false, true)  # 緩步
	_ck(steady.soup_amount > wild.soup_amount, "緩步該比一般少灑(%.1f vs %.1f)" % [steady.soup_amount, wild.soup_amount])

func _test_payout_thresholds() -> void:
	var a = SC.new(); a.soup_amount = 80.0            # spill 20 → 100-20
	_ck(a.settle_payout() == 80, "spill20 應 80")
	var b = SC.new(); b.soup_amount = 50.0            # spill 50 → 50-50=0
	_ck(b.settle_payout() == 0, "spill50 應 0")
	var b2 = SC.new(); b2.soup_amount = 55.0          # spill 45 → 50-45=5
	_ck(b2.settle_payout() == 5, "spill45 應 5")
	var c = SC.new(); c.soup_amount = 20.0            # spill 80 → 作廢
	_ck(c.settle_payout() == 0 and c.failed_count == 1, "spill80 應作廢")

func _test_perfect_and_streak() -> void:
	var s = SC.new()
	s.soup_amount = 97.0                              # spill 3 → 97 +20完美 = 117, streak=1
	_ck(s.settle_payout() == 117, "spill3 完美應 117(got %d)" % s.income)
	s.reset_bowl(); s.soup_amount = 93.0; s.settle_payout()   # spill7, streak=2
	s.reset_bowl(); s.soup_amount = 93.0
	var p3 = s.settle_payout()                        # spill7, streak=3 → +50 = 143
	_ck(p3 == 143, "第3碗連續低灑應 +50=143(got %d)" % p3)

func _test_collision_floor() -> void:
	var s = SC.new(); s.soup_amount = 90.0; s.collision_penalty = 200   # 90-200 → 0
	_ck(s.settle_payout() == 0, "碰撞扣到 0 不負")
