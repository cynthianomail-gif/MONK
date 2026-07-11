extends Control
## 劇情過場播放器（分鏡＋字幕軌，資料驅動 data/cutscenes.json）。
## 與簡易 CutsceneScreen 並存：本播放器供主線敘事（開場、神祇登場）用，
## 支援靜幀＋運鏡、動畫幀資料夾、純黑、底部對話框字幕、可跳過。
## 缺圖/缺幀安全顯黑 → 可先接線測通、美術之後填。

signal finished

const DATA_PATH := "res://data/cutscenes.json"
const DEFAULT_FPS := 12.0
const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const BOX_BG := Color(0.043, 0.043, 0.043, 0.94)
const VIEW := Vector2(1920, 1080)
const LID_CLOSE := 560.0   # 眨眼：眼皮閉合高度（略過半屏，確保完全蓋住）
const BLINK_CLOSE := 0.16  # 眨眼：閉眼時間
const BLINK_OPEN := 0.24   # 眨眼：睜眼時間
const FAINT_DUR := 3.0     # 暈倒：模糊＋向右旋倒的時間（放慢，與「驅.逐.出.去.」慢速打字同步）
const IMPACT_FLASH := 0.22 # 被打白光：白閃淡出時間
const IMPACT_SHAKE := 0.40 # 被打震動：晃動總時間
const IMPACT_AMP := 30.0   # 被打震動：最大位移（像素，逐下遞減）
const KNOCKOUT_DUR := 1.6  # 被打趴：揮拳放完→白光一下→慢慢翻倒至 -90°→圓形閉眼收黑（非暈眩）
const KNOCKOUT_AMP := 130.0 # 被打趴晃動：水平來回最大位移（像素，大幅度；逐下遞減）
const EYE_OPEN_DUR := 0.55 # 圓形睜眼：05_lineup 承接被打閉眼、睜開揭示群神的時間
const TYPE_CPS := 10.0     # 字幕打字機速度（字/秒），每句可用 "cps" 覆寫
const TYPE_SKIP := " 　\n，。、？！…—－「」（）().,!?"  # 這些字元不觸發打字音

var _shots: Array = []
var _captions: Array = []
var _t: float = 0.0
var _shot_idx: int = -1
var _shot_elapsed: float = 0.0
var _shot_dur: float = 0.0
var _cur_frames: Array[Texture2D] = []
var _cur_fps: float = DEFAULT_FPS
var _cues: Array = []       # 本鏡的定時提示（影片中精準觸發音效/白光），依 t 秒排序
var _cue_idx: int = 0
var _playing: bool = false
var _done: bool = false

