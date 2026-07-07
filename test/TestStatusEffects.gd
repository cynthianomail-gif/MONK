extends Node
## StatusEffects 單元測試（2026-07-08 修「stun/slow 雙處扣 duration」時補）。
## 核心情境：狀態上在「受害者本回合已行動之後」，回合結算不得把它清掉，
## 下回合輪到受害者時必須真的跳過。

const STATUS_SCRIPT := preload("res://src/screens/BattleScreen/StatusEffects.gd")

func _make(cid: String) -> Combatant:
	var c := Combatant.new()
	c.id = cid
	c.max_hp = 100
	c.current_hp = 100
	return c

func _ready() -> void:
	var status: Node = STATUS_SCRIPT.new()
	add_child(status)

	# 1) 順序依賴修復：stun(1) 上在受害者已行動後 → 回合結算 → 下回合仍被跳過，之後解除
	var a := _make("victim_after_act")
	status.apply("stun", a, 1)
	status.process_turn_end(a)                     # 該回合結算（受害者已行動過）
	if not status.has_status(a, "stun"):
		return _fail("回合結算不得消耗 stun（雙重扣回歸）")
	if status.process_turn_start(a):
		return _fail("stun(1) 下回合應跳過行動")
	if status.has_status(a, "stun"):
		return _fail("stun 消耗完應移除")
	if not status.process_turn_start(a):
		return _fail("stun 解除後應可行動")

	# 2) stun 上在受害者行動前 → 當回合跳過一次，僅一次
	var b := _make("victim_before_act")
	status.apply("stun", b, 1)
	if status.process_turn_start(b):
		return _fail("stun(1) 當回合應跳過")
	status.process_turn_end(b)
	if not status.process_turn_start(b):
		return _fail("stun(1) 只應跳過一次")

	# 3) slow(2) = 連續跳過兩次行動，不受回合結算影響
	var c := _make("slowpoke")
	status.apply("slow", c, 2)
	if status.process_turn_start(c): return _fail("slow(2) 第1次應跳過")
	status.process_turn_end(c)
	if status.process_turn_start(c): return _fail("slow(2) 第2次應跳過")
	status.process_turn_end(c)
	if not status.process_turn_start(c): return _fail("slow(2) 第3次應恢復行動")

	# 4) burn/poison 仍走回合結算：扣血＋到期移除
	var d := _make("burner")
	status.apply("burn", d, 2)
	status.process_turn_end(d)
	if d.current_hp != 85: return _fail("burn 應扣 15，實剩 %d" % d.current_hp)
	status.process_turn_end(d)
	if d.current_hp != 70: return _fail("burn 第2回合應再扣 15")
	if status.has_status(d, "burn"): return _fail("burn(2) 兩回合後應移除")

	# 5) 疊毒：2 層 poison 每回合扣 10*2
	var e := _make("poisoned")
	status.apply("poison", e, 2)
	status.apply("poison", e, 2)
	status.process_turn_end(e)
	if e.current_hp != 60: return _fail("2層毒應扣 40(2次結算×20)，實剩 %d" % e.current_hp)

	print("TEST PASS: StatusEffects（stun順序無關/單次消耗/slow連跳/burn/疊毒） OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
