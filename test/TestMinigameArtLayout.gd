extends Node
## headless 測試：小遊戲美術圖素材佈局工具 v3 擴充（LayoutStore/LayoutTuner）。
## 跑法：Godot --headless res://test/TestMinigameArtLayout.tscn
## 規格：D:\monk\_minigame_art_inventory.md（盤點）＋ 派工單（v3 擴充）。
##
## 驗證：
##   1) 逐款 instantiate 小遊戲場景，斷言 LayoutStore.live_entries() 含該款新增的
##      綠框 key（每款至少抽 2 個代表 key，含 bg）。
##   2) 每款抽 1 個代表琥珀節點，斷言掛有 layout_template meta。
##   3) LayoutTuner 巢狀拖曳座標修正：對一個巢狀節點（化緣 _monk_sprite，掛在
##      _bowl_node 底下）模擬 apply_override / 拖曳，位置正確換算到父座標系。

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await _test_darts()
	await _test_bowling()
	await _test_blackjack()
	await _test_roulette()
	await _test_batting()
	await _test_offering_toss()
	await _test_wooden_fish()
	await _test_beggar_challenge()
	await _test_soup_carry()
	await _test_nested_drag_coords()
	print("MINIGAME_ART_LAYOUT_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

## 共用：instantiate 場景、跑一幀、回傳 inst；呼叫端負責 queue_free。
func _spawn(path: String) -> Node:
	var ps: PackedScene = load(path)
	if ps == null:
		_check(false, "load scene %s" % path)
		return null
	var inst = ps.instantiate()
	inst.set("auto_start", false)
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	return inst

func _has_live_key(key: String) -> bool:
	for e in LayoutStore.live_entries():
		if String(e.get("key", "")) == key:
			return true
	return false

## 掃節點樹找出掛了 layout_template meta 且值等於 key 的節點是否存在。
func _has_template_key(root: Node, key: String) -> bool:
	if root is CanvasItem and root.has_meta("layout_template") and String(root.get_meta("layout_template")) == key:
		return true
	for c in root.get_children():
		if _has_template_key(c, key):
			return true
	return false

func _finish(inst: Node) -> void:
	if is_instance_valid(inst):
		inst.queue_free()
	await get_tree().process_frame

# ────────────────────────────────────────────────────────────────
# 1) Darts：bg / gauge 綠框；_dart / mode_button 琥珀
# ────────────────────────────────────────────────────────────────
func _test_darts() -> void:
	var inst = await _spawn("res://src/screens/Minigames/Darts.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/darts/bg"), "darts: bg 綠框已登記")
	_check(_has_live_key("minigame/darts/gauge"), "darts: gauge 綠框已登記")
	_check(_has_template_key(inst, "minigame/darts/dart"), "darts: _dart 掛 layout_template 琥珀 meta")
	_check(_has_template_key(inst, "minigame/darts/reticle"), "darts: _reticle 掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 2) Bowling：bg / hud_label 綠框；_ball 琥珀
# ────────────────────────────────────────────────────────────────
func _test_bowling() -> void:
	var inst = await _spawn("res://src/screens/Minigames/Bowling.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/bowling/bg"), "bowling: bg 綠框已登記")
	_check(_has_live_key("minigame/bowling/hud_label"), "bowling: hud_label 綠框已登記")
	_check(_has_live_key("minigame/bowling/tip_label"), "bowling: tip_label 綠框已登記（原本缺漏）")
	_check(_has_template_key(inst, "minigame/bowling/ball"), "bowling: _ball 掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 3) Blackjack：bg / sub 綠框；card 琥珀
# ────────────────────────────────────────────────────────────────
func _test_blackjack() -> void:
	var inst = await _spawn("res://src/screens/Minigames/Blackjack.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/blackjack/bg"), "blackjack: bg 綠框已登記")
	_check(_has_live_key("minigame/blackjack/sub_label"), "blackjack: sub_label 綠框已登記（原本缺漏）")
	# card 是動態發牌節點，需觸發一次發牌才會存在；auto_start=false 跳過了
	# _new_round()/_reset_deck()，牌堆是空的，直接呼叫 _deal_animated 前先補建牌堆。
	inst._reset_deck()
	await inst._deal_animated(true, true)
	_check(_has_template_key(inst, "minigame/blackjack/card"), "blackjack: 發出的牌掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 4) Roulette：bg / glow 綠框；_wheel 琥珀
# ────────────────────────────────────────────────────────────────
func _test_roulette() -> void:
	var inst = await _spawn("res://src/screens/Minigames/Roulette.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/roulette/bg"), "roulette: bg 綠框已登記")
	_check(_has_live_key("minigame/roulette/glow"), "roulette: glow 綠框已登記")
	_check(_has_template_key(inst, "minigame/roulette/wheel"), "roulette: _wheel 掛 layout_template 琥珀 meta（WHEEL_CENTER 耦合珠路徑）")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 5) Batting：bg / machine 綠框；_ball 琥珀
