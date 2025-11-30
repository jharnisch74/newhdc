# res://data/mission_data.gd
# Load mission templates from JSON file
extends RefCounted
class_name MissionData

const MISSION_DATA_PATH = "res://data/mission_templates.json"

static func get_mission_templates() -> Array:
	var data = _load_json()
	if not data:
		return _get_fallback_missions()
	
	var templates = []
	for mission_dict in data.get("missions", []):
		templates.append(_parse_mission_dict(mission_dict))
	
	return templates

static func _load_json() -> Dictionary:
	if not FileAccess.file_exists(MISSION_DATA_PATH):
		push_error("Mission data file not found: " + MISSION_DATA_PATH)
		return {}
	
	var file = FileAccess.open(MISSION_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open mission data file")
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse mission JSON: " + json.get_error_message())
		return {}
	
	return json.data

static func _parse_mission_dict(mission_dict: Dictionary) -> Dictionary:
	var result = {
		"name": mission_dict.get("name", "Unknown Mission"),
		"emoji": mission_dict.get("emoji", "❓"),
		"description": mission_dict.get("description", "No description"),
		"zone": mission_dict.get("zone", "downtown"),
		"specialties": []
	}
	
	# Parse difficulty
	var diff_str = mission_dict.get("difficulty", "EASY")
	match diff_str:
		"EASY":
			result["difficulty"] = Mission.Difficulty.EASY
		"MEDIUM":
			result["difficulty"] = Mission.Difficulty.MEDIUM
		"HARD":
			result["difficulty"] = Mission.Difficulty.HARD
		"EXTREME":
			result["difficulty"] = Mission.Difficulty.EXTREME
		_:
			result["difficulty"] = Mission.Difficulty.EASY
	
	# Parse specialties
	for spec_str in mission_dict.get("specialties", []):
		match spec_str:
			"COMBAT":
				result.specialties.append(Hero.Specialty.COMBAT)
			"SPEED":
				result.specialties.append(Hero.Specialty.SPEED)
			"TECH":
				result.specialties.append(Hero.Specialty.TECH)
			"RESCUE":
				result.specialties.append(Hero.Specialty.RESCUE)
			"INVESTIGATION":
				result.specialties.append(Hero.Specialty.INVESTIGATION)
	
	return result

static func _get_fallback_missions() -> Array:
	"""Fallback if JSON fails to load"""
	return [
		{
			"name": "Bank Robbery",
			"emoji": "🏦",
			"description": "Stop criminals robbing the city bank",
			"difficulty": Mission.Difficulty.MEDIUM,
			"specialties": [Hero.Specialty.COMBAT, Hero.Specialty.SPEED],
			"zone": "downtown"
		},
		{
			"name": "Fire Rescue",
			"emoji": "🔥",
			"description": "Save people from a burning building",
			"difficulty": Mission.Difficulty.MEDIUM,
			"specialties": [Hero.Specialty.RESCUE, Hero.Specialty.SPEED],
			"zone": "residential"
		}
	]

static func get_success_story(mission_name: String, hero_names: String, success: bool, money: int, fame: int) -> String:
	"""Generate mission completion story - kept in code for easy formatting"""
	var stories = {
		"Cat Rescue": {
			"success": "✅ %s successfully rescued the cat from the tree! The grateful owner rewarded them. (+$%d 💰 +%d ⭐)",
			"failure": "❌ The cat escaped to another tree... %s tried their best. (Partial: +$%d 💰 +%d ⭐)"
		},
		"Bank Robbery": {
			"success": "✅ %s stopped the bank robbery! The criminals have been apprehended and the money secured. (+$%d 💰 +%d ⭐)",
			"failure": "❌ The robbers escaped with some cash, but %s prevented greater losses. (Partial: +$%d 💰 +%d ⭐)"
		},
		"Hostage Crisis": {
			"success": "✅ %s rescued all hostages safely! The building was secured without casualties. (+$%d 💰 +%d ⭐)",
			"failure": "❌ Some hostages were injured during the rescue. %s did what they could. (Partial: +$%d 💰 +%d ⭐)"
		},
		"Fire Rescue": {
			"success": "✅ %s evacuated the building and extinguished the flames! Everyone made it out safely. (+$%d 💰 +%d ⭐)",
			"failure": "❌ The fire spread faster than expected. %s saved most people but some were injured. (Partial: +$%d 💰 +%d ⭐)"
		}
		# Add more as needed...
	}
	
	var story_key = "success" if success else "failure"
	if stories.has(mission_name) and stories[mission_name].has(story_key):
		return stories[mission_name][story_key] % [hero_names, money, fame]
	else:
		if success:
			return "✅ SUCCESS! %s completed %s! (+$%d 💰 +%d ⭐)" % [hero_names, mission_name, money, fame]
		else:
			return "❌ FAILED! %s couldn't complete %s. (Partial: +$%d 💰 +%d ⭐)" % [hero_names, mission_name, money, fame]