var _black: ColorRect
var _frame: TextureRect
var _cap_box: PanelContainer
var _cap_speaker: Label
var _cap_text: Label
var _lid_top: ColorRect     # 眨眼轉場：上眼皮
var _lid_bot: ColorRect     # 眨眼轉場：下眼皮
var _blur: ColorRect        # 暈倒：螢幕模糊覆蓋層
var _flash: ColorRect       # 被打：滿版白光閃
var _eye: ColorRect         # 被打趴：圓形閉眼/睜眼眼罩（shader 橢圓闔黑，比直線眼皮像真閉眼）
var _blink_closing := false
var _faint_active := false
var _groggy_tween: Tween = null  # 05_lineup 半昏迷「要閉不閉」的循環眼罩 tween（昏厥時中止）
var _cur_cap_idx := -1      # 目前字幕索引（用來在台詞「剛出現」時播一次配音）
var _type_player: AudioStreamPlayer  # 打字機逐字音效
var _type_shown := 0.0      # 已揭示字數（浮點累積）
var _type_done := 0         # 已揭示字數（整數，已播過音）
var _type_total := 0
var _type_cps := TYPE_CPS
var _type_blip_on := false   # 只有旁白(無主詞)與「無戒」台詞播打字機音；阿瑞斯等有配音者不播
var _input_ready := false   # play() 呼叫後、清空殘留輸入前，暫不「立即」接受跳過鍵（見 play() 內說明）
var _pending_skip := false  # 尚未 _input_ready 時按下的跳過鍵：記下來，轉 ready 的當下立刻補放行

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func play(cutscene_id: String) -> void:
	var all: Dictionary = JsonLoader.load_json(DATA_PATH)
	var data: Dictionary = all.get(cutscene_id, {})
	_shots = data.get("shots", [])
	_captions = data.get("captions", [])
	if data.has("bgm"):
		AudioManager.switch_bgm(data.bgm, 0.5, float(data.get("bgm_db", 0.0)))
	if _shots.is_empty():
		push_warning("StoryCutscene: 找不到過場 %s，直接結束" % cutscene_id)
		_finish.call_deferred()
		return
	_t = 0.0
	_shot_idx = -1
	_cur_cap_idx = -1
	_playing = true
	_input_ready = false
	_pending_skip = false
	# 保險：開場確保圓形眼罩全開（close=0，全透明），避免上次被打閉眼殘留。
	if _eye != null and _eye.material is ShaderMaterial:
		(_eye.material as ShaderMaterial).set_shader_parameter("close", 0.0)
	_advance_shot()
	# 清掉啟動本過場那次按鍵（Enter/空白/ESC）殘留的輸入佇列，避免同一次按鍵瞬間又把
	# 本過場跳掉；用「清空佇列＋下一幀才開始接受跳過鍵」取代舊的「開頭 0.4s 一律忽略」，
	# 因為固定時間窗會連玩家之後真的想跳過的第二次按鍵都吃掉（雨段連續過場即實際踩雷案例：
	# 玩家剛跳過上一段的按鍵一鬆手就緊接著按下一段的跳過，若落在窗內會被靜音吞掉、
	# 畫面上毫無提示，玩家以為「按了沒用」便不再按，只能眼睜睜等整段播完）。
	# 光是「清空＋等一幀」仍有極短的競態窗：玩家的按鍵剛好落在「已清空但還沒等滿一幀」
	# 之間，會被 _unhandled_input 直接丟掉。所以未 ready 前收到的跳過鍵改記到
	# _pending_skip，一旦轉 ready 立刻補放行，不會漏接。
	Input.flush_buffered_events()
	await get_tree().process_frame
	_input_ready = true
	if _pending_skip:
		_pending_skip = false
		_finish()

# --- 流程 ---

func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	_shot_elapsed += delta
	_update_caption()
	_update_typing(delta)
	_update_cues()
	# 動畫幀模式：依時間翻幀
	if not _cur_frames.is_empty():
		var fi: int = int(_shot_elapsed * _cur_fps)
		if fi < _cur_frames.size():
			_frame.texture = _cur_frames[fi]
	_update_transitions()
	if _shot_elapsed >= _shot_dur:
		_advance_shot()

## 鏡頭尾段觸發的轉場：暈倒（faint_out）與「下一鏡眨眼前先閉眼」。
func _update_transitions() -> void:
	if _shot_idx < 0 or _shot_idx >= _shots.size():
		return
	var cur: Dictionary = _shots[_shot_idx]
	# 暈倒：本鏡標記 faint_out → 於尾段 FAINT_DUR 觸發一次
	if not _faint_active and bool(cur.get("faint_out", false)) and _frame.visible \
			and _shot_elapsed >= _shot_dur - FAINT_DUR:
		_faint_active = true
		if String(cur.get("faint_sfx", "")) != "":
			AudioManager.play_sfx(cur.faint_sfx)
		_play_faint(FAINT_DUR)
	# 眨眼：下一鏡標記 blink → 於本鏡尾段先閉眼（暈倒中不搶戲）
	if not _blink_closing and not _faint_active and _shot_idx + 1 < _shots.size():
		var nxt: Dictionary = _shots[_shot_idx + 1]
		if bool(nxt.get("blink", false)) and _shot_elapsed >= _shot_dur - BLINK_CLOSE:
			_blink_closing = true
			_blink_close(BLINK_CLOSE)

