extends Area2D
## 傳送點：kind="location"(走進→進內景) 或 "edge"(走進→換區)。可點擊或走近觸發。
signal triggered(payload)        # 點擊/到達時發
signal clicked                   # 純被點（DistrictScene 用來走過去）

@onready var _label: Label = $Label

var kind := ""
var payload := ""
var display := ""

func _ready() -> void:
	_refresh()

func setup_location(id: String, name: String) -> void:
	kind = "location"; payload = id; display = name; _refresh()

func setup_edge(to_area: String, name: String) -> void:
	kind = "edge"; payload = to_area; display = name; _refresh()

func _refresh() -> void:
	if _label: _label.text = display

func trigger() -> void:
	triggered.emit(payload)

func _input_event(_vp: Object, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		get_viewport().set_input_as_handled()
