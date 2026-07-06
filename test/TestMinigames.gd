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

# --- 化緣（接缽化緣，P5 重寫：接落物玩法）---
func _test_beggar() -> void:
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	if gs == null:
		_check(false, "beggar script failed to load"); return
	var g = gs.new()
	_check(g.monk_portrait_path == "res://assets/art_direction/new_ink_shrine_style/minigames/wujie_beggar_front_game_ready.png", "beggar uses okami beggar portrait")
	_check(g.begging_sprite_path == "res://assets/art_direction/new_ink_shrine_style/minigames/beggar_wujie_begging.png", "beggar uses side-view begging Wujie")
	g.auto_start = false
	g._build_scene()

	# 落物接觸判定邊界：缽半寬 BOWL_HALF_W=90，邊界內外各測一點
	_check(g.bowl_catches(960.0, 960.0), "beggar catch: exact center caught")
	_check(g.bowl_catches(960.0, 960.0 + g.BOWL_HALF_W), "beggar catch: at half-width boundary caught (inclusive)")
	_check(not g.bowl_catches(960.0, 960.0 + g.BOWL_HALF_W + 0.5), "beggar catch: just past half-width missed")
	_check(g.bowl_catches(960.0, 960.0 - g.BOWL_HALF_W), "beggar catch: symmetric left boundary caught")

	# combo 倍率遞增與上限：×1.1 遞增，上限 ×3.0
	var m: float = 1.0
	m = g.step_combo_up(m)
	_check(absf(m - 1.1) < 0.001, "beggar combo step1 = x1.1 (got %f)" % m)
	m = g.step_combo_up(m)
	_check(absf(m - 1.21) < 0.001, "beggar combo step2 = x1.21 (got %f)" % m)
	var high: float = 2.95
	_check(absf(g.step_combo_up(high) - g.COMBO_CAP) < 0.001, "beggar combo caps at x3.0 when stepping past cap")
	_check(g.is_combo_maxed(g.COMBO_CAP), "beggar combo cap flagged as maxed")
	_check(not g.is_combo_maxed(2.5), "beggar combo below cap not flagged maxed")

	# 落物表：金額隨 combo 倍率縮放；飯糰只加功德不加金
	var coin_r: Dictionary = g.resolve_catch("coin", 1.0)
	_check(coin_r.gold_delta == 15, "beggar coin base +15")
	var coin_r2: Dictionary = g.resolve_catch("coin", 2.0)
	_check(coin_r2.gold_delta == 30, "beggar coin x2 combo = +30 (got %d)" % coin_r2.gold_delta)
	var ingot_r: Dictionary = g.resolve_catch("ingot", 1.0)
	_check(ingot_r.gold_delta == 80, "beggar ingot base +80")
	var rice_r: Dictionary = g.resolve_catch("riceball", 1.0)
	_check(rice_r.gold_delta == 0 and rice_r.merit_delta == 1, "beggar riceball: no gold, merit+1")

	# 垃圾懲罰：金 -30、combo 歸零、karma+1（純邏輯 resolve_catch 層級）
	var trash_r: Dictionary = g.resolve_catch("trash", 2.5)
	_check(trash_r.gold_delta == -30, "beggar trash gold delta = -30")
	_check(trash_r.karma_delta == 1, "beggar trash karma_delta = 1")
	_check(absf(trash_r.new_combo - 1.0) < 0.001, "beggar trash resets combo to x1.0")

	# 漏接：只斷 combo 不罰分
	_check(absf(g.resolve_miss() - 1.0) < 0.001, "beggar miss resets combo to x1.0, no score penalty (checked via _apply_miss below)")

	# 金下限 0：score 已是 0 時再接垃圾不可為負（走場景層 _apply_catch）
	g.score = 10
	g.combo_mult = 1.0
	g._apply_catch("trash")
	_check(g.score == 0, "beggar gold floors at 0 after trash penalty exceeds current score (got %d)" % g.score)
	g._apply_catch("trash")
	_check(g.score == 0, "beggar gold stays at 0, never negative (got %d)" % g.score)

	# combo 在場景層透過連續接錢正確遞增，接垃圾/漏接歸零
	g.score = 0
	g.combo_mult = 1.0
	g.combo_count = 0
	g._apply_catch("coin")
	_check(absf(g.combo_mult - 1.1) < 0.001, "beggar scene-level combo grows after catching coin")
	_check(g.combo_count == 1, "beggar combo_count = 1 after first catch")
	g._apply_catch("coin")
	_check(g.combo_count == 2, "beggar combo_count = 2 after second consecutive catch")
	g._apply_miss()
	_check(absf(g.combo_mult - 1.0) < 0.001 and g.combo_count == 0, "beggar miss resets combo_mult and combo_count")
	g._apply_catch("coin")
	g._apply_catch("trash")
	_check(absf(g.combo_mult - 1.0) < 0.001 and g.combo_count == 0, "beggar catching trash resets combo too")
	_check(g.trash_caught == 3, "beggar trash_caught tally correct (got %d)" % g.trash_caught)

	# 難度曲線：60 秒賽制，後 20 秒（time_left<=20）加速/加密/垃圾比例升
	_check(not g.is_hard_phase(21.0), "beggar not hard phase with 21s left")
	_check(g.is_hard_phase(20.0), "beggar hard phase kicks in at exactly 20s left")
	_check(g.is_hard_phase(5.0), "beggar hard phase holds near end")
	_check(g.current_fall_speed(30.0) == g.FALL_SPEED_BASE, "beggar base fall speed before hard phase")
	_check(g.current_fall_speed(10.0) == g.FALL_SPEED_HARD, "beggar faster fall speed in hard phase")
	_check(g.current_spawn_interval(30.0) == g.SPAWN_INTERVAL_BASE, "beggar base spawn interval before hard phase")
	_check(g.current_spawn_interval(10.0) == g.SPAWN_INTERVAL_HARD, "beggar denser spawn interval in hard phase")
	_check(g.current_trash_chance(30.0) == g.TRASH_CHANCE_BASE, "beggar base trash chance before hard phase")
	_check(g.current_trash_chance(10.0) == g.TRASH_CHANCE_HARD, "beggar higher trash chance in hard phase")

	# build_result 契約：{id,score,win,gold,merit,karma}；gold=score；merit=飯糰+combo/10；karma=垃圾數
	g.score = 800
	g.riceball_count = 3
	g.max_combo_count = 24
	g.trash_caught = 2
	var r: Dictionary = g.build_result()
	_check(r.id == "beggar_challenge", "beggar result id correct")
	_check(r.gold == 800, "beggar result gold=score (got %d)" % r.gold)
	_check(r.merit == 3 + int(24 / 10.0), "beggar result merit = riceball(3) + combo_bonus(2) = 5 (got %d)" % r.merit)
	_check(r.karma == 2, "beggar result karma = trash_caught (got %d)" % r.karma)
	_check(r.win == true, "beggar win when score >= threshold (800 >= %d)" % g.win_threshold())
	g.score = 100
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "beggar lose when score below threshold")

	# 評級三級 + 隱藏評級（滿 combo）
	_check(g.rating_for_score(100, false) == "空手而回", "beggar rating tier: low score")
	_check(g.rating_for_score(600, false) == "功德圓滿", "beggar rating tier: mid score")
	_check(g.rating_for_score(950, false) == "廣結善緣", "beggar rating tier: high score")
	_check(g.rating_for_score(100, true) == "功德無量", "beggar hidden rating overrides tier when combo maxed")

	# restart 重置：分數/連擊/計時/落物/垃圾/飯糰全歸零，_running 恢復
	g.score = 500
	g.time_left = 3.0
	g.combo_mult = 2.5
	g.combo_count = 8
	g.max_combo_count = 8
	g.riceball_count = 4
	g.trash_caught = 5
	g._running = false
	g.restart()
	_check(g.score == 0, "beggar restart resets score")
	_check(g.time_left == g.DURATION, "beggar restart resets time_left to full duration")
	_check(absf(g.combo_mult - 1.0) < 0.001, "beggar restart resets combo_mult")
	_check(g.combo_count == 0 and g.max_combo_count == 0, "beggar restart resets combo counts")
	_check(g.riceball_count == 0 and g.trash_caught == 0, "beggar restart resets riceball/trash tallies")
	_check(g._drops.is_empty(), "beggar restart clears drops")
	_check(g._running == true, "beggar restart resumes game loop")
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

