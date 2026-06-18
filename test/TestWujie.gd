extends Node
func _ready() -> void:
	var W := load("res://src/screens/MapScreen/Wujie.gd")
	var w: AnimatedSprite2D = W.new()
	add_child(w)
	await get_tree().process_frame
	if w.sprite_frames == null: return _fail("未建 SpriteFrames")
	if not w.sprite_frames.has_animation("walk"): return _fail("無 walk 動畫")
	if not w.sprite_frames.has_animation("idle"): return _fail("無 idle 動畫")
	w.set_walking(true)
	if w.animation != "walk": return _fail("set_walking(true) 未切 walk")
	w.face(1.0)
	if not w.flip_h: return _fail("face(1) 往右未翻面")
	w.face(-1.0)
	if w.flip_h: return _fail("face(-1) 往左不應翻面")
	w.set_walking(false)
	if w.animation != "idle": return _fail("set_walking(false) 未回 idle")
	print("TEST PASS: Wujie 動畫/翻面 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
