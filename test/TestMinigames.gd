extends Node
## headless 測試：各小遊戲的計分/判定純邏輯 + 場景煙霧測試
## （化緣/端湯/木魚/香火 + 遊藝場 飛鏢/輪盤/21點/打擊/保齡球）。
## 跑法：Godot --headless res://test/TestMinigames.tscn
## 驗證：邏輯正確、三場景能 instantiate 跑數幀不崩。

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_beggar()
	_test_soup()
	_test_wooden_fish()
	_test_offering_toss()
	_test_darts()
	_test_roulette()
	_test_blackjack()
	_test_batting()
	_test_bowling()
	await _smoke_scenes()
	print("MINIGAME_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

# --- 化緣 ---
func _test_beggar() -> void:
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	if gs == null:
		_check(false, "beggar script failed to load"); return
	var g = gs.new()
	_check(g.monk_portrait_path == "res://assets/art_direction/new_ink_shrine_style/minigames/wujie_beggar_front_game_ready.png", "beggar uses okami beggar portrait")
	_check(g.begging_sprite_path == "res://assets/art_direction/new_ink_shrine_style/minigames/beggar_wujie_begging.png", "beggar uses side-view begging Wujie")
	_check(g.citizen_sprite_paths.has("office_worker"), "beggar has office worker sprite mapping")
	_check(ResourceLoader.exists(g.citizen_sprite_paths["office_worker"][0]), "beggar office worker frame A exists")
	_check(ResourceLoader.exists(g.citizen_sprite_paths["office_worker"][1]), "beggar office worker frame B exists")
	g.auto_start = false
	g._build_scene()
	g._spawn_citizen()
	var spawned: Node = g._citizens[0].node
	_check(spawned.get_child_count() == 1 and spawned.get_child(0) is Sprite2D, "beggar spawned citizen uses Sprite2D art")
	_check(g.donate_reward("office_worker") == 50, "beggar office_worker=50")
	_check(g.donate_reward("tourist") == 100, "beggar tourist=100")
	_check(g.donate_reward("rich_lady") == 500, "beggar rich_lady=500")
	_check(g.donate_reward("drunk_man") == 10, "beggar drunk_man=10")
	_check(g.donate_reward("rich_lady", true) == 1500, "beggar QR x3 = 1500")
	_check(g.donate_reward("nobody") == 0, "beggar unknown=0")
	g.score = 1000
	g.greed_swings = 10
	var r: Dictionary = g.build_result()
	_check(r.gold == 1000, "beggar result gold=score")
	_check(r.karma == 2, "beggar greed 10/5 -> karma 2 (got %d)" % r.karma)
	g.free()

# --- 端湯 ---
func _test_soup() -> void:
	var gs = load("res://src/screens/Minigames/SoupCarry.gd")
	if gs == null:
		_check(false, "soup script failed to load"); return
	var g = gs.new()
	# 穩定握持：沒有加速度時不晃、不溢出。
	for i in 30:
		g.step_slosh(0.1, 0.0, false, false)
	_check(g.soup_amount == 100.0 and g.soup_slosh == 0.0, "soup stable -> no spill")
	# 猛烈加速：應在合理幀數內灑出。
	var g2 = load("res://src/screens/Minigames/SoupCarry.gd").new()
	for i in 60:
		g2.step_slosh(0.1, 3000.0, false, false)
	_check(g2.soup_amount < 100.0, "soup hard acceleration -> spill")
	g2.income = 350
	var won_res: Dictionary = g2.build_result()
	_check(won_res.win == true, "soup result win flag")
	g.free()
	g2.free()

# --- 木魚 ---
func _test_wooden_fish() -> void:
	var gs = load("res://src/screens/Minigames/WoodenFishRhythm.gd")
	if gs == null:
		_check(false, "wooden fish script failed to load"); return
	var g = gs.new()
	_check(g.monk_portrait_path == "res://assets/art_direction/new_ink_shrine_style/minigames/wujie_chanter_front_game_ready.png", "fish uses okami chanter portrait")
	_check(ResourceLoader.exists(g.woodenfish_sprite_path), "fish woodenfish sprite exists")
	_check(ResourceLoader.exists(g.note_sprite_path), "fish note sprite exists")
	g.note_count = 1
	g.auto_start = false
	g._build_scene()
	g._build_chart()
	_check(g._fish.get_child_count() == 1 and g._fish.get_child(0) is Sprite2D, "fish instrument uses Sprite2D art")
	_check(g._notes[0].node is Sprite2D, "fish note uses Sprite2D art")
	_check(g.judge_offset(0.0) == "perfect", "fish offset0=perfect")
	_check(g.judge_offset(-55.0) == "perfect", "fish -55=perfect")
	_check(g.judge_offset(100.0) == "good", "fish 100=good")
	_check(g.judge_offset(200.0) == "miss", "fish 200=miss")
	_check(g.score_for("perfect") == 100, "fish perfect=100")
	_check(g.score_for("good") == 50, "fish good=50")
	_check(g.score_for("miss") == 0, "fish miss=0")
	_check(g.decide_win(0.9, 0.82) == true, "fish win when acc>=opp")
	_check(g.decide_win(0.5, 0.82) == false, "fish lose when acc<opp")
	# build_result：32 音符、命中 30 → acc 0.9375 >= 0.82 → win
	g.note_count = 32
	g.opponent_accuracy = 0.82
	g.hits = 30
	g.score = 3000
	var r: Dictionary = g.build_result()
	_check(r.win == true, "fish 30/32 hits -> win")
	g.hits = 10
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "fish 10/32 hits -> lose")
	g.free()

