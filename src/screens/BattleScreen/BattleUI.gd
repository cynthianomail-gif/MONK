extends CanvasLayer

## 戰鬥 UI（Step 3 功能版；Step 4 套霓虹斜切美術；Step 5 技能子選單改版候選 A：直列卡片）

const STATUS_NAMES: Dictionary = {
	"chaos": "混亂", "burn": "燃燒", "stun": "暈眩", "seal": "封印",
	"slow": "遲緩", "fear": "恐懼", "poison": "中毒", "weaken": "虛弱",
	"taunt": "嘲諷"
}

# ─── 技能子選單卡片（候選 A，移植自 test/CaptureSkillMenuMockA.gd）───
const SKILL_INK_RED := Color(0.82, 0.18, 0.13)
const SKILL_GOLD := Color(0.788, 0.659, 0.38)
const SKILL_BG_CARD := Color(0.14, 0.14, 0.15, 0.95)
const SKILL_ATTR_GLYPH := {
	"physical": {"ch": "拳", "color": Color(0.85, 0.85, 0.85)},
	"karma":    {"ch": "業", "color": Color(0.82, 0.18, 0.13)},
	"merit":    {"ch": "功", "color": Color(0.788, 0.659, 0.38)},
	"support":  {"ch": "護", "color": Color(0.75, 0.75, 0.78)},
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
@onready var turn_order_host: Control = %TurnOrderHost
@onready var command_host: Control = %CommandHost
@onready var float_layer: Control = %FloatLayer
@onready var focus_dim: ColorRect = %FocusDim
@onready var daoxing_label: Label = %DaoxingLabel

signal hold_up_choice(choice: String)

var _panels: Array = []
var _pending_skill: String = ""
var _items: Dictionary = {}
var _player_job: String = "ascetic"
var _player_low: bool = false
var _turn_order: TurnOrderBar = null
var _command_menu: CommandMenu = null

# 技能子選單卡片導航（候選 A）：skill_menu 顯示技能列表時才啟用鍵盤/手把輸入。
var _skill_cards: Array = []       # Array[PanelContainer]，對應 _skill_nav_ids 同序
var _skill_nav_ids: Array = []     # Array[String]，可選技能 id（disabled 技能仍列出但不可選中執行）
var _skill_selected: int = 0
var _skill_nav_active: bool = false

func _ready() -> void:
	_items = JsonLoader.load_json("res://data/items.json")
	skill_menu.visible = false
	hold_up_menu.visible = false
	all_out_overlay.visible = false
	combo_label.visible = false
	manager.battle_log.connect(show_log)
	EventBus.combo_count_changed.connect(_on_combo)
	GameManager.stat_changed.connect(func(k, _v):
		_update_resources()
		if k == "daoxing":
			_update_daoxing())
	var executor: Node = manager.get_node("SkillExecutor")
	executor.gold_stolen.connect(_on_gold_stolen)
	executor.damage_dealt.connect(_on_damage_dealt)  # 傷害漂浮字（第一期）
	var status: Node = executor.get_node("StatusEffects")
	status.status_applied.connect(func(_id, _t): _refresh_statuses())
	status.status_damage.connect(func(id, amount, t):
		show_log("%s 受到 %s 傷害 %d" % [_panel_name(id), STATUS_NAMES.get(t, t), amount]))
	%HoldUpGold.pressed.connect(func(): _choose_hold_up("gold"))
	%HoldUpInfo.pressed.connect(func(): _choose_hold_up("info"))
	%HoldUpItem.pressed.connect(func(): _choose_hold_up("item"))
	focus_dim.visible = false
	_setup_turn_order()
	_setup_command_menu()
	_update_daoxing()

## 行動順序條（第一期）：掛在 TurnOrderHost 下。
func _setup_turn_order() -> void:
	_turn_order = TurnOrderBar.new()
	_turn_order.set_anchors_preset(Control.PRESET_TOP_LEFT)
	turn_order_host.add_child(_turn_order)

## 主指令選單（第一期）：掛在 CommandHost 下。
func _setup_command_menu() -> void:
	_command_menu = CommandMenu.new()
	_command_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_command_menu.command_chosen.connect(_on_command_chosen)
	command_host.add_child(_command_menu)

func render_turn_order(queue: Array, current_idx: int) -> void:
	if _turn_order != null:
		_turn_order.render(queue, current_idx)

## BattleManager 呼叫：開主指令選單，disabled＝要灰置的指令（如護法未實作）。
func open_command_menu(disabled_cmds: Array) -> void:
	skill_menu.visible = false
	_skill_nav_active = false
	if _command_menu != null:
		_command_menu.open_menu(disabled_cmds)

func _on_command_chosen(cmd: String) -> void:
	if _command_menu != null:
		_command_menu.close_menu()
	manager.on_command(cmd)

## 攻擊指令：走既有 target/use 流程（同技能一顆走）。
func begin_target_or_use(skill_id: String) -> void:
	_on_skill_card_pressed(skill_id)

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
		if cur < player_hp_bar.value:
			_shake_player_figure()
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

## 技能子選單（候選 A：直列卡片）：每卡＝屬性徽章(左) + 技能名+消耗(右上) + 一行描述常駐(右下)。
## 選中卡：Tween 放大 1.06＋朱紅描邊＋左側金色強調條。鍵盤/手把 ui_up／ui_down／interact／confirm／cancel。
func show_skill_menu(skill_ids: Array) -> void:
	focus_dim.visible = false
	skill_menu.visible = true
	for c in skill_buttons.get_children():
		c.queue_free()
	_skill_cards.clear()
	_skill_nav_ids.clear()

	for id in skill_ids:
		var sk: Dictionary = manager.executor.get_skill(id)
		var enabled: bool = manager.can_use(id)
		var card := _build_skill_card(id, sk, enabled)
		card.set_meta("skill_id", id)
		skill_buttons.add_child(card)
		_skill_cards.append(card)
		_skill_nav_ids.append(id)

	var back_btn := Button.new()
	back_btn.text = "← 返回指令"
	back_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_btn.pressed.connect(_back_to_command)
	skill_buttons.add_child(back_btn)

	skill_menu.visible = true
	_skill_selected = _first_enabled_skill()
	_skill_nav_active = true
	_refresh_skill_cards()

## 消耗文字（金色數字風格，同 mockup `_cost_text`）：業障/功德/HP%/需金，無消耗顯示「無消耗」。
func _skill_cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	if cost.get("karma", 0) > 0:
		parts.append("業障%d" % cost.karma)
	if cost.get("merit", 0) > 0:
		parts.append("功德%d" % cost.merit)
	if cost.get("hp", 0) > 0:
		parts.append("HP%d%%" % int(cost.hp * 100))
	if cost.get("gold_required", 0) > 0:
		parts.append("需金%d" % cost.gold_required)
	return "、".join(parts) if not parts.is_empty() else "無消耗"

## 建一張技能卡（移植自 test/CaptureSkillMenuMockA.gd 的 `_build_card()`）。
## disabled 技能（enabled=false）仍列出但整體降低不透明度，且不計入可選中導航的執行結果（點擊/確認不會出招）。
func _build_skill_card(id: String, sk: Dictionary, enabled: bool) -> PanelContainer:
	var card := PanelContainer.new()
	# 卡寬跟隨 SkillMenu 面板實際可用寬度（面板 520px－左右 margin 32px＝488px），
	# 不可比照 mockup 硬寫 560（mockup 擺拍用的是獨立寬面板，正式面板較窄，硬寫會讓卡片
	# 溢出 ScrollContainer 可視範圍，導致消耗文字被推到畫面外、描述被裁切）。
	card.custom_minimum_size = Vector2(0, 92)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pivot_offset = Vector2(0, 46)
	card.modulate.a = 1.0 if enabled else 0.55
	var sb := StyleBoxFlat.new()
	sb.bg_color = SKILL_BG_CARD
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.32, 0.32, 0.34)
	card.set("theme_override_styles/panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var accent := ColorRect.new()
	accent.color = SKILL_GOLD
	accent.custom_minimum_size = Vector2(5, 0)
	accent.visible = false
	hbox.add_child(accent)
	card.set_meta("accent", accent)

	var dtype: String = sk.get("damage_type", "physical")
	var glyph: Dictionary = SKILL_ATTR_GLYPH.get(dtype, SKILL_ATTR_GLYPH["physical"])
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(60, 60)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.05, 0.05, 0.06)
	badge_sb.set_corner_radius_all(30)
	badge_sb.set_border_width_all(2)
	badge_sb.border_color = glyph.color
	badge.set("theme_override_styles/panel", badge_sb)
	var badge_lbl := Label.new()
	badge_lbl.text = glyph.ch
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 26)
	badge_lbl.add_theme_color_override("font_color", glyph.color)
	badge.add_child(badge_lbl)
	hbox.add_child(badge)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	var name_lbl := Label.new()
	name_lbl.text = sk.get("name", id)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color",
			Color("#FFD700") if sk.get("is_heat_action", false) else Color(0.85, 0.85, 0.85))
	top_row.add_child(name_lbl)
	card.set_meta("name_lbl", name_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var cost_lbl := Label.new()
	cost_lbl.text = _skill_cost_text(sk.get("cost", {}))
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", SKILL_GOLD)
	top_row.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = sk.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.tooltip_text = sk.get("description", "")
	vbox.add_child(desc_lbl)

	# 滑鼠可點：透明 Button 覆蓋整卡（保留鍵盤/手把導航與滑鼠雙輸入，同 CommandMenu 手法）。
	var btn := Button.new()
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = not enabled
	btn.pressed.connect(_on_skill_card_pressed.bind(id))
	btn.mouse_entered.connect(_on_skill_card_hover.bind(id))
	card.add_child(btn)

	return card

func _first_enabled_skill() -> int:
	for i in _skill_nav_ids.size():
		if manager.can_use(_skill_nav_ids[i]):
			return i
	return 0 if not _skill_nav_ids.is_empty() else -1

## 卡片選中態刷新：朱紅描邊＋左側金條＋放大（Tween，同 CommandMenu._refresh() 手法）。
## 注意：只放大 Y 軸（1.08），不放大 X 軸——卡片寬度已 fill 滿 ScrollContainer 可視寬度，
## 若比照 CommandMenu 同時放大 X 軸，選中卡會橫向撐出裁切邊界（cost 文字/描述被切掉，實測踩過）。
func _refresh_skill_cards() -> void:
	for i in _skill_cards.size():
		var card: PanelContainer = _skill_cards[i]
		var id: String = _skill_nav_ids[i]
		var is_sel: bool = (i == _skill_selected)
		var enabled: bool = manager.can_use(id)
		var sb := StyleBoxFlat.new()
		sb.bg_color = SKILL_BG_CARD
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(12)
		if is_sel and enabled:
			sb.set_border_width_all(3)
			sb.border_color = SKILL_INK_RED
			sb.bg_color = Color(0.18, 0.1, 0.1, 0.97)
		else:
			sb.set_border_width_all(1)
			sb.border_color = Color(0.32, 0.32, 0.34)
		card.set("theme_override_styles/panel", sb)
		var accent: ColorRect = card.get_meta("accent")
		accent.visible = is_sel and enabled
		var name_lbl: Label = card.get_meta("name_lbl")
		if not (name_lbl.text.length() > 0 and _skill_is_heat(id)):
			name_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95) if (is_sel and enabled) else Color(0.85, 0.85, 0.85))
		var tw := card.create_tween()
		var target_scale := Vector2(1.0, 1.08) if (is_sel and enabled) else Vector2.ONE
		tw.tween_property(card, "scale", target_scale, 0.1)

