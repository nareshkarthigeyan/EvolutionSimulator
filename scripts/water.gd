extends Node2D

var radius := 80.0


func _ready():
	add_to_group("water")
	queue_redraw()


func _draw():
	draw_circle(
		Vector2.ZERO,
		radius + 12.0,
		Color(0.05, 0.34, 0.55, 0.5)
	)
	draw_circle(
		Vector2.ZERO,
		radius,
		Color.DEEP_SKY_BLUE
	)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		96,
		Color(0.75, 0.95, 1.0),
		4.0
	)