func _advance_shot() -> void:
	_shot_idx += 1
	if _shot_idx >= _shots.size():
		_finish()
		return
	_shot_elapsed = 0.0
	_cur_frames = []
	_reset_fx()
	var shot: Dictionary = _shots[_shot_idx]
	# 解析視覺來源：frames_dir > image > black
	var frames := _load_frames(shot.get("frames_dir", ""))
	if not frames.is_empty():
		_cur_frames = frames
		_cur_fps = float(shot.get("fps", DEFAULT_FPS))
		# 預設＝幀數/fps；但可用 duration 拉長本鏡（停在最後一格）讓尾段播完知幀後仍有
		# 時間跑昏厥/黑屏轉場（揮拳鏡：影格放完→白光昏倒→黑屏，再切下一鏡）。
		_shot_dur = maxf(_cur_frames.size() / _cur_fps, float(shot.get("duration", 0.0)))
		_black.visible = false
		_frame.visible = true
		_frame.texture = _cur_frames[0]
	elif shot.get("image", "") != "" and ResourceLoader.exists(shot.image):
		_frame.texture = load(shot.image)
		_frame.visible = true
		_black.visible = false
		_shot_dur = float(shot.get("duration", 3.0))
	else:
		# 純黑（或缺圖 fallback）
		_frame.visible = false
		_frame.texture = null
		_black.visible = true
		_shot_dur = float(shot.get("duration", 1.0))
	if shot.has("sfx"):
		AudioManager.play_sfx(shot.sfx)
	if shot.has("voice"):
		AudioManager.play_voice(shot.voice)
	# 定時提示：影片/影格鏡頭中於指定秒數觸發音效/白光（依 t 升冪）。
	_cues = (shot.get("cues", []) as Array).duplicate()
	_cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	_cue_idx = 0
	if shot.has("bgm_db"):
		AudioManager.fade_bgm_to(float(shot.bgm_db), float(shot.get("bgm_fade", 1.5)))
	_apply_motion(shot.get("motion", "none"))
	_apply_fade(shot)
	# 眨眼轉場：本鏡標記 blink → 從閉眼睜開揭示畫面；否則確保眼皮全開。
	if bool(shot.get("blink", false)):
		_blink_open(BLINK_OPEN)
	else:
		_open_lids_instant()
	_blink_closing = false
	# 圓形睜眼：本鏡標記 eye_open → 承接被打閉眼，從橢圓眼罩睜開揭示（與直線 blink 不同套）。
	if bool(shot.get("eye_open", false)):
		_eye_open(EYE_OPEN_DUR)
	# 半昏迷「要閉不閉」：睜眼揭示後，圓形眼罩持續微微闔合來回（被打趴後恍惚仰看群神，直到徹底昏厥）。
	if bool(shot.get("groggy", false)):
		var tg := create_tween()
		tg.tween_interval(EYE_OPEN_DUR)        # 等睜眼揭示完才開始
		tg.tween_callback(_eye_groggy_loop)
	# 被打反饋：本鏡標記 impact → 命中瞬間白光閃＋影像震動（與 sfx/voice 同幀觸發）。
	if bool(shot.get("impact", false)):
		_play_impact()

func _apply_motion(motion: String) -> void:
	if not _frame.visible:
		return
	_frame.scale = Vector2.ONE
	_frame.position = Vector2.ZERO
	_frame.pivot_offset = VIEW * 0.5
	match motion:
		"zoom_in":
			var tw := create_tween()
			tw.tween_property(_frame, "scale", Vector2(1.08, 1.08), maxf(0.1, _shot_dur))
		"pan_left":
			var tw := create_tween()
			tw.tween_property(_frame, "position", Vector2(-60, 0), maxf(0.1, _shot_dur))
		"shake":
			var tw := create_tween()
			for i in 6:
				var off := Vector2(randf_range(-18, 18), randf_range(-12, 12))
				tw.tween_property(_frame, "position", off, 0.05)
			tw.tween_property(_frame, "position", Vector2.ZERO, 0.05)

func _apply_fade(shot: Dictionary) -> void:
	var target: Control = _black if _black.visible else _frame
	if shot.get("fade_in", false):
		target.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(target, "modulate:a", 1.0, minf(1.2, _shot_dur * 0.4))
	else:
		target.modulate.a = 1.0

func _update_caption() -> void:
	var active := -1
	for i in _captions.size():
		var c: Dictionary = _captions[i]
		if _t >= float(c.start) and _t < float(c.end):
			active = i
			break
	if active != _cur_cap_idx:
		_cur_cap_idx = active
		if active >= 0:
			_start_caption(_captions[active])
	if active < 0:
		_cap_box.visible = false

