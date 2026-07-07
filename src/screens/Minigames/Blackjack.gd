extends "res://src/screens/Minigames/MinigameBase.gd"
## 21點 Blackjack —— 地下遊藝場小遊戲（2026-07-03 Yakuza 式 UI 全套）。
## 每局：點籌碼下注（+100/次、最多 10 枚、右鍵收回）→〔DEAL〕牌從牌靴飛出+翻牌動畫
## → 左側直排動作選單 HIT/STAND/DOUBLE DOWN/SURRENDER（滑鼠點擊＋↑↓/Enter）
## → 莊家補到 17 → RESULT 結算面板（押注/賠付/合計三行、數字右對齊）。
## 共 3 局，總淨額定勝負。天生 21 點賠 1.5 倍；莊家軟 17 停牌；SPLIT 不做（簡化）。
## 美術＝Codex parlor 近景資產（桌面烤好下注圈+右上紅色牌靴；籌碼用 chip_100、
## 缺檔時程式圓片頂著）；選單/結算面板全程式畫（StyleBoxFlat 扁平風）。

const ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
const ROUNDS: int = 3
const BET_STEP: int = 100                # 一枚籌碼的注金
const BET_CHIPS_MAX: int = 10            # 最多 10 枚（上限 1000）
const CARD_SCALE: float = 0.14
const DEALER_ROW_Y: float = 300.0        # 對齊背景桌面發牌弧線區
const PLAYER_ROW_Y: float = 705.0        # 對齊背景桌面中央下注圈（我方唯一座位）
const ROW_CENTER_X: float = 955.0        # 對齊背景桌面正中央
const CARD_GAP: float = 190.0
const BET_SPOT := Vector2(945.0, 735.0)  # 中央下注圈：下注籌碼疊這裡
const SHOE_POS := Vector2(1490.0, 210.0) # 牌靴（發牌動畫起點，背景右上烤好）
const MENU_POS := Vector2(96.0, 430.0)   # 左側直排選單
const MENU_ITEM_SIZE := Vector2(330.0, 62.0)
const MENU_GAP: float = 12.0
const SUITS: Array = ["♠", "♥", "♦", "♣"]
const RANK_LABELS: Array = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var auto_start: bool = true
var rounds_done: int = 0
var net: int = 0
var _wins: int = 0
var _losses: int = 0
var bet: int = 0                         # 本局注額（下注階段決定；DOUBLE DOWN 後 ×2）
var player_cards: Array = []             # 元素 = rank int 1..13
var dealer_cards: Array = []
var _phase: String = "bet"               # bet / dealing / player / dealer / settle / done
var _deck: Array = []
var _busy: bool = false                  # 動畫進行中，擋輸入
var _hud: Label
var _sub: Label                          # 左上第二行：你/莊點數
var _tip: Label
var _card_root: Node2D
var _chip_root: Node2D                   # 在 _card_root 之下，籌碼被牌自然壓住
var _bet_chips: Array = []
var _hole_card: Sprite2D                 # 莊家暗牌（開牌時翻開）
var _player_nodes: Array = []            # 已發牌的 Sprite2D（增量發牌用）
var _dealer_nodes: Array = []
var _menu_items: Array = []              # [{id, label, enabled, btn}]
var _menu_idx: int = 0
var _chip_zone: Control                  # 下注用的籌碼堆（點擊 +100）
var _panel: Panel                        # RESULT 結算面板
var _panel_title: Label
var _panel_vals: Array = []              # 押注/賠付/合計 數值 Label
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "blackjack"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_new_round()

# --- 純邏輯（測試用）---

