class_name EnemyPanel
extends Control

## 站立敵方單位：去背戰姿立繪(BreathingFigure) + 下方浮動名牌/HP + 點擊立繪選目標。
## （前版是框面板；本版改 P5 式站立對峙，見 spec 2026-06-17-battle-standing-figures。）

signal target_pressed(panel: EnemyPanel)

const ARES_VFX := preload("res://src/screens/BattleScreen/ares_vfx.gd")

var combatant: Combatant
var index: int = 0
var vfx: Control = null  # boss VFX 疊層(非 boss 為 null)

var _figure: BreathingFigure
var _hit_button: Button
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _status_label: Label
var _down_label: Label
var _weak_label: Label       # 弱點徽章列（第一期）：已探知顯示「弱 淨」，否則「弱 ？」
var _lv_label: Label         # 名字後綴 Lv
var _base_portrait: String = ""
var _mood_timer: SceneTreeTimer = null

## 三系屬性 → 顯示名（弱點徽章用）
const ELEM_NAMES := {"physical": "物", "karma": "業", "merit": "淨"}

func _init(c: Combatant, idx: int) -> void:
	combatant = c
	index = idx
	var big: bool = c.is_boss  # Boss 立繪放大、更具壓迫感（對比前景大無戒不會顯小）
	custom_minimum_size = Vector2(320, 520) if big else Vector2(320, 560)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 28)  # 名牌與 figure 拉開，血條浮在頭上方不壓到身體
	add_child(vbox)

	_figure = BreathingFigure.new()
	_figure.custom_minimum_size = Vector2(265, 455) if big else Vector2(300, 440)
	_figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_base_portrait = BattleArt.resolve_figure_path(_group_dir(c), _portrait_file(c))
	if _base_portrait != "" and ResourceLoader.exists(_base_portrait):
		_figure.texture = load(_base_portrait)
	else:
		_figure.visible = false
	vbox.add_child(_figure)

	# 浮動名牌（暗金霓虹）
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", BattleArt.neon_frame())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	plate.add_child(pv)

	_name_label = Label.new()
	_name_label.text = "%s  Lv%d" % [c.display_name, c.level]
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	pv.add_child(_name_label)

	# 弱點徽章列（第一期）：命中過才顯示屬性，否則「弱 ？」
	_weak_label = Label.new()
	_weak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weak_label.add_theme_font_size_override("font_size", 15)
	_weak_label.add_theme_color_override("font_color", Color("#FFD700"))
	pv.add_child(_weak_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = c.max_hp
	_hp_bar.value = c.current_hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(180, 12)
	pv.add_child(_hp_bar)

	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 16)
	pv.add_child(_hp_text)

	_down_label = Label.new()
	_down_label.text = "DOWN!"
	_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_label.add_theme_font_size_override("font_size", 22)
	_down_label.add_theme_color_override("font_color", Color("#FFD700"))
	_down_label.visible = false
	pv.add_child(_down_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#FF6B00"))
	pv.add_child(_status_label)

	vbox.add_child(plate)
	vbox.move_child(plate, 0)  # 名牌/血條移到 figure 上方（頭上），不再壓在腳下
	if big:
		var foot_lift := Control.new()  # Boss 腳底抬高＝往後站（站在頂樓較後方）
		foot_lift.custom_minimum_size = Vector2(0, 70)
		foot_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(foot_lift)

	# 點擊立繪選目標（覆蓋整格透明 Button，預設隱藏）
	_hit_button = Button.new()
	_hit_button.flat = true
	_hit_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_button.modulate = Color(1, 1, 1, 0)
	_hit_button.visible = false
	_hit_button.pressed.connect(func(): target_pressed.emit(self))
	add_child(_hit_button)

	c.hp_changed.connect(_on_hp_changed)
	c.down_changed.connect(_on_down_changed)
	_on_hp_changed(c.current_hp, c.max_hp)
	refresh_weakness_badges()

	# boss：掛 VFX 疊層(待機霧+火星常駐；受擊/攻擊/phase2/擊敗觸發)
	if c.is_boss and ResourceLoader.exists("res://assets/2d/portraits/boss/fx/idle_mist.png"):
		vfx = ARES_VFX.new()
		add_child(vfx)
		vfx.figure = _figure

func _group_dir(c: Combatant) -> String:
	return BattleArt.BOSS_DIR if c.is_boss else BattleArt.ENEMY_DIR

func _portrait_file(c: Combatant) -> String:
	return c.portrait_path.get_file() if c.portrait_path != "" else ""

func _on_hp_changed(current: int, max_hp: int) -> void:
	var prev := int(_hp_bar.value)
	_hp_bar.value = current
	_hp_text.text = "%d / %d" % [current, max_hp]
	if current < prev:
		play_hit_shake()
	if vfx != null:
		if current <= 0:
			vfx.play_defeat()
		elif current < prev:
			vfx.play_hit()
	if current <= 0:
		modulate = Color(0.4, 0.4, 0.4, 0.45)
		if _figure != null:
			_figure.breathing = false
		_down_label.visible = false
		_hit_button.visible = false

func _on_down_changed(is_down: bool) -> void:
	_down_label.visible = is_down and combatant.is_alive()

func set_statuses(statuses: Array) -> void:
	_status_label.text = "、".join(statuses)

## 弱點徽章（第一期）：走訪敵人 weaknesses，已探知的顯示屬性名，未探知顯示「？」。
## 無弱點的敵人不顯示。BattleManager 命中弱點後呼叫刷新（探知→揭曉）。
func refresh_weakness_badges() -> void:
	if _weak_label == null:
		return
	if combatant.weaknesses.is_empty():
		_weak_label.text = ""
		return
	var parts: Array = []
	var eid: String = combatant.base_id if combatant.base_id != "" else combatant.id
	for w in combatant.weaknesses:
		if GameManager.knows_weakness(eid, w):
			parts.append(ELEM_NAMES.get(w, w))
		else:
			parts.append("？")
	_weak_label.text = "弱 " + " ".join(parts)

func set_target_mode(enabled: bool) -> void:
	_hit_button.visible = enabled and combatant.is_alive()

## 持久換站姿（Boss 進階段）。
func set_base_portrait(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path) or _figure == null:
		return
	_base_portrait = path
	if _figure.visible:
		_figure.texture = load(path)
		_figure.reset_base()

## 受擊演出：紅閃＋左右震動。呼吸只動 scale/rotation，position tween 不與其打架；
## 結尾寫回起震時抓的 base，容器之後 re-layout 會自行修正。
func play_hit_shake() -> void:
	if _figure == null or not _figure.visible:
		return
	_figure.self_modulate = Color(1.7, 0.5, 0.45)
	var flash := create_tween()
	flash.tween_property(_figure, "self_modulate", Color.WHITE, 0.35)
	var base_x := _figure.position.x
	var shake := create_tween()
	for i in 4:
		shake.tween_property(_figure, "position:x", base_x + (7.0 if i % 2 == 0 else -7.0), 0.04)
	shake.tween_property(_figure, "position:x", base_x, 0.04)

## 出招演出：朝玩家(畫面左下)快速撲一步再回位。
func play_lunge() -> void:
	if _figure == null or not _figure.visible:
		return
	var base := _figure.position
	var tw := create_tween()
	tw.tween_property(_figure, "position", base + Vector2(-30.0, 22.0), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_figure, "position", base, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 暫態表情/姿勢：切 path，secs 後回 _base（新 flash 取消舊的）。
func flash_mood(path: String, secs: float) -> void:
	if path == "" or not ResourceLoader.exists(path) or _figure == null or not _figure.visible:
		return
	_figure.texture = load(path)
	_mood_timer = get_tree().create_timer(secs)
	var my := _mood_timer
	await my.timeout
	if my == _mood_timer and is_instance_valid(_figure):
		_figure.texture = load(_base_portrait)