## 新台詞出現：設好打字機初始狀態、播配音、（若標記）觸發暈倒。
func _start_caption(c: Dictionary) -> void:
	_cap_speaker.text = c.get("speaker", "")
	_cap_text.text = c.get("text", "")
	_cap_text.visible_characters = 0
	_type_shown = 0.0
	_type_done = 0
	_type_total = _cap_text.text.length()
	_type_cps = float(c.get("cps", TYPE_CPS))
	# 打字機音只給旁白(空主詞)與無戒；其餘(阿瑞斯…有 voice 配音)不疊打字音。
	var spk := String(c.get("speaker", ""))
	_type_blip_on = spk == "" or spk == "無戒"
	_cap_box.visible = true
	if String(c.get("voice", "")) != "":
		AudioManager.play_voice(c.voice)
	# 由台詞觸發暈倒：用於「驅逐出去」慢速打字與畫面暈倒同步。
	if bool(c.get("trigger_faint", false)) and not _faint_active and _frame.visible:
		_faint_active = true
		if String(c.get("faint_sfx", "")) != "":
			AudioManager.play_sfx(c.faint_sfx)
		_eye_faint_close(FAINT_DUR)  # 要閉不閉的眼，最後緩緩闔到全黑＝徹底昏過去
		_play_faint(FAINT_DUR)

## 打字機：依 cps 逐字揭示目前台詞，每出現一個（非標點）字播一次打字音。
func _update_typing(delta: float) -> void:
	if not _cap_box.visible or _type_done >= _type_total:
		return
	_type_shown += delta * _type_cps
	var n := mini(int(_type_shown), _type_total)
	if n > _type_done:
		_cap_text.visible_characters = n
		var ch := _cap_text.text.substr(n - 1, 1)
		if _type_blip_on and not TYPE_SKIP.contains(ch):
			if _type_player != null and _type_player.stream != null:
				_type_player.play()
		_type_done = n

## 定時提示：依 _shot_elapsed 觸發本鏡 cues（音效/配音/白光），每個只觸發一次。
## 用於影片鏡頭：在「拳頭命中那一刻」精準播 impact_heavy/monk_grunt、閃白光。
func _update_cues() -> void:
	while _cue_idx < _cues.size() and _shot_elapsed >= float(_cues[_cue_idx].get("t", 0.0)):
		var c: Dictionary = _cues[_cue_idx]
		if c.has("sfx"):
			AudioManager.play_sfx(c.sfx)
		if c.has("voice"):
			AudioManager.play_voice(c.voice)
		if bool(c.get("flash", false)):
			_flash_pulse(float(c.get("flash_strength", 0.9)), float(c.get("flash_time", IMPACT_FLASH)))
		# 命中後被打昏：白光之後世界急速傾倒模糊、淡入黑（接著切到地上仰視群神）。
		if bool(c.get("knockout", false)):
			_play_knockout(float(c.get("knockout_time", KNOCKOUT_DUR)))
		_cue_idx += 1

# --- 轉場特效 ---

## 每次換鏡先把上一鏡的特效殘留清乾淨（模糊、旋轉、位移、淡出）。
func _reset_fx() -> void:
	_faint_active = false
	if _groggy_tween != null and _groggy_tween.is_valid():
		_groggy_tween.kill()
	if _blur != null:
		_blur.visible = false
		var m := _blur.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("amount", 0.0)
	if _frame != null:
		_frame.rotation_degrees = 0.0
		_frame.scale = Vector2.ONE
		_frame.position = Vector2.ZERO
		_frame.modulate.a = 1.0
	if _flash != null:
		_flash.color.a = 0.0

func _open_lids_instant() -> void:
	if _lid_top: _lid_top.offset_bottom = 0.0
	if _lid_bot: _lid_bot.offset_top = 0.0

## 閉眼：上下眼皮往中間長到蓋滿。
func _blink_close(d: float) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_lid_top, "offset_bottom", LID_CLOSE, d)
	tw.tween_property(_lid_bot, "offset_top", -LID_CLOSE, d)

## 睜眼：先瞬間閉滿（蓋住換好的新圖），再往外打開揭示。
func _blink_open(d: float) -> void:
	_lid_top.offset_bottom = LID_CLOSE
	_lid_bot.offset_top = -LID_CLOSE
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lid_top, "offset_bottom", 0.0, d)
	tw.tween_property(_lid_bot, "offset_top", 0.0, d)