func _skill_is_heat(id: String) -> bool:
	var sk: Dictionary = manager.executor.get_skill(id)
	return sk.get("is_heat_action", false)

func _input(event: InputEvent) -> void:
	if not _skill_nav_active:
		return
	if event.is_action_pressed("ui_down"):
		_move_skill_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_skill_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
		_confirm_skill_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_back_to_command()
		get_viewport().set_input_as_handled()

func _move_skill_selection(dir: int) -> void:
	var n: int = _skill_nav_ids.size()
	if n == 0:
		return
	var i: int = _skill_selected
	for _k in n:
		i = (i + dir + n) % n
		if manager.can_use(_skill_nav_ids[i]):
			_skill_selected = i
			break
	_refresh_skill_cards()

func _confirm_skill_selection() -> void:
	if _skill_selected < 0 or _skill_selected >= _skill_nav_ids.size():
		return
	var id: String = _skill_nav_ids[_skill_selected]
	if not manager.can_use(id):
		return
	_on_skill_card_pressed(id)

func _on_skill_card_hover(id: String) -> void:
	if not manager.can_use(id):
		return
	var idx: int = _skill_nav_ids.find(id)
	if idx == -1:
		return
	_skill_selected = idx
	_refresh_skill_cards()

func _on_skill_card_pressed(skill_id: String) -> void:
	_skill_nav_active = false
	var sk: Dictionary = manager.executor.get_skill(skill_id)
	var alive: Array = manager.enemy_combatants.filter(func(e): return e.is_alive())
	var needs_target: bool = sk.get("target", "single") == "single" and alive.size() > 1 \
			and sk.get("damage_type", "") != "support"
	skill_menu.visible = false
	if needs_target:
		_pending_skill = skill_id
		show_log("選擇目標……")
		_set_focus_dim(true)  # 聚焦演出：背景壓暗
		for p in _panels:
			p.set_target_mode(true)
	else:
		manager.player_use_skill(skill_id, _first_alive_index())

