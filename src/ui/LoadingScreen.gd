extends CanvasLayer
## 場景切換時的讀取畫面，覆蓋最上層。近黑底 + 中央循環佛語 + 木魚敲擊聲。
## 以程式建立節點（無外部 sprite 依賴）。由 SceneRouter._show_loading 實例化、
## _hide_loading 呼叫 fade_out() 淡出自我釋放。對齊 GDD §8.7・五。

const LOADING_PHRASES: Array = [
	"阿彌陀佛...",
	"南無阿彌陀佛...",
	"色即是空，空即是色...",
	"萬般帶不走，唯有業隨身...",
	"放下屠刀，立地成佛...",
	"業障深重...",
	"功德無量...",
	"諸行無常，諸法無我...",
	"菩提本無樹，明鏡亦非台...",
	"人生八苦，生老病死...",
	"善有善報，惡有惡報...",
	"一念天堂，一念地獄...",
]

var _phrase_label: Label
var _knock_timer: Timer
var _phrase_idx: int = 0
var _active: bool = true

func _ready() -> void:
	layer = 128  # 最上層，蓋過所有 UI 與 TransitionEffect

	var bg := ColorRect.new()
	bg.color = Color("#0A0A0A")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_phrase_label = Label.new()
	_phrase_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phrase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phrase_label.add_theme_color_override("font_color", Color("#F5F5F0"))
	_phrase_label.add_theme_font_size_override("font_size", 40)
	_phrase_label.modulate.a = 0.0
	add_child(_phrase_label)

	_knock_timer = Timer.new()
	_knock_timer.wait_time = 0.5
	_knock_timer.timeout.connect(_on_knock_timer_timeout)
	add_child(_knock_timer)
	_knock_timer.start()

	_show_next_phrase()

func _show_next_phrase() -> void:
	if not _active:
		return
	_phrase_idx = (_phrase_idx + 1) % LOADING_PHRASES.size()
	_phrase_label.text = LOADING_PHRASES[_phrase_idx]
	var tw := create_tween()
	tw.tween_property(_phrase_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.2)
	tw.tween_property(_phrase_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_show_next_phrase)

func _on_knock_timer_timeout() -> void:
	AudioManager.play_sfx("wooden_fish_tap")

## SceneRouter 呼叫：淡出所有內容後釋放自身。
func fade_out(dur: float = 0.3) -> void:
	_active = false
	if _knock_timer:
		_knock_timer.stop()
	var tw := create_tween()
	tw.set_parallel(true)
	for c in get_children():
		if c is CanvasItem:
			tw.tween_property(c, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(queue_free)
