extends Node2D

@export var creature_scene: PackedScene
@export var bush_scene: PackedScene
@onready var stats_label = $CanvasLayer/StatsLabel

const WORLD_WIDTH = 1000
const WORLD_HEIGHT = 1000

func _ready():
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
		
func _process(delta):

	var population = get_tree().get_nodes_in_group("creature").size()
	var food_count = get_tree().get_nodes_in_group("food").size()

	stats_label.text = (
		"Population: %d\nFood: %d\nWorld: 1000x1000"
		% [population, food_count]
	)
