extends Control
## 阿瑞斯 boss 戰鬥 VFX 疊層（由 EnemyPanel 在 boss 時建立，疊在 figure 前景）。
## 常駐：待機霧×2(兩側低 alpha)+火星粒子；觸發：受擊閃紅+impact／攻擊爆發／擊敗溶解／phase2 加強。
## 素材 assets/2d/portraits/boss/fx/*.png（Codex ARES_VFX_HANDOFF）。class_name 省略改 preload，免註冊雷。

const FX := "res://assets/2d/portraits/boss/fx/"
const MIST_X := 95.0       # 霧離中心左右距
const CENTER_Y_BIAS := -10.0  # figure 中心相對 panel 中心的偏移(截圖後微調)

var figure: Control = null   # 要閃紅的 boss 立繪
var _back: Node2D            # 霧+火星(常駐)
var _front: Node2D          # 觸發式 FX
var _mist_l: Sprite2D
var _mist_r: Sprite2D
var _embers: CPUParticles2D
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_back = Node2D.new(); add_child(_back)
	_mist_l = _mist(false)
	_mist_r = _mist(true)
	_embers = _make_embers(); _back.add_child(_embers)
	_front = Node2D.new(); add_child(_front)

func _mist(flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(FX + "idle_mist.png"):
		s.texture = load(FX + "idle_mist.png")
	s.flip_h = flip
	s.modulate = Color(1, 1, 1, 0)
	_back.add_child(s)
	return s

func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	if ResourceLoader.exists(FX + "ember_sparks.png"):
		p.texture = load(FX + "ember_sparks.png")
	p.amount = 14
	p.lifetime = 1.2
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -12)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	p.color = Color(1.0, 0.5, 0.3, 0.9)
	p.emitting = true
	return p

func _process(delta: float) -> void:
	_t += delta
	var c := size * 0.5 + Vector2(0, CENTER_Y_BIAS)
	var h: float = size.y if size.y > 0.0 else 455.0
	var bob: float = sin(_t * 1.1) * 8.0
	var a: float = 0.30 + sin(_t * 0.8) * 0.06
	_mist_l.position = c + Vector2(-MIST_X, bob)
	_mist_r.position = c + Vector2(MIST_X, -bob)
	_mist_l.modulate.a = a
	_mist_r.modulate.a = a
	_fit(_mist_l, 0.40)
	_fit(_mist_r, 0.40)
	_embers.position = c + Vector2(0, h * 0.16)

func _fit(s: Sprite2D, k: float) -> void:
	if s.texture != null:
		s.scale = Vector2(k, k)

func _center() -> Vector2:
	return size * 0.5 + Vector2(0, CENTER_Y_BIAS)

# === 觸發式 ===

func play_hit() -> void:
	_flash_figure()
	_pop("hit_impact.png", _center(), 0.55, 1.05, 0.28)

func play_attack() -> void:
	_pop("attack_burst.png", _center() + Vector2(0, -20), 0.45, 1.2, 0.35)

func play_defeat() -> void:
	_pop("defeat_dissolve.png", _center() + Vector2(0, -30), 0.85, 1.2, 1.1)

func set_phase2() -> void:
	_embers.amount = 34
	_pop("phase2_transform_burst.png", _center(), 0.75, 1.15, 0.7)

## 受擊閃紅(modulate；不動 position 免和 BreathingFigure/容器排版衝突)。
func _flash_figure() -> void:
	if figure == null:
		return
	figure.modulate = Color(1.6, 0.5, 0.5, 1)
	var tw := create_tween()
	tw.tween_property(figure, "modulate", Color(1, 1, 1, 1), 0.18)

func _pop(file: String, pos: Vector2, s0: float, s1: float, dur: float) -> void:
	if not ResourceLoader.exists(FX + file):
		return
	var spr := Sprite2D.new()
	spr.texture = load(FX + file)
	spr.position = pos
	spr.scale = Vector2(s0, s0)
	_front.add_child(spr)
	var tw := create_tween()
	tw.parallel().tween_property(spr, "scale", Vector2(s1, s1), dur)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, dur)
	tw.tween_callback(spr.queue_free)