# ────────────────────────────────────────────────────────────────
func _test_batting() -> void:
	var inst = await _spawn("res://src/screens/Minigames/Batting.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/batting/bg"), "batting: bg 綠框已登記")
	_check(_has_live_key("minigame/batting/machine"), "batting: machine 綠框已登記")
	_check(_has_live_key("minigame/batting/hands"), "batting: hands 綠框已登記")
	_check(_has_template_key(inst, "minigame/batting/ball"), "batting: _ball 掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 6) OfferingToss：bg / sweet_mark 綠框；box 琥珀（耦合查證：判定用常數非節點位置）
# ────────────────────────────────────────────────────────────────
func _test_offering_toss() -> void:
	var inst = await _spawn("res://src/screens/Minigames/OfferingToss.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/offeringtoss/bg"), "offeringtoss: bg 綠框已登記（純幾何 ColorRect 照樣登記）")
	_check(_has_live_key("minigame/offeringtoss/sweet_mark"), "offeringtoss: sweet_mark 綠框已登記")
	_check(_has_live_key("minigame/offeringtoss/gauge"), "offeringtoss: gauge 綠框已登記")
	_check(_has_template_key(inst, "minigame/offeringtoss/box"), "offeringtoss: box 掛 layout_template 琥珀 meta（耦合查證結論：判定用常數，拖圖會脫鉤）")
	_check(_has_template_key(inst, "minigame/offeringtoss/coin"), "offeringtoss: _coin 掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 7) WoodenFishRhythm：bg / monk_a / fish_a 綠框
# ────────────────────────────────────────────────────────────────
func _test_wooden_fish() -> void:
	var inst = await _spawn("res://src/screens/Minigames/WoodenFishRhythm.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/woodenfishrhythm/bg"), "woodenfish: bg 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/monk_a"), "woodenfish: monk_a 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/monk_b"), "woodenfish: monk_b 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/player"), "woodenfish: player 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/fish_a"), "woodenfish: fish_a 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/fish_b"), "woodenfish: fish_b 綠框已登記")
	_check(_has_live_key("minigame/woodenfishrhythm/fish_player"), "woodenfish: fish_player 綠框已登記")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 8) BeggarChallenge：bg 綠框、monk_sprite 綠框（巢狀於 bowl_node）；bowl_node 琥珀
# ────────────────────────────────────────────────────────────────
func _test_beggar_challenge() -> void:
	var inst = await _spawn("res://src/screens/Minigames/BeggarChallenge.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/beggarchallenge/bg"), "beggar: bg 綠框已登記")
	_check(_has_live_key("minigame/beggarchallenge/hud_score"), "beggar: hud_score 綠框已登記")
	_check(_has_live_key("minigame/beggarchallenge/monk_sprite"), "beggar: monk_sprite（巢狀於 bowl_node）綠框已登記")
	_check(_has_template_key(inst, "minigame/beggarchallenge/bowl_node"), "beggar: _bowl_node 掛 layout_template 琥珀 meta")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 9) SoupCarry：唯一 3D 小遊戲，只有 2D HUD 可調（3D 內景不在範疇）
