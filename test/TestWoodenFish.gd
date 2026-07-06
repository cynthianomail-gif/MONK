extends Node
## headless 測試：三僧木魚 call-and-response 重寫（2026-07-04 第二期）。
## 驗證：pattern 排程正確性（示範/跟拍時間點）、判定窗邊界、評級門檻
## （59.9/60/79.9/80/100%）、全 Perfect 隱藏評級、win 門檻、restart 重置乾淨。
## 跑法：Godot --headless res://test/TestWoodenFish.tscn
##
## 時間模擬：沒有 BGM stream 時 _clock_ms() 走 Time.get_ticks_msec()-_clock_start_ms，
## 測試藉由回撥 _clock_start_ms 來「快轉」時間，不必真的等待。

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_round_table()
	_test_judge_boundaries()
	_test_rating_boundaries()
	_test_win_threshold()
	_test_all_perfect_hidden_rating()
	await _test_demo_then_player_flow()
	await _test_player_timing_judgement()
	await _test_restart_clean()
	print("WOODEN_FISH_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _make_game() -> Node:
	var gs = load("res://src/screens/Minigames/WoodenFishRhythm.gd")
	var g = gs.new()
	g.auto_start = false
	get_tree().root.add_child(g)
	g._build_scene()
	return g

# --- 曲目表逐回合核對（與 spec 2026-07-04 第 2 節逐條對照）---
func _test_round_table() -> void:
	var g = _make_game()
	_check(g.ROUNDS.size() == 12, "12 rounds total")
	# R1-3: BPM90 三連拍等間隔
	for i in range(0, 3):
		var rd: Dictionary = g.ROUNDS[i]
		_check(rd.bpm == 90.0, "R%d bpm=90" % (i + 1))
		_check(rd.beats == [0.0, 1.0, 2.0], "R%d beats=triplet equal spacing" % (i + 1))
		_check(rd.distract == false, "R%d no distraction" % (i + 1))
	# R4-6: BPM105 四連拍
	for i in range(3, 6):
		var rd: Dictionary = g.ROUNDS[i]
		_check(rd.bpm == 105.0, "R%d bpm=105" % (i + 1))
		_check(rd.beats.size() == 4, "R%d beats=quadruplet" % (i + 1))
	# R7-9: BPM105 切分型
	for i in range(6, 9):
		var rd: Dictionary = g.ROUNDS[i]
		_check(rd.bpm == 105.0, "R%d bpm=105 (syncopated)" % (i + 1))
		var has_half_beat := false
		for b in rd.beats:
			if fmod(float(b), 1.0) != 0.0:
				has_half_beat = true
		_check(has_half_beat, "R%d has off-beat (syncopation)" % (i + 1))
	# R10-12: BPM120 混合＋背景干擾
	for i in range(9, 12):
		var rd: Dictionary = g.ROUNDS[i]
		_check(rd.bpm == 120.0, "R%d bpm=120" % (i + 1))
		_check(rd.distract == true, "R%d has background distraction flag" % (i + 1))
	g.queue_free()

# --- 判定窗邊界：±60ms Perfect / ±120ms Good / 其外 Miss ---
func _test_judge_boundaries() -> void:
	var g = _make_game()
	for v in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		_check(g.judge_offset(v) == "perfect", "judge %.1fms = perfect" % v)
	for v in [-60.1, -120.0, 60.1, 120.0]:
		_check(g.judge_offset(v) == "good", "judge %.1fms = good" % v)
	for v in [-120.1, -500.0, 120.1, 500.0]:
		_check(g.judge_offset(v) == "miss", "judge %.1fms = miss" % v)
	g.queue_free()

# --- 評級門檻：59.9/60/79.9/80/100（五個邊界值）---
func _test_rating_boundaries() -> void:
	var g = _make_game()
	_check(g.rating_for(0.0, false) == "Try Again", "rate 0%% = Try Again")
	_check(g.rating_for(0.599, false) == "Try Again", "rate 59.9%% = Try Again")
	_check(g.rating_for(0.60, false) == "OK", "rate 60%% boundary = OK")
	_check(g.rating_for(0.799, false) == "OK", "rate 79.9%% = OK")
	_check(g.rating_for(0.80, false) == "Superb", "rate 80%% boundary = Superb")
	_check(g.rating_for(1.0, false) == "Superb", "rate 100%% (not flagged all_perfect) = Superb")
	g.queue_free()

# --- win 門檻：>=60% ---
func _test_win_threshold() -> void:
	var g = _make_game()
	_check(g.decide_win(0.0) == false, "win 0%% = false")
	_check(g.decide_win(0.599) == false, "win 59.9%% = false")
	_check(g.decide_win(0.60) == true, "win 60%% boundary = true")
	_check(g.decide_win(1.0) == true, "win 100%% = true")
	g.queue_free()

# --- 全 Perfect 隱藏評級「入定圓滿」---
func _test_all_perfect_hidden_rating() -> void:
	var g = _make_game()
	_check(g.rating_for(1.0, true) == "入定圓滿", "all-perfect + rate100%% = 入定圓滿")
	# 就算命中率 100% 但沒有全部 perfect（例如都 good），不給隱藏評級
	_check(g.rating_for(1.0, false) != "入定圓滿", "rate100%% without all_perfect flag != 入定圓滿")
	var total: int = g.total_beats_count()
	g.score = total * 100
	g.judged = total
	g.perfects = total
	var r: Dictionary = g.build_result()
	_check(r.get("rating", "") == "入定圓滿", "build_result full-perfect run -> 入定圓滿")
	g.score = total * 50   # 全部 good，命中率仍是 50% 分數 (score基準是perfect=100)
	g.perfects = 0
	var r2: Dictionary = g.build_result()
	_check(r2.get("rating", "") != "入定圓滿", "build_result all-good (not perfect) != 入定圓滿")
	g.queue_free()

# --- 排程正確性：示範 A → 示範 B → 玩家段，時間點與 pattern 一致 ---
func _test_demo_then_player_flow() -> void:
	var g = _make_game()
	g._start_game()
	await get_tree().process_frame
	_check(g._phase == 0, "starts in DEMO_A phase (Phase.DEMO_A=0)")
	var rd: Dictionary = g.ROUNDS[0]
	var dur: float = g.round_phase_duration_ms(rd)
	# 快轉超過示範A時長 -> 應進示範B
	g._clock_start_ms -= (dur + 10.0)
	await get_tree().process_frame
	_check(g._phase == 1, "advances to DEMO_B after demo-A duration elapses (got phase %d)" % g._phase)
	# 再快轉超過示範B時長 -> 應進玩家段，且 _player_beats 已按 pattern 建好
	g._clock_start_ms -= (dur + 10.0)
	await get_tree().process_frame
	_check(g._phase == 2, "advances to PLAYER phase after demo-B duration elapses (got phase %d)" % g._phase)
	_check(g._player_beats.size() == rd.beats.size(), "player beats scheduled match round pattern size")
	for i in rd.beats.size():
		var expect_ms: float = float(rd.beats[i]) * (60000.0 / float(rd.bpm))
		_check(absf(float(g._player_beats[i].target_ms) - expect_ms) < 0.01,
			"player beat[%d] target_ms matches pattern (expect %.1f got %.1f)" % [i, expect_ms, g._player_beats[i].target_ms])
	g.queue_free()

# --- 玩家跟拍時的即時判定（perfect/good/miss）透過模擬按鍵時間點 ---
func _test_player_timing_judgement() -> void:
	var g = _make_game()
	g._start_game()
	await get_tree().process_frame
	var rd: Dictionary = g.ROUNDS[0]
	var dur: float = g.round_phase_duration_ms(rd)
	# 快轉兩次進入玩家段
	g._clock_start_ms -= (dur + 10.0)
	await get_tree().process_frame
	g._clock_start_ms -= (dur + 10.0)
	await get_tree().process_frame
	_check(g._phase == 2, "in PLAYER phase for timing test")
	# 直接呼叫 _register_player 驗證分數/連段變化（不必真的敲鍵盤）
	var beat0: Dictionary = g._player_beats[0]
	g._register_player(beat0, g.judge_offset(5.0), 5.0)
	_check(g.score == 100, "perfect hit scores 100")
	_check(g.combo == 1, "combo increments on hit")
	_check(g.perfects == 1, "perfect counter increments")
	var beat1: Dictionary = g._player_beats[1]
	g._register_player(beat1, g.judge_offset(90.0), 90.0)
	_check(g.score == 150, "good hit adds 50 (total 150)")
	_check(g.combo == 2, "combo continues on good hit")
	var beat2: Dictionary = g._player_beats[2]
	g._register_player(beat2, "miss")
	_check(g.combo == 0, "combo resets to 0 on miss")
	_check(g.score == 150, "miss adds no score")
	g.queue_free()

# --- restart 重置乾淨：分數/連段/回合進度全歸零，_finished 旗標清除 ---
func _test_restart_clean() -> void:
	var g = _make_game()
	g.score = 500
	g.combo = 8
	g.max_combo = 8
	g.hits = 12
	g.perfects = 3
	g.total_taps = 12
	g.judged = 12
	g._finished = true
	g._round_idx = 5
	g.restart()
	await get_tree().process_frame
	_check(g.score == 0, "restart resets score")
	_check(g.combo == 0 and g.max_combo == 0, "restart resets combo/max_combo")
	_check(g.hits == 0 and g.perfects == 0 and g.total_taps == 0 and g.judged == 0, "restart resets hit counters")
	_check(g._round_idx == 0, "restart returns to round 0")
	_check(g._finished == false, "restart clears _finished")
	_check(g._running == true, "restart resumes game loop")
	g.queue_free()
	await get_tree().process_frame
