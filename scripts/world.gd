extends Node2D

@export var creature_scene: PackedScene
@export var bush_scene: PackedScene
@export var water_scene: PackedScene

@onready var stats_label = $CanvasLayer/StatsLabel

const WORLD_WIDTH = 1000
const WORLD_HEIGHT = 1000
const TERRAIN_TILE_SIZE = 20
const WATER_REJECT_RADIUS = 45.0
const WATER_EDGE_BUFFER = 8.0
const BUSH_MIN_SPACING = 42.0
const BUSH_WATER_MIN_DISTANCE = 45.0
const BUSH_WATER_IDEAL_DISTANCE = 150.0
const BUSH_WATER_MAX_DISTANCE = 320.0

var terrain_noise := FastNoiseLite.new()
var water_regions := [
	{
		"name": "North Lake",
		"position": Vector2(250, 170),
		"radius": 75.0
	},
	{
		"name": "East Lake",
		"position": Vector2(820, 470),
		"radius": 80.0
	},
	{
		"name": "South Lake",
		"position": Vector2(420, 840),
		"radius": 79.0
	}
]

func _ready():
	SimulationTime.reset()
	setup_terrain()

	queue_redraw()
	spawn_water_regions()

	for i in range(20):
		var creature = creature_scene.instantiate()
		creature.position = random_land_position()
		add_child(creature)

	print("Children:", get_child_count())

	print("Creature count after spawn:",
		get_tree().get_nodes_in_group("creature").size())

	spawn_initial_bushes(15)


func setup_terrain():
	terrain_noise.seed = randi()
	terrain_noise.frequency = 0.01


func spawn_water_regions():
	if water_scene == null:
		push_warning("Cannot spawn water: water_scene is not assigned")
		return

	for region in water_regions:
		var pond = water_scene.instantiate()
		add_child(pond)
		pond.global_position = region["position"]
		pond.radius = region["radius"]
		pond.name = region["name"]
		pond.queue_redraw()


func spawn_initial_bushes(count: int):
	var planted = 0
	var attempts = 0

	while planted < count and attempts < count * 30:
		attempts += 1

		var region = water_regions[randi_range(0, water_regions.size() - 1)]
		var angle = randf_range(0.0, TAU)
		var edge_distance = randf_range(BUSH_WATER_MIN_DISTANCE, BUSH_WATER_MAX_DISTANCE)
		var distance = region["radius"] + edge_distance
		var planting_position = region["position"] + Vector2(cos(angle), sin(angle)) * distance

		if plant_bush_at(planting_position):
			planted += 1


func random_land_position() -> Vector2:
	for i in range(100):
		var candidate = Vector2(
			randf_range(10, WORLD_WIDTH - 10),
			randf_range(10, WORLD_HEIGHT - 10)
		)

		if not is_water_at(candidate):
			return candidate

	return Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)


func plant_bush_at(world_position: Vector2) -> bool:
	if bush_scene == null:
		push_warning("Cannot plant bush: bush_scene is not assigned")
		return false

	var planting_position = clamp_to_world(world_position)

	if terrain_at(planting_position) != "grass":
		return false

	if is_bush_too_close(planting_position):
		return false

	var water_distance = nearest_water_distance(planting_position)

	if water_distance < BUSH_WATER_MIN_DISTANCE:
		return false

	if water_distance > BUSH_WATER_MAX_DISTANCE:
		return false

	if water_distance < BUSH_WATER_IDEAL_DISTANCE:
		var near_water_penalty = inverse_lerp(
			BUSH_WATER_MIN_DISTANCE,
			BUSH_WATER_IDEAL_DISTANCE,
			water_distance
		)

		if randf() > lerp(0.25, 1.0, near_water_penalty):
			return false

	var bush = bush_scene.instantiate()
	add_child(bush)
	bush.global_position = planting_position
	return true


func is_bush_too_close(world_position: Vector2) -> bool:
	for bush in get_tree().get_nodes_in_group("bush"):
		if world_position.distance_to(bush.global_position) < BUSH_MIN_SPACING:
			return true

	return false


func nearest_water_distance(world_position: Vector2) -> float:
	var nearest_distance = INF

	for water in get_tree().get_nodes_in_group("water"):
		var water_radius = water.get("radius")
		if water_radius == null:
			water_radius = WATER_REJECT_RADIUS

		var distance = max(0.0, world_position.distance_to(water.global_position) - water_radius)
		nearest_distance = min(nearest_distance, distance)

	if nearest_distance < INF:
		return nearest_distance

	for region in water_regions:
		var distance = max(0.0, world_position.distance_to(region["position"]) - region["radius"])
		nearest_distance = min(nearest_distance, distance)

	return nearest_distance


func nearest_water_edge_point(world_position: Vector2) -> Vector2:
	var nearest_point = world_position
	var nearest_distance = INF

	for water in get_tree().get_nodes_in_group("water"):
		var water_radius = water.get("radius")
		if water_radius == null:
			water_radius = WATER_REJECT_RADIUS

		var to_position = world_position - water.global_position
		if to_position.length() <= 0.001:
			to_position = Vector2.RIGHT

		var edge_point = water.global_position + to_position.normalized() * (water_radius + WATER_EDGE_BUFFER)
		var distance = world_position.distance_to(edge_point)

		if distance < nearest_distance:
			nearest_point = edge_point
			nearest_distance = distance

	for region in water_regions:
		var to_position = world_position - region["position"]
		if to_position.length() <= 0.001:
			to_position = Vector2.RIGHT

		var edge_point = region["position"] + to_position.normalized() * (region["radius"] + WATER_EDGE_BUFFER)
		var distance = world_position.distance_to(edge_point)

		if distance < nearest_distance:
			nearest_point = edge_point
			nearest_distance = distance

	return clamp_to_world(nearest_point)


