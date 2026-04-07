extends Node3D

const PAN_SPEED := 15.0
const ZOOM_SPEED := 3.0
const MIN_ZOOM := 8.0
const MAX_ZOOM := 60.0
const CAMERA_ANGLE_DEG := 50.0
# Y rotation per player: northwest for A (-135°), southeast for B (45°)
const PLAYER_ANGLES := [-135.0, 45.0]

var zoom := 28.0
var _dragging := false
var _drag_start_mouse: Vector2
var _drag_start_pos: Vector3
var _tween: Tween = null

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_zoom()


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1.0

	if pan != Vector3.ZERO:
		position += pan.normalized() * PAN_SPEED * delta
		_apply_zoom()

	if _dragging:
		var delta_mouse := get_viewport().get_mouse_position() - _drag_start_mouse
		position = _drag_start_pos + Vector3(-delta_mouse.x, 0.0, -delta_mouse.y) * zoom * 0.001
		_apply_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clamp(zoom - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clamp(zoom + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			if _dragging:
				_drag_start_mouse = get_viewport().get_mouse_position()
				_drag_start_pos = position


func focus_for_player(player_index: int, instant: bool = false) -> void:
	var target_angle: float = PLAYER_ANGLES[player_index]
	if _tween != null and _tween.is_running():
		_tween.kill()
	if instant:
		position = Vector3.ZERO
		rotation_degrees.y = target_angle
		_apply_zoom()
		return
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", Vector3.ZERO, 0.7)
	_tween.tween_property(self, "rotation_degrees:y", target_angle, 0.7)
	_tween.chain().tween_callback(_apply_zoom)


func fit_to_grid(grid_size: int) -> void:
	var half := grid_size / 2.0
	var corners := [
		Vector3(-half, 0.0,  half),
		Vector3( half, 0.0,  half),
		Vector3(-half, 0.0, -half),
		Vector3( half, 0.0, -half),
	]
	zoom = MAX_ZOOM
	_apply_zoom()
	while zoom > MIN_ZOOM + 1.0:
		zoom -= 1.0
		_apply_zoom()
		var all_in := true
		for c in corners:
			if not camera.is_position_in_frustum(c):
				all_in = false
				break
		if not all_in:
			zoom += 3.0  # step back with padding
			_apply_zoom()
			break


func _apply_zoom() -> void:
	var angle := deg_to_rad(CAMERA_ANGLE_DEG)
	camera.position = Vector3(0.0, zoom * cos(angle), zoom * sin(angle))
	camera.look_at(global_position, Vector3.UP)
