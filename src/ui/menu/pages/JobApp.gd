extends VBoxContainer
## 手機「105 打工」頁：打工板列兩工（端湯/化緣），選工耗 1 時段→啟動小遊戲，獎勵走小遊戲 intrinsic。
## 木魚節奏＝街頭藝人對話觸發，不進板。

const GOLD := Color(0.788, 0.659, 0.38)
const DIM := Color(0.55, 0.52, 0.46)

const JOBS := [
	{"id": "soup_carry", "name": "端湯小弟", "desc": "限時把味增湯送上桌，灑越少賺越多。"},
	{"id": "beggar_challenge", "name": "街頭托缽", "desc": "化緣修行，看人下菜。"},
]

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "105 打工　（每份工耗 1 時段）"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)

	for job in JOBS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var btn := Button.new()
		btn.text = job.name
		btn.add_theme_font_size_override("font_size", 24)
		var jid: String = job.id
		btn.pressed.connect(func() -> void: _take_job(jid))
		box.add_child(btn)
		var desc := Label.new()
		desc.text = job.desc
		desc.add_theme_color_override("font_color", DIM)
		desc.add_theme_font_size_override("font_size", 18)
		box.add_child(desc)
		add_child(box)

## 開工：耗 1 時段（抽出供測試，不換場）。
func _start_job_time() -> void:
	GameManager.advance_time(1)

func _take_job(minigame_id: String) -> void:
	get_tree().paused = false
	_start_job_time()
	SceneRouter.go_to_minigame(minigame_id)
