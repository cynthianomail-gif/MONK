extends "res://src/screens/Minigames/MinigameBase.gd"
## 打擊場 Batting —— 神社街店家小遊戲（人中之龍打擊中心式，2026-07-03 從地下
## 遊藝場搬到神社街獨立店面，跟賭博的三款分開，走陽光休閒路線）。
## 第一人稱視角：球從投球機飛來（由遠到近放大），抓時機按鍵揮棒，
## 依按下時機判定 全壘打/安打/揮空。10 球定勝負。
## 美術已換神社街水墨版：`shrine_games/batting_bg_shrine_v2.png` 是空台座
## （投球機沒烤進背景，程式疊一個獨立會動的投球機 sprite——待機搖擺/揮臂蓄力/
## 出手，符合 handoff 的「投球機要能獨立動畫」要求）；球/球棒手仍沿用 parlor 資產。

const ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
const SHRINE_ART := "res://assets/art_direction/new_ink_shrine_style/minigames/shrine_games/"
const PITCHES: int = 10
const MACHINE_POS := Vector2(976, 620)   # 投球機立在背景台座上的位置
const PITCH_FROM := Vector2(976, 560)    # 投球機出球口（機身砲管高度）
const PITCH_TO := Vector2(970, 950)      # 到達本壘板（畫面下方，接近打者）
const SCALE_FROM: float = 0.020
const SCALE_TO: float = 0.30
const CONTACT_T: float = 1.0             # 到達本壘的進度值
const WIN_HITS: int = 6

var auto_start: bool = true
var pitches_done: int = 0
var hits: int = 0
var homeruns: int = 0
var _phase: String = "idle"              # idle / windup / fly / done
var _t: float = 0.0
var _pitch_time: float = 1.1             # 這球的飛行秒數（會隨機快慢球）
var _ball: Sprite2D
var _hands: Sprite2D
var _machine: Sprite2D
var _machine_idle_tween: Tween
var _hud: Label
var _judge_popup: Label
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "batting"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_new_pitch()

# --- 純邏輯（測試用）---

## 揮棒時機判定：offset = 按鍵時進度 - 到達本壘進度（CONTACT_T）。
## 早揮為負、晚揮為正；越接近 0 越準。
func judge_swing(offset: float) -> String:
	var d := absf(offset)
	if d <= 0.045:
		return "homerun"
	if d <= 0.12:
		return "hit"
	return "miss"

func swing_score(judge: String) -> int:
	match judge:
		"homerun":
			return 3
		"hit":
			return 1
		_:
			return 0

func build_result() -> Dictionary:
	var won: bool = hits >= WIN_HITS
	return make_result({
		"score": hits + homeruns * 2, "win": won,
		"gold": hits * 30 + homeruns * 60 + (100 if won else 0),
		"merit": 1 if won else 0,   # 練身也算修行
	})

# --- 流程 ---

func _process(delta: float) -> void:
	if _phase != "fly":
		return
	_t += delta / _pitch_time
	_place_ball(_t)
	if _t > CONTACT_T + 0.14:
		_on_swung("miss", true)   # 看著球過去＝揮空

func _input(event: InputEvent) -> void:
	if _phase != "fly":
		return
	var tap: bool = (event.is_action_pressed("confirm")
		or event.is_action_pressed("interact")
		or (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_F, KEY_J, KEY_SPACE])
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if tap:
		_swing()

func _new_pitch() -> void:
	if pitches_done >= PITCHES:
		_end()
		return
	_phase = "windup"
	_pitch_time = _rng.randf_range(0.85, 1.35)
	_update_hud()
	# 投球機蓄力動畫：機身先往後縮再彈出（模擬出球衝力），球在動畫尾聲才出現
	var tw := create_tween()
	tw.tween_property(_machine, "scale", Vector2(0.38, 0.42), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_machine, "scale", Vector2(0.41, 0.39), 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_machine, "scale", Vector2(0.40, 0.40), 0.08)
	tw.tween_callback(_release_pitch)

func _release_pitch() -> void:
	if _phase != "windup":
		return   # 若這球在蓄力動畫播完前已被別的流程結束(理論上不會，防呆)
	_phase = "fly"
	_t = 0.0
	_ball.visible = true
	_place_ball(0.0)

func _place_ball(t: float) -> void:
	var k: float = clampf(t, 0.0, 1.15)
	# 進度平方讓球「越近越快」，貼近真實透視
	var e: float = k * k
	_ball.position = PITCH_FROM.lerp(PITCH_TO, e)
	_ball.scale = Vector2.ONE * lerpf(SCALE_FROM, SCALE_TO, e)

func _swing() -> void:
	var judge := judge_swing(_t - CONTACT_T)
	# 揮棒動畫：手臂快速一沉再回位
	var tw := create_tween()
	tw.tween_property(_hands, "rotation_degrees", -16.0, 0.06)
	tw.tween_property(_hands, "rotation_degrees", 0.0, 0.18)
	_on_swung(judge, false)

