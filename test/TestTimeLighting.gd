extends Node
## 驗證 ShrineStreet 時段光照 profile ＋ 時段環境音景：
## ①深夜太陽能量/背景亮度 < 上午 ②燈籠深夜比上午亮 ③環境音依時段換 loop 且有播。

func _ready() -> void:
	var env := (load("res://src/screens/MapScreen/environments/ShrineStreet.tscn") as PackedScene).instantiate()
	add_child(env)
	await get_tree().process_frame
	await get_tree().process_frame

	env._apply_time_profile(0)
	var sun_day: float = env._sun.light_energy
	var sky_day: Color = env._sky_mat.sky_top_color
	var lantern_day: float = (env._warm_lights[0][0] as OmniLight3D).light_energy
	var amb_day := _ambient_path(env)

	env._apply_time_profile(3)
	var sun_night: float = env._sun.light_energy
	var sky_night: Color = env._sky_mat.sky_top_color
	var lantern_night: float = (env._warm_lights[0][0] as OmniLight3D).light_energy
	var amb_night := _ambient_path(env)

	if sun_night >= sun_day: return _fail("深夜太陽應比上午弱 (%f >= %f)" % [sun_night, sun_day])
	if env._env.background_mode != Environment.BG_SKY: return _fail("背景應為天空(BG_SKY)")
	if sky_night.v >= sky_day.v: return _fail("深夜天空應比上午暗")
	if lantern_night <= lantern_day: return _fail("深夜燈籠應比上午亮")
	if not env._env.ssao_enabled: return _fail("SSAO 未開")
	if not amb_day.contains("day"): return _fail("上午環境音應為 day，got %s" % amb_day)
	if not amb_night.contains("night"): return _fail("深夜環境音應為 night，got %s" % amb_night)
	if env._ambient == null or not env._ambient.playing: return _fail("環境音未播放")
	if env._ambient.bus != "SFX": return _fail("環境音應走 SFX bus")

	env._apply_time_profile(2)
	if not _ambient_path(env).contains("dusk"): return _fail("傍晚環境音應為 dusk")

	print("TEST PASS: 時段光照 + 環境音景 OK")
	get_tree().quit(0)

func _ambient_path(env: Node) -> String:
	if env._ambient == null or env._ambient.stream == null:
		return ""
	return env._ambient.stream.resource_path

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