# --- 香火投擲 ---
func _test_offering_toss() -> void:
	var gs = load("res://src/screens/Minigames/OfferingToss.gd")
	if gs == null:
		_check(false, "offering script failed to load"); return
	var g = gs.new()
	# 力度計：0 與 1/GAUGE_SPEED 秒處應在兩端往返
	_check(absf(g.gauge_value(0.0) - 0.0) < 0.01, "toss gauge t0=0")
	_check(absf(g.gauge_value(1.0 / g.GAUGE_SPEED) - 1.0) < 0.01, "toss gauge half cycle=1")
	# 落點：甜蜜點力度+無風＝正中投入口
	var sweet: Vector2 = g.landing_point(g.POWER_SWEET, 0.0)
	_check(g.judge_landing(sweet) == "perfect", "toss sweet power + no wind = perfect")
	# 太弱=落短、滿風=吹出投入口
	_check(g.judge_landing(g.landing_point(0.2, 0.0)) == "miss", "toss weak power = miss")
	_check(g.judge_landing(g.landing_point(g.POWER_SWEET, 1.0)) == "miss", "toss full wind = miss")
	# 邊緣命中：x 在半寬內、力度在窗內
	var edge: Vector2 = Vector2(g.START_POS.x + g.BOX_HALF_W - 5.0, g.BOX_MOUTH_Y + g.MOUTH_HALF_H - 5.0)
	_check(g.judge_landing(edge) == "hit", "toss edge of mouth = hit")
	# build_result：3 中含 1 perfect → win，merit = 3+1+3
	g.hits = 3
	g.perfects = 1
	var r: Dictionary = g.build_result()
	_check(r.win == true, "toss 3 hits -> win")
	_check(r.merit == 7, "toss merit 3+1+3=7 (got %d)" % r.merit)
	g.hits = 2
	g.perfects = 0
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "toss 2 hits -> lose")
	_check(r2.merit == 2, "toss lose merit=hits")
	g.free()

