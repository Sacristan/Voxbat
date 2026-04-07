extends Node3D

const GRID_SIZE := 5
const CellScene := preload("res://scenes/cell.tscn")

const INDUSTRIAL_POSITIONS := [
	Vector2i(2, 0), Vector2i(0, 3),  # near Player A: 2 and 3 steps away
	Vector2i(2, 4), Vector2i(4, 1),  # near Player B: 2 and 3 steps away
]

var grid: Array = []
var _selected_cell: Cell = null
var _is_game_over: bool = false

@onready var grid_root: Node3D = $GridRoot
@onready var camera_rig = $CameraRig
@onready var hud = $HUD
@onready var cell_panel = $CellPanel


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_spawn_grid()
	_place_starting_cells()
	camera_rig.fit_to_grid(GRID_SIZE)
	GameState.turn_changed.connect(_on_turn_changed)
	hud.end_turn_pressed.connect(_on_end_turn)
	cell_panel.occupy_pressed.connect(_on_occupy_pressed)
	cell_panel.panel_closed.connect(_on_panel_closed)
	_update_hud()


func _spawn_grid() -> void:
	grid.resize(GRID_SIZE)
	for z in GRID_SIZE:
		grid[z] = []
		grid[z].resize(GRID_SIZE)
		for x in GRID_SIZE:
			var cell: Cell = CellScene.instantiate()
			cell.position = Vector3(x - GRID_SIZE / 2.0 + 0.5, 0.0, z - GRID_SIZE / 2.0 + 0.5)
			cell.grid_x = x
			cell.grid_z = z
			if (x == 0 and z == 0) or (x == GRID_SIZE - 1 and z == GRID_SIZE - 1):
				cell.cell_type = Cell.CellType.RESIDENTIAL
			elif Vector2i(x, z) in INDUSTRIAL_POSITIONS:
				cell.cell_type = Cell.CellType.INDUSTRY
			cell.cell_clicked.connect(_on_cell_clicked)
			grid_root.add_child(cell)
			grid[z][x] = cell


func _place_starting_cells() -> void:
	grid[0][0].claim(GameState.players[0])
	grid[GRID_SIZE - 1][GRID_SIZE - 1].claim(GameState.players[1])


func _has_adjacent_owned(gx: int, gz: int, player_idx: int) -> bool:
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nx: int = gx + dx
			var nz: int = gz + dz
			if nx < 0 or nx >= GRID_SIZE or nz < 0 or nz >= GRID_SIZE:
				continue
			if grid[nz][nx].owner_index == player_idx:
				return true
	return false


func _occupation_cost(cell: Cell) -> int:
	if cell.owner_index == -1:
		return 10
	if cell.owner_index != GameState.current_player_index:
		if cell.cell_type == Cell.CellType.RESIDENTIAL:
			return GameState.opponent().manpower * 2
		return 20
	return 0


func _can_occupy(cell: Cell) -> bool:
	if _is_game_over or GameState.has_occupied_this_turn:
		return false
	if cell.owner_index == GameState.current_player_index:
		return false
	if not _has_adjacent_owned(cell.grid_x, cell.grid_z, GameState.current_player_index):
		return false
	return GameState.current_player().manpower >= _occupation_cost(cell)


func _calc_resource_deltas(player_idx: int) -> Dictionary:
	var mp := 0
	var sup := 0
	var mat := 0
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.owner_index != player_idx:
				continue
			match cell.cell_type:
				Cell.CellType.RESOURCE:
					mp -= 1
					sup += 5
				Cell.CellType.INDUSTRY:
					sup -= 10
					mat += 5
				Cell.CellType.RESIDENTIAL:
					mp += 10
					sup -= 20
					mat -= 10
	return {"mp": mp, "sup": sup, "mat": mat}


# Returns winner name on game over, empty string otherwise.
func _apply_turn_effects(player_idx: int) -> String:
	var player := GameState.players[player_idx]
	var residential_starved := false

	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.owner_index != player_idx:
				continue
			match cell.cell_type:
				Cell.CellType.RESOURCE:
					player.manpower = max(0, player.manpower - 1)
					player.supplies += 5
				Cell.CellType.INDUSTRY:
					player.supplies = max(0, player.supplies - 10)
					player.materials += 5
				Cell.CellType.RESIDENTIAL:
					if player.supplies < 20 or player.materials < 10:
						residential_starved = true
					player.supplies = max(0, player.supplies - 20)
					player.materials = max(0, player.materials - 10)

	# Zero-resource penalties
	if player.supplies == 0:
		player.manpower = max(0, player.manpower - 10)
	if player.materials == 0:
		player.manpower = max(0, player.manpower - 10)

	# Starvation tracking
	if residential_starved:
		player.starvation_turns += 1
		if player.starvation_turns >= 3:
			var opp_idx := (player_idx + 1) % GameState.players.size()
			return GameState.players[opp_idx].player_name
	else:
		player.starvation_turns = 0

	return ""


func _on_cell_clicked(cell: Cell) -> void:
	if _selected_cell != null and _selected_cell != cell:
		_selected_cell.deselect()
	_selected_cell = cell
	cell.select()
	var can_occupy := _can_occupy(cell)
	var cost := _occupation_cost(cell)
	cell_panel.show_for_cell(cell, can_occupy, cost)


func _on_occupy_pressed(cell: Cell) -> void:
	var player := GameState.current_player()
	var is_enemy_residential := (
		cell.owner_index != -1
		and cell.owner_index != GameState.current_player_index
		and cell.cell_type == Cell.CellType.RESIDENTIAL
	)
	player.manpower -= _occupation_cost(cell)
	cell.claim(player)
	_selected_cell = null
	GameState.has_occupied_this_turn = true
	_update_hud()
	if is_enemy_residential:
		_is_game_over = true
		hud.show_game_over(player.player_name)


func _on_panel_closed() -> void:
	if _selected_cell != null:
		_selected_cell.deselect()
		_selected_cell = null


func _on_end_turn() -> void:
	if _is_game_over:
		return
	var winner := _apply_turn_effects(GameState.current_player_index)
	if winner != "":
		_is_game_over = true
		hud.show_game_over(winner)
		return
	if _selected_cell != null:
		_selected_cell.deselect()
		_selected_cell = null
	cell_panel.hide()
	GameState.end_turn()


func _on_turn_changed(_player: PlayerData) -> void:
	_update_hud()


func _update_hud() -> void:
	var deltas := _calc_resource_deltas(GameState.current_player_index)
	hud.update_turn(GameState.current_player().player_name)
	hud.update_resources(GameState.current_player(), deltas["mp"], deltas["sup"], deltas["mat"])
