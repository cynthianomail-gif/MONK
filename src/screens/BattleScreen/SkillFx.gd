class_name SkillFx
extends RefCounted

## 技能命中特效（體感打磨）：純程式 Line2D/Polygon2D/CPUParticles2D/Tween 組合，無新增圖片素材。
## 三系基調：physical＝白/朱紅利落線條；karma＝墨黑紫暴烈飛濺；merit＝金白柔亮漣漪。
## 資料驅動：skills.json 每技能填 "fx" 欄（preset 名），BattleUI 命中時呼叫 SkillFx.play(preset, host, pos)。
## 單個特效時長 0.3~0.6 秒（GDD 體感打磨需求：不拖節奏）。
##
## 用法：SkillFx.play("slash_white", float_layer, target_pos)
## host：掛接的 Control/CanvasItem 容器（通常是 BattleUI 的 float_layer）；pos：目標位置（該容器內座標）。

const INK_RED := Color("#C93A2E")
const WHITE := Color(0.96, 0.96, 0.94)
const GOLD := Color(0.788, 0.659, 0.38)
const KARMA_PURPLE := Color(0.42, 0.08, 0.55)
const KARMA_BLACK := Color(0.08, 0.05, 0.09)
const MERIT_GOLD_WHITE := Color(1.0, 0.95, 0.78)

## preset 名 → 播放函式。找不到 preset 時 fallback 依 damage_type 基調（見 play_for_skill）。
static func play(preset: String, host: Control, pos: Vector2) -> void:
	match preset:
		"slash_white":
			_slash(host, pos, WHITE, 1)
		"slash_white_double":
			_slash(host, pos, WHITE, 2)
		"punch_ring_red":
			_punch_ring(host, pos, INK_RED)
		"punch_ring_white":
			_punch_ring(host, pos, WHITE)
		"heavy_slam":
			_punch_ring(host, pos, INK_RED, 1.4)
			_slash(host, pos, WHITE, 1)
		"ink_burst":
			_ink_burst(host, pos, KARMA_BLACK, KARMA_PURPLE, 1.0)
		"ink_burst_wide":
			_ink_burst(host, pos, KARMA_BLACK, KARMA_PURPLE, 1.5)
		"ink_burst_all":
			_ink_burst(host, pos, KARMA_BLACK, KARMA_PURPLE, 1.2)
			_shockwave_ring(host, pos, KARMA_PURPLE)
		"karma_rings":
			_shockwave_ring(host, pos, KARMA_PURPLE)
			_ink_burst(host, pos, KARMA_BLACK, KARMA_PURPLE, 0.8)
		"karma_seal_dark":
			_seal_glyph(host, pos, KARMA_PURPLE)
		"gold_ripple":
			_ripple(host, pos, GOLD, 1)
		"gold_ripple_wide":
			_ripple(host, pos, GOLD, 2)
		"gold_ripple_all":
			_ripple(host, pos, GOLD, 2)
			_prayer_beads(host, pos, MERIT_GOLD_WHITE)
		"prayer_beads":
			_prayer_beads(host, pos, MERIT_GOLD_WHITE)
		"sound_wave_gold":
			_shockwave_ring(host, pos, GOLD)
			_ripple(host, pos, MERIT_GOLD_WHITE, 1)
		"coin_scatter":
			_coin_scatter(host, pos)
		"self_glow_red":
			_self_glow(host, pos, INK_RED)
		"self_glow_purple":
			_self_glow(host, pos, KARMA_PURPLE)
		"self_glow_gold":
			_self_glow(host, pos, GOLD)
		"guard_spark":
			_punch_ring(host, pos, WHITE, 0.8)
		"item_sparkle":
			_sparkle(host, pos, MERIT_GOLD_WHITE)
		_:
			pass  # 未指定或未知 preset：不播放（技能仍正常結算）