## 暈倒：模糊由淺漸深 → 畫面緩緩向右旋倒、後段才淡入黑。
func _play_faint(d: float) -> void:
	# 漸進模糊（螢幕 shader，amount 為取樣像素距離）：
	# 用 EASE_IN（慢起快收）跑滿全程 → 一開始幾乎不糊，越到後面越糊（昏厥感）。
	if _blur != null:
		_blur.visible = true
		var m := _blur.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("amount", 0.0)
			var tb := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tb.tween_method(
				func(v: float) -> void: m.set_shader_parameter("amount", v),
				0.0, 7.0, d)
	# 黑底墊在後面：影像淡出時整片均勻轉黑（影像全程蓋滿畫面，不會露出邊角黑塊）。
	_black.visible = true
	_black.modulate.a = 1.0
	_frame.pivot_offset = VIEW * 0.5
	_frame.scale = Vector2(1.05, 1.05)  # 先給底 overscan，旋轉一開始就不會露邊
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 旋倒＋放大＋微滑全程 d 完成（d 已加長＝整體更慢）。
	# 位移收小、放大加大 → 旋轉時影像仍完整覆蓋畫面，不會露出邊角黑塊。
	tw.tween_property(_frame, "scale", Vector2(1.24, 1.24), d)       # 放大蓋住旋轉露出的邊角
	tw.tween_property(_frame, "rotation_degrees", 8.0, d)           # 向右傾倒（順時針＝向右倒）
	tw.tween_property(_frame, "position", Vector2(40, 40), d)       # 往右下微滑（量小，避免露邊）
	# 影像保持可見更久（前 40% 不淡），後 60% 才淡入黑 → 配合模糊漸深，黑得更晚更自然。
	tw.tween_property(_frame, "modulate:a", 0.0, d * 0.6).set_delay(d * 0.4)

## 被打趴：命中白光後，先快速劇烈晃動（被打天旋），再急速往下栽倒並淡入全黑。
## 非暈眩（不模糊、不慢旋）；由揮拳鏡 cue 與命中音效同刻觸發，黑屏後切 05_lineup。
func _play_knockout(d: float) -> void:
	if _faint_active:
		return
	_faint_active = true  # 佔住狀態，避免本鏡其他轉場搶戲（換鏡時 _reset_fx 會清掉）
	# 黑底墊後面：翻倒/閉眼時整片均勻轉黑（不露邊角）。
	_black.visible = true
	_black.modulate.a = 1.0
	if _frame == null or not _frame.visible:
		_eye_close(0.4, 0.0)  # 無影像：直接圓形閉眼收黑
		return
	_frame.pivot_offset = VIEW * 0.5
	_frame.scale = Vector2(1.2, 1.2)  # 晃動期 overscan：大幅來回晃動也不露邊角黑邊
	# 三段：被打劇震(快速來回晃) → 停頓(白光那拍停久一點) → 翻倒至 -90°(快一點點，尾段圓形閉眼)。
	# hold 加長＝白光那拍停更久；fall 拿剩餘時間(總長 d 不變→hold 變多 fall 自動變快)。
	var shake_t := 0.32
	var hold_t := 0.4
	var fall_t := maxf(0.5, d - shake_t - hold_t)
	var tw := create_tween()
	# 快速大幅「來回」晃動：水平左右猛甩、逐下遞減，不旋轉畫面（被打劇震）。
	var steps := 8
	for i in steps:
		var dec := 1.0 - float(i) / float(steps)
		var dir := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(_frame, "position", Vector2(KNOCKOUT_AMP * dir * dec, 0.0), shake_t / float(steps)) \
			.set_trans(Tween.TRANS_SINE)
	# 短停頓（白光一下子）：位移歸位、靜止一拍，等揮拳的白光閃完再倒。
	tw.tween_property(_frame, "position", Vector2.ZERO, hold_t)
	# 慢慢往另一邊翻倒至 -90°＋下沉＋放大蓋滿（接在停頓之後）。
	# scale 先衝大(EASE_OUT)確保翻倒時不露黑角；旋轉/下沉走 EASE_IN（越倒越快）。
	tw.tween_property(_frame, "rotation_degrees", -90.0, fall_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_frame, "scale", Vector2(1.9, 1.9), fall_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_frame, "position", Vector2(0, 120), fall_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 圓形閉眼收黑：翻倒後段才闔眼（橢圓眼罩往中央闔黑，取代直線眼皮）。
	# 下一鏡 05_lineup 設 eye_open → 從橢圓睜開揭示群神（被打趴→睜眼仰看）。
	_eye_close(fall_t * 0.62, shake_t + hold_t + fall_t * 0.42)

## 圓形閉眼：橢圓眼罩 close 0→1 往中央闔成全黑（dur=闔眼時間, delay=起始延遲）。
func _eye_close(dur: float, delay: float) -> void:
	if _eye == null:
		return
	var m := _eye.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("close", 0.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("close", v),
		0.0, 1.0, maxf(0.05, dur)).set_delay(maxf(0.0, delay))

## 圓形睜眼：橢圓眼罩 close 1→0 睜開揭示畫面（承接被打閉眼）。
func _eye_open(dur: float) -> void:
	if _eye == null:
		return
	var m := _eye.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("close", 1.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("close", v),
		1.0, 0.0, maxf(0.05, dur))

## 半昏迷眼神：圓形眼罩 close 在 0.08↔0.42 緩緩來回（要閉不閉），循環直到昏厥被中止。
func _eye_groggy_loop() -> void:
	if _eye == null:
		return
	var m := _eye.material as ShaderMaterial
	if m == null:
		return
	if _groggy_tween != null and _groggy_tween.is_valid():
		_groggy_tween.kill()
	_groggy_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 闔下慢、抬起更慢（眼皮沉重）；幅度只到 0.42＝半閉（底部字幕仍讀得到、上方群神被眼皮壓住一點）。
	_groggy_tween.tween_method(func(v: float) -> void: m.set_shader_parameter("close", v), 0.08, 0.42, 1.0)
	_groggy_tween.tween_method(func(v: float) -> void: m.set_shader_parameter("close", v), 0.42, 0.08, 1.35)

## 徹底昏厥：停掉「要閉不閉」來回，圓形眼罩從目前狀態緩緩闔到全黑（與 _play_faint 同步＝慢慢昏過去）。
func _eye_faint_close(d: float) -> void:
	if _groggy_tween != null and _groggy_tween.is_valid():
		_groggy_tween.kill()
	if _eye == null:
		return
	var m := _eye.material as ShaderMaterial
	if m == null:
		return
	var from_v := float(m.get_shader_parameter("close"))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("close", v), from_v, 1.0, maxf(0.1, d))

