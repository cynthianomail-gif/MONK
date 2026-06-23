extends Node
## smoke：AresVFX 元件建立 + 4 個觸發方法(hit/attack/phase2/defeat)不 crash。
func _ready() -> void:
	var VFX := load("res://src/screens/BattleScreen/ares_vfx.gd")
	if VFX == null:
		push_error("TEST FAIL: ares_vfx.gd 載入失敗"); get_tree().quit(1); return
	var host := Control.new(); host.custom_minimum_size = Vector2(320, 520); host.size = Vector2(320, 520)
	add_child(host)
	var fig := TextureRect.new(); host.add_child(fig)
	var vfx: Control = VFX.new()
	host.add_child(vfx)
	vfx.figure = fig
	await get_tree().process_frame
	await get_tree().process_frame
	vfx.play_hit()
	vfx.play_attack()
	vfx.set_phase2()
	vfx.play_defeat()
	for i in 8:
		await get_tree().process_frame
	print("TEST PASS: AresVFX 建立+4 觸發無 crash")
	get_tree().quit(0)
