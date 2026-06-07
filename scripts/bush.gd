extends Node2D

@export var food_scene: PackedScene

var timer := 0.0

func _ready():
	add_to_group("bush")
	#queue_redraw()

func _process(delta):

	timer -= delta

	if timer <= 0:

		timer = randf_range(2.0, 4.0)

		var food_count = 0

		for child in get_children():
			if child.is_in_group("food"):
				food_count += 1

		if food_count < 3:

			var food = food_scene.instantiate()

			food.position = Vector2(
				randf_range(-10, 10),
				randf_range(-10, 10)
			)

			add_child(food)

#func _draw():
	#draw_circle(Vector2.ZERO, 15, Color.DARK_GREEN)
