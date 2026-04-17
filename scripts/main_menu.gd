extends Control

@onready var local_versus_btn: Button = $CenterContainer/VBoxContainer/LocalVersusButton

func _ready() -> void:
	local_versus_btn.pressed.connect(_on_local_versus_pressed)

func _on_local_versus_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
