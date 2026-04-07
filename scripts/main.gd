extends Node3D

const GRID_SIZE := 16
const CellScene := preload("res://scenes/cell.tscn")

@onready var grid_root: Node3D = $GridRoot
@onready var hud = $HUD


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_spawn_grid()
	GameState.turn_changed.connect(func(p: PlayerData) -> void: hud.update_turn(p.player_name))
	hud.update_turn(GameState.current_player().player_name)


func _spawn_grid() -> void:
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = CellScene.instantiate()
			cell.position = Vector3(x - GRID_SIZE / 2.0 + 0.5, 0.0, z - GRID_SIZE / 2.0 + 0.5)
			cell.grid_x = x
			cell.grid_z = z
			cell.cell_clicked.connect(_on_cell_clicked)
			grid_root.add_child(cell)


func _on_cell_clicked(cell: Cell) -> void:
	if cell.owner_index != -1:
		return
	cell.claim(GameState.current_player())
	GameState.advance_turn()
