extends CharacterBody2D
# ART
@onready var sprite = $Sprite2D

const SEED_DROP_CHANCE := 0.5
const SEED_PLANT_CHANCE := 0.5
const SEED_PLANT_RADIUS := 20.0
const MAX_NEED := 100.0
const CREATURE_COLLISION_RADIUS := 14.0
const CREATURE_SEPARATION_FORCE := 0.65
const DRINK_EDGE_DISTANCE := 14.0

var direction: Vector2
var change_timer := 0.0
var seed_plant_timer := 0.0
var hunger := 100.0
var thirst := 100.0
var reproduction_cooldown := 0.0
var seeds := 0

# PROPERTIES
var age_seconds := 0.0
var age_years := 0.0
var age := 0.0
var generation := 0

# GENES:
var speed := 80.0
var vision_radius := 150.0
var reproduction_threshold := 100.0
var max_age_years := 30.0


func _ready():
	add_to_group("creature")
	queue_redraw()

	direction = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()
	seed_plant_timer = randf_range(1.0, 3.0)
	

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
	child.reproduction_threshold += randf_range(-5, 5)

	# prevent nonsense values
	child.speed = max(child.speed, 20)
	child.vision_radius = max(child.vision_radius, 20)
	child.reproduction_threshold = clamp(child.reproduction_threshold, 50, 100)
	
	child.generation = generation + 1
	
	get_parent().add_child(child)
	
	SimulationStats.births += 1

	hunger -= 40.0
	hunger = max(hunger, 5.0)


func find_nearest_food():

	var nearest = null
	var nearest_distance = INF

	for food in get_tree().get_nodes_in_group("food"):

		var d = position.distance_to(food.global_position)

		if d < vision_radius and d < nearest_distance:
			nearest = food
			nearest_distance = d

	return nearest


func find_nearest_water():
	var nearest = null
	var nearest_distance = INF

	for water in get_tree().get_nodes_in_group("water"):
		var edge_position = get_water_edge_position(water)
		var d = global_position.distance_to(edge_position)

		if d < vision_radius and d < nearest_distance:
			nearest = water
			nearest_distance = d

	return nearest


func choose_target():
	if thirst < hunger:
		var water = find_nearest_water()
		if water:
			return water
		return find_nearest_food()

	var food = find_nearest_food()
	if food:
		return food

	return find_nearest_water()


func try_collect_seed():
	if randf() >= SEED_DROP_CHANCE:
		return

	seeds += 1
	SimulationStats.seeds_found += 1


func try_plant_seed():
	if seeds <= 0 or randf() >= SEED_PLANT_CHANCE:
		return

	var world = get_parent()

	if world == null or not world.has_method("plant_bush_at"):
		return

	var planting_position = global_position + Vector2(
		randf_range(-SEED_PLANT_RADIUS, SEED_PLANT_RADIUS),
		randf_range(-SEED_PLANT_RADIUS, SEED_PLANT_RADIUS)
	)

	if world.plant_bush_at(planting_position):
		seeds -= 1
		SimulationStats.seeds_planted += 1


func get_water_edge_position(water) -> Vector2:
	var water_radius = water.get("radius")
	if water_radius == null:
		water_radius = 40.0

	var to_creature = global_position - water.global_position
	if to_creature.length() <= 0.001:
		to_creature = Vector2.RIGHT

	return water.global_position + to_creature.normalized() * (water_radius + 8.0)


func resolve_creature_collisions():
	var push = Vector2.ZERO

	for creature in get_tree().get_nodes_in_group("creature"):
		if creature == self:
			continue

		var offset = global_position - creature.global_position
		var distance = offset.length()
		var minimum_distance = CREATURE_COLLISION_RADIUS * 2.0

		if distance <= 0.001:
			offset = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
			distance = 0.001

		if distance < minimum_distance:
			push += offset.normalized() * (minimum_distance - distance)

	if push.length() > 0.0:
		global_position += push * CREATURE_SEPARATION_FORCE


func stay_out_of_water():
	var world = get_parent()

	if world == null or not world.has_method("is_water_at"):
		return

	if not world.is_water_at(global_position):
		return

	if world.has_method("water_push_out_position"):
		global_position = world.water_push_out_position(global_position)

	direction = -direction


func _physics_process(delta):

	var r = clamp(speed / 200.0, 0.0, 1.0)
	var g = clamp(vision_radius / 300.0, 0.0, 1.0)
	var b = clamp(generation / 50.0, 0.2, 1.0)

	sprite.modulate = Color(r, g, b)

	# Timers
	reproduction_cooldown -= delta
	seed_plant_timer -= delta

	# Aging & Needs
	age_seconds += delta
	age_years = SimulationTime.seconds_to_years(age_seconds)
	age = age_years
	hunger -= delta * 5
	thirst -= delta * 8

	if hunger <= 0:
		SimulationStats.deaths += 1
		queue_free()
		return

	if thirst <= 0:
		SimulationStats.deaths += 1
		queue_free()
		return

	# Old age death
	if age_years > max_age_years:
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

	var target = choose_target()

	if target:
		var target_position = target.global_position

		if target.is_in_group("water"):
			target_position = get_water_edge_position(target)

		direction = (target_position - global_position).normalized()

	# Face movement direction
	if direction.length() > 0:
		rotation = direction.angle()

	# Move
	velocity = direction * speed
	move_and_slide()
	resolve_creature_collisions()
	stay_out_of_water()

	if seed_plant_timer <= 0.0:
		seed_plant_timer = randf_range(1.0, 3.0)
		try_plant_seed()

	if target and target.is_in_group("water"):
		var edge_position = get_water_edge_position(target)

		if global_position.distance_to(edge_position) <= DRINK_EDGE_DISTANCE:
			thirst = MAX_NEED

	if target and target.is_in_group("food") and global_position.distance_to(target.global_position) < 10:

		SimulationStats.food_eaten += 1
		try_collect_seed()

		if target.age_years < target.ripe_age_years:

			# Unripe fruit
			hunger += 50

		elif target.age_years < target.rotten_age_years:

			# Perfectly ripe fruit
			hunger += 100

		else:

			# Rotten fruit
			if randf() < 0.7:
				hunger -= 20
			else:
				hunger += 45

		hunger = clamp(hunger, 0.0, MAX_NEED)

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
		age_years / max_age_years
	)
	fertility = clamp(fertility, 0.0, 1.0)

	if (
		hunger > reproduction_threshold
		and thirst > 65.0
		and reproduction_cooldown <= 0.0
	):

		if randf() < fertility:

			reproduce()

			reproduction_cooldown = 5.0
