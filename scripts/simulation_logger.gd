extends Node

var file: FileAccess
var epoch := 0
var timer := 0.0


func _ready():
	var timestamp = Time.get_datetime_string_from_system()

	timestamp = timestamp.replace(":", "-")
	timestamp = timestamp.replace(" ", "_")

	var filename = "res://data/run_%s.csv" % timestamp

	file = FileAccess.open(
		filename,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Failed to create simulation log: %s" % filename)
		set_process(false)
		return

	file.store_line(
		"epoch,population,food,bushes,avg_speed,avg_vision,avg_reproduction,max_generation,oldest_age,births,deaths,food_eaten"
	)

	print("Logging to:", filename)
	file.flush()


func _process(delta):
	timer += delta
	if timer < 1.0:
		return

	timer = 0.0
	epoch += 1

	log_epoch()


func log_epoch():
	if file == null:
		return

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

	file.store_line(
		"%d,%d,%d,%d,%.2f,%.2f,%.2f,%d,%.2f,%d,%d,%d"
		% [
			epoch,
			population,
			food_count,
			bush_count,
			avg_speed,
			avg_vision,
			avg_reproduction,
			max_generation,
			oldest_age,
			SimulationStats.births,
			SimulationStats.deaths,
			SimulationStats.food_eaten
		]
	)

	file.flush()
	SimulationStats.reset_epoch()


func _exit_tree():
	if file:
		file.flush()
