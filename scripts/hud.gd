extends CanvasLayer

signal end_turn_pressed

@onready var turn_label: Label = $TopBar/TopBarInner/TurnLabel
@onready var end_turn_btn: Button = $TopBar/TopBarInner/EndTurnButton
@onready var manpower_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerLabel
@onready var manpower_delta_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerDeltaLabel
@onready var supplies_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesLabel
@onready var supplies_delta_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesDeltaLabel
@onready var materials_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsLabel
@onready var materials_delta_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsDeltaLabel
@onready var game_over_label: Label = $GameOverLabel


func _ready() -> void:
	end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())


func update_turn(player_name: String) -> void:
	turn_label.text = "Turn: " + player_name


func update_resources(player: PlayerData, mp_delta: int, sup_delta: int, mat_delta: int) -> void:
	manpower_label.text = "MP: %d" % player.manpower
	_set_delta(manpower_delta_label, mp_delta)
	supplies_label.text = "SUP: %d" % player.supplies
	_set_delta(supplies_delta_label, sup_delta)
	materials_label.text = "MAT: %d" % player.materials
	_set_delta(materials_delta_label, mat_delta)


func show_game_over(winner_name: String) -> void:
	game_over_label.text = winner_name + " wins!"
	game_over_label.visible = true
	end_turn_btn.disabled = true


func _set_delta(label: Label, delta: int) -> void:
	label.text = "(+%d)" % delta if delta >= 0 else "(%d)" % delta
	if delta < 0:
		label.modulate = Color(1.0, 0.25, 0.25)
	elif delta <= 2:
		label.modulate = Color(1.0, 0.90, 0.00)
	else:
		label.modulate = Color(0.25, 1.00, 0.35)
