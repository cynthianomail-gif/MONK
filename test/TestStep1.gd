extends Node

## 測試入口場景：把 TestRunner 掛到 root，避免場景切換時被釋放

func _ready() -> void:
	var runner: Node = preload("res://test/TestRunner.gd").new()
	runner.name = "TestRunner"
	get_tree().root.add_child.call_deferred(runner)