## 依 damage_type 決定 fallback 基調（skills.json 缺 fx 欄時的保底，理論上不應觸發——每技能都應填 fx）。
static func play_for_skill(sk: Dictionary, host: Control, pos: Vector2) -> void:
	var preset: String = sk.get("fx", "")
	if preset != "":
		play(preset, host, pos)
		return
	match sk.get("damage_type", "physical"):
		"karma":
			play("ink_burst", host, pos)
		"merit":
			play("gold_ripple", host, pos)
		_:
			play("slash_white", host, pos)

# ─── 物理系：白/朱紅利落線條 ──────────────────────────────

## 斜斬光痕：Line2D 沿對角線快速劃過並淡出。count>1＝連斬（角度略錯開）。
static func _slash(host: Control, pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var line := Line2D.new()
		line.width = 10.0
		line.default_color = Color(color.r, color.g, color.b, 0.95)
		line.z_index = 100
		var angle: float = deg_to_rad(-35.0 + i * 18.0)
		var half := Vector2(cos(angle), sin(angle)) * 90.0
		line.add_point(pos - half)
		line.add_point(pos + half)
		line.modulate.a = 0.0
		host.add_child(line)
		var tw := host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(line, "modulate:a", 1.0, 0.04).set_delay(i * 0.05)
		tw.tween_property(line, "modulate:a", 0.0, 0.22).set_delay(i * 0.05 + 0.1)
		tw.chain().tween_callback(line.queue_free)

## 拳印震圈：正多邊形環快速放大淡出，模擬重擊衝擊波。
static func _punch_ring(host: Control, pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	var ring := Polygon2D.new()
	var pts: PackedVector2Array = []
	var n := 10
	for i in n:
		var a: float = TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.0)
	ring.position = pos
	ring.z_index = 100
	host.add_child(ring)
	# 用外框感：疊一個縮小版當內圈挖空的近似（純色環：外環淡入淡出＋放大）
	ring.color.a = 0.85
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * (2.6 * scale_mult), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)

# ─── 業系：墨黑紫暴烈飛濺 ──────────────────────────────

## 水墨迸散：CPUParticles2D 黑紫噴濺，短促暴烈。
static func _ink_burst(host: Control, pos: Vector2, c1: Color, c2: Color, scale_mult: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 100
	p.emitting = false
	p.one_shot = true
	p.amount = int(22 * scale_mult)
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 80.0 * scale_mult
	p.initial_velocity_max = 220.0 * scale_mult
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color = c1
	host.add_child(p)
	p.emitting = true
	var tw := host.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(p.queue_free)
	# 疊一圈紫色衝擊環，強化「暴烈」感
	_shockwave_ring(host, pos, c2, 0.6)

## 業系衝擊環：比拳印震圈更粗、更暗，帶輕微不規則抖動邊緣。
static func _shockwave_ring(host: Control, pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	var ring := Polygon2D.new()
	var pts: PackedVector2Array = []
	var n := 12
	for i in n:
		var a: float = TAU * i / n
		var jitter: float = 1.0 + randf_range(-0.08, 0.08)
		pts.append(Vector2(cos(a), sin(a)) * 26.0 * jitter)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.8)
	ring.position = pos
	ring.z_index = 99
	host.add_child(ring)
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * (3.0 * scale_mult), 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 0.32)
	tw.chain().tween_callback(ring.queue_free)

## 業封印符文：多邊形「印」形（簡化八角）緩緩浮現又炸開，用於封印/詛咒類技能。
static func _seal_glyph(host: Control, pos: Vector2, color: Color) -> void:
	var glyph := Polygon2D.new()
	var pts: PackedVector2Array = []
	var n := 8
	for i in n:
		var a: float = TAU * i / n + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 30.0)
	glyph.polygon = pts
	glyph.color = Color(color.r, color.g, color.b, 0.0)
	glyph.position = pos
	glyph.z_index = 100
	glyph.rotation = 0.0
	host.add_child(glyph)
	var tw := host.create_tween()
	tw.tween_property(glyph, "color:a", 0.9, 0.12)
	tw.parallel().tween_property(glyph, "rotation", PI * 0.5, 0.4)
	tw.tween_property(glyph, "color:a", 0.0, 0.16)
	tw.parallel().tween_property(glyph, "scale", Vector2.ONE * 1.6, 0.16)
	tw.tween_callback(glyph.queue_free)

