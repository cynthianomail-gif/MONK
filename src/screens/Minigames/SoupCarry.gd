extends "res://src/screens/Minigames/MinigameBase.gd"
## 端湯上塔 SoupCarry —— 滑鼠左右(或 A/D)控制碗的傾斜，
## 阻尼自然回正，每層有風干擾；溢出 100% 失敗，爬完 10 層成功。
## GDD v4_P5 §10.2 物理。

const MAX_TILT: float = 25.0
const DAMPING: float = 2.5
const SPILL_RATE: float = 8.0
const TOTAL_FLOORS: int = 10
const FLOOR_TIME: float = 4.0      # 每層需穩住的秒數
const KEY_TILT_SPEED: float = 60.0  # A/D 每秒傾斜度
const MOUSE_TILT_GAIN: float = 0.15

@export var background_path: String = "res://assets/2d/backgrounds/bg_battle_temple.png"
@export var auto_start: bool = true

var bowl_tilt: float = 0.0
var spillage: float = 0.0
var floor_index: int = 1
var _floor_timer: float = 0.0
var _running: bool = false
var _bowl: Node2D
var _spill_particles: CPUParticles2D
var _hud_floor: Label
var _hud_spill: Label

func minigame_id() -> String:
	return "soup_carry"

func _ready() -> void:
	_build_scene()
	if auto_start:
		_running = true

# --- 純邏輯（測試用）---

## 每層風的振幅：7 樓以上加強。
func floor_wind_amplitude(floor: int) -> float:
	return 12.0 if floor >= 7 else 3.0

## 推進一幀物理。input_tilt = 本幀外加的傾斜量（測試可直接灌大值）。
## 回傳 true 表示本幀因溢滿觸發失敗。
func step_physics(delta: float, input_tilt: float = 0.0) -> bool:
	bowl_tilt += input_tilt
	if absf(bowl_tilt) > MAX_TILT:
		spillage += (absf(bowl_tilt) - MAX_TILT) * delta * SPILL_RATE
		if _spill_particles:
			_spill_particles.emitting = true
	elif _spill_particles:
		_spill_particles.emitting = false
	bowl_tilt = lerpf(bowl_tilt, 0.0, DAMPING * delta)
	spillage = clampf(spillage, 0.0, 100.0)
	return spillage >= 100.0

## 結算 result：win=登頂；湯剩越多 merit 越高。
func build_result(won: bool) -> Dictionary:
	var soup_left: int = int(100.0 - spillage)
	return make_result({
		"score": soup_left, "win": won,
		"merit": int(soup_left / 20.0) if won else 0,
	})

# --- 流程 ---

func _process(delta: float) -> void:
	if not _running:
		return
	# 鍵盤輸入
	var key_input := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_input += KEY_TILT_SPEED * delta
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_input -= KEY_TILT_SPEED * delta
	# 風
	var wind := sin(Time.get_ticks_msec() * (0.002 if floor_index >= 7 else 0.001))
	wind *= floor_wind_amplitude(floor_index) * delta
	var dead := step_physics(delta, key_input + wind)
	_update_bowl_visual()
	_update_hud()
	if dead:
		_end(false)
		return
	# 爬層
	_floor_timer += delta
	if _floor_timer >= FLOOR_TIME:
		_floor_timer = 0.0
		floor_index += 1
		AudioManager.play_sfx("wooden_fish_tap")
		if floor_index > TOTAL_FLOORS:
			_end(true)

func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		bowl_tilt += event.relative.x * MOUSE_TILT_GAIN

func _end(won: bool) -> void:
	_running = false
	if won:
		AudioManager.play_sfx("merit_chime")
	finish(build_result(won))

# --- 視覺 ---

func _update_bowl_visual() -> void:
	if _bowl:
		_bowl.rotation_degrees = bowl_tilt

func _update_hud() -> void:
	if _hud_floor:
		_hud_floor.text = "第 %d / %d 層" % [mini(floor_index, TOTAL_FLOORS), TOTAL_FLOORS]
	if _hud_spill:
		_hud_spill.text = "溢出 %d%%" % int(spillage)

func _build_scene() -> void:
	_add_background(background_path, Color(0.1, 0.09, 0.08))
	# 碗（程式繪製：碗身 + 湯面）
	_bowl = Node2D.new()
	_bowl.position = Vector2(960, 720)
	add_child(_bowl)
	var soup := Polygon2D.new()
	soup.polygon = PackedVector2Array([
		Vector2(-120, 0), Vector2(120, 0), Vector2(96, 30), Vector2(-96, 30)])
	soup.color = Color(0.85, 0.6, 0.25)
	_bowl.add_child(soup)
	var bowl_body := Polygon2D.new()
	bowl_body.polygon = PackedVector2Array([
		Vector2(-130, 0), Vector2(130, 0), Vector2(90, 90), Vector2(-90, 90)])
	bowl_body.color = Color(0.3, 0.22, 0.18)
	_bowl.add_child(bowl_body)
	_spill_particles = CPUParticles2D.new()
	_spill_particles.emitting = false
	_spill_particles.amount = 16
	_spill_particles.lifetime = 0.8
	_spill_particles.position = Vector2(0, 10)
	_spill_particles.gravity = Vector2(0, 600)
	_spill_particles.initial_velocity_min = 40.0
	_spill_particles.initial_velocity_max = 120.0
	_spill_particles.color = Color(0.85, 0.6, 0.25)
	_bowl.add_child(_spill_particles)
	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_floor = Label.new()
	_hud_floor.text = "第 1 / %d 層" % TOTAL_FLOORS
	_hud_floor.position = Vector2(48, 36)
	_hud_floor.add_theme_font_size_override("font_size", 44)
	_hud_floor.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	layer.add_child(_hud_floor)
	_hud_spill = Label.new()
	_hud_spill.text = "溢出 0%"
	_hud_spill.position = Vector2(48, 96)
	_hud_spill.add_theme_font_size_override("font_size", 32)
	_hud_spill.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
	layer.add_child(_hud_spill)

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
