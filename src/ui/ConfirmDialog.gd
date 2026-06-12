extends CanvasLayer

signal chose(ok: bool)

@onready var desc_label: Label = %DescLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button  = %NoButton

func _ready() -> void:
	layer = 100
	yes_button.pressed.connect(func(): chose.emit(true))
	no_button.pressed.connect(func(): chose.emit(false))

func setup(desc: String, yes_text: String, no_text: String) -> void:
	desc_label.text = desc
	yes_button.text = yes_text
	no_button.text = no_text
