extends Node

const SECONDS_PER_YEAR := 10.0

var elapsed_seconds := 0.0


func reset():
	elapsed_seconds = 0.0


func _process(delta):
	elapsed_seconds += delta


func elapsed_years() -> float:
	return seconds_to_years(elapsed_seconds)


func seconds_to_years(seconds: float) -> float:
	return seconds / SECONDS_PER_YEAR


func years_to_seconds(years: float) -> float:
	return years * SECONDS_PER_YEAR
