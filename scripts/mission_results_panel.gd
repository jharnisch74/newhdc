extends Control

var game_manager: Node
var results_vbox: VBoxContainer
var scroll: ScrollContainer

func _ready() -> void:
	_create_ui()

func setup(gm: Node) -> void:
	game_manager = gm

func _create_ui() -> void:
	# Panel Style (for the background of the results area)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1e2a44")
	style.border_width_left = 3
	style.border_color = Color("#00d9ff")
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 10)
	panel.add_child(margin)
	
	var vbox_main = VBoxContainer.new()
	margin.add_child(vbox_main)
	
	# Header
	var header_label = Label.new()
	header_label.text = "🚨 MISSION LOG"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.add_theme_color_override("font_color", Color("#ffd700"))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_main.add_child(header_label)
	
	vbox_main.add_child(HSeparator.new())
	
	# Scroll Container for Results
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_main.add_child(scroll)
	
	results_vbox = VBoxContainer.new()
	results_vbox.add_theme_constant_override("separation", 10)
	results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(results_vbox)

# Called when game_manager.mission_completed signal is emitted
# Inside mission_results_panel.gd

# Called when game_manager.mission_completed signal is emitted
# Inside mission_results_panel.gd

# Called when game_manager.mission_completed signal is emitted
func _on_mission_completed(mission: Mission, success: bool, hero: Hero) -> void:
	var result_panel = _create_result_entry(mission, success, hero)
	
	# Add the newest result to the top
	results_vbox.add_child(result_panel)
	results_vbox.move_child(result_panel, 0)
	
	# 🚨 CRITICAL FIX: Use await get_tree().process_frame for deferral 🚨
	# This ensures the new child is added to the UI tree before we try to scroll.
	await get_tree().process_frame
	
	# Scroll to the top to show the new result
	if is_instance_valid(scroll) and scroll.get_v_scroll_bar():
		scroll.get_v_scroll_bar().value = 0

func _create_result_entry(mission: Mission, success: bool, hero: Hero) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	
	var result_color: Color
	var result_text: String
	
	if success:
		result_color = Color("#4ecca3") # Green for Success
		result_text = "SUCCESS"
		style.bg_color = Color("#4ecca3").darkened(0.8)
		style.border_color = result_color
	else:
		result_color = Color("#ff6b6b") # Red for Failure
		result_text = "FAILURE"
		style.bg_color = Color("#ff6b6b").darkened(0.7)
		style.border_color = result_color
	
	style.border_width_left = 5
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 5)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# 1. Mission Title & Result
	var hbox_header = HBoxContainer.new()
	
	var title_label = Label.new()
	title_label.text = "%s %s" % [mission.mission_emoji, mission.mission_name]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(title_label)
	
	var result_label = Label.new()
	result_label.text = result_text
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.add_theme_color_override("font_color", result_color)
	hbox_header.add_child(result_label)
	
	vbox.add_child(hbox_header)
	
	# 2. Hero and Rewards
	var detail_label = Label.new()
	var reward_icon = "💰"
	if mission.money_reward == 0:
		reward_icon = "⭐"
	
	detail_label.text = "Hero: %s | %s %s" % [hero.hero_name, reward_icon, str(mission.money_reward + mission.fame_reward)]
	detail_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	vbox.add_child(detail_label)
	
	return panel