func _on_target_chosen(panel: EnemyPanel) -> void:
	for p in _panels:
		p.set_target_mode(false)
	_set_focus_dim(false)
	if _pending_skill.is_empty():
		return
	var skill: String = _pending_skill
	_pending_skill = ""
	manager.player_use_skill(skill, panel.index)

## 聚焦壓暗（第一期）：選目標時背景 modulate 壓暗 0.6。
func _set_focus_dim(on: bool) -> void:
	if focus_dim == null:
		return
	focus_dim.visible = true
	var tw := create_tween()
	tw.tween_property(focus_dim, "color:a", 0.6 if on else 0.0, 0.15)
	if not on:
		tw.tween_callback(func(): focus_dim.visible = false)

func _first_alive_index() -> int:
	for i in manager.enemy_combatants.size():
		if manager.enemy_combatants[i].is_alive():
			return i
	return 0

## 返回主指令選單（技能/道具子選單的返回鍵）。
func _back_to_command() -> void:
	skill_menu.visible = false
	_skill_nav_active = false
	open_command_menu(manager._disabled_commands())

## 公開：由 BattleManager on_command("item") 呼叫。
func show_item_menu() -> void:
	if not _has_usable_items():
		_back_to_command()
		return
	_show_item_menu()

# ─── 護法子選單（第四期）────────────────────────────────
## 公開：由 BattleManager on_command("summon") 呼叫。2 尊列出，已用過/金幣不足灰置。
func show_summon_menu() -> void:
	skill_menu.visible = false
	_skill_nav_active = false
	for c in skill_buttons.get_children():
		c.queue_free()
	var defs: Dictionary = manager.summon_defs()
	for sid in defs.keys():
		var data: Dictionary = defs[sid]
		var btn := Button.new()
		btn.text = _summon_button_text(sid, data)
		btn.tooltip_text = data.get("desc", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not manager.can_summon(sid)
		btn.pressed.connect(_on_summon_pressed.bind(sid))
		skill_buttons.add_child(btn)
	var back := Button.new()
	back.text = "← 返回指令"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_back_to_command)
	skill_buttons.add_child(back)
	skill_menu.visible = true