# --- 飛鏢（遊藝場）---
func _test_darts() -> void:
	var gs = load("res://src/screens/Minigames/Darts.gd")
	if gs == null:
		_check(false, "darts script failed to load"); return
	var g = gs.new()
	_check(ResourceLoader.exists(g.ART + "darts_dart_game_ready.png"), "darts dart art exists")
	_check(ResourceLoader.exists(g.ART + "darts_bg_v2.png"), "darts close-up bg v2 exists")
	# FX 圖（2026-07-03 Codex 交回，MinigameBase 共用）
	_check(ResourceLoader.exists(g.FX_ART + "fx_impact_burst_game_ready.png"), "fx impact burst exists")
	_check(ResourceLoader.exists(g.FX_ART + "fx_gold_sparkle_game_ready.png"), "fx gold sparkle exists")
	_check(ResourceLoader.exists(g.FX_ART + "fx_speed_trail_game_ready.png"), "fx speed trail exists")
	# 真飛鏢盤計分：紅心/外紅心/單雙三倍環/分區角度/脫靶
	var pr: float = g.PLAY_R
	_check(int(g.dart_value(Vector2.ZERO).points) == 50, "darts bull=50")
	_check(int(g.dart_value(Vector2(0, -pr * 0.09)).points) == 25, "darts outer bull=25")
	_check(int(g.dart_value(Vector2(0, -pr * 0.75)).points) == 20, "darts top single=20")
	_check(int(g.dart_value(Vector2(0, -pr * 0.59)).points) == 60, "darts top triple=T20=60")
	_check(int(g.dart_value(Vector2(0, -pr * 0.96)).points) == 40, "darts top double=D20=40")
	_check(int(g.dart_value(Vector2(0, -pr * 1.05)).points) == 0, "darts off-board=0")
	var a1 := deg_to_rad(18.0)   # 正上偏右一格＝1 分區
	_check(int(g.dart_value(Vector2(sin(a1), -cos(a1)) * pr * 0.75).points) == 1, "darts sector right of 20 = 1")
	# 力度條三角波與散布
	_check(absf(g.gauge_value(0.0) - 0.0) < 0.01, "darts gauge t0=0")
	_check(absf(g.gauge_value(g.GAUGE_PERIOD * 0.5) - 1.0) < 0.01, "darts gauge half=1")
	_check(absf(g.gauge_value(g.GAUGE_PERIOD) - 0.0) < 0.01, "darts gauge full cycle=0")
	_check(g.scatter_for(0.5) < g.scatter_for(0.9), "darts off-center scatter bigger")
	# 301：正常倒扣/爆輪/歸零獲勝
	var r301: Dictionary = g.apply_301(301, 60)
	_check(int(r301.score) == 241 and not r301.bust, "darts 301-60=241")
	var rbust: Dictionary = g.apply_301(40, 60)
	_check(rbust.bust and int(rbust.score) == 40, "darts overshoot=bust keeps score")
	var rwin: Dictionary = g.apply_301(40, 40)
	_check(rwin.win, "darts exact zero=win")
	# build_result：兩種模式
	g.mode = "301"
	g.score301 = 0
	var r: Dictionary = g.build_result()
	_check(r.win == true and r.gold == 500 and r.karma == 1, "darts 301 win -> gold 500")
	g.score301 = 101
	var r2: Dictionary = g.build_result()
	_check(r2.win == false and r2.gold == 100, "darts 301 lose -> consolation gold")
	g.mode = "countup"
	g.score = 420
	var r3: Dictionary = g.build_result()
	_check(r3.win == true and r3.gold == 210 + 150, "darts countup 420 -> win")
	g.free()

