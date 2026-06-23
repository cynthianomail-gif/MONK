extends CanvasLayer

## 戰鬥 UI（Step 3 功能版；Step 4 套霓虹斜切美術）

const STATUS_NAMES: Dictionary = {
	"chaos": "混亂", "burn": "燃燒", "stun": "暈眩", "seal": "封印",
	"slow": "遲緩", "fear": "恐懼", "poison": "中毒", "weaken": "虛弱",
	"taunt": "嘲諷"
}

@onready var manager: Control = get_parent()
@onready var enemy_area: HBoxContainer = %EnemyArea
@onready var player_name: Label = %PlayerName
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_text: Label = %PlayerHPText
@onready var resource_label: Label = %ResourceLabel
@onready var skill_menu: PanelContainer = %SkillMenu
@onready var skill_buttons: VBoxContainer = %SkillButtons
@onready var log_label: Label = %LogLabel
@onready var combo_label: Label = %ComboLabel
@onready var hold_up_menu: CenterContainer = %HoldUpMenu
@onready var all_out_overlay: ColorRect = %AllOutOverlay
@onready var all_out_label: Label = %AllOutLabel
@onready var battle_bg: TextureRect = %BattleBg
@onready var player_figure: BreathingFigure = %PlayerFigure

signal hold_up_choice(choice: String)

var _panels: Array = []
var _pending_skill: String = ""
var _items: Dictionary = {}
var _player_job: String = "ascetic"
var _player_low: bool = false

func _ready() -> void:
	_items = JsonLoader.load_json("res://data/items.json")
	skill_menu.visible = false
	hold_up_menu.visible = false
	all_out_overlay.visible = false
	combo_label.visible = false
	manager.battle_log.connect(show_log)
	EventBus.combo_count_changed.connect(_on_combo)
	GameManager.stat_changed.connect(func(_k, _v): _update_resources())
	var executor: Node = manager.get_node("SkillExecutor")
	executor.gold_stolen.connect(_on_gold_stolen)
	var status: Node = executor.get_node("StatusEffects")
	status.status_applied.connect(func(_id, _t): _refresh_statuses())
	status.status_damage.connect(func(id, amount, t):
		show_log("%s 受到 %s 傷害 %d" % [_panel_name(id), STATUS_NAMES.get(t, t), amount]))
	%HoldUpGold.pressed.connect(func(): _choose_hold_up("gold"))
	%HoldUpInfo.pressed.connect(func(): _choose_hold_up("info"))
	%HoldUpItem.pressed.connect(func(): _choose_hold_up("item"))

func build(player: Combatant, enemies: Array) -> void:
	for c in enemy_area.get_children():
		c.queue_free()
	_panels.clear()
	for i in enemies.size():
		add_enemy_panel(enemies[i])
	player_name.text = player.display_name
	player_hp_bar.max_value = player.max_hp
	_player_job = GameManager.player.job
	_player_low = false
	_set_player_portrait("normal")
	player.hp_changed.connect(func(cur, mx):
		player_hp_bar.value = cur
		player_hp_text.text = "%d / %d" % [cur, mx]
		var low: bool = cur < mx * 0.3
		if low != _player_low:
			_player_low = low
			_set_player_portrait("hurt" if low else "normal"))
	player_hp_bar.value = player.current_hp
	player_hp_text.text = "%d / %d" % [player.current_hp, player.max_hp]
	_update_resources()

func add_enemy_panel(c: Combatant) -> void:
	var panel := EnemyPanel.new(c, _panels.size())
	panel.target_pressed.connect(_on_target_chosen)
	enemy_area.add_child(panel)
	_panels.append(panel)

