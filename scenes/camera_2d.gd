extends Camera2D

const MOVE_SPEED = 100.0
const ZOOM_SPEED = 0.03

@export var world_width := 1000
@export var world_height := 1000

func _process(delta):

	var move = Vector2.ZERO

	# WASD
	if Input.is_key_pressed(KEY_W):
		move.y -= 1

	if Input.is_key_pressed(KEY_S):
		move.y += 1

	if Input.is_key_pressed(KEY_A):
		move.x -= 1

	if Input.is_key_pressed(KEY_D):
		move.x += 1

	# Arrow Keys
	if Input.is_key_pressed(KEY_UP):
		move.y -= 1

	if Input.is_key_pressed(KEY_DOWN):
		move.y += 1

	if Input.is_key_pressed(KEY_LEFT):
		move.x -= 1

	if Input.is_key_pressed(KEY_RIGHT):
		move.x += 1

	if move != Vector2.ZERO:
		position += move.normalized() * MOVE_SPEED * delta

	# Q = Zoom In
	if Input.is_key_pressed(KEY_Q):
		zoom *= (1.0 - ZOOM_SPEED)

	# E = Zoom Out
	if Input.is_key_pressed(KEY_E):
		zoom *= (1.0 + ZOOM_SPEED)

	# Clamp zoom
	zoom.x = clamp(zoom.x, 0.2, 5.0)
	zoom.y = clamp(zoom.y, 0.2, 5.0)

	# Keep camera inside world
	position.x = clamp(position.x, 0, world_width)
	position.y = clamp(position.y, 0, world_height)


func _input(event):

	if event is InputEventMouseButton:

		# Mouse Wheel Up = Zoom In
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom *= 0.9

		# Mouse Wheel Down = Zoom Out
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom *= 1.1

		zoom.x = clamp(zoom.x, 0.2, 5.0)
		zoom.y = clamp(zoom.y, 0.2, 5.0)