func _summon_button_text(sid: String, data: Dictionary) -> String:
	var name: String = data.get("name", sid)
	var cost: int = int(data.get("gold_cost", 0))
	if manager.summon_used(sid):
		return "%s（本場已請過）" % name
	if GameManager.player.gold < cost:
		return "%s（金幣不足，需 %d）" % [name, cost]
	return "%s（金幣 %d）" % [name, cost]

func _on_summon_pressed(summon_id: String) -> void:
	skill_menu.visible = false
	manager.player_use_summon(summon_id)

## 護法演出（第四期）：立繪從側面滑入＋全屏色閃＋震動＋結算（BattleManager 結算完效果後呼叫的是本函式本身，
## 效果套用在 BattleManager._apply_summon_effect，本函式只管演出，等待完成後回傳）。
func play_summon_effect(_summon_id: String, data: Dictionary) -> void:
	AudioManager.play_sfx("impact_heavy")
	show_log(String(data.get("cutscene_text", data.get("name", ""))))

	# 全屏色閃（依效果類型：傷害朱紅／支援金色）
	var flash_color: Color = Color("#C93A2E") if data.get("effect_kind", "") == "damage" else Color(0.788, 0.659, 0.38)
	var flash := ColorRect.new()
	flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.75, 0.08)
	ft.tween_property(flash, "color:a", 0.0, 0.25)

	# 立繪從側面滑入
	var portrait_path: String = String(data.get("portrait", ""))
	var summon_fig: TextureRect = null
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		summon_fig = TextureRect.new()
		summon_fig.texture = load(portrait_path)
		summon_fig.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		summon_fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var vh: Vector2 = get_viewport().get_visible_rect().size
		summon_fig.custom_minimum_size = Vector2(vh.x * 0.32, vh.y * 0.7)
		summon_fig.size = summon_fig.custom_minimum_size
		var target_pos := Vector2(vh.x * 0.5 - summon_fig.size.x * 0.5, vh.y * 0.18)
		summon_fig.position = Vector2(-summon_fig.size.x, target_pos.y)
		add_child(summon_fig)
		var st := create_tween()
		st.tween_property(summon_fig, "position:x", target_pos.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 震動（全畫面 Control 位移抖動，純 Tween）
	_hit_stop(0.05, 0.1)
	await get_tree().create_timer(0.55).timeout

	if summon_fig != null and is_instance_valid(summon_fig):
		var out_tw := create_tween()
		out_tw.tween_property(summon_fig, "modulate:a", 0.0, 0.25)
		out_tw.tween_callback(summon_fig.queue_free)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(flash):
		flash.queue_free()

# ─── 道具子選單 ────────────────────────────────────────
func _has_usable_items() -> bool:
	for id in GameManager.player.get("inventory", {}):
		if GameManager.item_count(id) > 0 and _items.has(id):
			return true
	return false

func _show_item_menu() -> void:
	_skill_nav_active = false
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
	back.text = "← 返回指令"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_back_to_command)
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
	_lunge_player_figure()
	show_log(text)
	_refresh_statuses()
	await get_tree().create_timer(0.45).timeout