# --- 輪盤（遊藝場）---
func _test_roulette() -> void:
	var gs = load("res://src/screens/Minigames/Roulette.gd")
	if gs == null:
		_check(false, "roulette script failed to load"); return
	var g = gs.new()
	_check(ResourceLoader.exists(g.ART + "roulette_wheel_top_game_ready.png"), "roulette wheel art exists")
	_check(ResourceLoader.exists(g.ART + "roulette_ball_game_ready.png"), "roulette ball art exists")
	_check(ResourceLoader.exists(g.ART + "roulette_table_top_v2.png"), "roulette table bg exists")
	# 歐式輪盤排序：37 格、0..36 齊全
	_check(g.EURO_ORDER.size() == 37, "roulette euro order has 37 slots")
	var all_present := true
	for n in range(37):
		if n not in g.EURO_ORDER:
			all_present = false
	_check(all_present, "roulette euro order covers 0..36")
	# 格心角度：0 在正上方、順時針遞增一格
	_check(absf(g.sector_angle(0) - (-PI * 0.5)) < 0.001, "roulette 0 at top")
	_check(absf(g.sector_angle(32) - (-PI * 0.5 + TAU / 37.0)) < 0.001, "roulette 32 one slot clockwise")
	# 押注格淨賠率：直注35/打行2/外圍1、0 通殺外圍
	_check(g.cell_net("n17", 17) == 35, "roulette straight hit=35")
	_check(g.cell_net("n17", 5) == -1, "roulette straight miss=-1")
	_check(g.cell_net("dz1", 12) == 2, "roulette dozen1 hit=2")
	_check(g.cell_net("col_top", 36) == 2, "roulette top column hit=2")
	_check(g.cell_net("red", 32) == 1, "roulette red hit=1")
	_check(g.cell_net("black", 32) == -1, "roulette black on red=-1")
	_check(g.cell_net("red", 0) == -1, "roulette zero kills red")
	_check(g.cell_net("even", 0) == -1, "roulette zero kills even")
	_check(g.cell_net("low", 18) == 1 and g.cell_net("high", 19) == 1, "roulette low/high bounds")
	_check(g.cell_net("n0", 0) == 35, "roulette straight zero hit=35")
	# 一局多注總結算：押 0 直注×1 + 紅×2，開 0 → +3500 - 200 = 3300
	_check(g.round_net({"n0": 1, "red": 2}, 0) == 3300, "roulette multi-bet round net")
	# build_result：淨額>0 才算贏，gold=net（可為負）
	g.net = 300
	var r: Dictionary = g.build_result()
	_check(r.win == true and r.gold == 300, "roulette net+300 -> win")
	g.net = -100
	var r2: Dictionary = g.build_result()
	_check(r2.win == false and r2.gold == -100, "roulette net-100 -> lose, gold negative")
	g.free()

# --- 21點（遊藝場）---
func _test_blackjack() -> void:
	var gs = load("res://src/screens/Minigames/Blackjack.gd")
	if gs == null:
		_check(false, "blackjack script failed to load"); return
	var g = gs.new()
	_check(ResourceLoader.exists(g.ART + "card_back_game_ready.png"), "blackjack card back art exists")
	_check(ResourceLoader.exists(g.ART + "card_frame_blank_game_ready.png"), "blackjack card frame art exists")
	# 點數：JQK=10、A 軟硬轉換
	_check(g.hand_value([10, 12]) == 20, "bj 10+Q=20")
	_check(g.hand_value([1, 12]) == 21, "bj A+Q=21 (soft)")
	_check(g.hand_value([1, 5]) == 16, "bj A+5=16 (soft)")
	_check(g.hand_value([1, 5, 10]) == 16, "bj A+5+10=16 (ace demoted)")
	_check(g.hand_value([1, 1, 9]) == 21, "bj A+A+9=21")
	_check(g.hand_value([10, 5, 9]) == 24, "bj bust value 24")
	# 天生 21 與莊家補牌線
	_check(g.is_blackjack([1, 13]) == true, "bj A+K is blackjack")
	_check(g.is_blackjack([7, 7, 7]) == false, "bj 21 in 3 cards is not blackjack")
	_check(g.dealer_should_hit([10, 6]) == true, "bj dealer hits 16")
	_check(g.dealer_should_hit([10, 7]) == false, "bj dealer stands 17")
	# 結算：爆牌/比大小/BJ 1.5倍/平手（注額參數化，BET 已改成變數）
	_check(g.round_payout([10, 5, 9], [10, 7], 100) == -100, "bj player bust loses")
	_check(g.round_payout([10, 9], [10, 5, 9], 100) == 100, "bj dealer bust wins")
	_check(g.round_payout([1, 13], [10, 7], 100) == 150, "bj natural pays 1.5x")
	_check(g.round_payout([1, 13], [1, 12], 100) == 0, "bj both natural = push")
	_check(g.round_payout([10, 9], [10, 8], 100) == 100, "bj 19 beats 18")
	_check(g.round_payout([10, 8], [10, 9], 100) == -100, "bj 18 loses to 19")
	_check(g.round_payout([10, 9], [10, 9], 100) == 0, "bj push")
	# 加倍＝注 ×2 傳入；投降＝拿回半注；兩者只限前兩張
	_check(g.round_payout([10, 9], [10, 8], 200) == 200, "bj double-down wager doubles win")
	_check(g.round_payout([10, 5, 9], [10, 7], 600) == -600, "bj double-down bust loses double")
	_check(g.surrender_net(100) == -50, "bj surrender loses half bet")
	_check(g.surrender_net(1000) == -500, "bj surrender half of max bet")
	_check(g.can_double([10, 6]) and g.can_surrender([10, 6]), "bj double/surrender on first two cards")
	_check(not g.can_double([10, 3, 3]) and not g.can_surrender([10, 3, 3]), "bj no double/surrender after hit")
	# 下注規格：一枚 100、最多 10 枚；籌碼圖（FX handoff 已交回）
	_check(g.BET_STEP == 100 and g.BET_CHIPS_MAX == 10, "bj bet step 100 / cap 10 chips")
	_check(ResourceLoader.exists(g.ART + "chip_100_game_ready.png"), "bj chip_100 art exists")
	# build_result
	g.net = 150
	var r: Dictionary = g.build_result()
	_check(r.win == true and r.gold == 150 and r.karma == 1, "bj net+150 -> win")
	g.net = 0
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "bj net 0 -> not a win")
	g.free()

