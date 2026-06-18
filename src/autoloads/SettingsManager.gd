extends Node
## 全域偏好設定單一真相源。讀寫 user://settings.cfg（獨立於存檔），開機 apply_all。
## 音量存 linear 0~1；text_speed 存「速度倍率」（越大越快，0.5~2.0），套用時反轉成 Dialogic 的延遲倍率。

const PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"master_vol": 1.0,
	"bgm_vol": 1.0,
	"sfx_vol": 1.0,
	"fullscreen": false,
	"text_speed": 1.0,
}

var _data: Dictionary = {}

func _ready() -> void:
	_load()
	apply_all()

func _load() -> void:
	_data = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			_data[k] = cfg.get_value(SECTION, k, DEFAULTS[k])

func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _data:
		cfg.set_value(SECTION, k, _data[k])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsManager: could not save settings (error %d)" % err)

func get_setting(key: String) -> Variant:
	return _data.get(key, DEFAULTS.get(key))

func set_setting(key: String, value: Variant) -> void:
	_data[key] = _clamp_value(key, value)
	_apply_one(key)
	_save()

## 寫入前先夾值，讓存檔/讀回的狀態與實際套用（已夾）的一致。
func _clamp_value(key: String, value: Variant) -> Variant:
	match key:
		"master_vol", "bgm_vol", "sfx_vol":
			return clampf(float(value), 0.0, 1.0)
		"text_speed":
			return clampf(float(value), 0.5, 2.0)
		_:
			return value

func apply_all() -> void:
	for k in _data:
		_apply_one(k)

func _apply_one(key: String) -> void:
	match key:
		"master_vol":
			AudioManager.set_bus_volume_linear("Master", float(_data[key]))
		"bgm_vol":
			AudioManager.set_bus_volume_linear("BGM", float(_data[key]))
		"sfx_vol":
			AudioManager.set_bus_volume_linear("SFX", float(_data[key]))
		"fullscreen":
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_data[key])
				else DisplayServer.WINDOW_MODE_WINDOWED)
		"text_speed":
			_apply_text_speed(float(_data[key]))

func _apply_text_speed(speed_mult: float) -> void:
	speed_mult = clampf(speed_mult, 0.5, 2.0)
	# Dialogic text_speed = 每字延遲倍率（越大越慢）；我們的 speed_mult 越大越快 → 取倒數。
	if Dialogic.has_subsystem("Settings"):
		Dialogic.Settings.text_speed = 1.0 / speed_mult
