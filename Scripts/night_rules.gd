extends Object
class_name NightRules

## Per-night gameplay tuning. Keep this file as the single place to add new nights / rules.


## Night 1: wrong forward/delete does not spawn viruses. Night 2+: it does.
static func viruses_on_wrong_disposal(night: int) -> bool:
	match clampi(night, 1, 99):
		1:
			return false
		_:
			return true


static func phone_duplicate_interval_seconds(night: int) -> float:
	match clampi(night, 1, 99):
		1:
			return 5.0
		_:
			return 5.0


## Night 3+: permanent mouse inversion virus is active for the whole shift.
static func has_inverted_mouse_virus(night: int) -> bool:
	return clampi(night, 1, 99) >= 3


## Night 3+: email text glitch virus is active for the whole shift.
static func has_email_text_glitch_virus(night: int) -> bool:
	return clampi(night, 1, 99) >= 3
