extends Node2D
class_name MinigameBase
## 所有小遊戲的共用基底。
## 子類負責玩法與計分，結束時呼叫 finish(result)；
## 由 SceneRouter.finish_minigame 統一套用獎勵、回報結果、返回地圖。
##
## result 契約：
##   { "id": String, "score": int, "win": bool,
##     "gold": int, "merit": int, "karma": int }
## 小遊戲本身不直接改 GameManager 狀態（保持純邏輯、好測試）。

const RESULT_TEMPLATE := {
	"id": "", "score": 0, "win": false,
	"gold": 0, "merit": 0, "karma": 0,
}

var _finished: bool = false

## 子類覆寫，回傳本小遊戲的 id（與場景檔名 to_snake_case 對應）。
func minigame_id() -> String:
	return ""

## 把 result 補齊預設欄位後回傳（子類組 result 時可用）。
func make_result(fields: Dictionary) -> Dictionary:
	var r := RESULT_TEMPLATE.duplicate(true)
	for k in fields:
		r[k] = fields[k]
	if r.id == "":
		r.id = minigame_id()
	return r

## 結束小遊戲：交給 SceneRouter 套用獎勵並返回地圖。重複呼叫只生效一次。
func finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var r := make_result(result)
	if Engine.has_singleton("SceneRouter") or get_node_or_null("/root/SceneRouter") != null:
		SceneRouter.finish_minigame(r)
	else:
		# 測試情境下沒有 autoload：直接發訊號讓測試接住。
		minigame_finished.emit(r)

signal minigame_finished(result: Dictionary)

# --- 共用體感（畫面震動＋頓幀；HUD 都在 CanvasLayer 上不受震動影響）---

## 畫面震動：搖場景根節點（強度遞減的隨機偏移）。命中/撞擊瞬間用。
func shake(strength: float = 12.0, dur: float = 0.25) -> void:
	var steps := maxi(int(dur / 0.04), 2)
	var tw := create_tween()
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tw.tween_property(self, "position", off, 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)

## 頓幀（hit-stop）：重擊瞬間全域慢動作一瞬，強化打擊感。
## dur=真實秒數；重入保護（已在頓幀中就跳過）。
func hit_stop(dur: float = 0.06, slow: float = 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = slow
	await get_tree().create_timer(dur, true, false, true).timeout   # ignore_time_scale
	Engine.time_scale = 1.0

# --- 共用 FX（Codex fx_* 圖，additive 疊加、縮放+淡出後自清；缺圖靜默跳過）---

const FX_ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"

## 命中爆點：飛鏢釘靶/保齡球撞瓶的瞬間。fx_scale＝最終 scale（圖 1254px 見方）。
func spawn_fx_burst(pos: Vector2, fx_scale: float) -> void:
	_spawn_fx("fx_impact_burst_game_ready.png", pos, fx_scale, 0.12, 0.28)

## 贏錢金光：結算/紅心/全倒的慶祝閃光，停留久一點。
func spawn_fx_sparkle(pos: Vector2, fx_scale: float) -> void:
	_spawn_fx("fx_gold_sparkle_game_ready.png", pos, fx_scale, 0.18, 0.75)

func _spawn_fx(file: String, pos: Vector2, fx_scale: float, grow_t: float, fade_t: float) -> void:
	var path := FX_ART + file
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.scale = Vector2.ONE * fx_scale * 0.45
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * fx_scale, grow_t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, grow_t + fade_t)
	tw.tween_callback(s.queue_free)
