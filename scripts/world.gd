extends Node2D

@export var creature_scene: PackedScene
@export var bush_scene: PackedScene
@onready var stats_label = $CanvasLayer/StatsLabel

const WORLD_WIDTH = 1000
const WORLD_HEIGHT = 1000

var simulation_time := 0.0

const SECONDS_PER_YEAR := 10.0

func _ready():

	queue_redraw()

	# existing spawn code...
	for i in range(20):
		var creature = creature_scene.instantiate()

		creature.position = Vector2(
			randf_range(10, WORLD_WIDTH - 10),
			randf_range(10, WORLD_HEIGHT - 10)
		)

		add_child(creature)

	print("Children:", get_child_count())

	print("Creature count after spawn:",
		get_tree().get_nodes_in_group("creature").size())

	for i in range(15):
		var bush = bush_scene.instantiate()

		bush.position = Vector2(
			randf_range(100, 900),
			randf_range(100, 900)
		)

		add_child(bush)

func _draw():

	# grass
	draw_rect(
		Rect2(0, 0, WORLD_WIDTH, WORLD_HEIGHT),
		Color(0.25, 0.6, 0.25)
	)

	# border
	draw_rect(
		Rect2(0, 0, WORLD_WIDTH, WORLD_HEIGHT),
		Color.BLACK,
		false,
		8
	)
	
func _process(_delta):
	simulation_time += _delta
	var year = int(simulation_time / SECONDS_PER_YEAR)
	var creatures = get_tree().get_nodes_in_group("creature")

	var population = creatures.size()
	var food_count = get_tree().get_nodes_in_group("food").size()
	var bush_count = get_tree().get_nodes_in_group("bush").size()

	var avg_speed = 0.0
	var avg_vision = 0.0
	var avg_reproduction = 0.0

	var max_generation = 0
	var oldest_age = 0.0

	for creature in creatures:
		avg_speed += creature.speed
		avg_vision += creature.vision_radius
		avg_reproduction += creature.reproduction_threshold

		max_generation = max(
			max_generation,
			creature.generation
		)

		oldest_age = max(
			oldest_age,
			creature.age
		)

	if population > 0:
		avg_speed /= population
		avg_vision /= population
		avg_reproduction /= population

	stats_label.text = (
	"Year: %d\n" +
	"Population: %d\n" +
	"Food: %d\n" +
	"Bushes: %d\n" +
	"World: %dx%d"
) % [
	year,
	population,
	food_count,
	bush_count,
	WORLD_WIDTH,
	WORLD_HEIGHT
]
