extends Node2D

func _ready():
	add_to_group("food")
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 5, Color.GREEN)