# --- 打擊籠（遊藝場）---
func _test_batting() -> void:
	var gs = load("res://src/screens/Minigames/Batting.gd")
	if gs == null:
		_check(false, "batting script failed to load"); return
	var g = gs.new()
	_check(ResourceLoader.exists(g.SHRINE_ART + "batting_bg_shrine_v2.png"), "batting shrine bg v2 exists")
	_check(ResourceLoader.exists(g.SHRINE_ART + "pitching_machine_shrine_game_ready.png"), "batting pitching machine art exists")
	_check(ResourceLoader.exists(g.ART + "baseball_ball_game_ready.png"), "batting ball art exists")
	_check(ResourceLoader.exists(g.ART + "batting_hands_game_ready.png"), "batting hands art exists")
	# 時機判定：準=全壘打、稍偏=安打、大偏=揮空（早晚對稱）
	_check(g.judge_swing(0.0) == "homerun", "batting perfect=homerun")
	_check(g.judge_swing(-0.04) == "homerun", "batting -0.04=homerun")
	_check(g.judge_swing(0.08) == "hit", "batting 0.08=hit")
	_check(g.judge_swing(-0.08) == "hit", "batting -0.08=hit")
	_check(g.judge_swing(0.2) == "miss", "batting 0.2=miss")
	_check(g.swing_score("homerun") == 3 and g.swing_score("hit") == 1 and g.swing_score("miss") == 0,
		"batting scoring 3/1/0")
	# build_result：6 安打過關、全壘打加成、無業障
	g.hits = 7
	g.homeruns = 2
	var r: Dictionary = g.build_result()
	_check(r.win == true, "batting 7 hits -> win")
	_check(r.gold == 7 * 30 + 2 * 60 + 100, "batting gold formula (got %d)" % r.gold)
	_check(r.karma == 0 and r.merit == 1, "batting no karma, win merit=1")
	g.hits = 3
	g.homeruns = 0
	var r2: Dictionary = g.build_result()
	_check(r2.win == false and r2.merit == 0, "batting 3 hits -> lose")
	g.free()

