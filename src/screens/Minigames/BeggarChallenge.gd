extends "res://src/screens/Minigames/MinigameBase.gd"
## 化緣 BeggarChallenge —— 2D 側視，路人從右往左走入，
## 進入「化緣區」時按 interact/confirm/滑鼠左鍵化緣收金幣。
## GDD v4_P5 §10.1 數值。

const DURATION: float = 60.0
const SPAWN_INTERVAL: float = 1.2
const ZONE_X: float = 760.0          # 化緣區左緣
const ZONE_W: float = 400.0          # 化緣區寬
const GREED_KARMA_PER: int = 5        # 每 N 次空揮 → karma +1
const MINIGAME_ART_DIR: String = "res://assets/art_direction/new_ink_shrine_style/minigames/"

const CITIZEN_TYPES: Dictionary = {
	"office_worker": {"reward": 50,  "weight": 0.4, "speed": 180.0, "color": Color(0.4, 0.55, 0.8)},
	"tourist":       {"reward": 100, "weight": 0.3, "speed": 120.0, "color": Color(0.4, 0.75, 0.5)},
	"rich_lady":     {"reward": 500, "weight": 0.1, "speed": 100.0, "color": Color(0.85, 0.7, 0.3)},
	"drunk_man":     {"reward": 10,  "weight": 0.2, "speed": 220.0, "color": Color(0.7, 0.4, 0.4)},
}

# 可抽換美術（留空＝用程式繪製的佔位）。
@export var background_path: String = "res://assets/2d/backgrounds/bg_battle_wanhua.png"
@export var monk_portrait_path: String = MINIGAME_ART_DIR + "wujie_beggar_front_game_ready.png"
@export var begging_sprite_path: String = MINIGAME_ART_DIR + "beggar_wujie_begging.png"
@export var citizen_sprite_paths: Dictionary = {
	"office_worker": [MINIGAME_ART_DIR + "beggar_ped_office_worker_a.png", MINIGAME_ART_DIR + "beggar_ped_office_worker_b.png"],
	"tourist": [MINIGAME_ART_DIR + "beggar_ped_tourist_a.png", MINIGAME_ART_DIR + "beggar_ped_tourist_b.png"],
	"rich_lady": [MINIGAME_ART_DIR + "beggar_ped_rich_lady_a.png", MINIGAME_ART_DIR + "beggar_ped_rich_lady_b.png"],
	"drunk_man": [MINIGAME_ART_DIR + "beggar_ped_drunk_man_a.png", MINIGAME_ART_DIR + "beggar_ped_drunk_man_b.png"],
}
@export var auto_start: bool = true   # 測試時設 false 以停用計時/生成

var score: int = 0
var time_left: float = DURATION
var greed_swings: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _citizens: Array[Dictionary] = []
var _hud_score: Label
var _hud_time: Label
var _world: Node2D

func minigame_id() -> String:
	return "beggar_challenge"

func _ready() -> void:
	_build_scene()
	if auto_start:
		_running = true

# --- 純邏輯（給測試直接呼叫）---

## 單筆化緣金額：行動支付 flag 時 ×3。
func donate_reward(citizen_type: String, has_qr: bool = false) -> int:
	if not CITIZEN_TYPES.has(citizen_type):
		return 0
	var base: int = CITIZEN_TYPES[citizen_type].reward
	return int(base * 3.0) if has_qr else base

## 結算 result：gold=score；空揮越多 karma 越高、merit 越低。
func build_result() -> Dictionary:
	var karma_gain: int = int(greed_swings / float(GREED_KARMA_PER))
	var merit_gain: int = maxi(0, int(score / 500.0) - karma_gain)
	return make_result({
		"score": score, "win": score > 0,
		"gold": score, "merit": merit_gain, "karma": karma_gain,
	})

# --- 遊戲流程 ---

func _process(delta: float) -> void:
	if not _running:
		return
	time_left -= delta
	if _hud_time:
		_hud_time.text = "%02d" % maxi(0, int(ceil(time_left)))
	if time_left <= 0.0:
		_end()
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_citizen()
	# 移動路人
	for i in range(_citizens.size() - 1, -1, -1):
		var c: Dictionary = _citizens[i]
		var node: Node2D = c.node
		node.position.x -= c.speed * delta
		_update_citizen_walk_frame(c)
		if node.position.x < -120.0:
			node.queue_free()
			_citizens.remove_at(i)

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event.is_action_pressed("interact")
		or event.is_action_pressed("confirm")
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if pressed:
		_try_donate()