## 傷害漂浮字（第一期）：命中/爆擊/弱點/Miss 四態，飄在目標立繪上方。
func _on_damage_dealt(target_id: String, amount: int, dtype: String) -> void:
	var pos: Vector2 = _floater_pos_for(target_id)
	var opts: Dictionary = {}
	if dtype == "miss":
		opts["miss"] = true
	else:
		# 命中對象是敵人且屬性剛好是其弱點 → WEAK 標籤（reflect 打回玩家不算）
		var tgt: Combatant = _combatant_for(target_id)
		if tgt != null and dtype in tgt.weaknesses:
			opts["hit_weakness"] = true
			opts["is_crit"] = true  # 弱點必放大顯示
	DamageFloater.spawn(float_layer, pos, amount, opts)

func _combatant_for(target_id: String) -> Combatant:
	if target_id == "player":
		return manager.player_combatant
	for p in _panels:
		if p.combatant.id == target_id:
			return p.combatant
	return null

func _floater_pos_for(target_id: String) -> Vector2:
	if target_id == "player":
		if player_figure != null:
			return player_figure.global_position + Vector2(player_figure.size.x * 0.5, 80.0)
		return Vector2(300, 500)
	for p in _panels:
		if p.combatant.id == target_id:
			return p.global_position + Vector2(p.size.x * 0.5, 120.0)
	return Vector2(get_viewport().get_visible_rect().size.x * 0.6, 300.0)

