# res://scripts/components/mission_card.gd
# Component for the swipeable mission card
extends PanelContainer
class_name MissionCard

signal swiped_left()
signal swiped_right()
signal card_tapped()

var mission_emoji: Label
var mission_name: Label
var mission_zone: Label
var mission_difficulty: Label
var mission_rewards: Label
var mission_duration: Label
var best_hero_display: VBoxContainer

# Swipe detection
var swipe_start_pos: Vector2
var is_swiping: bool = false
const SWIPE_THRESHOLD = 100.0

func _ready() -> void:
	_create_ui()
	gui_input.connect(_on_card_input)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _create_ui() -> void:
	custom_minimum_size = Vector2(350, 500)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.set_corner_radius_all(25)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color("#00d9ff")
	add_theme_stylebox_override("panel", style)
	
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 30)
	card_margin.add_theme_constant_override("margin_right", 30)
	card_margin.add_theme_constant_override("margin_top", 30)
	card_margin.add_theme_constant_override("margin_bottom", 30)
	add_child(card_margin)
	
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 15)
	card_margin.add_child(card_vbox)
	
	# Mission emoji (huge!)
	mission_emoji = Label.new()
	mission_emoji.text = "🚨"
	mission_emoji.add_theme_font_size_override("font_size", 120)
	mission_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(mission_emoji)
	
	# Mission name
	mission_name = Label.new()
	mission_name.text = "Bank Robbery"
	mission_name.add_theme_font_size_override("font_size", 28)
	mission_name.add_theme_color_override("font_color", Color("#00d9ff"))
	mission_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(mission_name)
	
	# Zone + Difficulty
	var zone_diff := HBoxContainer.new()
	zone_diff.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_child(zone_diff)
	
	mission_zone = Label.new()
	mission_zone.text = "🏙️ Downtown"
	mission_zone.add_theme_font_size_override("font_size", 18)
	zone_diff.add_child(mission_zone)
	
	var sep := Label.new()
	sep.text = " | "
	sep.add_theme_font_size_override("font_size", 18)
	zone_diff.add_child(sep)
	
	mission_difficulty = Label.new()
	mission_difficulty.text = "⭐⭐ Medium"
	mission_difficulty.add_theme_font_size_override("font_size", 18)
	zone_diff.add_child(mission_difficulty)
	
	card_vbox.add_child(HSeparator.new())
	
	# Duration
	mission_duration = Label.new()
	mission_duration.text = "⏱️ 30 seconds"
	mission_duration.add_theme_font_size_override("font_size", 20)
	mission_duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(mission_duration)
	
	# Rewards
	mission_rewards = Label.new()
	mission_rewards.text = "💰 $150  |  ⭐ 10 Fame"
	mission_rewards.add_theme_font_size_override("font_size", 22)
	mission_rewards.add_theme_color_override("font_color", Color("#4ecca3"))
	mission_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(mission_rewards)
	
	card_vbox.add_child(HSeparator.new())
	
	# Best hero display
	best_hero_display = VBoxContainer.new()
	best_hero_display.add_theme_constant_override("separation", 5)
	card_vbox.add_child(best_hero_display)
	
	var hero_label := Label.new()
	hero_label.text = "🎯 Recommended Hero:"
	hero_label.add_theme_font_size_override("font_size", 14)
	hero_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_hero_display.add_child(hero_label)
	
	var hero_name_label := Label.new()
	hero_name_label.name = "HeroName"
	hero_name_label.text = "🦸 Captain Justice"
	hero_name_label.add_theme_font_size_override("font_size", 18)
	hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_hero_display.add_child(hero_name_label)
	
	var choose_label := Label.new()
	choose_label.text = "(Tap to choose different hero)"
	choose_label.add_theme_font_size_override("font_size", 12)
	choose_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	choose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_hero_display.add_child(choose_label)
	
	# Swipe hint
	var hint := Label.new()
	hint.text = "⬅️ Swipe Left = Decline  |  Swipe Right = Select Hero ➡️"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(hint)

func update_mission(mission: Mission, best_hero: Hero = null) -> void:
	if not mission:
		mission_name.text = "No missions available"
		return
	
	mission_emoji.text = mission.mission_emoji
	mission_name.text = mission.mission_name
	mission_zone.text = _get_zone_emoji(mission.zone) + " " + mission.zone.capitalize()
	mission_difficulty.text = mission.get_difficulty_string()
	mission_difficulty.add_theme_color_override("font_color", mission.get_difficulty_color())
	mission_duration.text = "⏱️ %.0f seconds" % mission.base_duration
	mission_rewards.text = "💰 $%d  |  ⭐ %d Fame" % [mission.money_reward, mission.fame_reward]
	
	if best_hero:
		var hero_name_label = best_hero_display.get_node("HeroName")
		hero_name_label.text = best_hero.hero_emoji + " " + best_hero.hero_name
		best_hero_display.visible = true
	else:
		best_hero_display.visible = false

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			swipe_start_pos = event.position
			is_swiping = true
		elif not event.pressed and is_swiping:
			var swipe_distance = event.position - swipe_start_pos
			is_swiping = false
			
			if swipe_distance.x > SWIPE_THRESHOLD:
				# Swipe right = open hero selection
				swiped_right.emit()
			elif swipe_distance.x < -SWIPE_THRESHOLD:
				# Swipe left = decline
				swiped_left.emit()
			elif swipe_distance.length() < 20:
				# Short tap
				card_tapped.emit()

func _get_zone_emoji(zone: String) -> String:
	match zone:
		"downtown": return "🏙️"
		"industrial": return "🏭"
		"residential": return "🏘️"
		"park": return "🌳"
		"waterfront": return "🌊"
		_: return "📍"