func _on_swung(judge: String, watched: bool) -> void:
	_phase = "judge"
	pitches_done += 1
	var pts := swing_score(judge)
	match judge:
		"homerun":
			hits += 1
			homeruns += 1
			AudioManager.play_sfx("weakness_hit")
			hit_stop(0.10, 0.04)                       # 全壘打：重頓幀+大震+爆點
			shake(18.0, 0.32)
			spawn_fx_burst(_ball.position, 0.55)
			_show_judge("全壘打！！", Color(1, 0.85, 0.4))
			_fly_away(Vector2(_rng.randf_range(300, 1600), -160), 0.028)
		"hit":
			hits += 1
			AudioManager.play_sfx("impact_heavy")
			hit_stop(0.05)                             # 安打：輕頓幀+小震
			shake(9.0, 0.2)
			spawn_fx_burst(_ball.position, 0.35)
			_show_judge("安打！", Color(0.9, 0.78, 0.5))
			_fly_away(Vector2(_rng.randf_range(100, 700), _rng.randf_range(100, 300)), 0.06)
		_:
			AudioManager.play_sfx("wooden_fish_tap")
			_show_judge("看走眼了……" if watched else "揮空！", Color(0.8, 0.4, 0.35))
			_ball.visible = false
	_update_hud()
	await get_tree().create_timer(0.6).timeout
	_new_pitch()

## 打中後球飛遠：往指定點縮小飛出。
func _fly_away(to: Vector2, end_scale: float) -> void:
	var tw := create_tween()
	tw.tween_property(_ball, "position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ball, "scale", Vector2.ONE * end_scale, 0.4)

func _end() -> void:
	_phase = "done"
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "全壘打王" if result.win else "再練練"
	show_result_panel("打擊場", rating, [
		{"label": "安打", "value": "%d/%d" % [hits, PITCHES]},
		{"label": "全壘打", "value": "%d" % homeruns},
		{"label": "獲得金幣", "value": "%d" % result.gold},
	], result)

## 重開一局：歸零計數，重新開始投球。
func restart() -> void:
	pitches_done = 0
	hits = 0
	homeruns = 0
	_finished = false
	_new_pitch()

# --- 視覺（Codex 資產＋最小 UI）---

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(SHRINE_ART + "batting_bg_shrine_v2.png")
	bg.centered = false
	bg.scale = Vector2(1920.0 / 1672.0, 1080.0 / 941.0)
	add_child(bg)
	_machine = Sprite2D.new()
	_machine.texture = load(SHRINE_ART + "pitching_machine_shrine_game_ready.png")
	_machine.position = MACHINE_POS
	_machine.scale = Vector2(0.40, 0.40)
	add_child(_machine)
	_start_machine_idle_sway()
	_ball = Sprite2D.new()
	_ball.texture = load(ART + "baseball_ball_game_ready.png")
	_ball.visible = false
	add_child(_ball)
	_hands = Sprite2D.new()
	_hands.texture = load(ART + "batting_hands_game_ready.png")
	_hands.position = Vector2(1450, 1010)
	_hands.scale = Vector2(0.62, 0.62)
	add_child(_hands)
	_build_hud()

## 待機微動：機身左右輕搖，暗示機械運轉中（走 rotation，跟蓄力動畫的 scale
## 是不同屬性，兩者同時播不會打架）。
func _start_machine_idle_sway() -> void:
	_machine_idle_tween = create_tween()
	_machine_idle_tween.set_loops()
	_machine_idle_tween.tween_property(_machine, "rotation_degrees", 1.2, 1.4).set_trans(Tween.TRANS_SINE)
	_machine_idle_tween.tween_property(_machine, "rotation_degrees", -1.2, 1.4).set_trans(Tween.TRANS_SINE)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(48, 36)
	var hud_ls := LabelSettings.new()
	hud_ls.font_size = 40
	hud_ls.font_color = Color(0.9, 0.75, 0.42)
	hud_ls.outline_size = 8
	hud_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_hud.label_settings = hud_ls
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：左上 HUD 文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/batting/hud_label")
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(0, 430)
	_judge_popup.size = Vector2(1920, 90)
	_judge_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var jp_ls := LabelSettings.new()
	jp_ls.font_size = 72
	jp_ls.outline_size = 12
	jp_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_judge_popup.label_settings = jp_ls
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	# 佈局工具 v2（P4）：判定彈出字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_judge_popup, "minigame/batting/judge_popup")
	var tip := Label.new()
	tip.text = "球到眼前按〔空白鍵〕揮棒（%d 支安打過關）" % WIN_HITS
	tip.position = Vector2(620, 990)
	var tip_ls := LabelSettings.new()
	tip_ls.font_size = 30
	tip_ls.font_color = Color(0.85, 0.80, 0.72)
	tip_ls.outline_size = 8
	tip_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	tip.label_settings = tip_ls
	layer.add_child(tip)
	_update_hud()

func _update_hud() -> void:
	if _hud:
		_hud.text = "打擊 %d/%d 球   安打 %d（全壘打 %d）" % [pitches_done, PITCHES, hits, homeruns]

func _show_judge(text: String, color: Color) -> void:
	_judge_popup.text = text
	_judge_popup.modulate = color
	_judge_popup.modulate.a = 1.0
	# 彈跳感：大字砸下來再回正，比純淡入有勁
	_judge_popup.pivot_offset = _judge_popup.size * 0.5
	_judge_popup.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_judge_popup, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.30)
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.3)