## 手牌點數：J/Q/K=10、A 先算 11、爆了逐張降回 1。
func hand_value(cards: Array) -> int:
	var total: int = 0
	var aces: int = 0
	for c in cards:
		var rank: int = int(c)
		if rank == 1:
			aces += 1
			total += 11
		else:
			total += mini(rank, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

## 是否天生 21 點（前兩張 A+十點牌）。
func is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and hand_value(cards) == 21

## 莊家補牌規則：不滿 17 就要（軟 17 也停，簡化）。
func dealer_should_hit(cards: Array) -> bool:
	return hand_value(cards) < 17

## 單局結算淨額（wager＝實際注額；DOUBLE DOWN 時傳 ×2 後的注）：
## 爆牌先判、再比大小；天生 21 賠 1.5 倍、平手退注。
func round_payout(p_cards: Array, d_cards: Array, wager: int) -> int:
	var pv := hand_value(p_cards)
	var dv := hand_value(d_cards)
	if pv > 21:
		return -wager
	if is_blackjack(p_cards) and not is_blackjack(d_cards):
		return int(wager * 1.5)
	if dv > 21:
		return wager
	if pv > dv:
		return wager
	if pv < dv:
		return -wager
	return 0

## 投降淨額：拿回半注（注額固定百位整數，除 2 無殘差）。
func surrender_net(wager: int) -> int:
	return -int(wager / 2.0)

## 加倍/投降只能在前兩張牌時做。
func can_double(cards: Array) -> bool:
	return cards.size() == 2

func can_surrender(cards: Array) -> bool:
	return cards.size() == 2

func build_result() -> Dictionary:
	var won: bool = net > 0
	return make_result({
		"score": net, "win": won,
		"gold": net,
		"karma": 1,   # 小賭怡情，業障一點
	})

# --- 流程 ---

func _input(event: InputEvent) -> void:
	if _busy:
		return
	if _phase == "bet" and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_remove_bet_chip()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match _phase:
		"bet":
			match event.keycode:
				KEY_UP:
					_add_bet_chip()
				KEY_DOWN:
					_remove_bet_chip()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_try_deal()
		"player":
			match event.keycode:
				KEY_UP:
					_menu_move(-1)
				KEY_DOWN:
					_menu_move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_menu_activate()

func _new_round() -> void:
	if rounds_done >= ROUNDS:
		_end()
		return
	_phase = "bet"
	bet = 0
	player_cards.clear()
	dealer_cards.clear()
	for c in _card_root.get_children():
		c.queue_free()
	_player_nodes.clear()
	_dealer_nodes.clear()
	_hole_card = null
	for c in _chip_root.get_children():
		c.queue_free()
	_bet_chips.clear()
	_panel.visible = false
	_chip_zone.visible = true
	_build_menu([{"id": "deal", "label": "DEAL　發牌"}])
	_tip.text = "點籌碼下注 +%d（右鍵收回、最多 %d 枚）｜↑↓ 加減注｜Enter 發牌" % [BET_STEP, BET_CHIPS_MAX]
	_update_hud()

func _reset_deck() -> void:
	_deck.clear()
	for rank in range(1, 14):
		for s in 4:
			_deck.append(rank)
	# Fisher-Yates
	for i in range(_deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = tmp

# --- 下注階段 ---

func _add_bet_chip() -> void:
	if _phase != "bet":
		return
	if bet >= BET_STEP * BET_CHIPS_MAX:
		AudioManager.play_sfx("ui_cancel")
		return
	bet += BET_STEP
	AudioManager.play_sfx("gold_collect")
	_spawn_chip(_bet_chips.size())
	_update_hud()

func _remove_bet_chip() -> void:
	if _phase != "bet" or bet <= 0:
		return
	bet -= BET_STEP
	AudioManager.play_sfx("ui_cancel")
	var chip: Node2D = _bet_chips.pop_back()
	var tw := create_tween()
	tw.tween_property(chip, "modulate:a", 0.0, 0.12)
	tw.tween_callback(chip.queue_free)
	_update_hud()

## 在下注圈疊一枚籌碼（淡入）。idx 決定堆疊高度；x_off 給 DOUBLE DOWN 的第二疊用。
func _spawn_chip(idx: int, x_off: float = 0.0) -> void:
	var chip := _make_chip()
	chip.position = BET_SPOT + Vector2(x_off + _rng.randf_range(-3.0, 3.0), -idx * 6.0)
	chip.modulate.a = 0.0
	# 佈局工具 v3：動態下注籌碼，標樣板不可拖（位置由 BET_SPOT 常數＋堆疊 idx 決定）。
	chip.set_meta("layout_template", "minigame/blackjack/chip")
	_chip_root.add_child(chip)
	_bet_chips.append(chip)
	var tw := create_tween()
	tw.tween_property(chip, "modulate:a", 1.0, 0.18)

func _make_chip() -> Node2D:
	var path := ART + "chip_100_game_ready.png"
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.scale = Vector2.ONE * (84.0 / 1254.0)
		return s
	return ChipDraw.new()

## 缺 chip 圖時的程式圓片（同 Roulette 做法）。
class ChipDraw extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 30, Color(0.66, 0.13, 0.11))
		draw_arc(Vector2.ZERO, 26, 0, TAU, 48, Color(0.92, 0.78, 0.38), 4.0)
		draw_circle(Vector2.ZERO, 14, Color(0.88, 0.74, 0.32))
		for i in range(6):
			var a := TAU * float(i) / 6.0
			draw_arc(Vector2.ZERO, 30, a, a + 0.28, 6, Color(0.95, 0.88, 0.72), 6.0)

func _try_deal() -> void:
	if _phase != "bet":
		return
	if bet <= 0:
		AudioManager.play_sfx("ui_cancel")
		return
	_phase = "dealing"
	_busy = true
	_hide_menu()
	_chip_zone.visible = false
	_tip.text = ""
	_reset_deck()
	AudioManager.play_sfx("ui_select")
	# 開局：玩家兩明、莊家一明一暗，逐張從牌靴飛出
	await _deal_animated(true, true)
	await _deal_animated(false, true)
	await _deal_animated(true, true)
	await _deal_animated(false, false)
	_busy = false
	_update_hud()
	if is_blackjack(player_cards):
		_stand()
	else:
		_phase = "player"
		_show_action_menu()
		_tip.text = "↑↓ 選、Enter 決定（滑鼠也可點）"

# --- 玩家回合（左側選單動作）---

func _show_action_menu() -> void:
	var two := can_double(player_cards)
	_build_menu([
		{"id": "hit", "label": "HIT　要牌"},
		{"id": "stand", "label": "STAND　停牌"},
		{"id": "double", "label": "DOUBLE DOWN　加倍", "enabled": two},
		{"id": "surrender", "label": "SURRENDER　投降", "enabled": two},
	])

func _hit() -> void:
	_busy = true
	_hide_menu()
	await _deal_animated(true, true)
	_busy = false
	_update_hud()
	if hand_value(player_cards) > 21:
		_settle("bust")
	else:
		_show_action_menu()

func _stand() -> void:
	_phase = "dealer"
	_hide_menu()
	AudioManager.play_sfx("ui_select")
	_dealer_play()

## 加倍：注 ×2（桌面補一疊籌碼）、強制只補一張後停牌。
func _double_down() -> void:
	if not can_double(player_cards):
		return
	AudioManager.play_sfx("gold_collect")
	var chips := int(bet / float(BET_STEP))
	bet *= 2
	for i in chips:
		_spawn_chip(i, 46.0)
	_busy = true
	_hide_menu()
	await _deal_animated(true, true)
	_busy = false
	_update_hud()
	if hand_value(player_cards) > 21:
		_settle("bust")
	else:
		_stand()

## 投降：拿回半注、棄局。
func _surrender() -> void:
	if not can_surrender(player_cards):
		return
	_hide_menu()
	_settle("surrender")

func _dealer_play() -> void:
	_busy = true
	if _hole_card:
		await _flip_card(_hole_card)
		_hole_card = null
	_update_hud()
	while dealer_should_hit(dealer_cards):
		await get_tree().create_timer(0.45).timeout
		await _deal_animated(false, true)
		_update_hud()
	await get_tree().create_timer(0.4).timeout
	_busy = false
	_settle("")

# --- 結算 ---

func _settle(kind: String) -> void:
	_phase = "settle"
	_hide_menu()
	rounds_done += 1
	_busy = true
	if _hole_card:   # 爆牌/投降時莊家不補牌，但翻開暗牌給玩家看
		await _flip_card(_hole_card)
		_hole_card = null
	_busy = false
	var delta: int
	var title: String
	var color: Color
	if kind == "surrender":
		delta = surrender_net(bet)
		title = "SURRENDER　投降"
		color = Color(0.80, 0.80, 0.85)
		AudioManager.play_sfx("ui_cancel")
	else:
		delta = round_payout(player_cards, dealer_cards, bet)
		if delta > 0:
			title = "BLACKJACK　天生 21 點" if is_blackjack(player_cards) else "WIN　勝"
			color = Color(0.95, 0.82, 0.40)
			AudioManager.play_sfx("merit_chime")
			spawn_fx_sparkle(BET_SPOT + Vector2(0, -30), 0.20)   # 贏錢金光（下注圈籌碼上方）
		elif delta < 0:
			title = "BUST　爆牌" if kind == "bust" else "LOSE　負"
			color = Color(0.90, 0.42, 0.34)
			AudioManager.play_sfx("wooden_fish_tap")
		else:
			title = "PUSH　平手"
			color = Color(0.80, 0.80, 0.85)
			AudioManager.play_sfx("ui_cancel")
	net += delta
	if delta > 0:
		_wins += 1
	elif delta < 0:
		_losses += 1
	_update_hud()
	_show_result_panel(title, color, delta)
	await get_tree().create_timer(2.2).timeout
	_new_round()

## 三局打完＝離開賭桌前的整場統計面板（局內每局的 RESULT 橫幅不受影響）。
## 「再玩一次」＝繼續留在賭桌（重置局數，不重複發獎勵）；
## 「離開賭桌」才真正 finish() 套用獎勵。
func _end() -> void:
	_phase = "done"
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "滿載而歸" if result.win else "小賭怡情"
	show_result_panel("21點", rating, [
		{"label": "局數", "value": "%d" % ROUNDS},
		{"label": "贏／輸局數", "value": "%d／%d" % [_wins, _losses]},
		{"label": "淨損益", "value": "%s%d 金" % ["+" if net >= 0 else "", net]},
	], result, "離開賭桌")

## 重開一局＝繼續留在賭桌：歸零局數統計，重新開始下注（net 累計不歸零，
## 因為離開時才用最後狀態的 net 結算；連續玩多輪＝net 一路累加到最後離開那刻）。
func restart() -> void:
	rounds_done = 0
	_wins = 0
	_losses = 0
	_finished = false
	_new_round()

# --- 發牌動畫（增量：只動新牌，舊牌平移讓位）---

## 抽一張進手牌＋從牌靴飛入動畫；face_up=false 保持牌背（莊家暗牌）。
func _deal_animated(to_player: bool, face_up: bool) -> void:
	var hand: Array = player_cards if to_player else dealer_cards
	var nodes: Array = _player_nodes if to_player else _dealer_nodes
	var y: float = PLAYER_ROW_Y if to_player else DEALER_ROW_Y
	var rank: int = _deck.pop_back()
	hand.append(rank)
	var card := Sprite2D.new()
	card.texture = load(ART + "card_back_game_ready.png")
	card.scale = Vector2.ONE * CARD_SCALE
	card.position = SHOE_POS
	card.rotation_degrees = -18.0
	card.set_meta("rank", rank)
	# 佈局工具 v3：發牌動畫每張牌都是新節點、position 由 tween 逐幀控制（C 類），
	# 標樣板不可拖。
	card.set_meta("layout_template", "minigame/blackjack/card")
	_card_root.add_child(card)
	nodes.append(card)
	AudioManager.play_sfx("ui_select")
	# 整排重新置中：舊牌平移讓位、新牌從牌靴飛入
	var x0: float = ROW_CENTER_X - CARD_GAP * (nodes.size() - 1) * 0.5
	for i in nodes.size() - 1:
		var n: Sprite2D = nodes[i]
		create_tween().tween_property(n, "position:x", x0 + CARD_GAP * i, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target := Vector2(x0 + CARD_GAP * (nodes.size() - 1), y)
	var tw := create_tween()
	tw.tween_property(card, "position", target, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "rotation_degrees", 0.0, 0.25)
	await tw.finished
	if face_up:
		await _flip_card(card)
	else:
		_hole_card = card
	_update_hud()   # 每張落定即更新左上點數

## 假 3D 翻牌：scale.x 收 0 → 換牌面貼點數 → 撐回。
func _flip_card(card: Sprite2D) -> void:
	var tw := create_tween()
	tw.tween_property(card, "scale:x", 0.0, 0.09)
	await tw.finished
	_set_card_face(card, int(card.get_meta("rank")))
	var tw2 := create_tween()
	tw2.tween_property(card, "scale:x", CARD_SCALE, 0.09)
	await tw2.finished

## 牌背 → 牌面＋點數花色（花色只是風味，不影響點數：以 rank 混一個穩定花色）。
func _set_card_face(card: Sprite2D, rank: int) -> void:
	card.texture = load(ART + "card_frame_blank_game_ready.png")
	var l := Label.new()
	l.text = "%s\n%s" % [RANK_LABELS[rank - 1], SUITS[(rank * 7) % 4]]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 320)
	l.add_theme_color_override("font_color",
		Color(0.72, 0.16, 0.12) if (rank * 7) % 4 in [1, 2] else Color(0.12, 0.10, 0.10))
	l.position = Vector2(-260, -420)
	l.size = Vector2(520, 840)
	card.add_child(l)

# --- 視覺（Codex 資產＋程式 UI）---

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(ART + "blackjack_table_top_v2.png")
	bg.centered = false
	bg.scale = Vector2(1920.0 / 1672.0, 1080.0 / 941.0)
	add_child(bg)
	# 佈局工具 v3：背景整塊登記（A 靜態，父節點是本場景根節點，非 Container，
	# is_free()==true）。
	LayoutStore.register(bg, "minigame/blackjack/bg")
	_chip_root = Node2D.new()
	add_child(_chip_root)
	_card_root = Node2D.new()
	add_child(_card_root)
	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(48, 36)
	var hud_ls := LabelSettings.new()
	hud_ls.font_size = 40
	hud_ls.font_color = Color(0.9, 0.75, 0.42)
	hud_ls.outline_size = 8
	hud_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_hud.label_settings = hud_ls
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：左上 HUD 文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/blackjack/hud_label")
	# 左上第二行：你/莊點數（描邊字，不下桌面中央）
	_sub = Label.new()
	_sub.position = Vector2(48, 92)
	var sub_ls := LabelSettings.new()
	sub_ls.font_size = 36
	sub_ls.font_color = Color(0.92, 0.88, 0.80)
	sub_ls.outline_size = 8
	sub_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_sub.label_settings = sub_ls
	layer.add_child(_sub)
	# 佈局工具 v3：第二行點數文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_sub, "minigame/blackjack/sub_label")
	_build_chip_zone(layer)
	_build_result_panel(layer)
	_tip = Label.new()
	_tip.position = Vector2(0, 1020)
	_tip.size = Vector2(1920, 50)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip_ls := LabelSettings.new()
	tip_ls.font_size = 28
	tip_ls.font_color = Color(0.85, 0.80, 0.72)
	tip_ls.outline_size = 8
	tip_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_tip.label_settings = tip_ls
	layer.add_child(_tip)
	# 佈局工具 v2（P4）：底部提示文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_tip, "minigame/blackjack/tip_label")
	_update_hud()

## 下注籌碼堆：點左鍵 +100（籌碼淡入下注圈）。
func _build_chip_zone(layer: CanvasLayer) -> void:
	_chip_zone = Control.new()
	_chip_zone.position = Vector2(660, 830)
	_chip_zone.size = Vector2(140, 150)
	_chip_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_chip_zone.gui_input.connect(func(event: InputEvent) -> void:
		if _phase == "bet" and event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_add_bet_chip())
	layer.add_child(_chip_zone)
	# 佈局工具 v2（P4）：籌碼下注區整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_chip_zone, "minigame/blackjack/chip_zone")
	for i in 3:
		var chip := _make_chip()
		chip.position = Vector2(70.0 + (i - 1) * 3.0, 62.0 - i * 8.0)
		_chip_zone.add_child(chip)
	var l := Label.new()
	l.text = "+%d" % BET_STEP
	l.position = Vector2(0, 100)
	l.size = Vector2(140, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 28
	ls.font_color = Color(0.95, 0.82, 0.40)
	ls.outline_size = 8
	ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	l.label_settings = ls
	_chip_zone.add_child(l)

## RESULT 結算面板：橫向半透明深色帶+金框標題+三行數字右對齊。
func _build_result_panel(layer: CanvasLayer) -> void:
	_panel = Panel.new()
	_panel.position = Vector2(610, 420)
	_panel.size = Vector2(700, 258)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.88)
	sb.border_color = Color(0.80, 0.62, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	layer.add_child(_panel)
	# 佈局工具 v2（P4）：RESULT 結算橫幅整塊登記（父節點 layer 是 CanvasLayer，
	# 非 Container，is_free()==true）。
	LayoutStore.register(_panel, "minigame/blackjack/result_banner")
	_panel_title = Label.new()
	_panel_title.position = Vector2(0, 10)
	_panel_title.size = Vector2(700, 56)
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	title_ls.font_size = 42
	title_ls.outline_size = 6
	title_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_panel_title.label_settings = title_ls
	_panel.add_child(_panel_title)
	var sep := ColorRect.new()
	sep.position = Vector2(28, 74)
	sep.size = Vector2(644, 2)
	sep.color = Color(0.80, 0.62, 0.28, 0.9)
	_panel.add_child(sep)
	_panel_vals = []
	var names: Array = ["押注", "賠付", "合計"]
	for i in names.size():
		var row_y := 90.0 + i * 52.0
		var name_l := Label.new()
		name_l.text = String(names[i])
		name_l.position = Vector2(60, row_y)
		name_l.add_theme_font_size_override("font_size", 32)
		name_l.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
		_panel.add_child(name_l)
		var val_l := Label.new()
		val_l.position = Vector2(240, row_y)
		val_l.size = Vector2(400, 44)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 32)
		_panel.add_child(val_l)
		_panel_vals.append(val_l)

func _show_result_panel(title: String, color: Color, delta: int) -> void:
	_panel_title.text = title
	_panel_title.label_settings.font_color = color
	_panel_vals[0].text = "%d 金" % bet
	_panel_vals[0].add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	_panel_vals[1].text = "%+d 金" % delta
	_panel_vals[1].add_theme_color_override("font_color",
		Color(0.95, 0.82, 0.40) if delta > 0 else (Color(0.90, 0.42, 0.34) if delta < 0 else Color(0.80, 0.80, 0.85)))
	_panel_vals[2].text = "%+d 金" % net
	_panel_vals[2].add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	_panel.modulate.a = 0.0
	_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)