# --- 保齡球（遊藝場）---
func _test_bowling() -> void:
	var gs = load("res://src/screens/Minigames/Bowling.gd")
	if gs == null:
		_check(false, "bowling script failed to load"); return
	var g = gs.new()
	_check(ResourceLoader.exists(g.SHRINE_ART + "bowling_lane_shrine_v2.png"), "bowling shrine bg v2 exists")
	_check(ResourceLoader.exists(g.ART + "bowling_pin_game_ready.png"), "bowling pin art exists")
	_check(ResourceLoader.exists(g.ART + "bowling_ball_game_ready.png"), "bowling ball art exists")
	# 倒瓶表（Wii 式）：曲球勾進口袋=全倒、直球正中=分瓶 8、洗溝 0
	_check(g.pins_knocked(-30.0, true) == 10, "bowling hook pocket=strike")
	_check(g.pins_knocked(30.0, true) == 10, "bowling hook pocket (right)=strike")
	_check(g.pins_knocked(0.0, true) == 9, "bowling hook dead center=9")
	_check(g.pins_knocked(0.0, false) == 8, "bowling straight dead center=split 8")
	_check(g.pins_knocked(30.0, false) == 9, "bowling straight near pocket=9")
	_check(g.pins_knocked(100.0, false) == 3, "bowling straight wide=3")
	_check(g.pins_knocked(200.0, true) == 0, "bowling gutter=0")
	# 軌跡：直球不偏、曲球終點向左勾 HOOK_AMT
	_check(absf(g.final_offset(50.0, false) - 50.0) < 0.01, "bowling straight keeps offset")
	_check(absf(g.final_offset(120.0, true) - (120.0 - g.HOOK_AMT)) < 0.01, "bowling hook curves left")
	_check(absf(g.lane_offset(0.0, 120.0, true) - 120.0) < 0.01, "bowling hook starts straight")
	# 曲球中途勾量小於終點（二次曲線，越滾越勾）
	_check(g.lane_offset(0.5, 120.0, true) > g.lane_offset(1.0, 120.0, true), "bowling hook accelerates")
	# 瓶陣：前到後 1-2-3-4 共 10 支，1 號瓶（頭瓶）獨自在最前排（y 最大）
	g._pin_root = Node2D.new()
	g.add_child(g._pin_root)
	g._setup_pins()
	_check(g._pins.size() == 10, "bowling sets up 10 pins")
	var front_y: float = -1.0
	for p in g._pins:
		front_y = maxf(front_y, (p as Sprite2D).position.y)
	var front_count: int = 0
	for p in g._pins:
		if absf((p as Sprite2D).position.y - front_y) < 0.5:
			front_count += 1
	_check(front_count == 1, "bowling head pin alone in front row")
	# build_result：38 分過關、無業障；bonus 算進分數與金幣
	g.pins_total = 40
	g.bonus = 0
	var r: Dictionary = g.build_result()
	_check(r.win == true and r.gold == 40 * 8 + 120, "bowling 40 pins -> win, gold %d" % r.gold)
	_check(r.karma == 0 and r.merit == 1, "bowling no karma, win merit=1")
	g.pins_total = 30
	g.bonus = 8
	var r3: Dictionary = g.build_result()
	_check(r3.win == true and r3.score == 38, "bowling 30+8 bonus -> win at threshold")
	g.pins_total = 20
	g.bonus = 0
	var r2: Dictionary = g.build_result()
	_check(r2.win == false and r2.gold == 160, "bowling 20 pins -> lose")
	g.free()

# --- 場景煙霧測試 ---
func _smoke_scenes() -> void:
	for path in [
		"res://src/screens/Minigames/BeggarChallenge.tscn",
		"res://src/screens/Minigames/SoupCarry.tscn",
		"res://src/screens/Minigames/WoodenFishRhythm.tscn",
		"res://src/screens/Minigames/OfferingToss.tscn",
		"res://src/screens/Minigames/Darts.tscn",
		"res://src/screens/Minigames/Roulette.tscn",
		"res://src/screens/Minigames/Blackjack.tscn",
		"res://src/screens/Minigames/Batting.tscn",
		"res://src/screens/Minigames/Bowling.tscn",
	]:
		var ps: PackedScene = load(path)
		if ps == null:
			_check(false, "load scene %s" % path)
			continue
		var inst = ps.instantiate()
		inst.set("auto_start", false)   # 不自動開跑/結束
		get_tree().root.add_child(inst)
		await get_tree().process_frame
		inst.spawn_fx_burst(Vector2(200, 200), 0.05)    # FX helper 冒煙（缺圖也要靜默不崩）
		inst.spawn_fx_sparkle(Vector2(300, 200), 0.05)
		for i in 5:
			await get_tree().process_frame
		_check(is_instance_valid(inst), "smoke %s alive" % path)
		inst.queue_free()
		await get_tree().process_frame
