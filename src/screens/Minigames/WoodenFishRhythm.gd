extends "res://src/screens/Minigames/MinigameBase.gd"
## 木魚節奏戰 WoodenFishRhythm —— 音符落向判定線，於時間窗敲擊。
## 「誰漏的少誰贏」：玩家準確率 ≥ 對手 → 勝。jie 支線勝負獎勵由 context 套用。

const PERFECT_MS: float = 60.0
const GOOD_MS: float = 120.0
const PERFECT_SCORE: int = 100
const GOOD_SCORE: int = 50
const APPROACH_MS: float = 1400.0   # 音符從生成到判定線的飛行時間
const LEAD_IN_MS: float = 1800.0    # 開場緩衝
const MINIGAME_ART_DIR: String = "res://assets/art_direction/new_ink_shrine_style/minigames/"

@export var bpm: float = 120.0
@export var note_count: int = 32
@export var opponent_accuracy: float = 0.82
@export var background_path: String = "res://assets/2d/backgrounds/bg_battle_temple.png"
@export var jie_portrait_path: String = "res://assets/2d/portraits/npcs/npc_jie.png"
@export var monk_portrait_path: String = MINIGAME_ART_DIR + "wujie_chanter_front_game_ready.png"
@export var woodenfish_sprite_path: String = MINIGAME_ART_DIR + "woodenfish_instrument.png"
@export var note_sprite_path: String = MINIGAME_ART_DIR + "woodenfish_note.png"
@export var hit_fx_sprite_path: String = MINIGAME_ART_DIR + "woodenfish_hit_fx.png"
@export var auto_start: bool = true

const JUDGE_Y: float = 840.0
const SPAWN_Y: float = 80.0
const LANE_X: float = 960.0

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var hits: int = 0           # perfect + good
var judged: int = 0         # 已判定的音符數（含 miss）
var _notes: Array[Dictionary] = []   # {target_ms, node, done}
var _start_ms: float = 0.0
var _running: bool = false
var _fish: Node2D
var _hud: Label
var _judge_popup: Label

func minigame_id() -> String:
	return "wooden_fish_rhythm"

func _ready() -> void:
	_build_scene()
	_build_chart()
	if auto_start:
		_start_ms = Time.get_ticks_msec()
		_running = true

# --- 純邏輯（測試用）---

## 依離判定時刻的毫秒差判定。offset 取絕對值前可帶正負。
func judge_offset(offset_ms: float) -> String:
	var a := absf(offset_ms)
	if a <= PERFECT_MS:
		return "perfect"
	elif a <= GOOD_MS:
		return "good"
	return "miss"

func score_for(judgement: String) -> int:
	match judgement:
		"perfect": return PERFECT_SCORE
		"good": return GOOD_SCORE
		_: return 0

## 誰漏的少誰贏：玩家準確率 >= 對手 → 勝。
func decide_win(player_acc: float, opp_acc: float) -> bool:
	return player_acc >= opp_acc

func player_accuracy() -> float:
	return float(hits) / float(maxi(1, note_count))

func build_result() -> Dictionary:
	var won := decide_win(player_accuracy(), opponent_accuracy)
	return make_result({
		"score": score, "win": won,
		"merit": 3 if won else 0,
	})

# --- 流程 ---

func _process(_delta: float) -> void:
	if not _running:
		return
	var now := Time.get_ticks_msec() - _start_ms
	for n in _notes:
		if n.done:
			continue
		# 進入接近期才現身、開始落下
		var t: float = 1.0 - (n.target_ms - now) / APPROACH_MS
		if n.node:
			n.node.visible = t >= 0.0
			n.node.position.y = lerpf(SPAWN_Y, JUDGE_Y, clampf(t, 0.0, 1.2))
		# 超過 good 窗仍未敲 → miss
		if now - n.target_ms > GOOD_MS:
			_register(n, "miss")
	if judged >= note_count:
		_end()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var tap: bool = (event.is_action_pressed("confirm")
		or event.is_action_pressed("interact")
		or (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_F, KEY_J, KEY_SPACE])
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if tap:
		_on_tap()

func _on_tap() -> void:
	var now := Time.get_ticks_msec() - _start_ms
	# 找最近、未判定、且在 good 窗內的音符
	var best: Dictionary = {}
	var best_abs: float = GOOD_MS + 1.0
	for n in _notes:
		if n.done:
			continue
		var off: float = absf(now - n.target_ms)
		if off <= GOOD_MS and off < best_abs:
			best_abs = off
			best = n
	if best.is_empty():
		return   # 空敲不罰（節奏遊戲慣例）
	_register(best, judge_offset(now - best.target_ms))
	_animate_fish()