# --- 左側直排選單（Yakuza 式：深色底、選中白底+◆）---

func _build_menu(items: Array) -> void:
	_hide_menu()
	_menu_idx = 0
	for i in items.size():
		var it: Dictionary = items[i]
		var enabled: bool = bool(it.get("enabled", true))
		var b := Button.new()
		b.position = MENU_POS + Vector2(0, (MENU_ITEM_SIZE.y + MENU_GAP) * i)
		b.size = MENU_ITEM_SIZE
		b.disabled = not enabled
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 28)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		if enabled:
			b.mouse_entered.connect(func() -> void:
				if _menu_idx != idx:
					_menu_idx = idx
					_menu_refresh())
		b.pressed.connect(_menu_do.bind(String(it.id)))
		# 佈局工具 v2（P4）：純標註，不影響遊戲行為。按鈕在 HUD layer 下逐項動態生成，
		# 視為重複樣板元件，改樣板（MENU_POS/MENU_ITEM_SIZE 常數）調整，不個別拖曳。
		b.set_meta("layout_template", "minigame/blackjack/menu_item")
		_hud.get_parent().add_child(b)
		_menu_items.append({"id": it.id, "label": it.label, "enabled": enabled, "btn": b})
	# 預設選第一個可用項
	while _menu_idx < _menu_items.size() - 1 and not bool(_menu_items[_menu_idx].enabled):
		_menu_idx += 1
	_menu_refresh()

