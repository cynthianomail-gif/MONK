extends Control
## 地點內景：靜態背景 + 開該地行動選單。離開回街景。
signal left

@onready var bg: TextureRect = $Background
@onready var _leave: Button = $Leave

func _ready() -> void:
	_leave.pressed.connect(close)

## open(loc, menu_cb)：menu_cb(title, actions, perform_cb) 交給外部用 MapHUD 開選單。
func open(loc: Dictionary, menu_cb: Callable, perform_cb: Callable = Callable()) -> void:
	var path := String(loc.get("interior_2d", ""))
	bg.texture = (load(path) as Texture2D) if (path != "" and ResourceLoader.exists(path)) else _placeholder()
	visible = true
	menu_cb.call(String(loc.get("name", "")), loc.get("actions", []), perform_cb)

func close() -> void:
	visible = false
	left.emit()

func _placeholder() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.13, 1.0))
	return ImageTexture.create_from_image(img)
