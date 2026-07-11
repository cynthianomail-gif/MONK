extends Control
## 手機「說明」app：鍵位表＋系統回顧，教學內容的常駐回顧處（K3，2026-07-08）。
## 教學戰（BattleTutorial）解說只播一次，鍵位與機制散落無處可查，這裡是永久參照。
## 四區塊：①鍵位表 ②戰鬥系統 ③時段規則 ④小遊戲。純資料陳列，不含互動邏輯。
## 內容仿 QuestsApp 風格：ScrollContainer + 分節 PanelContainer，避免撐爆 MenuShell
## 內容區（實際可用高 ~570，07-07 BoardApp 已踩過固定高度撐爆的坑）。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 1.0)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	scroll.add_child(col)

	col.add_child(_heading("鍵位表"))
	col.add_child(_keymap_section())
	col.add_child(_heading("戰鬥系統"))
	col.add_child(_battle_section())
	col.add_child(_heading("時段規則"))
	col.add_child(_period_section())
	col.add_child(_heading("小遊戲"))
	col.add_child(_minigame_section())

# --- ①鍵位表 ---
# 查證出處：project.godot:157-220（interact/confirm/cancel/open_menu 等 InputMap）、
# PlayerController.gd:49-56（sprint 執行期註冊=左Shift）、
# PlayerController.gd:59-73（2026-07-10 review 退回修正 F5：ui_left/right/up/down 內建 action
# 執行期補上 WASD 事件，"W/A/S/D 移動" 這行文字原本查無實據，現在是真的）、
# CameraRig.gd:1-38+195-198（滑鼠視角預設捕捉即轉、Q/E 備援轉視角，2026-07-10 由 A/D 改，見 D-1）、
# DialogueHistoryPanel.gd:42-58（Tab 開關對話回想）、
# MapScreen.gd:298-304+MapHUD.gd:11（"休息"＝定點互動，非全域熱鍵）。
func _keymap_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var rows := [
		["W / A / S / D", "移動（方向鍵亦可）"],
		["左 Shift（按住）", "跑步（探索中）／加速戰鬥演出（戰鬥中）"],
		["滑鼠移動", "轉動視角（探索中預設鎖定游標）"],
		["Q / E", "轉動視角（備援，滑鼠不便時用）"],
		["E", "互動 / 灌注解鎖（修行盤）／完美格擋（戰鬥中）"],
		["Esc", "開關選單／取消／切換滑鼠視角鎖定"],
		["M", "開關選單"],
		["Enter / 空白鍵", "確認"],
		["Tab", "開關對話回想記錄（對話進行中）"],
		["休息（互動指令）", "在特定地點以 E 觸發：回血並主動推進時段"],
	]
	for r in rows:
		vb.add_child(_key_row(r[0], r[1]))
	return panel

func _key_row(key_text: String, desc_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var k := Label.new()
	k.text = key_text
	k.custom_minimum_size = Vector2(220, 0)
	k.add_theme_color_override("font_color", GOLD)
	k.add_theme_font_size_override("font_size", 20)
	row.add_child(k)
	var d := Label.new()
	d.text = desc_text
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_theme_color_override("font_color", WARM)
	d.add_theme_font_size_override("font_size", 20)
	row.add_child(d)
	return row

# --- ②戰鬥系統 ---
# 查證出處：CommandMenu.gd:15-22（攻擊/技能/防禦/道具/護法/逃跑六指令，用詞照 COMMANDS 字樣）、
# BattleTutorial.gd:18-39（POINTS 五教學點：回合順序/指令選單/弱點如來爆擊/完美格擋/初試身手）。
func _battle_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var lines := [
		"回合順序：依「敏捷」輪流行動，我方快過對方會先出手。",
		"指令：攻擊（免費近身）／技能（耗業障/功德）／防禦（減傷）／道具（自我施放）／護法（第四期解鎖）／逃跑（雜魚戰可逃，Boss 不可逃）。",
		"弱點與佛祖保佑再來一擊：打中敵人弱點會觸發「如來爆擊」，佛祖保佑再來一擊，可以立刻再行動一次，一路打到對方全倒。",
		"總攻擊：全體敵人皆倒地（或皆中弱點）時可發動的收尾強攻。",
		"完美格擋：敵人出招前會有紅色警示，這時按下「E」，能大幅減傷。",
		"加速：按住「Shift」讓戰鬥演出以 2.5 倍速播放，放開恢復原速。",
		"佛具：水野佛具店可購入念珠（攻）／袈裟（防+HP）／缽（戰勝金幣/功德加成）三欄護符，經書「佛具」頁隨時免費換裝。",
	]
	for l in lines:
		vb.add_child(_line(l))
	return panel

# --- ③時段規則 ---
# 查證出處：MapScreen.gd:298-304（"rest" 動作：GameManager.heal(150) + pending_period_advance）、
# 07-08 交接記憶：時段改版只在戰鬥/小遊戲結束後推進，對話/移動/打工不推進。
# 2026-07-10：字卡文字已拿掉，時段推進只剩短暫轉場黑幕，畫面靠場景光影變化呈現。
func _period_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var lines := [
		"時段只在「戰鬥結束」或「小遊戲完成」後推進，對話、移動、打工都不會推進時段。",
		"「休息」＝在特定地點以 E 主動打坐：立即回血並推進到下一時段，是主動控制時段的手段。",
		"時段推進只有一瞬間的黑幕轉場，不會顯示文字說明，新的時段以場景光影變化呈現。",
	]
	for l in lines:
		vb.add_child(_line(l))
	return panel

# --- ④小遊戲 ---
func _minigame_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var lines := [
		"街上／地下遊藝場的地點會提供小遊戲入口（如飛鏢、保齡球、21點、輪盤、木魚節奏等）。",
		"小遊戲進行中按 Esc 可開啟暫停頁。",
	]
	for l in lines:
		vb.add_child(_line(l))
	return panel

# --- helpers ---
func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_size_override("font_size", 24)
	return l

func _line(text: String) -> Label:
	var l := Label.new()
	l.text = "· " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", WARM)
	l.add_theme_font_size_override("font_size", 20)
	return l

func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = GOLD.darkened(0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	return pc