# ─── 淨系：金白柔亮漣漪 ──────────────────────────────

## 金色漣漪：同心圓環柔和放大淡出（比業系震圈慢、更柔）。
static func _ripple(host: Control, pos: Vector2, color: Color, rings: int) -> void:
	for i in rings:
		var ring := Polygon2D.new()
		var pts: PackedVector2Array = []
		var n := 24
		for k in n:
			var a: float = TAU * k / n
			pts.append(Vector2(cos(a), sin(a)) * 18.0)
		ring.polygon = pts
		ring.color = Color(color.r, color.g, color.b, 0.0)
		ring.position = pos
		ring.z_index = 100
		host.add_child(ring)
		var tw := host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "color:a", 0.55, 0.06).set_delay(i * 0.12)
		tw.tween_property(ring, "scale", Vector2.ONE * 2.4, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property(ring, "color:a", 0.0, 0.3).set_delay(i * 0.12 + 0.15)
		tw.chain().tween_callback(ring.queue_free)

## 念珠環繞：小圓點排成環，繞一圈後淡出（淨系支援/治療類）。
static func _prayer_beads(host: Control, pos: Vector2, color: Color) -> void:
	var host_node := Node2D.new()
	host_node.position = pos
	host_node.z_index = 100
	host.add_child(host_node)
	var n := 8
	for i in n:
		var bead := Polygon2D.new()
		var pts: PackedVector2Array = []
		for k in 8:
			var a: float = TAU * k / 8
			pts.append(Vector2(cos(a), sin(a)) * 5.0)
		bead.polygon = pts
		bead.color = Color(color.r, color.g, color.b, 0.0)
		var a0: float = TAU * i / n
		bead.position = Vector2(cos(a0), sin(a0)) * 34.0
		host_node.add_child(bead)
		var tw := host_node.create_tween()
		tw.set_parallel(true)
		tw.tween_property(bead, "color:a", 0.9, 0.08).set_delay(i * 0.02)
		tw.tween_property(bead, "color:a", 0.0, 0.25).set_delay(0.3 + i * 0.02)
	var rtw := host_node.create_tween()
	rtw.tween_property(host_node, "rotation", PI * 0.6, 0.55)
	rtw.tween_callback(host_node.queue_free)

## 淨系音波：偷金/化緣類技能專用——金幣狀小方塊噴出後淡出。
static func _coin_scatter(host: Control, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 100
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.7
	p.color = GOLD
	host.add_child(p)
	p.emitting = true
	var tw := host.create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(p.queue_free)

## 小碎光：道具使用等極簡回饋。
static func _sparkle(host: Control, pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 100
	p.emitting = false
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	p.color = color
	host.add_child(p)
	p.emitting = true
	var tw := host.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(p.queue_free)

# ─── 自身系（防禦/buff）：施放者身上的柔光脈動 ──────────────────────

## 自身柔光：在施放者位置畫一個柔和放大淡出的圓暈，用於防禦/buff/道具類自我施放技能。
static func _self_glow(host: Control, pos: Vector2, color: Color) -> void:
	var glow := Polygon2D.new()
	var pts: PackedVector2Array = []
	var n := 20
	for i in n:
		var a: float = TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * 40.0)
	glow.polygon = pts
	glow.color = Color(color.r, color.g, color.b, 0.0)
	glow.position = pos
	glow.z_index = 90
	host.add_child(glow)
	var tw := host.create_tween()
	tw.tween_property(glow, "color:a", 0.45, 0.1)
	tw.parallel().tween_property(glow, "scale", Vector2.ONE * 1.3, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "color:a", 0.0, 0.2)
	tw.tween_callback(glow.queue_free)
