class_name AiPlayer
extends Node

const THINK_DELAY := 0.6
const SCORE_JITTER := 8  # random noise added to each candidate's score

var _main


func setup(main_node) -> void:
	_main = main_node


func take_turn() -> void:
	await get_tree().create_timer(THINK_DELAY).timeout
	_try_action()
	await get_tree().create_timer(THINK_DELAY).timeout
	_main.game_net.handle_end_turn()


func _try_action() -> void:
	var best_cell: Cell = _best_occupiable_cell()
	if best_cell:
		_main.game_net.handle_action("occupy", best_cell)
		return
	var up_cell: Cell = _best_upgradeable_cell()
	if up_cell:
		_main.game_net.handle_action("upgrade", up_cell)
		return
	var build_cell: Cell = _best_build_cell()
	if build_cell:
		_main.game_net.handle_action("build_residential", build_cell)


func _pick_best(candidates: Array) -> Cell:
	candidates.shuffle()
	var best: Cell = null
	var best_score: int = -1
	for entry in candidates:
		var score: int = entry[0] + randi_range(0, SCORE_JITTER)
		if score > best_score:
			best_score = score
			best = entry[1]
	return best


func _best_occupiable_cell() -> Cell:
	var candidates: Array = []
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if _main._can_occupy(cell):
				candidates.append([_occupy_score(cell), cell])
	return _pick_best(candidates)


func _occupy_score(cell: Cell) -> int:
	var is_enemy: bool = cell.owner_index != -1
	match cell.cell_type:
		Cell.CellType.RESIDENTIAL:
			return 100 if is_enemy else 30
		Cell.CellType.INDUSTRY:
			return 60 if is_enemy else 20
		_:
			return 40 if is_enemy else 10


func _best_upgradeable_cell() -> Cell:
	var candidates: Array = []
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_upgrade(cell):
				continue
			var score: int = cell.cell_level * 10
			if cell.cell_type == Cell.CellType.RESIDENTIAL:
				score += 5
			candidates.append([score, cell])
	return _pick_best(candidates)


func _best_build_cell() -> Cell:
	var candidates: Array = []
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if _main._can_convert(cell, Cell.CellType.RESIDENTIAL):
				candidates.append([0, cell])
	return _pick_best(candidates)