# ────────────────────────────────────────────────────────────────
func _test_soup_carry() -> void:
	var inst = await _spawn("res://src/screens/Minigames/SoupCarry.tscn")
	if inst == null:
		return
	_check(_has_live_key("minigame/soupcarry/hud_time") or _has_live_key("minigame/common/result_panel"), "soupcarry: 2D HUD 仍走既有登記（3D 內景本輪不做，範圍確認）")
	await _finish(inst)

# ────────────────────────────────────────────────────────────────
# 10) LayoutTuner 巢狀拖曳座標修正：BeggarChallenge 的 _monk_sprite 掛在
#     _bowl_node 底下（_bowl_node 不在原點），模擬 apply_override 後位置正確。
# ────────────────────────────────────────────────────────────────
func _test_nested_drag_coords() -> void:
	var inst = await _spawn("res://src/screens/Minigames/BeggarChallenge.tscn")
	if inst == null:
		return
	var monk_sprite: Node2D = inst.get("_monk_sprite")
	var bowl_node: Node2D = inst.get("_bowl_node")
	if monk_sprite == null or bowl_node == null:
		_check(false, "beggar: _monk_sprite/_bowl_node 存在（前置條件，缺圖環境可能走無 sprite 分支）")
		await _finish(inst)
		return

	# 把父節點(_bowl_node)移到非原點位置，確保這是「巢狀且父不在原點」的真實情境。
	bowl_node.position = Vector2(700.0, 500.0)
	await get_tree().process_frame

	# 記錄 monk_sprite 目前的 viewport(螢幕) 座標，這是我們想要「拖曳後仍停在同一螢幕位置」
	# 的基準（模擬使用者在螢幕上把它拖到「目前這個看起來的位置」，不應該跳位）。
	var screen_pos_before: Vector2 = LayoutTuner._get_screen_pos(monk_sprite)

	# 模擬 LayoutTuner._set_pos 收到「viewport 座標」目標（拖曳邏輯：mouse_pos + drag_offset）。
	LayoutTuner._set_pos(monk_sprite, screen_pos_before)
	await get_tree().process_frame
	var screen_pos_after: Vector2 = LayoutTuner._get_screen_pos(monk_sprite)
	_check(screen_pos_after.distance_to(screen_pos_before) < 0.5,
		"nested drag: _set_pos 傳入目前螢幕座標應讓節點螢幕位置不變 (before=%s after=%s)" % [screen_pos_before, screen_pos_after])

	# 再把目標移動 (50, 30)（viewport 座標系），驗證螢幕位置確實移動了那麼多
	# （而不是被誤當成 local 座標，導致巢狀節點跳到不相關的位置）。
	var target_screen: Vector2 = screen_pos_before + Vector2(50.0, 30.0)
	LayoutTuner._set_pos(monk_sprite, target_screen)
	await get_tree().process_frame
	var screen_pos_moved: Vector2 = LayoutTuner._get_screen_pos(monk_sprite)
	_check(screen_pos_moved.distance_to(target_screen) < 0.5,
		"nested drag: _set_pos 傳入 viewport 目標座標，巢狀節點的螢幕位置正確落在目標點 (got=%s want=%s)" % [screen_pos_moved, target_screen])

	# 驗證 LayoutStore.capture 抓到的是換算後的 local position（相對 _bowl_node），
	# 不是誤把 viewport 座標存進去。
	LayoutStore.capture("minigame/beggarchallenge/monk_sprite")
	var stored: Dictionary = LayoutStore._overrides.get("minigame/beggarchallenge/monk_sprite", {})
	_check(stored.get("kind", "") == "node2d", "nested drag: capture 記錄 kind=node2d")
	if stored.has("pos"):
		var stored_pos := Vector2(stored.pos[0], stored.pos[1])
		_check(stored_pos == monk_sprite.position, "nested drag: capture 存的是換算後的 local position，跟節點目前 local position 一致 (got %s)" % [stored_pos])
		# local position 不應該剛好等於 viewport 座標（除非巧合），確認換算真的發生了。
		_check(stored_pos.distance_to(target_screen) > 10.0, "nested drag: 換算後的 local position 明顯不同於 viewport 座標，證明有做座標系轉換 (local=%s viewport=%s)" % [stored_pos, target_screen])

	await _finish(inst)
