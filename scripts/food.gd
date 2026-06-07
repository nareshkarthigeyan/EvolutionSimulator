extends Node2D

var age := 0.0
@onready var sprite = $Sprite2D
var ripe_age := 5.0
var rotten_age := 15.0
var max_age := 25.0

func _ready():
	add_to_group("food")

func _process(delta):

	age += delta
	if age >= ripe_age:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(0.6, 1.0, 0.6)

	if age >= max_age:
		queue_free()