## 弱點徽章刷新（第一期）：命中弱點揭曉後 BattleManager 呼叫。
func refresh_all_weakness_badges() -> void:
	for p in _panels:
		p.refresh_weakness_badges()

## 完美格擋判定窗：目標(玩家)處紅色警示（純 Control 閃爍）。
func show_guard_warning(_attacker: Combatant) -> void:
	if player_figure == null or not player_figure.visible:
		return
	AudioManager.play_sfx("weakness_hit")  # 警示音（沿用既有音效資產）
	var tw := create_tween().set_loops(3)
	tw.tween_property(player_figure, "self_modulate", Color(1.6, 0.4, 0.4), 0.12)
	tw.tween_property(player_figure, "self_modulate", Color.WHITE, 0.12)
	player_figure.set_meta("guard_tw", tw)

func hide_guard_warning() -> void:
	if player_figure != null:
		if player_figure.has_meta("guard_tw"):
			var tw = player_figure.get_meta("guard_tw")
			if tw is Tween and tw.is_valid():
				tw.kill()
		player_figure.self_modulate = Color.WHITE

## 完美格擋成功：立繪閃白＋斜切「格擋！」字樣＋短 hit-stop。
func flash_perfect_guard() -> void:
	AudioManager.play_sfx("impact_heavy")
	if player_figure != null and player_figure.visible:
		player_figure.self_modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(player_figure, "self_modulate", Color.WHITE, 0.25)
	# 斜切「格擋！」字樣
	var lbl := Label.new()
	lbl.text = "格擋！"
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	lbl.rotation_degrees = -10.0
	lbl.position = _floater_pos_for("player") + Vector2(-60, -40)
	float_layer.add_child(lbl)
	lbl.modulate.a = 0.0
	var t2 := create_tween()
	t2.tween_property(lbl, "modulate:a", 1.0, 0.08)
	t2.tween_interval(0.4)
	t2.tween_property(lbl, "modulate:a", 0.0, 0.2)
	t2.tween_callback(lbl.queue_free)
	# 短 hit-stop（沿用 MinigameBase 體感模式：Engine.time_scale 一瞬）
	_hit_stop(0.06, 0.08)

