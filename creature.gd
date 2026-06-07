extends CharacterBody2D

var direction: Vector2
var change_timer := 0.0

var energy := 100.0

# GENES:
var speed := 100.0
var vision_radius := 150.0
var reproduction_threshold := 200.0


func _ready():
	add_to_group("creature")
	queue_redraw()

	direction = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()
	

func reproduce():

	var child = preload("res://creature.tscn").instantiate()

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

	get_parent().add_child(child)

	energy *= 0.5


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

	# Lose energy over time
	energy -= delta * 10

	# Die if energy runs out
	if energy <= 0:
		queue_free()
		return

	# Random wandering timer
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
		direction = (target.global_position - global_position).normalized()

	# Move
	velocity = direction * speed
	move_and_slide()

	# Eat food
	if target and global_position.distance_to(target.global_position) < 10:
		target.queue_free()
		energy += 50

	# Bounce off world boundaries
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

	# Reproduce
	if energy > reproduction_threshold:
		reproduce()
	
	queue_redraw()

func _draw():

	var r = clamp(speed / 200.0, 0.0, 1.0)
	var g = clamp(vision_radius / 300.0, 0.0, 1.0)

	draw_circle(
		Vector2.ZERO,
		10,
		Color(r, g, 1.0)
	)
