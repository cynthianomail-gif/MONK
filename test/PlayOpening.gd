extends Node
## 實機錄製用：純播放 opening_temple_falls，播完即退出。
## 搭配 Movie Maker 模式錄成影片（含音軌）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK --write-movie D:/monk/_art_review/cutscene_okami/opening_play.avi res://test/PlayOpening.tscn
var _cs: Control

func _ready() -> void:
	var ps: PackedScene = load("res://src/screens/CutsceneScreen/StoryCutscene.tscn")
	var cl := CanvasLayer.new()
	add_child(cl)
	_cs = ps.instantiate()
	cl.add_child(_cs)
	await get_tree().process_frame
	_cs.finished.connect(func() -> void: get_tree().quit(0))
	_cs.play("opening_temple_falls")
