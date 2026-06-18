extends Control
## 城市地圖：依 areas 建區圖釘(鎖區 disabled)，選區發 district_selected。
signal district_selected(area_id)

const CITY_MAP_IMG := "res://assets/2d/map/city_map.png"
@onready var bg: TextureRect = $Background
@onready var pins: Control = $Pins
@onready var _close: Button = $Close

var _locked: Dictionary = {}

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)

func setup(areas: Dictionary) -> void:
	bg.texture = (load(CITY_MAP_IMG) as Texture2D) if ResourceLoader.exists(CITY_MAP_IMG) else null
	for c in pins.get_children(): c.queue_free()
	_locked.clear()
	for aid in areas:
		var a: Dictionary = areas[aid]
		var locked: bool = a.has("unlock_flag") and not GameManager.get_flag(a.unlock_flag)
		_locked[aid] = locked
		var b := Button.new()
		b.text = String(a.get("name", aid)) + ("（鎖）" if locked else "")
		b.disabled = locked
		var mp: Dictionary = a.get("map_pos", {"x": 0.5, "y": 0.5})
		b.anchor_left = float(mp.x); b.anchor_top = float(mp.y)
		b.anchor_right = float(mp.x); b.anchor_bottom = float(mp.y)
		b.pressed.connect(pick.bind(aid))
		pins.add_child(b)

func is_locked(area_id: String) -> bool:
	return bool(_locked.get(area_id, false))

func pick(area_id: String) -> void:
	if is_locked(area_id): return
	visible = false
	district_selected.emit(area_id)

func open() -> void:
	visible = true