func _hide_menu() -> void:
	for it in _menu_items:
		(it.btn as Button).queue_free()
	_menu_items.clear()

func _menu_refresh() -> void:
	for i in _menu_items.size():
		var it: Dictionary = _menu_items[i]
		var b: Button = it.btn
		var sel: bool = (i == _menu_idx) and bool(it.enabled)
		b.text = ("◆ " if sel else "　 ") + String(it.label)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.91, 0.86, 0.96) if sel else Color(0.07, 0.06, 0.07, 0.84)
		sb.border_color = Color(0.80, 0.62, 0.28) if sel else Color(0.55, 0.42, 0.20, 0.9)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 16.0
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var dis_sb := sb.duplicate() as StyleBoxFlat
		dis_sb.bg_color = Color(0.06, 0.05, 0.06, 0.6)
		dis_sb.border_color = Color(0.35, 0.30, 0.22, 0.6)
		b.add_theme_stylebox_override("disabled", dis_sb)
		var fc := Color(0.10, 0.08, 0.08) if sel else Color(0.90, 0.86, 0.78)
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_color_override("font_pressed_color", fc)
		b.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.40))

func _menu_move(dir: int) -> void:
	if _menu_items.is_empty():
		return
	var n := _menu_items.size()
	var idx := _menu_idx
	for step in n:
		idx = (idx + dir + n) % n
		if bool(_menu_items[idx].enabled):
			break
	if idx != _menu_idx:
		_menu_idx = idx
		AudioManager.play_sfx("ui_select")
		_menu_refresh()

func _menu_activate() -> void:
	if _menu_items.is_empty():
		return
	var it: Dictionary = _menu_items[_menu_idx]
	if bool(it.enabled):
		_menu_do(String(it.id))

func _menu_do(id: String) -> void:
	if _busy:
		return
	match id:
		"deal":
			_try_deal()
		"hit":
			if _phase == "player":
				_hit()
		"stand":
			if _phase == "player":
				_stand()
		"double":
			if _phase == "player":
				_double_down()
		"surrender":
			if _phase == "player":
				_surrender()

func _update_hud() -> void:
	if _hud:
		var cur := mini(rounds_done + 1, ROUNDS) if _phase != "done" else ROUNDS
		_hud.text = "21點 第 %d/%d 局   注 %d 金   淨額 %s%d 金" % [cur, ROUNDS, bet, "+" if net >= 0 else "", net]
	if _sub:
		if _phase == "bet":
			_sub.text = "下注中……"
		elif _phase in ["player", "dealing"]:
			_sub.text = "你 %d｜莊 ？" % hand_value(player_cards)
		else:
			_sub.text = "你 %d｜莊 %d" % [hand_value(player_cards), hand_value(dealer_cards)]
