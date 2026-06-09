extends Node2D

var age_seconds := 0.0
var age_years := 0.0
var age := 0.0
@onready var sprite = $Sprite2D
var ripe_age_years := 0.5
var rotten_age_years := 1.5
var max_age_years := 2.5

func _ready():
	add_to_group("food")

func _process(delta):

	age_seconds += delta
	age_years = SimulationTime.seconds_to_years(age_seconds)
	age = age_years

	if age_years >= ripe_age_years:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(0.6, 1.0, 0.6)

	if age_years >= max_age_years:
		queue_free()