# --- 木魚（三僧木魚 call-and-response，2026-07-04 重寫）---
func _test_wooden_fish() -> void:
	var gs = load("res://src/screens/Minigames/WoodenFishRhythm.gd")
	if gs == null:
		_check(false, "wooden fish script failed to load"); return
	var g = gs.new()
	# 12 回合曲目表：R1-3 BPM90 三連拍／R4-6 BPM105 四連拍／R7-9 BPM105 切分／R10-12 BPM120 混合+干擾
	_check(g.ROUNDS.size() == 12, "fish has 12 rounds (got %d)" % g.ROUNDS.size())
	for i in range(0, 3):
		_check(g.ROUNDS[i].bpm == 90.0 and g.ROUNDS[i].beats.size() == 3 and g.ROUNDS[i].distract == false,
			"fish round %d = BPM90 triplet no-distract" % (i + 1))
	for i in range(3, 6):
		_check(g.ROUNDS[i].bpm == 105.0 and g.ROUNDS[i].beats.size() == 4,
			"fish round %d = BPM105 quadruplet" % (i + 1))
	for i in range(6, 9):
		_check(g.ROUNDS[i].bpm == 105.0 and g.ROUNDS[i].beats.size() >= 3 and g.ROUNDS[i].distract == false,
			"fish round %d = BPM105 syncopated" % (i + 1))
	for i in range(9, 12):
		_check(g.ROUNDS[i].bpm == 120.0 and g.ROUNDS[i].distract == true,
			"fish round %d = BPM120 mixed+distraction" % (i + 1))
	# 判定窗邊界：±60ms Perfect／±120ms Good／其外 Miss
	_check(g.judge_offset(0.0) == "perfect", "fish offset0=perfect")
	_check(g.judge_offset(-60.0) == "perfect", "fish -60=perfect (boundary)")
	_check(g.judge_offset(60.0) == "perfect", "fish 60=perfect (boundary)")
	_check(g.judge_offset(60.1) == "good", "fish 60.1=good (just past perfect)")
	_check(g.judge_offset(-120.0) == "good", "fish -120=good (boundary)")
	_check(g.judge_offset(120.0) == "good", "fish 120=good (boundary)")
	_check(g.judge_offset(120.1) == "miss", "fish 120.1=miss (just past good)")
	_check(g.judge_offset(200.0) == "miss", "fish 200=miss")
	_check(g.score_for("perfect") == 100, "fish perfect=100")
	_check(g.score_for("good") == 50, "fish good=50")
	_check(g.score_for("miss") == 0, "fish miss=0")
	# Early/Perfect/Late 顯示文字
	_check(g.timing_label(-80.0) == "EARLY", "fish -80ms = EARLY label")
	_check(g.timing_label(80.0) == "LATE", "fish 80ms = LATE label")
	_check(g.timing_label(10.0) == "PERFECT", "fish 10ms = PERFECT label")
	_check(g.timing_label(500.0) == "MISS", "fish 500ms = MISS label")
	# 拍點排程：一回合的毫秒時間表 = beats * (60000/bpm)
	var r1_times: Array = g.round_beat_times_ms(g.ROUNDS[0])
	_check(absf(r1_times[0] - 0.0) < 0.01 and absf(r1_times[1] - (60000.0 / 90.0)) < 0.01,
		"fish round1 beat times = 0, one-beat-at-bpm90")
	var r7_times: Array = g.round_beat_times_ms(g.ROUNDS[6])   # 摳摳．摳＝0, 0.5拍, 2拍
	_check(absf(r7_times[1] - 0.5 * (60000.0 / 105.0)) < 0.01, "fish round7 syncopation beat[1]=0.5 beat")
	# 總分母＝所有回合拍數總和
	var total_beats: int = g.total_beats_count()
	var expect_total := 0
	for rd in g.ROUNDS:
		expect_total += rd.beats.size()
	_check(total_beats == expect_total, "fish total_beats_count sums all rounds (got %d)" % total_beats)
	# 評級門檻：59.9/60/79.9/80/100 五個邊界值 + 全 Perfect 隱藏評級
	_check(g.rating_for(0.599, false) == "Try Again", "fish rate 59.9%% = Try Again")
	_check(g.rating_for(0.60, false) == "OK", "fish rate 60%% = OK (boundary)")
	_check(g.rating_for(0.799, false) == "OK", "fish rate 79.9%% = OK")
	_check(g.rating_for(0.80, false) == "Superb", "fish rate 80%% = Superb (boundary)")
	_check(g.rating_for(1.0, false) == "Superb", "fish rate 100%% without all-perfect flag = Superb")
	_check(g.rating_for(1.0, true) == "入定圓滿", "fish rate 100%% + all_perfect = 入定圓滿 hidden rating")
	# win 門檻：>=60% 為 win
	_check(g.decide_win(0.599) == false, "fish win threshold: 59.9%% = lose")
	_check(g.decide_win(0.60) == true, "fish win threshold: 60%% = win (boundary)")
	_check(g.decide_win(0.80) == true, "fish win threshold: 80%% = win")
	# build_result：算好 score 反推 hit_rate，驗證評級與 win 一致
	g.score = int(total_beats * 100 * 0.85)   # 85% 命中率 -> Superb + win
	g.judged = total_beats
	g.perfects = 0
	var r: Dictionary = g.build_result()
	_check(r.win == true, "fish 85%% rate -> win")
	_check(r.get("rating", "") == "Superb", "fish 85%% rate -> Superb rating (got %s)" % r.get("rating", ""))
	_check(r.merit == 3, "fish win merit=3")
	g.score = int(total_beats * 100 * 0.3)   # 30% -> Try Again + lose
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "fish 30%% rate -> lose")
	_check(r2.get("rating", "") == "Try Again", "fish 30%% rate -> Try Again rating")
	_check(r2.merit == 0, "fish lose merit=0")
	g.score = total_beats * 100   # 全 Perfect
	g.perfects = total_beats
	var r3: Dictionary = g.build_result()
	_check(r3.get("rating", "") == "入定圓滿", "fish all-perfect -> 入定圓滿 hidden rating")
	# 場景冒煙：零素材下建場不崩，角色/木魚節點都建立（缺圖走程式佔位）
	g.auto_start = false
	g._build_scene()
	_check(g._monk_a is Sprite2D and g._monk_b is Sprite2D and g._player_sprite is Sprite2D,
		"fish builds 3 character sprites (placeholder art ok)")
	_check(g._fish_a is Node2D and g._fish_b is Node2D and g._fish_player is Node2D,
		"fish builds 3 woodenfish nodes")
	# restart 重置乾淨：跑完一局後 restart 應歸零計分並重新從第 0 回合開始
	g.score = 999
	g.combo = 5
	g.max_combo = 5
	g.hits = 10
	g.perfects = 2
	g.judged = 10
	g._finished = true
	g.restart()
	_check(g.score == 0 and g.combo == 0 and g.max_combo == 0, "fish restart resets score/combo")
	_check(g.hits == 0 and g.perfects == 0 and g.judged == 0, "fish restart resets hit counters")
	_check(g._round_idx == 0, "fish restart returns to round 0")
	_check(g._finished == false, "fish restart clears _finished flag")
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