func set_battle_bg(path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		battle_bg.texture = load(path)

## 玩家站立背面圖：state ∈ {normal, hurt}（HP<30% 換受傷姿），套呼吸。
func _set_player_portrait(state: String) -> void:
	var p: String = BattleArt.player_figure_path(_player_job, state)
	if ResourceLoader.exists(p):
		player_figure.texture = load(p)
		player_figure.visible = true
		player_figure.reset_base()
	else:
		player_figure.visible = false

func _panel_for(c: Combatant) -> EnemyPanel:
	for p in _panels:
		if p.combatant == c:
			return p
	return null

## Boss 暫態表情（act/hurt）。
func flash_enemy_mood(c: Combatant, path: String, secs: float) -> void:
	var p := _panel_for(c)
	if p != null:
		p.flash_mood(path, secs)

## Boss 持久換底圖（phase2）。
func set_enemy_base(c: Combatant, path: String) -> void:
	var p := _panel_for(c)
	if p != null:
		p.set_base_portrait(path)

## Boss VFX（攻擊爆發 / 二階加強）；非 boss panel 無 vfx 則略過。
func boss_vfx(c: Combatant, kind: String) -> void:
	var p := _panel_for(c)
	if p != null and p.vfx != null:
		if kind == "attack":
			p.vfx.play_attack()
		elif kind == "phase2":
			p.vfx.set_phase2()

# ─── 技能選單 ──────────────────────────────────────────

func show_skill_menu(skill_ids: Array) -> void:
	for c in skill_buttons.get_children():
		c.queue_free()
	var item_btn := Button.new()
	item_btn.text = "🎒 道具"
	item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_btn.disabled = not _has_usable_items()
	item_btn.pressed.connect(_show_item_menu)
	skill_buttons.add_child(item_btn)
	for id in skill_ids:
		var sk: Dictionary = manager.executor.get_skill(id)
		var btn := Button.new()
		btn.text = _skill_button_text(id, sk)
		btn.tooltip_text = sk.get("description", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not manager.can_use(id)
		if sk.get("is_heat_action", false):
			btn.add_theme_color_override("font_color", Color("#FFD700"))
		btn.pressed.connect(_on_skill_pressed.bind(id))
		skill_buttons.add_child(btn)
	skill_menu.visible = true

func _skill_button_text(id: String, sk: Dictionary) -> String:
	var cost: Dictionary = sk.get("cost", {})
	var parts: Array = []
	if cost.get("karma", 0) > 0:
		parts.append("業障%d" % cost.karma)
	if cost.get("merit", 0) > 0:
		parts.append("功德%d" % cost.merit)
	if cost.get("hp", 0) > 0:
		parts.append("HP%d%%" % int(cost.hp * 100))
	if cost.get("gold_required", 0) > 0:
		parts.append("需金%d" % cost.gold_required)
	var suffix: String = "（%s）" % "、".join(parts) if not parts.is_empty() else ""
	return "%s%s" % [sk.get("name", id), suffix]

func _on_skill_pressed(skill_id: String) -> void:
	var sk: Dictionary = manager.executor.get_skill(skill_id)
	var alive: Array = manager.enemy_combatants.filter(func(e): return e.is_alive())
	var needs_target: bool = sk.get("target", "single") == "single" and alive.size() > 1 \
			and sk.get("damage_type", "") != "support"
	skill_menu.visible = false
	if needs_target:
		_pending_skill = skill_id
		show_log("選擇目標……")
		for p in _panels:
			p.set_target_mode(true)
	else:
		manager.player_use_skill(skill_id, _first_alive_index())

func _on_target_chosen(panel: EnemyPanel) -> void:
	for p in _panels:
		p.set_target_mode(false)
	if _pending_skill.is_empty():
		return
	var skill: String = _pending_skill
	_pending_skill = ""
	manager.player_use_skill(skill, panel.index)

func _first_alive_index() -> int:
	for i in manager.enemy_combatants.size():
		if manager.enemy_combatants[i].is_alive():
			return i
	return 0

# ─── 道具子選單 ────────────────────────────────────────
func _has_usable_items() -> bool:
	for id in GameManager.player.get("inventory", {}):
		if GameManager.item_count(id) > 0 and _items.has(id):
			return true
	return false

func _show_item_menu() -> void:
	for c in skill_buttons.get_children():
		c.queue_free()
	for id in GameManager.player.get("inventory", {}):
		var count: int = GameManager.item_count(id)
		if count <= 0 or not _items.has(id):
			continue
		var data: Dictionary = _items[id]
		var btn := Button.new()
		btn.text = "%s ×%d" % [data.get("name", id), count]
		btn.tooltip_text = data.get("desc", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_pressed.bind(id))
		skill_buttons.add_child(btn)
	var back := Button.new()
	back.text = "← 返回"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(func() -> void: show_skill_menu(manager.available_skills()))
	skill_buttons.add_child(back)
	skill_menu.visible = true

func _on_item_pressed(item_id: String) -> void:
	skill_menu.visible = false
	manager.player_use_item(item_id)

# ─── 演出 ──────────────────────────────────────────────

func play_skill_effect(skill_name: String, hit_weakness: bool, is_crit: bool) -> void:
	var text: String = "「%s」" % skill_name
	if is_crit:
		text += " 會心一擊！"
	if hit_weakness:
		AudioManager.play_sfx("weakness_hit")
	show_log(text)
	_refresh_statuses()
	await get_tree().create_timer(0.45).timeout

func play_all_out() -> void:
	all_out_overlay.visible = true
	all_out_label.text = "超　渡　大　陣"
	AudioManager.play_sfx("impact_heavy")
	var tw := create_tween()
	all_out_overlay.modulate.a = 0.0
	tw.tween_property(all_out_overlay, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(all_out_overlay, "modulate:a", 0.0, 0.3)
	await tw.finished
	all_out_overlay.visible = false

func show_hold_up_menu() -> String:
	hold_up_menu.visible = true
	var choice: String = await hold_up_choice
	hold_up_menu.visible = false
	return choice

func _choose_hold_up(choice: String) -> void:
	hold_up_choice.emit(choice)

func play_victory(gold: int) -> void:
	AudioManager.switch_bgm("victory_jingle")
	show_log("勝利！獲得 %d 金幣、功德 +15" % gold)
	await get_tree().create_timer(0.8).timeout

func play_defeat() -> void:
	AudioManager.switch_bgm("defeat_sting")
	show_log("無戒倒下了……（金幣減半，回古廟休養）")
	await get_tree().create_timer(1.2).timeout

# ─── 顯示更新 ──────────────────────────────────────────

func show_log(text: String) -> void:
	log_label.text = text

func _panel_name(id: String) -> String:
	if id == "player":
		return "無戒"
	for p in _panels:
		if p.combatant.id == id:
			return p.combatant.display_name
	return id

func _on_combo(count: int) -> void:
	combo_label.visible = count > 1
	if count > 1:
		combo_label.text = "連擊 ×%d" % count
		var tw := create_tween()
		combo_label.scale = Vector2(1.3, 1.3)
		tw.tween_property(combo_label, "scale", Vector2.ONE, 0.15)

func _on_gold_stolen(amount: int) -> void:
	if amount >= 0:
		show_log("奪得 %d 金幣！" % amount)
		AudioManager.play_sfx("gold_collect")
	else:
		show_log("被搶走了 %d 金幣！" % -amount)

func _update_resources() -> void:
	var p: Dictionary = GameManager.player
	resource_label.text = "業障 %d ｜ 功德 %d ｜ 金幣 %d" % [p.karma, p.merit, p.gold]

func _refresh_statuses() -> void:
	var status: Node = manager.get_node("SkillExecutor/StatusEffects")
	for p in _panels:
		var names: Array = []
		for s in status.active_statuses(p.combatant):
			names.append(STATUS_NAMES.get(s, s))
		p.set_statuses(names)
