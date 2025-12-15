extends Camera2D

@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var pan_button: MouseButton = MOUSE_BUTTON_MIDDLE

var _is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# Handle zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(zoom_speed, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(-zoom_speed, event.position)
		elif event.button_index == pan_button:
			_is_panning = event.pressed
	
	# Handle pan
	if event is InputEventMouseMotion and _is_panning:
		position -= event.relative / zoom

func _zoom_at_point(zoom_delta: float, mouse_pos: Vector2) -> void:
	var old_zoom := zoom
	var new_zoom_value := clampf(zoom.x + zoom_delta, min_zoom, max_zoom)
	zoom = Vector2(new_zoom_value, new_zoom_value)
	
