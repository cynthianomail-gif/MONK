extends AnimatedSprite2D
## 2D 無戒視覺：_ready 由 sprite PNG 程式建 SpriteFrames；set_walking 切 idle/walk、face 翻面。
## 位移由 DistrictScene 控制（本節點只管外觀）。
const DIR := "res://assets/2d/characters/wujie/sprite/"
const WALK_FRAMES := 8
const FPS := 10.0

func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle"); sf.set_animation_loop("idle", true); sf.set_animation_speed("idle", 1.0)
	var idle_tex := _tex(DIR + "idle_0.png")
	if idle_tex: sf.add_frame("idle", idle_tex)
	sf.add_animation("walk"); sf.set_animation_loop("walk", true); sf.set_animation_speed("walk", FPS)
	for i in WALK_FRAMES:
		var t := _tex(DIR + "walk_%d.png" % i)
		if t: sf.add_frame("walk", t)
	if sf.get_frame_count("idle") == 0: sf.add_frame("idle", _placeholder())
	if sf.get_frame_count("walk") == 0: sf.add_frame("walk", _placeholder())
	sprite_frames = sf
	play("idle")

func set_walking(on: bool) -> void:
	var want := "walk" if on else "idle"
	if animation != want: play(want)

func face(dir: float) -> void:
	# sprite 渲出來預設朝左，故往右(dir>0)才翻面，否則會「倒退走」。
	if dir != 0.0: flip_h = dir > 0.0

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path) as Texture2D
	return null

func _placeholder() -> Texture2D:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.46, 0.32, 1.0))
	return ImageTexture.create_from_image(img)