## 白光閃一下（被打/命中反饋共用；strength=峰值不透明度，dur=淡出時間）。
func _flash_pulse(strength: float = 0.9, dur: float = IMPACT_FLASH) -> void:
	if _flash == null:
		return
	_flash.color = Color(1, 1, 1, strength)
	var tf := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tf.tween_property(_flash, "color:a", 0.0, dur)

## 被打反饋：白光閃一下 ＋ 影像快速震動（晃幾下、幅度遞減）。在標記 impact 的鏡頭開頭觸發。
func _play_impact() -> void:
	_flash_pulse(0.9, IMPACT_FLASH)
	# 影像震動：先微放大 overscan（免晃動時露出邊角黑邊），再用遞減位移晃幾下回正。
	if _frame != null and _frame.visible:
		_frame.pivot_offset = VIEW * 0.5
		_frame.scale = Vector2(1.06, 1.06)
		var tw := create_tween()
		var steps := 8
		for i in steps:
			var dec := 1.0 - float(i) / float(steps)     # 一下比一下小
			var off := Vector2(
				randf_range(-IMPACT_AMP, IMPACT_AMP),
				randf_range(-IMPACT_AMP, IMPACT_AMP) * 0.7) * dec
			tw.tween_property(_frame, "position", off, IMPACT_SHAKE / float(steps + 1)) \
				.set_trans(Tween.TRANS_SINE)
		tw.tween_property(_frame, "position", Vector2.ZERO, IMPACT_SHAKE / float(steps + 1))

func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if not (event.is_action_pressed("confirm") or event.is_action_pressed("cancel")):
		return
	get_viewport().set_input_as_handled()
	# _input_ready 在 play() 清空殘留輸入佇列＋等過一幀後才轉 true：避免啟動本過場的
	# 那次按鍵（Enter/空白/ESC）殘留輸入瞬間跳過。不用固定時間窗（見 play() 內註解）。
	# 未 ready 前收到的按鍵不會被丟棄，記到 _pending_skip，轉 ready 當下立刻補放行，
	# 確保玩家跳過上一段後緊接著按下一段跳過鍵，不會被吞掉。
	if _input_ready:
		_finish()
	else:
		_pending_skip = true

func _finish() -> void:
	if _done:
		return
	_done = true
	_playing = false
	finished.emit()

