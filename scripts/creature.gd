extends CharacterBody2D

class Brain:
	const INPUT_COUNT := 10
	const HIDDEN_COUNT := 8
	const OUTPUT_COUNT := 5
	const MUTATION_RATE := 0.05
	const MUTATION_AMOUNT := 0.3

	var inputs := []
	var hidden := []
	var outputs := []
	var weights_input_hidden := []
	var weights_hidden_output := []

	func _init(parent_brain = null):
		inputs.resize(INPUT_COUNT)
		hidden.resize(HIDDEN_COUNT)
		outputs.resize(OUTPUT_COUNT)

		if parent_brain == null:
			_randomize_weights()
		else:
			weights_input_hidden = parent_brain.weights_input_hidden.duplicate()
			weights_hidden_output = parent_brain.weights_hidden_output.duplicate()
			mutate()

	func _randomize_weights():
		weights_input_hidden.resize(INPUT_COUNT * HIDDEN_COUNT)
		weights_hidden_output.resize(HIDDEN_COUNT * OUTPUT_COUNT)

		for i in range(weights_input_hidden.size()):
			weights_input_hidden[i] = randf_range(-1.0, 1.0)

		for i in range(weights_hidden_output.size()):
			weights_hidden_output[i] = randf_range(-1.0, 1.0)

	func mutate():
		for i in range(weights_input_hidden.size()):
			if randf() < MUTATION_RATE:
				weights_input_hidden[i] += randf_range(-MUTATION_AMOUNT, MUTATION_AMOUNT)

		for i in range(weights_hidden_output.size()):
			if randf() < MUTATION_RATE:
				weights_hidden_output[i] += randf_range(-MUTATION_AMOUNT, MUTATION_AMOUNT)

	func think(new_inputs: Array) -> Array:
		for i in range(INPUT_COUNT):
			inputs[i] = new_inputs[i]

		for h in range(HIDDEN_COUNT):
			var hidden_sum := 0.0
			for i in range(INPUT_COUNT):
				hidden_sum += inputs[i] * weights_input_hidden[i * HIDDEN_COUNT + h]
			hidden[h] = tanh(hidden_sum)

		for o in range(OUTPUT_COUNT):
			var output_sum := 0.0
			for h in range(HIDDEN_COUNT):
				output_sum += hidden[h] * weights_hidden_output[h * OUTPUT_COUNT + o]
			outputs[o] = tanh(output_sum)

		return outputs


@onready var sprite = $Sprite2D

const SEED_DROP_CHANCE := 0.5
const SEED_PLANT_RADIUS := 20.0
const MAX_NEED := 100.0
const CREATURE_COLLISION_RADIUS := 14.0
const CREATURE_SEPARATION_FORCE := 0.65
const DRINK_EDGE_DISTANCE := 14.0
const WORLD_WIDTH := 1000.0
const WORLD_HEIGHT := 1000.0
const MEMORY_LERP_RATE := 0.05
const VISION_ANGLE := PI * 1.2222222222
const TURN_RATE := 4.0
const REPRODUCE_OUTPUT_THRESHOLD := 0.35
const PLANT_OUTPUT_THRESHOLD := 0.25
const REPRODUCE_DRIVE_TO_ACT := 1.0
const PLANT_DRIVE_TO_ACT := 1.0
const REPRODUCTION_COOLDOWN_SECONDS := 12.0
const PLANT_COOLDOWN_SECONDS := 3.0
const MIN_REPRODUCE_HUNGER := 92.0
const MIN_REPRODUCE_THIRST := 82.0
const MIN_REPRODUCE_AGE_YEARS := 1.5
const REPRODUCTION_HUNGER_COST := 65.0
const REPRODUCTION_THIRST_COST := 35.0
const NEARBY_DENSITY_TARGET := 8.0
const MAX_SEED_RATIO := 8.0

var direction := Vector2.RIGHT
var exploration_direction := Vector2.RIGHT
var exploration_timer := 0.0
var seed_plant_timer := 0.0
var hunger := 100.0
var thirst := 100.0
var reproduction_cooldown := 0.0
var seeds := 0
var memory := 0.0
var current_reward_signal := 0.0
var brain := Brain.new()
var brain_outputs := [0.0, 0.0, 0.0, 0.0, 0.0]
var reproduction_drive := 0.0
var plant_drive := 0.0
var visible_food_position := Vector2.ZERO
var visible_water_position := Vector2.ZERO
var sees_food := false
var sees_water := false

