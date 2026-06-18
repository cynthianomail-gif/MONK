extends CanvasLayer
## 全螢幕轉場特效。由 SceneRouter 實例化、加到 root，play() 後 await finished 再釋放。
## 以程式建立 ColorRect + Tween 演出（非 AnimationPlayer 軌），對齊 GDD §8.7 色系。

signal finished

const COLOR := {
	"karma_main": Color("#FF2D2D"),  # 業障紅
	"ink_black":  Color("#1A0A00"),  # 水墨黑
	"neon_blue":  Color("#00BFFF"),  # 霓虹藍
	"black":      Color("#000000"),
}

var _rect: ColorRect

func _ready() -> void:
	layer = 100  # 蓋過一般 UI，但低於 LoadingScreen(128)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)

func play(type: int) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	match type:
		SceneRouter.Transition.SLASH_RED:  await _slash(vp)
		SceneRouter.Transition.INK_SPLASH:  await _fade(COLOR.ink_black, "ink_splash", vp)
		SceneRouter.Transition.NEON_FLASH:  await _flash(COLOR.neon_blue, vp)
		SceneRouter.Transition.FADE_BLACK:  await _fade(COLOR.black, "", vp)
		_:                                  await _fade(COLOR.black, "", vp)
	finished.emit()

## 業障紅斜切：從左方斜劃過畫面再劃出
func _slash(vp: Vector2) -> void:
	_rect.color = COLOR.karma_main
	_rect.rotation = deg_to_rad(8.0)
	_rect.size = Vector2(vp.x * 1.5, vp.y * 1.5)
	_rect.position = Vector2(-vp.x * 1.5, -vp.y * 0.25)
	AudioManager.play_sfx("slash_red")
	var tw := create_tween()
	tw.tween_property(_rect, "position:x", -vp.x * 0.25, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.05)
	tw.tween_property(_rect, "position:x", vp.x * 1.5, 0.18).set_ease(Tween.EASE_IN)
	await tw.finished

## 純色淡入再淡出（水墨黑 / 全黑），可選 SFX
func _fade(c: Color, sfx: String, vp: Vector2) -> void:
	_rect.rotation = 0.0
	_rect.size = vp
	_rect.position = Vector2.ZERO
	_rect.color = Color(c.r, c.g, c.b, 0.0)
	if sfx != "":
		AudioManager.play_sfx(sfx)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, 0.18)
	tw.tween_interval(0.04)
	tw.tween_property(_rect, "color:a", 0.0, 0.18)
	await tw.finished

## 霓虹快閃
func _flash(c: Color, vp: Vector2) -> void:
	_rect.rotation = 0.0
	_rect.size = vp
	_rect.position = Vector2.ZERO
	_rect.color = Color(c.r, c.g, c.b, 0.0)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.9, 0.06)
	tw.tween_property(_rect, "color:a", 0.0, 0.12)
	await tw.finished