func water_push_out_position(world_position: Vector2) -> Vector2:
	var pushed_position = world_position

	for water in get_tree().get_nodes_in_group("water"):
		var water_radius = water.get("radius")
		if water_radius == null:
			water_radius = WATER_REJECT_RADIUS

		var to_position = pushed_position - water.global_position
		var minimum_distance = water_radius + WATER_EDGE_BUFFER

		if to_position.length() < minimum_distance:
			if to_position.length() <= 0.001:
				to_position = Vector2.RIGHT

			pushed_position = water.global_position + to_position.normalized() * minimum_distance

	for region in water_regions:
		var to_position = pushed_position - region["position"]
		var minimum_distance = region["radius"] + WATER_EDGE_BUFFER

		if to_position.length() < minimum_distance:
			if to_position.length() <= 0.001:
				to_position = Vector2.RIGHT

			pushed_position = region["position"] + to_position.normalized() * minimum_distance

	return clamp_to_world(pushed_position)


func is_water_at(world_position: Vector2) -> bool:
	for water in get_tree().get_nodes_in_group("water"):
		var water_radius = water.get("radius")
		if water_radius == null:
			water_radius = WATER_REJECT_RADIUS

		if world_position.distance_to(water.global_position) <= water_radius:
			return true

	for region in water_regions:
		if world_position.distance_to(region["position"]) <= region["radius"]:
			return true

	return false


func terrain_at(world_position: Vector2) -> String:
	if is_water_at(world_position):
		return "water"

	if terrain_noise.get_noise_2d(world_position.x, world_position.y) > 0.3:
		return "forest"

	return "grass"


func clamp_to_world(world_position: Vector2) -> Vector2:
	return Vector2(
		clamp(world_position.x, 0.0, float(WORLD_WIDTH)),
		clamp(world_position.y, 0.0, float(WORLD_HEIGHT))
	)

func _draw():
	draw_rect(
		Rect2(0, 0, WORLD_WIDTH, WORLD_HEIGHT),
		Color(0.22, 0.58, 0.24)
	)

	for x in range(0, WORLD_WIDTH, TERRAIN_TILE_SIZE):
		for y in range(0, WORLD_HEIGHT, TERRAIN_TILE_SIZE):
			var point = Vector2(x + TERRAIN_TILE_SIZE * 0.5, y + TERRAIN_TILE_SIZE * 0.5)
			var terrain = terrain_at(point)
			if terrain == "water":
				continue

			var color = Color(0.24, 0.62, 0.28)

			if terrain == "forest":
				color = Color(0.13, 0.42, 0.18)

			draw_rect(
				Rect2(x, y, TERRAIN_TILE_SIZE, TERRAIN_TILE_SIZE),
				color
			)

	for region in water_regions:
		draw_circle(region["position"], region["radius"] + 12.0, Color(0.06, 0.36, 0.55, 0.55))
		draw_circle(region["position"], region["radius"], Color.DEEP_SKY_BLUE)
		draw_arc(region["position"], region["radius"], 0.0, TAU, 96, Color(0.75, 0.95, 1.0), 4.0)

	draw_rect(
		Rect2(0, 0, WORLD_WIDTH, WORLD_HEIGHT),
		Color.BLACK,
		false,
		8
	)
	
func _process(_delta):
	var year = SimulationTime.elapsed_years()
	var creatures = get_tree().get_nodes_in_group("creature")
	var bushes = get_tree().get_nodes_in_group("bush")
	var water_count = get_tree().get_nodes_in_group("water").size()

	var population = creatures.size()
	var food_count = get_tree().get_nodes_in_group("food").size()
	var bush_count = bushes.size()

	var avg_speed = 0.0
	var avg_vision = 0.0
	var avg_reproduction = 0.0
	var avg_hunger = 0.0
	var avg_thirst = 0.0

	var max_generation = 0
	var oldest_age = 0.0
	var oldest_bush_age = 0.0
	var seeds_held = 0

	for creature in creatures:
		avg_speed += creature.speed
		avg_vision += creature.vision_radius
		avg_reproduction += creature.reproduction_threshold
		avg_hunger += creature.hunger
		avg_thirst += creature.thirst
		seeds_held += creature.seeds

		max_generation = max(
			max_generation,
			creature.generation
		)

		oldest_age = max(
			oldest_age,
			creature.age_years
		)

	for bush in bushes:
		oldest_bush_age = max(
			oldest_bush_age,
			bush.age_years
		)

	if population > 0:
		avg_speed /= population
		avg_vision /= population
		avg_reproduction /= population
		avg_hunger /= population
		avg_thirst /= population

	stats_label.text = (
	"World Age: %.1f years\n" +
	"Population: %d\n" +
	"Food: %d\n" +
	"Bushes: %d\n" +
	"Water: %d\n" +
	"Seeds Held: %d\n" +
	"Avg Hunger: %.1f\n" +
	"Avg Thirst: %.1f\n\n" +
	"Oldest Creature: %.1f years\n" +
	"Oldest Bush: %.1f years\n" +
	"World: %dx%d"
) % [
	year,
	population,
	food_count,
	bush_count,
	water_count,
	seeds_held,
	avg_hunger,
	avg_thirst,
	oldest_age,
	oldest_bush_age,
	WORLD_WIDTH,
	WORLD_HEIGHT
]