func _hit_stop(dur: float, slow: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = slow
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

func _update_daoxing() -> void:
	if daoxing_label != null:
		daoxing_label.text = "道行 %d" % int(GameManager.player.get("daoxing", 0))

## 玩家出招：背面立繪朝敵陣(右上)前撲再回位（position tween 不與呼吸 scale 打架）。
func _lunge_player_figure() -> void:
	if player_figure == null or not player_figure.visible:
		return
	var base := player_figure.position
	var tw := create_tween()
	tw.tween_property(player_figure, "position", base + Vector2(44.0, -26.0), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_figure, "position", base, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 出招瞬間立繪 scale 1.06 彈一下（聚焦演出）
	var base_s := player_figure.scale
	var bt := create_tween()
	bt.tween_property(player_figure, "scale", base_s * 1.06, 0.1).set_trans(Tween.TRANS_BACK)
	bt.tween_property(player_figure, "scale", base_s, 0.14).set_trans(Tween.TRANS_QUAD)

## 玩家受擊：紅閃＋震動。
func _shake_player_figure() -> void:
	if player_figure == null or not player_figure.visible:
		return
	player_figure.self_modulate = Color(1.7, 0.5, 0.45)
	var flash := create_tween()
	flash.tween_property(player_figure, "self_modulate", Color.WHITE, 0.35)
	var base_x := player_figure.position.x
	var shake := create_tween()
	for i in 4:
		shake.tween_property(player_figure, "position:x", base_x + (8.0 if i % 2 == 0 else -8.0), 0.04)
	shake.tween_property(player_figure, "position:x", base_x, 0.04)

## 敵人出招前撲（BattleManager 敵人回合呼叫）。
func enemy_lunge(c: Combatant) -> void:
	var p := _panel_for(c)
	if p != null:
		p.play_lunge()

## 總攻擊演出升級（第二期第 3 點）：全畫面白閃 → 玩家立繪多重殘影交錯掃過 ＋速度線條紋
## → 水墨定格（背景急停壓暗、朱印「超渡」大字）→ 結算。全 Control+Tween，不新增圖片素材。
func play_all_out() -> void:
	AudioManager.play_sfx("impact_heavy")
	# 1) 全畫面白閃
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.9, 0.06)
	ft.tween_property(flash, "color:a", 0.0, 0.2)
	await ft.finished
	flash.queue_free()

	# 2) 玩家立繪多重殘影 + 速度線
	_play_afterimages()
	var lines := _make_speed_lines()
	add_child(lines)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(lines):
		lines.queue_free()

	# 3) 水墨定格：背景急停壓暗 + 朱印「超渡」大字
	all_out_overlay.visible = true
	all_out_overlay.color = Color(0.06, 0.02, 0.03, 0.0)
	all_out_label.text = "超　渡"
	all_out_label.add_theme_color_override("font_color", Color("#C93A2E"))
	all_out_label.pivot_offset = all_out_label.size * 0.5
	all_out_label.scale = Vector2(1.6, 1.6)
	all_out_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(all_out_overlay, "color:a", 0.9, 0.12)
	var lt := create_tween()
	lt.set_parallel(true)
	lt.tween_property(all_out_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_property(all_out_label, "modulate:a", 1.0, 0.12)
	await get_tree().create_timer(0.9).timeout
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(all_out_overlay, "color:a", 0.0, 0.3)
	out.tween_property(all_out_label, "modulate:a", 0.0, 0.3)
	await out.finished
	all_out_overlay.visible = false
	all_out_label.add_theme_color_override("font_color", Color.WHITE)  # 還原（下場沿用）

## 玩家立繪殘影：複製 TextureRect 快速交錯掃過後淡出自清。
func _play_afterimages() -> void:
	if player_figure == null or not player_figure.visible or player_figure.texture == null:
		return
	for i in 5:
		var ghost := TextureRect.new()
		ghost.texture = player_figure.texture
		ghost.expand_mode = player_figure.expand_mode
		ghost.stretch_mode = player_figure.stretch_mode
		ghost.size = player_figure.size
		ghost.position = player_figure.position
		ghost.modulate = Color("#C93A2E")
		ghost.modulate.a = 0.5
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ghost)
		var dx := 120.0 * (i + 1)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(ghost, "position:x", ghost.position.x + dx, 0.3).set_delay(i * 0.04)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.3).set_delay(i * 0.04)
		tw.chain().tween_callback(ghost.queue_free)

## 速度線：橫向朱紅/白條紋 ColorRect 群（純 Control）。
func _make_speed_lines() -> Control:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vh := get_viewport().get_visible_rect().size
	for i in 14:
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.18) if i % 2 == 0 else Color("#C93A2E")
		bar.color.a = 0.16
		var y := randf() * vh.y
		bar.position = Vector2(-vh.x, y)
		bar.size = Vector2(vh.x, randf_range(2, 6))
		host.add_child(bar)
		var tw := host.create_tween()
		tw.tween_property(bar, "position:x", vh.x, randf_range(0.15, 0.3)).set_delay(randf() * 0.1)
	return host

func show_hold_up_menu() -> String:
	hold_up_menu.visible = true
	var choice: String = await hold_up_choice
	hold_up_menu.visible = false
	return choice

func _choose_hold_up(choice: String) -> void:
	hold_up_choice.emit(choice)

## 勝利結算（第二期第 4 點）：金幣/功德/道行三行。
func play_victory(gold: int, merit: int = 15, daoxing: int = 0) -> void:
	AudioManager.switch_bgm("victory_jingle")
	show_log("勝利！　金幣 +%d　功德 +%d　道行 +%d" % [gold, merit, daoxing])
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
