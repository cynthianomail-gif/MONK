class_name BreathingFigure
extends TextureRect

## 站立立繪呼吸微動：腳踩地（pivot 底部中央），sine 上下浮 + 胸口縮放 + 輕搖。
## 各圖隨機相位（_phase）→ 多隻不同步。受擊/出招的暫態 shake 疊在上面，不污染 _base_y。

@export var amp_y: float = 5.0       # 垂直浮動 px
@export var period: float = 3.4      # 一個呼吸秒數
@export var sway: float = 0.009      # 輕搖弧度（≈0.5°）
@export var breathing: bool = true

var _base_y: float = 0.0
var _phase: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_base_y = position.y
	_phase = randf() * TAU
	_set_pivot_bottom_center()

func _set_pivot_bottom_center() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)

func _process(delta: float) -> void:
	if not breathing:
		return
	_t += delta
	# 腳底中央 pivot 每幀重設（容器排版後 size 才正確）；只用 scale+輕搖呼吸，
	# 不改 position → 不與容器版面打架、腳踩地不浮起。胸口脹縮帶動上半身微浮。
	pivot_offset = Vector2(size.x * 0.5, size.y)
	var w: float = TAU / max(period, 0.1)
	var s: float = sin(_t * w + _phase)
	scale = Vector2(1.0 - s * 0.01, 1.0 + s * 0.02)
	rotation = sin(_t * w * 0.5 + _phase) * sway

## 換圖/重新定位後重設基準（避免 shake/換圖殘留位移）。
func reset_base() -> void:
	_base_y = position.y
	_set_pivot_bottom_center()