# PROPERTIES
var age_seconds := 0.0
var age_years := 0.0
var age := 0.0
var generation := 0
var lineage_id := 0

# GENES
var speed := 80.0
var vision_radius := 150.0
var max_age_years := 30.0
var preferred_seed_count := 2.0


func _ready():
	add_to_group("creature")
	queue_redraw()

	if lineage_id == 0:
		lineage_id = SimulationStats.claim_lineage_id()

	direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT

	exploration_direction = direction
	exploration_timer = randf_range(0.5, 1.5)
	seed_plant_timer = randf_range(0.5, 2.0)


func _draw():
	var half_vision_angle = VISION_ANGLE * 0.5
	var vision_color = Color(1.0, 1.0, 1.0, 0.12)

	draw_arc(Vector2.ZERO, vision_radius, -half_vision_angle, half_vision_angle, 32, vision_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(-half_vision_angle) * vision_radius, vision_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(half_vision_angle) * vision_radius, vision_color, 1.0)

	if sees_food:
		draw_line(Vector2.ZERO, to_local(visible_food_position), Color(0.2, 1.0, 0.2, 0.55), 2.0)

	if sees_water:
		draw_line(Vector2.ZERO, to_local(visible_water_position), Color(0.2, 0.65, 1.0, 0.55), 2.0)


func reproduce():
	var child = preload("res://scenes/creature.tscn").instantiate()

	child.position = position + Vector2(
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0)
	)

	child.brain = Brain.new(brain)
	child.speed = max(20.0, speed + randf_range(-6.0, 6.0))
	child.vision_radius = max(30.0, vision_radius + randf_range(-12.0, 12.0))
	child.max_age_years = max(8.0, max_age_years + randf_range(-2.0, 2.0))
	child.preferred_seed_count = clamp(preferred_seed_count + randf_range(-0.5, 0.5), 0.0, MAX_SEED_RATIO)
	child.hunger = 55.0
	child.thirst = min(thirst, 75.0)
	child.generation = generation + 1
	child.lineage_id = lineage_id

	get_parent().add_child(child)

	SimulationStats.record_birth()
	add_reward(1.0)

	hunger = max(hunger - REPRODUCTION_HUNGER_COST, 5.0)
	thirst = max(thirst - REPRODUCTION_THIRST_COST, 5.0)
	reproduction_drive = 0.0
	reproduction_cooldown = REPRODUCTION_COOLDOWN_SECONDS


func find_nearest_food():
	var nearest = null
	var nearest_distance := INF

	for food in get_tree().get_nodes_in_group("food"):
		var d = global_position.distance_to(food.global_position)

		if d < vision_radius and d < nearest_distance and can_see_position(food.global_position):
			nearest = food
			nearest_distance = d

	return nearest


func find_nearest_water():
	var nearest = null
	var nearest_distance := INF

	for water in get_tree().get_nodes_in_group("water"):
		var edge_position = get_water_edge_position(water)
		var d = global_position.distance_to(edge_position)

		if d < vision_radius and d < nearest_distance and can_see_position(edge_position):
			nearest = water
			nearest_distance = d

	return nearest


func try_collect_seed():
	if randf() >= SEED_DROP_CHANCE:
		return

	seeds += 1
	SimulationStats.record_seed_found()


func try_plant_seed() -> bool:
	seed_plant_timer = PLANT_COOLDOWN_SECONDS

	if seeds <= 0:
		add_reward(-0.3)
		return false

	var world = get_parent()

	if world == null or not world.has_method("plant_bush_at"):
		add_reward(-0.3)
		return false

	var planting_position = global_position + Vector2(
		randf_range(-SEED_PLANT_RADIUS, SEED_PLANT_RADIUS),
		randf_range(-SEED_PLANT_RADIUS, SEED_PLANT_RADIUS)
	)

	if world.plant_bush_at(planting_position):
		seeds -= 1
		SimulationStats.record_seed_planted()
		add_reward(0.7)
		return true

	add_reward(-0.3)
	return false


func add_reward(amount: float):
	current_reward_signal = clamp(current_reward_signal + amount, -1.0, 1.0)


func get_water_edge_position(water) -> Vector2:
	var water_radius = water.get("radius")
	if water_radius == null:
		water_radius = 40.0

	var to_creature = global_position - water.global_position
	if to_creature.length() <= 0.001:
		to_creature = Vector2.RIGHT

	return water.global_position + to_creature.normalized() * (water_radius + 8.0)


