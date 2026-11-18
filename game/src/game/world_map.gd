class_name WorldMap
extends Node2D
## Placeholder until the travel map is built.

func _ready() -> void:
	var l := UITheme.label("World map (not built yet)", 24)
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(l)
