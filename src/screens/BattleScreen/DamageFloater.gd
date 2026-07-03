class_name DamageFloater
extends Label

## 傷害漂浮字（第一期）：斜體、彈跳上飄淡出。三態：
##   普通命中＝白字；爆擊＝放大 1.4x 變朱紅；命中弱點＝附斜切「WEAK！」標籤；Miss＝灰字。
## 純 Control+Tween，不新增圖片素材。用完自清。
## 用法：DamageFloater.spawn(parent, world_pos, amount, {"is_crit":true, "hit_weakness":true, "miss":false})

const INK_RED := Color("#C93A2E")     # 朱印紅（風格強調色）
const WHITE := Color(0.96, 0.96, 0.94)
const GREY := Color(0.6, 0.6, 0.6)

## 在 parent（通常 CanvasLayer/Control）上生一個漂浮字，pos 為 parent 內座標。
static func spawn(parent: Node, pos: Vector2, amount: int, opts: Dictionary = {}) -> DamageFloater:
	var f := DamageFloater.new()
	parent.add_child(f)
	f._play(pos, amount, opts)
	return f

func _play(pos: Vector2, amount: int, opts: Dictionary) -> void:
	var is_crit: bool = opts.get("is_crit", false)
	var hit_weakness: bool = opts.get("hit_weakness", false)
	var miss: bool = opts.get("miss", false)

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 46 if is_crit else 36)
	# 斜體感（Label 無 italic → 用輕微 skew 的 pivot 旋轉近似；此處以位移+縮放為主，字型維持）
	var base_size := 46 if is_crit else 36

	if miss:
		text = "MISS"
		add_theme_color_override("font_color", GREY)
	elif is_crit:
		text = "%d!" % amount
		add_theme_color_override("font_color", INK_RED)
	else:
		text = str(amount)
		add_theme_color_override("font_color", WHITE)

	# 弱點：附斜切「WEAK！」小標籤在上方
	if hit_weakness and not miss:
		var weak := Label.new()
		weak.text = "WEAK!"
		weak.add_theme_font_size_override("font_size", 26)
		weak.add_theme_color_override("font_color", Color("#FFD700"))
		weak.rotation_degrees = -10.0   # 斜切
		weak.position = Vector2(-6, -40)
		add_child(weak)

	custom_minimum_size = Vector2(160, 60)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	position = pos - size * 0.5

	# 爆擊放大 1.4x 起手
	scale = Vector2(1.4, 1.4) if is_crit else Vector2(1.15, 1.15)
	modulate.a = 1.0

	var tw := create_tween()
	tw.set_parallel(true)
	# 彈跳上飄
	tw.tween_property(self, "position:y", position.y - 70.0, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 縮放回穩
	tw.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 淡出（延遲後）
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
