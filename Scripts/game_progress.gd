extends Node

signal night_changed(new_night: int)

## In-memory only: closing the game resets to day 1. Progress still advances during a single play session.

var current_night: int = 1


func get_current_night() -> int:
	return current_night


func viruses_enabled_this_night() -> bool:
	return NightRules.viruses_on_wrong_disposal(current_night)


## Call when the player finishes a shift (e.g. logs out to the end screen).
func complete_shift_end_of_day() -> void:
	current_night = mini(current_night + 1, 999)
	night_changed.emit(current_night)


## After logout, `current_night` already points at the *next* shift. Call this to replay the shift you just finished.
func replay_last_shift_instead_of_advancing() -> void:
	current_night = maxi(1, current_night - 1)
	night_changed.emit(current_night)


func reset_progress_for_debug() -> void:
	current_night = 1
	night_changed.emit(current_night)