func _register(note: Dictionary, judgement: String) -> void:
	note.done = true
	judged += 1
	if note.node:
		note.node.queue_free()
		note.node = null
	if judgement == "miss":
		combo = 0
		_show_judge("MISS", Color(0.8, 0.3, 0.3))
		return
	hits += 1
	score += score_for(judgement)
	combo += 1
	max_combo = maxi(max_combo, combo)
	AudioManager.play_sfx("wooden_fish_tap")
	if combo > 0 and combo % 10 == 0:
		AudioManager.play_sfx("combo_up")
	_show_hit_fx()
	_show_judge("%s  x%d" % [judgement.to_upper(), combo],
		Color(1, 0.85, 0.4) if judgement == "perfect" else Color(0.7, 0.85, 1))

func _end() -> void:
	_running = false
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	finish(result)

# --- 視覺 ---

func _build_chart() -> void:
	var beat_ms: float = 60000.0 / bpm
	for i in note_count:
		_notes.append({"target_ms": LEAD_IN_MS + i * beat_ms, "node": null, "done": false})
	# 為已生成的音符建立視覺節點
	for n in _notes:
		var note_node: Node2D = _make_note_sprite()
		note_node.position = Vector2(LANE_X, SPAWN_Y)
		note_node.visible = false   # 進入接近期才顯示
		add_child(note_node)
		n.node = note_node
	# 接近期才現身：用 process 控制 visible
	set_process(true)

func _build_scene() -> void:
	_add_background(background_path, Color(0.1, 0.09, 0.08))
	# 判定線
	var line := ColorRect.new()
	line.size = Vector2(360, 8)
	line.position = Vector2(LANE_X - 180, JUDGE_Y - 4)
	line.color = Color(0.95, 0.3, 0.3, 0.8)
	add_child(line)
	# 木魚（程式繪製佔位）
	_fish = Node2D.new()
	_fish.position = Vector2(LANE_X, JUDGE_Y)
	add_child(_fish)
	var fish_tex := _try_load(woodenfish_sprite_path)
	if fish_tex:
		var fish_sprite := Sprite2D.new()
		fish_sprite.texture = fish_tex
		fish_sprite.scale = Vector2(0.42, 0.42)
		_fish.add_child(fish_sprite)
	else:
		var fish_body := Polygon2D.new()
		var pts := PackedVector2Array()
		for a in range(20):
			var ang := TAU * a / 20.0
			pts.append(Vector2(cos(ang) * 70.0, sin(ang) * 50.0))
		fish_body.polygon = pts
		fish_body.color = Color(0.45, 0.32, 0.2)
		_fish.add_child(fish_body)
	# 對手 / 我方立繪
	_add_portrait(jie_portrait_path, Vector2(300, 540), 0.6)
	_add_portrait(monk_portrait_path, Vector2(1620, 540), 0.6)
	_build_hud()

func _animate_fish() -> void:
	if not _fish:
		return
	var tw := create_tween()
	tw.tween_property(_fish, "scale", Vector2(0.85, 0.85), 0.05)
	tw.tween_property(_fish, "scale", Vector2(1, 1), 0.1)

func _make_note_sprite() -> Node2D:
	var tex := _try_load(note_sprite_path)
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(0.35, 0.35)
		return sp
	var dot := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in range(16):
		var ang := TAU * a / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * 34.0)
	dot.polygon = pts
	dot.color = Color(0.788, 0.659, 0.38)
	return dot

func _show_hit_fx() -> void:
	var tex := _try_load(hit_fx_sprite_path)
	if tex == null:
		return
	var fx := Sprite2D.new()
	fx.texture = tex
	fx.position = Vector2(LANE_X, JUDGE_Y)
	fx.scale = Vector2(0.7, 0.7)
	fx.modulate.a = 0.9
	add_child(fx)
	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector2(1.15, 1.15), 0.18)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.18)
	tw.tween_callback(fx.queue_free)

func _show_judge(text: String, color: Color) -> void:
	if not _judge_popup:
		return
	_judge_popup.text = text
	_judge_popup.modulate = color
	_judge_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.5)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.text = "分數 0"
	_hud.position = Vector2(48, 36)
	_hud.add_theme_font_size_override("font_size", 40)
	_hud.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	layer.add_child(_hud)
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(LANE_X - 120, JUDGE_Y - 160)
	_judge_popup.add_theme_font_size_override("font_size", 48)
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	# 隨分數更新
	stat_timer()

func stat_timer() -> void:
	var t := Timer.new()
	t.wait_time = 0.1
	t.autostart = true
	t.timeout.connect(func() -> void:
		if _hud:
			_hud.text = "分數 %d   連段 %d" % [score, combo])
	add_child(t)

func _add_portrait(path: String, pos: Vector2, scl: float) -> void:
	var tex := _try_load(path)
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.position = pos
		sp.scale = Vector2(scl, scl)
		add_child(sp)

func _add_background(path: String, fallback: Color) -> void:
	var tex := _try_load(path)
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var sz: Vector2 = tex.get_size()
		sp.scale = Vector2(1920.0 / sz.x, 1080.0 / sz.y)
		add_child(sp)
	else:
		var bg := ColorRect.new()
		bg.size = Vector2(1920, 1080)
		bg.color = fallback
		add_child(bg)

func _try_load(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
