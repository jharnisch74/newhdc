# res://data/hero_data.gd
# Load hero templates from JSON file
extends RefCounted
class_name HeroData

const HERO_DATA_PATH = "res://data/hero_templates.json"

static func get_starting_heroes() -> Array:
	var data = _load_json()
	if not data:
		return _get_fallback_starting_heroes()
	
	var heroes = []
	for hero_dict in data.get("starting_heroes", []):
		heroes.append(_parse_hero_dict(hero_dict))
	
	return heroes

static func get_hero_pool() -> Array:
	var data = _load_json()
	if not data:
		return []
	
	var pool = []
	var recruitable = data.get("recruitable_heroes", {})
	
	# Add common heroes
	for hero_dict in recruitable.get("common", []):
		var hero_data = _parse_hero_dict(hero_dict)
		hero_data["rarity"] = RecruitmentSystem.Rarity.COMMON
		pool.append(hero_data)
	
	# Add rare heroes
	for hero_dict in recruitable.get("rare", []):
		var hero_data = _parse_hero_dict(hero_dict)
		hero_data["rarity"] = RecruitmentSystem.Rarity.RARE
		pool.append(hero_data)
	
	# Add epic heroes
	for hero_dict in recruitable.get("epic", []):
		var hero_data = _parse_hero_dict(hero_dict)
		hero_data["rarity"] = RecruitmentSystem.Rarity.EPIC
		pool.append(hero_data)
	
	# Add legendary heroes
	for hero_dict in recruitable.get("legendary", []):
		var hero_data = _parse_hero_dict(hero_dict)
		hero_data["rarity"] = RecruitmentSystem.Rarity.LEGENDARY
		pool.append(hero_data)
	
	return pool

static func _load_json() -> Dictionary:
	if not FileAccess.file_exists(HERO_DATA_PATH):
		push_error("Hero data file not found: " + HERO_DATA_PATH)
		return {}
	
	var file = FileAccess.open(HERO_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open hero data file")
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse hero JSON: " + json.get_error_message())
		return {}
	
	return json.data

static func _parse_hero_dict(hero_dict: Dictionary) -> Dictionary:
	var result = {
		"name": hero_dict.get("name", "Unknown"),
		"emoji": hero_dict.get("emoji", "❓"),
		"specialties": []
	}
	
	# Convert specialty strings to enums
	for spec_str in hero_dict.get("specialties", []):
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

static func _get_fallback_starting_heroes() -> Array:
	"""Fallback if JSON fails to load"""
	return [
		{
			"name": "Captain Thunder",
			"emoji": "⚡",
			"specialties": [Hero.Specialty.COMBAT, Hero.Specialty.SPEED]
		},
		{
			"name": "Shadow Strike",
			"emoji": "🥷",
			"specialties": [Hero.Specialty.SPEED, Hero.Specialty.INVESTIGATION]
		},
		{
			"name": "Tech Wizard",
			"emoji": "🧙",
			"specialties": [Hero.Specialty.TECH, Hero.Specialty.INVESTIGATION]
		}
	]
