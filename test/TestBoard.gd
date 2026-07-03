extends Node
## headless 驗證：第三期修行盤（CultivationBoard 資料/邏輯 + BoardApp UI + 手機入口）。
## 涵蓋：json 載入與圖連通性、解鎖前置/扣款判定、bonus 計算、舊存檔缺鍵相容、
## 劇情鎖節點、skill 節點直接習得（不經 SkillUnlockManager 雙重門檻）、手機選單入口。
## 跑法：Godot --headless res://test/TestBoard.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_json_load_and_connectivity()
	_test_node_states()
	_test_unlock_requires_and_cost()
	_test_bonus_calculation()
	_test_skill_node_direct_learn()
	_test_passive_flags()
	_test_story_lock()
	_test_old_save_missing_keys()
	_test_combatant_from_player_uses_bonus()
	await _test_board_app_ui()
	await _test_phone_menu_entry()
	print("BOARD_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _reset_player_board() -> void:
	GameManager.player["board_unlocked"] = ["core"]
	GameManager.player["daoxing"] = 0
	CultivationBoard.reload()

# ─── json 載入與圖連通性 ───
func _test_json_load_and_connectivity() -> void:
	var board: Dictionary = CultivationBoard.get_board()
	_check(not board.is_empty(), "cultivation_board.json 載入非空")
	var nodes: Array = CultivationBoard.get_nodes()
	_check(nodes.size() >= 24 and nodes.size() <= 40, "節點數量在合理範圍 (got %d)" % nodes.size())
	var ring_counts: Dictionary = {}
	for n in nodes:
		var r: int = int(n.ring)
		ring_counts[r] = ring_counts.get(r, 0) + 1
	_check(ring_counts.get(3, 0) >= 4 and ring_counts.get(3, 0) <= 6,
		"外環(師鎖)節點數 4~6 (got %d)" % ring_counts.get(3, 0))
	# 圖連通性：除 core 外，每節點可經 requires 鏈追溯到 core（無孤島）
	var ids: Dictionary = {}
	for n in nodes:
		ids[String(n.id)] = true
	var reachable: Dictionary = {"core": true}
	var changed: bool = true
	while changed:
		changed = false
		for n in nodes:
			var nid: String = String(n.id)
			if reachable.has(nid):
				continue
			var reqs: Array = n.get("requires", [])
			if reqs.is_empty():
				continue
			var all_met: bool = true
			for r in reqs:
				if not reachable.has(String(r)):
					all_met = false
					break
			if all_met:
				reachable[nid] = true
				changed = true
	var unreachable: Array = []
	for nid in ids:
		if not reachable.has(nid):
			unreachable.append(nid)
	_check(unreachable.is_empty(), "requires 圖無孤島 (unreachable=%s)" % str(unreachable))
	# requires 引用的 id 都存在
	var bad_refs: Array = []
	for n in nodes:
		for r in n.get("requires", []):
			if not ids.has(String(r)):
				bad_refs.append("%s->%s" % [n.id, r])
	_check(bad_refs.is_empty(), "requires 引用皆為有效節點 id (bad=%s)" % str(bad_refs))

# ─── 節點四態 ───
func _test_node_states() -> void:
	_reset_player_board()
	_check(CultivationBoard.node_state("core") == "unlocked", "core 恆已解鎖")
	# 找一個以 core 為前置的環1節點
	var ring1_node: String = ""
	for n in CultivationBoard.get_nodes():
		if n.requires.has("core") and int(n.ring) == 1:
			ring1_node = String(n.id)
			break
	_check(ring1_node != "", "找到環1節點供測試")
	if ring1_node != "":
		_check(CultivationBoard.node_state(ring1_node) == "available", "前置達成(core)→available (got %s)" % CultivationBoard.node_state(ring1_node))
	# 找一個環2節點（前置未達，應為 locked）
	var ring2_node: String = ""
	for n in CultivationBoard.get_nodes():
		if int(n.ring) == 2:
			ring2_node = String(n.id)
			break
	_check(ring2_node != "" and CultivationBoard.node_state(ring2_node) == "locked",
		"環2節點前置未達→locked (got %s)" % CultivationBoard.node_state(ring2_node))

# ─── 解鎖前置/扣款判定 ───
func _test_unlock_requires_and_cost() -> void:
	_reset_player_board()
	var ring1_node: String = ""
	var cost: int = 0
	for n in CultivationBoard.get_nodes():
		if n.requires.has("core") and String(n.type) == "stat":
			ring1_node = String(n.id)
			cost = int(n.cost)
			break
	_check(ring1_node != "", "找到 stat 節點供扣款測試")
	if ring1_node == "":
		return
	# 道行不足 → 不可解鎖
	GameManager.player.daoxing = cost - 1
	_check(not CultivationBoard.can_unlock(ring1_node), "道行不足時 can_unlock=false")
	_check(not CultivationBoard.unlock_node(ring1_node), "道行不足時 unlock_node 失敗")
	_check(int(GameManager.player.daoxing) == cost - 1, "失敗解鎖不扣款")
	# 道行足夠 → 可解鎖，成功後扣款+加入 board_unlocked
	GameManager.player.daoxing = cost
	_check(CultivationBoard.can_unlock(ring1_node), "道行足夠時 can_unlock=true")
	_check(CultivationBoard.unlock_node(ring1_node), "unlock_node 成功")
	_check(int(GameManager.player.daoxing) == 0, "解鎖成功扣款正確 (剩 %d)" % int(GameManager.player.daoxing))
	_check(ring1_node in GameManager.player.board_unlocked, "節點加入 board_unlocked")
	_check(not CultivationBoard.can_unlock(ring1_node), "已解鎖節點不可再次解鎖")
	# 前置未達的環2節點：即使道行給滿也不可解鎖
	var ring2_node: String = ""
	for n in CultivationBoard.get_nodes():
		if int(n.ring) == 2:
			ring2_node = String(n.id)
			break
	GameManager.player.daoxing = 99999
	_check(not CultivationBoard.can_unlock(ring2_node), "前置未達時即使道行足夠仍不可解鎖")

# ─── bonus 計算 ───
func _test_bonus_calculation() -> void:
	_reset_player_board()
	var b0: Dictionary = CultivationBoard.compute_bonus()
	_check(int(b0.hp) == 0 and int(b0.atk) == 0 and int(b0.def) == 0 and int(b0.spd) == 0,
		"僅 core 時 bonus 全 0")
	# 手動解鎖兩個 stat 節點，驗證累加
	var atk_nodes: Array = []
	for n in CultivationBoard.get_nodes():
		if String(n.type) == "stat" and n.effect.get("stat", "") == "atk":
			atk_nodes.append(n)
	_check(atk_nodes.size() >= 2, "atk 節點至少 2 個供累加測試")
	var expected_atk: int = 0
	GameManager.player.daoxing = 999999
	# 依 requires 鏈依序解鎖前兩個可達的 atk 節點
	var unlocked_count: int = 0
	for n in atk_nodes:
		var nid: String = String(n.id)
		if CultivationBoard.can_unlock(nid):
			CultivationBoard.unlock_node(nid)
			expected_atk += int(n.effect.add)
			unlocked_count += 1
		if unlocked_count >= 2:
			break
	var b1: Dictionary = CultivationBoard.compute_bonus()
	_check(int(b1.atk) == expected_atk, "atk bonus 累加正確 (expected %d, got %d)" % [expected_atk, int(b1.atk)])

# ─── skill 節點：解鎖即直接習得（不經 SkillUnlockManager 雙重門檻）───
func _test_skill_node_direct_learn() -> void:
	_reset_player_board()
	var skill_node: String = ""
	var learn_id: String = ""
	for n in CultivationBoard.get_nodes():
		if String(n.type) == "skill":
			skill_node = String(n.id)
			learn_id = String(n.effect.learn_skill)
			break
	_check(skill_node != "", "找到 skill 型節點")
	if skill_node == "":
		return
	GameManager.player.skills_unlocked.erase(learn_id)
	_check(learn_id not in GameManager.player.skills_unlocked, "測試前確保未習得 %s" % learn_id)
	# 手動滿足所有前置
	GameManager.player.daoxing = 999999
	_unlock_chain_to(skill_node)
	_check(CultivationBoard.unlock_node(skill_node), "skill 節點解鎖成功")
	_check(learn_id in GameManager.player.skills_unlocked, "解鎖後技能直接進 skills_unlocked (%s)" % learn_id)
	# 確認該技能不在 SkillUnlockManager.UNLOCK_TABLE 的雙重門檻中（board 專屬技能）
	_check(not SkillUnlockManager.UNLOCK_TABLE.has(learn_id),
		"board 專屬技能不在 SkillUnlockManager.UNLOCK_TABLE (避免雙重門檻)")

## 依 requires 鏈把 target 的所有前置（遞迴）都解鎖，方便測試深層節點。
func _unlock_chain_to(target: String) -> void:
	var n: Dictionary = CultivationBoard.get_node_def(target)
	for req in n.get("requires", []):
		var rid: String = String(req)
		if not CultivationBoard.is_unlocked(rid):
			_unlock_chain_to(rid)
			CultivationBoard.unlock_node(rid)

# ─── passive 節點：戰鬥端可讀旗標 ───
func _test_passive_flags() -> void:
	_reset_player_board()
	var passive_node: String = ""
	var passive_id: String = ""
	for n in CultivationBoard.get_nodes():
		if String(n.type) == "passive" and String(n.id) != "core":
			passive_node = String(n.id)
			passive_id = String(n.effect.passive)
			break
	_check(passive_node != "", "找到 passive 型節點")
	if passive_node == "":
		return
	_check(not CultivationBoard.has_passive(passive_id), "解鎖前 has_passive=false")
	GameManager.player.daoxing = 999999
	_unlock_chain_to(passive_node)
	CultivationBoard.unlock_node(passive_node)
	_check(CultivationBoard.has_passive(passive_id), "解鎖後 has_passive=true (%s)" % passive_id)

# ─── 劇情鎖（外環）───
func _test_story_lock() -> void:
	_reset_player_board()
	GameManager.player.flags.erase("c1_master_trial")
	var outer_node: String = ""
	for n in CultivationBoard.get_nodes():
		if int(n.ring) == 3:
			outer_node = String(n.id)
			break
	_check(outer_node != "", "找到外環節點")
	if outer_node == "":
		return
	GameManager.player.daoxing = 999999
	_unlock_chain_to(outer_node)
	_check(CultivationBoard.node_state(outer_node) == "story_locked",
		"未達 c1_master_trial 時外環節點為 story_locked (got %s)" % CultivationBoard.node_state(outer_node))
	_check(not CultivationBoard.can_unlock(outer_node), "劇情鎖節點即使前置+道行皆足也不可解鎖")
	GameManager.set_flag("c1_master_trial", true)
	_check(CultivationBoard.node_state(outer_node) == "available",
		"達成 c1_master_trial 後外環節點變 available (got %s)" % CultivationBoard.node_state(outer_node))
	GameManager.player.flags.erase("c1_master_trial")

# ─── 舊存檔缺鍵相容 ───
func _test_old_save_missing_keys() -> void:
	GameManager.player.erase("board_unlocked")
	_check(not GameManager.player.has("board_unlocked"), "測試前確認鍵已移除")
	# node_state/compute_bonus 等入口呼叫時應自動補回 ["core"]，不炸
	var state: String = CultivationBoard.node_state("core")
	_check(state == "unlocked", "缺鍵時呼叫 node_state 不炸且 core 視為已解鎖 (got %s)" % state)
	_check(GameManager.player.has("board_unlocked") and "core" in GameManager.player.board_unlocked,
		"缺鍵防呆後自動重建 board_unlocked=[core]")
	var b: Dictionary = CultivationBoard.compute_bonus()
	_check(int(b.hp) == 0, "缺鍵重建後 compute_bonus 不炸 (hp=0)")
	# GameManager 自身的 _ensure_battle_keys 路徑也要防呆（daoxing/weakness_intel）
	GameManager.player.erase("daoxing")
	GameManager.add_daoxing(10)
	_check(int(GameManager.player.get("daoxing", -1)) == 10, "GameManager 缺 daoxing 鍵防呆 (got %d)" % int(GameManager.player.get("daoxing", -1)))
	_reset_player_board()

# ─── Combatant.from_player() 吃 bonus ───
func _test_combatant_from_player_uses_bonus() -> void:
	_reset_player_board()
	GameManager.player.max_hp = 500
	GameManager.player.current_hp = 500
	var c0 := Combatant.from_player()
	_check(c0.max_hp == 500 and c0.attack == 100 and c0.defense == 10 and c0.speed == 15,
		"僅 core 時基礎值不變 (hp=%d atk=%d def=%d spd=%d)" % [c0.max_hp, c0.attack, c0.defense, c0.speed])
	# 解鎖一個 hp 節點與一個 spd 節點，驗證 Combatant 讀到加成
	var hp_node: Dictionary = {}
	var spd_node: Dictionary = {}
	for n in CultivationBoard.get_nodes():
		if String(n.type) == "stat" and n.effect.get("stat", "") == "hp" and hp_node.is_empty():
			hp_node = n
		if String(n.type) == "stat" and n.effect.get("stat", "") == "spd" and spd_node.is_empty():
			spd_node = n
	GameManager.player.daoxing = 999999
	_unlock_chain_to(String(hp_node.id))
	CultivationBoard.unlock_node(String(hp_node.id))
	_unlock_chain_to(String(spd_node.id))
	CultivationBoard.unlock_node(String(spd_node.id))
	var c1 := Combatant.from_player()
	_check(c1.max_hp == 500 + int(hp_node.effect.add), "Combatant.max_hp 含 hp bonus (got %d)" % c1.max_hp)
	_check(c1.speed == 15 + int(spd_node.effect.add), "Combatant.speed 含 spd bonus (got %d)" % c1.speed)
	_reset_player_board()
	GameManager.player.max_hp = 500
	GameManager.player.current_hp = 500

# ─── BoardApp UI 煙霧 ───
func _test_board_app_ui() -> void:
	_reset_player_board()
	var app_ps = load("res://src/ui/menu/pages/BoardApp.gd")
	_check(app_ps != null, "load BoardApp.gd")
	if app_ps == null:
		return
	var app = app_ps.new()
	get_tree().root.add_child(app)
	for i in 3:
		await get_tree().process_frame
	_check(is_instance_valid(app), "BoardApp alive after ready")
	_check(app.has_method("select_node"), "BoardApp has select_node")
	# 選中一個可解鎖節點，驗證資訊面板刷新不崩
	var ring1_node: String = ""
	for n in CultivationBoard.get_nodes():
		if n.requires.has("core"):
			ring1_node = String(n.id)
			break
	if ring1_node != "":
		app.select_node(ring1_node)
		await get_tree().process_frame
		_check(is_instance_valid(app), "select_node 後仍存活")
	app.queue_free()
	await get_tree().process_frame

# ─── 手機選單入口 ───
func _test_phone_menu_entry() -> void:
	var shell = load("res://src/ui/menu/MenuShell.tscn").instantiate()
	shell.set("pause_game", false)
	get_tree().root.add_child(shell)
	for i in 3:
		await get_tree().process_frame
	shell._show_device("phone")
	await get_tree().process_frame
	var phone_pages: Array = shell._devices["phone"]["pages"]
	var titles: Array = []
	for p in phone_pages:
		titles.append(p.title)
	_check("修行" in titles, "手機選單含「修行」app")
	var idx: int = titles.find("修行")
	if idx != -1:
		shell._show_page(idx)
		await get_tree().process_frame
		_check(is_instance_valid(shell), "開啟修行頁不崩")
	shell.queue_free()
	await get_tree().process_frame
