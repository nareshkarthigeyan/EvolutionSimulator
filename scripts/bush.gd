extends Node2D

@export var food_scene: PackedScene

var timer := 0.0
var age_seconds := 0.0
var age_years := 0.0
var age := 0.0
var lifespan_years := 50.0

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("bush")
	#queue_redraw()

func _process(delta):
	age_seconds += delta
	age_years = SimulationTime.seconds_to_years(age_seconds)
	age = age_years

	if sprite:
		var life_ratio = clamp(age_years / lifespan_years, 0.0, 1.0)
		sprite.modulate = Color(
			1.0,
			1.0 - life_ratio * 0.35,
			1.0 - life_ratio * 0.65
		)

	if age_years >= lifespan_years:
		queue_free()
		return

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