func _try_donate() -> void:
	# 找化緣區內最右邊（先到的）路人
	var target_idx: int = -1
	var best_x: float = -INF
	for i in _citizens.size():
		var x: float = _citizens[i].node.position.x
		if x >= ZONE_X and x <= ZONE_X + ZONE_W and x > best_x:
			best_x = x
			target_idx = i
	if target_idx == -1:
		greed_swings += 1   # 空揮：貪婪懲罰
		AudioManager.play_sfx("ui_cancel")
		return
	var c: Dictionary = _citizens[target_idx]
	var reward: int = donate_reward(c.type, GameManager.get_flag("has_qr_code"))
	score += reward
	AudioManager.play_sfx("gold_collect")
	_popup("+%d" % reward, c.node.position)
	c.node.queue_free()
	_citizens.remove_at(target_idx)
	if _hud_score:
		_hud_score.text = "功德金：%d" % score

func _spawn_citizen() -> void:
	var type: String = _weighted_pick()
	var info: Dictionary = CITIZEN_TYPES[type]
	var node := Node2D.new()
	node.position = Vector2(2000.0, 760.0)
	var frames := _citizen_frames(type)
	if frames.size() >= 2:
		var sp := Sprite2D.new()
		sp.texture = frames[0]
		sp.position = Vector2(0, -126)
		sp.scale = Vector2(0.28, 0.28)
		node.add_child(sp)
		_world.add_child(node)
		_citizens.append({"node": node, "type": type, "speed": info.speed, "sprite": sp, "frames": frames})
		return
	# 程式繪製的人形 fallback
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-26, 0), Vector2(26, 0), Vector2(20, -120), Vector2(-20, -120)])
	body.color = info.color
	node.add_child(body)
	var head := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in range(12):
		var ang := TAU * a / 12.0
		pts.append(Vector2(cos(ang), sin(ang)) * 24.0 + Vector2(0, -150))
	head.polygon = pts
	head.color = info.color.lightened(0.2)
	node.add_child(head)
	_world.add_child(node)
	_citizens.append({"node": node, "type": type, "speed": info.speed})

func _citizen_frames(type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not citizen_sprite_paths.has(type):
		return frames
	for path in citizen_sprite_paths[type]:
		var tex := _try_load(str(path))
		if tex:
			frames.append(tex)
	return frames

func _update_citizen_walk_frame(c: Dictionary) -> void:
	if not c.has("sprite") or not c.has("frames"):
		return
	var frames: Array = c.frames
	if frames.size() < 2:
		return
	var sp := c.sprite as Sprite2D
	if not sp:
		return
	var frame_idx := int(Time.get_ticks_msec() / 250) % 2
	sp.texture = frames[frame_idx]

func _weighted_pick() -> String:
	var r := randf()
	var acc := 0.0
	for type in CITIZEN_TYPES:
		acc += CITIZEN_TYPES[type].weight
		if r <= acc:
			return type
	return "office_worker"

func _end() -> void:
	_running = false
	finish(build_result())

# --- 場景搭建（純程式，方便抽換）---

func _build_scene() -> void:
	_add_background(background_path, Color(0.12, 0.1, 0.14))
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	# 化緣區地面提示
	var zone := Polygon2D.new()
	zone.polygon = PackedVector2Array([
		Vector2(ZONE_X, 700), Vector2(ZONE_X + ZONE_W, 700),
		Vector2(ZONE_X + ZONE_W, 780), Vector2(ZONE_X, 780)])
	zone.color = Color(0.788, 0.659, 0.38, 0.18)
	add_child(zone)
	# 乞討的無戒（用立繪佔位）
	var monk := Sprite2D.new()
	var tex := _try_load(begging_sprite_path)
	if tex == null:
		tex = _try_load(monk_portrait_path)
	if tex:
		monk.texture = tex
		monk.position = Vector2(ZONE_X + ZONE_W * 0.5, 636)
		monk.scale = Vector2(0.31, 0.31)
		add_child(monk)
	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_score = Label.new()
	_hud_score.text = "功德金：0"
	_hud_score.position = Vector2(48, 36)
	_hud_score.add_theme_font_size_override("font_size", 40)
	_hud_score.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	layer.add_child(_hud_score)
	_hud_time = Label.new()
	_hud_time.text = "%02d" % int(DURATION)
	_hud_time.position = Vector2(1820, 36)
	_hud_time.add_theme_font_size_override("font_size", 48)
	_hud_time.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	layer.add_child(_hud_time)

func _popup(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-20, -180)
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_world.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 80, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

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
