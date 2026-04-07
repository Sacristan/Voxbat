extends CanvasLayer

@onready var turn_label: Label = $TurnLabel


func update_turn(player_name: String) -> void:
	turn_label.text = "Turn: " + player_name