## 供「held」流程使用（MainQuestManager stage.hold=true 時本場景播完不換場，
## 留著當下一段對話的背景畫布）：把畫面收成純黑，蓋掉最後一幀停格與所有轉場疊層。
## 根因（C-1 bug）：Dialogic 的 [background] 淡入是「前一張 Dialogic 背景→新背景」
## 的 shader 交叉淡化；本過場從未設過 Dialogic 背景，所以「前一張」在 shader 眼中是
## 全透明，淡入過程中 Dialogic 背景層本身透明度從 0 升到 1，這段時間會透出「疊在它
## 下面、仍完整不透明」的 StoryCutscene 停格畫面——玩家看到的就是「過場背景殘留」。
## 對話一開始通常會立刻設自己的 [background]（本專案兩處 hold 後接的對話皆是），
## 停格幀本來就不是要給那段對話當背景用，改收黑即可讓淡入過程透出的是黑幕而非
## 不相干的舊過場畫面，且視覺上與「淡入淡出」天然融合。
func hold_to_black() -> void:
	_playing = false
	if _frame != null:
		_frame.texture = null
		_frame.visible = false
	if _black != null:
		_black.visible = true
		_black.modulate.a = 1.0
		_black.color = Color.BLACK
	if _cap_box != null:
		_cap_box.visible = false
	if _blur != null:
		_blur.visible = false
	if _flash != null:
		_flash.color.a = 0.0
	if _eye != null and _eye.material is ShaderMaterial:
		(_eye.material as ShaderMaterial).set_shader_parameter("close", 0.0)
	_open_lids_instant()
	if _skip_hint_label() != null:
		_skip_hint_label().visible = false

## _make_skip_hint() 建立的提示是動態 add_child，沒存參照；held 收黑時一併找出來隱藏
## （held 狀態下已無跳過操作可跳，提示留著會跟黑幕一起卡在畫面上）。
func _skip_hint_label() -> Label:
	for child in get_children():
		if child is Label:
			return child
	return null

# --- UI ---

func _build_ui() -> void:
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)

	_frame = TextureRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 注意：不要設 _frame.size = VIEW。此時節點尚未進場景樹（父容器大小為 0），
	# 設 size 會在「填滿父容器」的錨點上再疊加 +1920/+1080 偏移，導致進樹後
	# 框被撐成 3840x2160（父 1920x1080 + VIEW），圖被放大成 2 倍只露出一角。
	# COVERED：等比放大填滿整個畫面（極少的邊緣裁掉，無灰邊也無黑邊）→ 真正滿版。
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.visible = false
	add_child(_frame)

	# 暈倒模糊層：疊在影像之上、字幕之下；平時隱藏，暈倒時淡入。
	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.color = Color.WHITE
	_blur.material = _make_blur_material()
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.visible = false
	add_child(_blur)

	# 字幕：純文字、無底框（影片式）。以陰影描邊確保在影像上可讀。
	_cap_box = PanelContainer.new()
	_cap_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap_box.anchor_top = 1.0; _cap_box.anchor_bottom = 1.0
	_cap_box.offset_top = -220; _cap_box.offset_bottom = -70
	_cap_box.offset_left = 100; _cap_box.offset_right = -100
	_cap_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_box.visible = false
	add_child(_cap_box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_END
	_cap_box.add_child(vb)
	_cap_speaker = Label.new()
	_cap_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_speaker.add_theme_color_override("font_color", GOLD)
	_cap_speaker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_cap_speaker.add_theme_constant_override("shadow_offset_x", 2)
	_cap_speaker.add_theme_constant_override("shadow_offset_y", 2)
	_cap_speaker.add_theme_constant_override("shadow_outline_size", 6)
	_cap_speaker.add_theme_font_size_override("font_size", 26)
	vb.add_child(_cap_speaker)
	_cap_text = Label.new()
	_cap_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_text.add_theme_color_override("font_color", WARM)
	_cap_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_cap_text.add_theme_constant_override("shadow_offset_x", 2)
	_cap_text.add_theme_constant_override("shadow_offset_y", 2)
	_cap_text.add_theme_constant_override("shadow_outline_size", 7)
	_cap_text.add_theme_font_size_override("font_size", 36)
	_cap_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_cap_text)

	# 被打白光：滿版白，平時全透明；命中瞬間閃一下再淡出。疊在影像/字幕上、眼皮下。
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# 被打趴閉眼眼罩：圓形（橢圓）shader 闔黑/睜開，比直線眼皮更像真的閉眼。
	# 平時 close=0＝整片透明（橢圓夠大蓋滿、無黑），閉眼時 close→1 橢圓往中央闔成全黑。
	_eye = ColorRect.new()
	_eye.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eye.color = Color.BLACK
	_eye.material = _make_eye_material()
	_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eye)

	# 眨眼眼皮：疊在最上層（轉場瞬間連字幕一起蓋）。初始全開（高度 0）。
	_lid_top = ColorRect.new()
	_lid_top.color = Color.BLACK
	_lid_top.anchor_left = 0.0; _lid_top.anchor_right = 1.0
	_lid_top.anchor_top = 0.0; _lid_top.anchor_bottom = 0.0
	_lid_top.offset_left = 0.0; _lid_top.offset_right = 0.0
	_lid_top.offset_top = 0.0; _lid_top.offset_bottom = 0.0
	_lid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lid_top)

	_lid_bot = ColorRect.new()
	_lid_bot.color = Color.BLACK
	_lid_bot.anchor_left = 0.0; _lid_bot.anchor_right = 1.0
	_lid_bot.anchor_top = 1.0; _lid_bot.anchor_bottom = 1.0
	_lid_bot.offset_left = 0.0; _lid_bot.offset_right = 0.0
	_lid_bot.offset_top = 0.0; _lid_bot.offset_bottom = 0.0
	_lid_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lid_bot)

	# 打字機逐字音效（獨立播放器，與語音／SFX 不互搶）
	_type_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/sfx/text_blip.mp3"):
		_type_player.stream = load("res://assets/audio/sfx/text_blip.mp3")
	_type_player.volume_db = -5.0
	add_child(_type_player)

	# 右下角跳過提示（半透明小字，提醒可按 ESC 跳過劇情；疊在最上層、不擋輸入）。
	add_child(_make_skip_hint())