func resolve_creature_collisions():
	var push := Vector2.ZERO

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


func count_nearby_creatures() -> int:
	var count := 0

	for creature in get_tree().get_nodes_in_group("creature"):
		if creature == self:
			continue

		if global_position.distance_to(creature.global_position) <= vision_radius and can_see_position(creature.global_position):
			count += 1

	return count


func can_see_position(world_position: Vector2) -> bool:
	var offset = world_position - global_position
	var distance = offset.length()

	if distance > vision_radius:
		return false

	if distance <= CREATURE_COLLISION_RADIUS:
		return true

	return abs(relative_angle_to_position(world_position)) <= VISION_ANGLE * 0.5


func relative_angle_to_position(world_position: Vector2) -> float:
	var offset = world_position - global_position

	if offset.length() <= 0.001:
		return 0.0

	return wrapf(offset.angle() - direction.angle(), -PI, PI)


func update_visible_debug(nearest_food, nearest_water):
	sees_food = nearest_food != null
	sees_water = nearest_water != null

	if sees_food:
		visible_food_position = nearest_food.global_position

	if sees_water:
		visible_water_position = get_water_edge_position(nearest_water)

	queue_redraw()


func build_brain_inputs(nearest_food, nearest_water) -> Array:
	return [
		1.0 - clamp(hunger / MAX_NEED, 0.0, 1.0),
		1.0 - clamp(thirst / MAX_NEED, 0.0, 1.0),
		clamp(age_years / max_age_years, 0.0, 1.0),
		normalized_distance_to(nearest_food),
		normalized_direction_to(nearest_food),
		normalized_distance_to(nearest_water, true),
		normalized_direction_to(nearest_water, true),
		clamp(float(seeds) / max(1.0, preferred_seed_count), 0.0, 1.0),
		clamp(float(count_nearby_creatures()) / NEARBY_DENSITY_TARGET, 0.0, 1.0),
		memory
	]


func normalized_distance_to(target, use_water_edge := false) -> float:
	if target == null:
		return 1.0

	var target_position = target.global_position
	if use_water_edge:
		target_position = get_water_edge_position(target)

	return clamp(global_position.distance_to(target_position) / vision_radius, 0.0, 1.0)


func normalized_direction_to(target, use_water_edge := false) -> float:
	if target == null:
		return 0.0

	var target_position = target.global_position
	if use_water_edge:
		target_position = get_water_edge_position(target)

	var to_target = target_position - global_position
	if to_target.length() <= 0.001:
		return 0.0

	return clamp(relative_angle_to_position(target_position) / (VISION_ANGLE * 0.5), -1.0, 1.0)


func update_exploration(delta: float):
	exploration_timer -= delta
	if exploration_timer > 0.0:
		return

	exploration_timer = randf_range(0.8, 2.2)
	exploration_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if exploration_direction.length() <= 0.001:
		exploration_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))


func update_memory():
	if hunger < 15.0:
		add_reward(-0.5)

	if thirst < 15.0:
		add_reward(-0.5)

	memory = lerp(memory, current_reward_signal, MEMORY_LERP_RATE)
	memory = clamp(memory, -1.0, 1.0)


func die():
	SimulationStats.record_death()
	queue_free()


func _physics_process(delta):
	current_reward_signal = 0.0

	var r = clamp(speed / 200.0, 0.0, 1.0)
	var g = clamp(vision_radius / 300.0, 0.0, 1.0)
	var b = clamp(generation / 50.0, 0.2, 1.0)
	sprite.modulate = Color(r, g, b)

	reproduction_cooldown -= delta
	seed_plant_timer -= delta

	age_seconds += delta
	age_years = SimulationTime.seconds_to_years(age_seconds)
	age = age_years
	hunger -= delta * 5.0
	thirst -= delta * 8.0

	if hunger <= 0.0:
		add_reward(-1.0)
		update_memory()
		die()
		return

	if thirst <= 0.0:
		add_reward(-1.0)
		update_memory()
		die()
		return

	if age_years > max_age_years:
		die()
		return

	update_exploration(delta)

	var nearest_food = find_nearest_food()
	var nearest_water = find_nearest_water()
	update_visible_debug(nearest_food, nearest_water)
	brain_outputs = brain.think(build_brain_inputs(nearest_food, nearest_water))

	var forward = direction.normalized()
	var side = forward.rotated(PI * 0.5)
	var neural_move = forward * brain_outputs[0] + side * brain_outputs[1]
	var exploration_urge = clamp((brain_outputs[4] + 1.0) * 0.5, 0.0, 1.0)
	var exploration_weight = 0.25 if sees_food or sees_water else 0.85
	var desired_move = neural_move + exploration_direction * exploration_urge * exploration_weight

	if desired_move.length() > 0.001:
		var desired_direction = desired_move.normalized()
		var turned_direction = direction.lerp(desired_direction, clamp(TURN_RATE * delta, 0.0, 1.0))
		if turned_direction.length() > 0.001:
			direction = turned_direction.normalized()
		else:
			direction = desired_direction

	if direction.length() > 0.0:
		rotation = direction.angle()

	velocity = direction * speed
	move_and_slide()
	resolve_creature_collisions()
	stay_out_of_water()
	clamp_to_world()

	handle_food_and_water(nearest_food, nearest_water)
	handle_seed_planting(delta)
	handle_reproduction(delta)
	update_memory()


