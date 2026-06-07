extends CharacterBody2D
# ART
@onready var sprite = $Sprite2D
const SECONDS_PER_YEAR := 10.0

var direction: Vector2
var change_timer := 0.0
var energy := 100.0
var reproduction_cooldown := 0.0

# PROPERTIES
var age := 0.0
var generation := 0
var age_years := age / 10.0

# GENES:
var speed := 150.0
var vision_radius := 150.0
var reproduction_threshold := 400.0
var max_age_years := 80.0


func _ready():
	add_to_group("creature")
	queue_redraw()

	direction = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()
	

func reproduce():

	var child = preload("res://scenes/creature.tscn").instantiate()

	child.position = position + Vector2(
		randf_range(-20, 20),
		randf_range(-20, 20)
	)

	# inherit genes
	child.speed = speed
	child.vision_radius = vision_radius
	child.reproduction_threshold = reproduction_threshold

	# mutations
	child.speed += randf_range(-10, 10)
	child.vision_radius += randf_range(-20, 20)
	child.reproduction_threshold += randf_range(-20, 20)

	# prevent nonsense values
	child.speed = max(child.speed, 20)
	child.vision_radius = max(child.vision_radius, 20)
	child.reproduction_threshold = max(child.reproduction_threshold, 50)
	
	child.generation = generation + 1
	
	get_parent().add_child(child)
	
	SimulationStats.births += 1

	energy -= reproduction_threshold
	energy = max(energy, 5.0)


func find_nearest_food():

	var nearest = null
	var nearest_distance = INF

	for food in get_tree().get_nodes_in_group("food"):

		var d = position.distance_to(food.global_position)

		if d < vision_radius and d < nearest_distance:
			nearest = food
			nearest_distance = d

	return nearest


func _physics_process(delta):

	var r = clamp(speed / 200.0, 0.0, 1.0)
	var g = clamp(vision_radius / 300.0, 0.0, 1.0)
	var b = clamp(generation / 50.0, 0.2, 1.0)

	sprite.modulate = Color(r, g, b)

	# Timers
	reproduction_cooldown -= delta

	# Aging & Energy
	age += delta
	energy -= delta * 10

	# Starvation death
	if energy <= 0:
		SimulationStats.deaths += 1
		queue_free()
		return

	# Old age death
	if age > max_age_years * SECONDS_PER_YEAR:
		SimulationStats.deaths += 1
		queue_free()
		return

	# Random wandering
	change_timer -= delta

	if change_timer <= 0:
		change_timer = randf_range(1.0, 3.0)

		direction = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized()

	# Find food
	var target = find_nearest_food()

	# Chase food
	if target:
		direction = (
			target.global_position - global_position
		).normalized()

	# Face movement direction
	if direction.length() > 0:
		rotation = direction.angle()

	# Move
	velocity = direction * speed
	move_and_slide()

	# Eat food
	if target and global_position.distance_to(target.global_position) < 10:

		SimulationStats.food_eaten += 1

		if target.age < target.ripe_age:

			# Unripe fruit
			energy += 10

		elif target.age < target.rotten_age:

			# Perfectly ripe fruit
			energy += 50

		else:

			# Rotten fruit
			if randf() < 0.7:
				energy -= 30
			else:
				energy += 5

		target.queue_free()

	# World bounds
	if position.x < 0:
		position.x = 0
		direction.x *= -1

	if position.x > 1000:
		position.x = 1000
		direction.x *= -1

	if position.y < 0:
		position.y = 0
		direction.y *= -1

	if position.y > 1000:
		position.y = 1000
		direction.y *= -1

	# Reproduction
	var fertility = 1.0 - (
		age / (max_age_years * SECONDS_PER_YEAR)
	)
	fertility = clamp(fertility, 0.0, 1.0)

	if (
		energy > reproduction_threshold
		and reproduction_cooldown <= 0.0
	):

		if randf() < fertility:

			reproduce()

			reproduction_cooldown = 5.0
