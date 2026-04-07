class_name Cell
extends StaticBody3D

signal cell_clicked(cell: Cell)

var grid_x: int = 0
var grid_z: int = 0
var owner_index: int = -1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

const UNCLAIMED_COLOR := Color(0.0, 0.8, 0.2)
const SELECTED_COLOR := Color(1.0, 0.9, 0.0)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UNCLAIMED_COLOR
	mesh_instance.set_surface_override_material(0, mat)


func _input_event(_camera: Camera3D, event: InputEvent,
		_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			cell_clicked.emit(self)


func select() -> void:
	var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = SELECTED_COLOR


func deselect() -> void:
	var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = UNCLAIMED_COLOR if owner_index == -1 else GameState.players[owner_index].color


func claim(player: PlayerData) -> void:
	owner_index = GameState.players.find(player)
	var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = player.color