func handle_food_and_water(nearest_food, nearest_water):
	if nearest_water:
		var edge_position = get_water_edge_position(nearest_water)

		if global_position.distance_to(edge_position) <= DRINK_EDGE_DISTANCE:
			if thirst < MAX_NEED:
				add_reward(0.8)
			thirst = MAX_NEED

	if nearest_food and global_position.distance_to(nearest_food.global_position) < 10.0:
		SimulationStats.record_food_eaten()
		try_collect_seed()

		if nearest_food.age_years < nearest_food.ripe_age_years:
			hunger += 50.0
			add_reward(0.4)
		elif nearest_food.age_years < nearest_food.rotten_age_years:
			hunger += 100.0
			add_reward(1.0)
		else:
			if randf() < 0.7:
				hunger -= 20.0
				add_reward(-0.4)
			else:
				hunger += 45.0
				add_reward(0.3)

		hunger = clamp(hunger, 0.0, MAX_NEED)
		nearest_food.queue_free()


func output_desire(output_value: float, threshold: float) -> float:
	return clamp((output_value - threshold) / (1.0 - threshold), 0.0, 1.0)


func update_action_drive(current_drive: float, desire: float, delta: float) -> float:
	if desire > 0.0:
		return clamp(current_drive + desire * delta, 0.0, 1.25)

	return max(current_drive - delta * 0.6, 0.0)


func handle_seed_planting(delta: float):
	var desire = output_desire(brain_outputs[3], PLANT_OUTPUT_THRESHOLD)
	plant_drive = update_action_drive(plant_drive, desire, delta)

	if plant_drive < PLANT_DRIVE_TO_ACT:
		return

	if seed_plant_timer > 0.0:
		plant_drive = min(plant_drive, PLANT_DRIVE_TO_ACT)
		return

	var preferred_ready = seeds >= int(round(preferred_seed_count))
	if preferred_ready or brain_outputs[3] > 0.75:
		try_plant_seed()
	else:
		seed_plant_timer = PLANT_COOLDOWN_SECONDS * 0.5
		add_reward(-0.15)

	plant_drive = 0.0


func handle_reproduction(delta: float):
	var desire = output_desire(brain_outputs[2], REPRODUCE_OUTPUT_THRESHOLD)
	reproduction_drive = update_action_drive(reproduction_drive, desire, delta)

	if reproduction_drive < REPRODUCE_DRIVE_TO_ACT:
		return

	if age_years < MIN_REPRODUCE_AGE_YEARS:
		reproduction_drive = 0.25
		return

	if reproduction_cooldown > 0.0:
		reproduction_drive = min(reproduction_drive, REPRODUCE_DRIVE_TO_ACT)
		return

	if hunger <= MIN_REPRODUCE_HUNGER or thirst <= MIN_REPRODUCE_THIRST:
		reproduction_drive = 0.5
		return

	var fertility = clamp(1.0 - (age_years / max_age_years), 0.0, 1.0)
	if randf() < fertility:
		reproduce()
	else:
		reproduction_drive = 0.0


func clamp_to_world():
	if position.x < 0.0:
		position.x = 0.0
		direction.x *= -1.0

	if position.x > WORLD_WIDTH:
		position.x = WORLD_WIDTH
		direction.x *= -1.0

	if position.y < 0.0:
		position.y = 0.0
		direction.y *= -1.0

	if position.y > WORLD_HEIGHT:
		position.y = WORLD_HEIGHT
		direction.y *= -1.0
