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
		"epoch,year,population,food,bushes,water,avg_generation,max_generation,avg_memory,avg_speed,avg_vision,avg_age,avg_hunger,avg_thirst,oldest_age,oldest_bush_age,births,deaths,food_eaten,seeds_found,seeds_planted,seeds_held"
	)

	print("Logging to:", filename)
	file.flush()


func _process(delta):
	timer += delta
	if timer < 0.5:
		return

	timer = 0.0
	epoch += 1

	log_epoch()


func log_epoch():
	if file == null:
		return

	var creatures = get_tree().get_nodes_in_group("creature")
	var bushes = get_tree().get_nodes_in_group("bush")

	var population = creatures.size()
	var food_count = get_tree().get_nodes_in_group("food").size()
	var bush_count = bushes.size()
	var water_count = get_tree().get_nodes_in_group("water").size()

	var avg_speed = 0.0
	var avg_vision = 0.0
	var avg_generation = 0.0
	var avg_memory = 0.0
	var avg_age = 0.0
	var avg_hunger = 0.0
	var avg_thirst = 0.0
	var max_generation = 0
	var oldest_age = 0.0
	var oldest_bush_age = 0.0
	var seeds_held = 0

	for creature in creatures:
		avg_speed += creature.speed
		avg_vision += creature.vision_radius
		avg_generation += creature.generation
		avg_memory += creature.memory
		avg_age += creature.age_years
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
		avg_generation /= population
		avg_memory /= population
		avg_age /= population
		avg_hunger /= population
		avg_thirst /= population

	file.store_line(
		"%d,%.2f,%d,%d,%d,%d,%.2f,%d,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%d,%d"
		% [
			epoch,
			SimulationTime.elapsed_years(),
			population,
			food_count,
			bush_count,
			water_count,
			avg_generation,
			max_generation,
			avg_memory,
			avg_speed,
			avg_vision,
			avg_age,
			avg_hunger,
			avg_thirst,
			oldest_age,
			oldest_bush_age,
			SimulationStats.births,
			SimulationStats.deaths,
			SimulationStats.food_eaten,
			SimulationStats.seeds_found,
			SimulationStats.seeds_planted,
			seeds_held
		]
	)

	file.flush()
	SimulationStats.reset_epoch()


func _exit_tree():
	if file:
		file.flush()