## 右下角半透明「ESC 跳過」提示。CutsceneScreen 也用同樣視覺（各自建）。
func _make_skip_hint() -> Label:
	var l := Label.new()
	l.text = "ESC 跳過"
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.offset_left = -200.0; l.offset_top = -54.0
	l.offset_right = -28.0; l.offset_bottom = -20.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", WARM)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.modulate = Color(1, 1, 1, 0.5)   # 稍微透明
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _load_frames(dir: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if dir == "":
		return out
	var i := 1
	while true:
		var path := "%s/frame_%04d.png" % [dir.rstrip("/"), i]
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
		i += 1
	return out

## 暈倒用的螢幕模糊材質：9-tap 加權模糊，amount=取樣像素距離（0=不模糊）。
func _make_blur_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "uniform float amount : hint_range(0.0, 12.0) = 0.0;\n" \
		+ "uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;\n" \
		+ "void fragment() {\n" \
		+ "	vec2 px = amount / vec2(textureSize(screen_tex, 0));\n" \
		+ "	vec4 c = texture(screen_tex, SCREEN_UV) * 4.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)) * 2.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)) * 2.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)) * 2.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)) * 2.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV + px) * 1.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV - px) * 1.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y)) * 1.0;\n" \
		+ "	c += texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y)) * 1.0;\n" \
		+ "	COLOR = c / 16.0;\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amount", 0.0)
	return m

## 圓形閉眼用的眼罩材質：以 UV 中心的橢圓開口，close 0→1 時垂直半徑縮到 0（眼皮闔下）。
## 橢圓邊界＝彎曲(圓潤)，非直線；close=0 橢圓夠大全透明、close=1 整片黑。
func _make_eye_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "uniform float close : hint_range(0.0, 1.0) = 0.0;\n" \
		+ "void fragment() {\n" \
		+ "	vec2 p = UV - vec2(0.5);\n" \
		+ "	float rx = mix(1.25, 0.62, close);\n" \
		+ "	float ry = mix(0.85, 0.0, close);\n" \
		+ "	float d = length(vec2(p.x / max(rx, 0.0001), p.y / max(ry, 0.0001)));\n" \
		+ "	float a = smoothstep(0.9, 1.02, d);\n" \
		+ "	a = max(a, smoothstep(0.86, 1.0, close));\n" \
		+ "	COLOR = vec4(0.0, 0.0, 0.0, a);\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("close", 0.0)
	return m
