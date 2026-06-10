extends Node

var births := 0
var deaths := 0
var food_eaten := 0
var seeds_found := 0
var seeds_planted := 0
var total_births := 0
var total_deaths := 0
var total_food_eaten := 0
var total_seeds_found := 0
var total_seeds_planted := 0
var next_lineage_id := 1


func reset_epoch():
	births = 0
	deaths = 0
	food_eaten = 0
	seeds_found = 0
	seeds_planted = 0


func claim_lineage_id() -> int:
	var id = next_lineage_id
	next_lineage_id += 1
	return id


func record_birth():
	births += 1
	total_births += 1


func record_death():
	deaths += 1
	total_deaths += 1


func record_food_eaten():
	food_eaten += 1
	total_food_eaten += 1


func record_seed_found():
	seeds_found += 1
	total_seeds_found += 1


func record_seed_planted():
	seeds_planted += 1
	total_seeds_planted += 1
