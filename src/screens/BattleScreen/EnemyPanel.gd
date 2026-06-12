class_name EnemyPanel
extends PanelContainer

## 單一敵人的戰鬥面板（Step 4 將換成 Higgsfield 立繪 + 霓虹框）

signal target_pressed(panel: EnemyPanel)

var combatant: Combatant
var index: int = 0

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _status_label: Label
var _down_label: Label
var _target_button: Button

func _init(c: Combatant, idx: int) -> void:
	combatant = c
	index = idx
	custom_minimum_size = Vector2(260, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.text = c.display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = c.max_hp
	_hp_bar.value = c.current_hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(_hp_bar)

	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_hp_text)

	_down_label = Label.new()
	_down_label.text = "DOWN!"
	_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_label.add_theme_font_size_override("font_size", 24)
	_down_label.add_theme_color_override("font_color", Color("#FFD700"))
	_down_label.visible = false
	vbox.add_child(_down_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("#FF6B00"))
	vbox.add_child(_status_label)

	_target_button = Button.new()
	_target_button.text = "選擇目標"
	_target_button.visible = false
	_target_button.pressed.connect(func(): target_pressed.emit(self))
	vbox.add_child(_target_button)

	c.hp_changed.connect(_on_hp_changed)
	c.down_changed.connect(_on_down_changed)
	_on_hp_changed(c.current_hp, c.max_hp)

func _on_hp_changed(current: int, max_hp: int) -> void:
	_hp_bar.value = current
	_hp_text.text = "%d / %d" % [current, max_hp]
	if current <= 0:
		modulate = Color(0.4, 0.4, 0.4, 0.5)
		_down_label.visible = false
		_target_button.visible = false

func _on_down_changed(is_down: bool) -> void:
	_down_label.visible = is_down and combatant.is_alive()

func set_statuses(statuses: Array) -> void:
	_status_label.text = "、".join(statuses)

func set_target_mode(enabled: bool) -> void:
	_target_button.visible = enabled and combatant.is_alive()
