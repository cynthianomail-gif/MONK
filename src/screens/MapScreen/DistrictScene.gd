extends Control
## 橫向捲動街景：載背景、擺無戒於 spawn、建傳送點(地點+邊界,依時段/解鎖)、相機跟隨、方向鍵/點擊走動。
signal location_entered(id)
signal edge_to(area_id)
signal request_city_map

const PORTAL := preload("res://src/screens/MapScreen/Portal.tscn")
const WALK_SPEED := 320.0
const ARRIVE_EPS := 8.0
const NEAR := 56.0

@onready var bg: Sprite2D = $World/Background
@onready var portals_root: Node2D = $World/Portals
@onready var wujie: AnimatedSprite2D = $World/Wujie
@onready var cam: Camera2D = $World/Camera2D
@onready var tint: CanvasModulate = $TimeTint

# 上午/下午/傍晚/夜 的畫面調色
const PERIOD_TINT := [Color(1.0, 0.97, 0.9), Color(1.0, 1.0, 1.0), Color(0.95, 0.85, 0.8), Color(0.55, 0.6, 0.85)]

var _map_w := 0.0
var _ground_y := 0.0
var _target_x := 0.0
var _auto := false
var _pending: Node = null

func _ready() -> void:
	$MapBtn.pressed.connect(func(): request_city_map.emit())

func apply_period_tint(period: int) -> void:
	tint.color = PERIOD_TINT[clampi(period, 0, 3)]

func setup(area: Dictionary, locations: Array, period: int, locked_areas: Dictionary = {}, spawn_x_frac: float = -1.0) -> void:
	var tex := _load_tex(String(area.get("scene_2d", "")))
	var vp := get_viewport_rect().size
	if tex:
		bg.texture = tex
		_map_w = tex.get_width()
	else:
		_map_w = vp.x * 2.5
		bg.texture = _placeholder_tex(int(_map_w), int(vp.y))
	bg.scale = Vector2.ONE
	var bh := bg.texture.get_height()
	var sp: Dictionary = area.get("scene_spawn", {"x": 0.1, "y": 0.82})
	var spawn_frac_x: float = float(sp.x) if spawn_x_frac < 0.0 else clampf(spawn_x_frac, 0.0, 1.0)
	wujie.position = Vector2(_map_w * spawn_frac_x, bh * float(sp.y))
	_ground_y = wujie.position.y
	_target_x = wujie.position.x
	_auto = false; _pending = null
	cam.limit_left = 0; cam.limit_right = int(_map_w)
	cam.limit_top = 0; cam.limit_bottom = bh
	_build_portals(area, locations, period, bh, locked_areas)
	apply_period_tint(period)
	_update_camera()

func portal_count() -> int:
	return portals_root.get_child_count()

## JSON 數字會被解析成 float（[1.0,2.0,3.0]），用 int 強制比對避免 int≠float。
func _has_period(arr: Array, p: int) -> bool:
	for v in arr:
		if int(v) == p: return true
	return false

func _build_portals(area: Dictionary, locations: Array, period: int, bh: int, locked_areas: Dictionary) -> void:
	for c in portals_root.get_children(): c.queue_free()
	for loc in locations:
		if not _has_period(loc.get("available_periods", [0, 1, 2, 3]), period): continue
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag): continue
		var p := PORTAL.instantiate(); portals_root.add_child(p)
		var sp: Dictionary = loc.get("scene_pos", {"x": 0.5, "y": 0.8})
		p.position = Vector2(_map_w * float(sp.x), bh * float(sp.y))
		p.setup_location(String(loc.id), String(loc.name))
		p.clicked.connect(_walk_to_portal.bind(p))
		p.triggered.connect(func(id): location_entered.emit(id))
	for ep in area.get("edge_portals", []):
		var to_area: String = String(ep.to)
		if bool(locked_areas.get(to_area, false)): continue
		var p := PORTAL.instantiate(); portals_root.add_child(p)
		p.position = Vector2(_map_w * float(ep.x), bh * 0.80)
		p.setup_edge(to_area, "往 %s" % to_area)
		p.clicked.connect(_walk_to_portal.bind(p))
		p.triggered.connect(func(a): edge_to.emit(a))

func _walk_to_portal(p: Node) -> void:
	_target_x = p.position.x; _auto = true; _pending = p

func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("ui_left"): dir -= 1.0
	if Input.is_action_pressed("ui_right"): dir += 1.0
	if dir != 0.0:
		_auto = false; _pending = null
		wujie.position.x = clampf(wujie.position.x + dir * WALK_SPEED * delta, 0.0, _map_w)
		wujie.face(dir); wujie.set_walking(true)
		_check_near()
	elif _auto:
		var dx := _target_x - wujie.position.x
		if absf(dx) <= ARRIVE_EPS:
			wujie.position.x = _target_x; _auto = false; wujie.set_walking(false)
			if _pending != null: _pending.trigger(); _pending = null
		else:
			var d := signf(dx)
			wujie.position.x += d * WALK_SPEED * delta
			wujie.face(d); wujie.set_walking(true)
	else:
		wujie.set_walking(false)
	wujie.position.y = _ground_y
	_update_camera()

func _check_near() -> void:
	if not Input.is_action_just_pressed("interact"): return
	for p in portals_root.get_children():
		if absf(p.position.x - wujie.position.x) <= NEAR:
			p.trigger(); return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var world_x: float = cam.get_screen_center_position().x - get_viewport_rect().size.x * 0.5 + mb.position.x
		_target_x = clampf(world_x, 0.0, _map_w); _auto = true; _pending = null

func _update_camera() -> void:
	var bh := bg.texture.get_height() if bg.texture else int(get_viewport_rect().size.y)
	cam.position = Vector2(wujie.position.x, bh * 0.5)
	if not cam.is_current(): cam.make_current()

func _load_tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path): return load(path) as Texture2D
	return null

func _placeholder_tex(w: int, h: int) -> Texture2D:
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.16, 0.17, 0.22, 1.0))
	for y in range(int(h * 0.82), h):
		for x in range(w): img.set_pixel(x, y, Color(0.3, 0.3, 0.34, 1.0))
	return ImageTexture.create_from_image(img)
