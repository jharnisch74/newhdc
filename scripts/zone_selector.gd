# res://scripts/components/zone_selector.gd
# Component for zone filtering UI
extends PanelContainer
class_name ZoneSelector

signal zone_changed(zone_id: String)

var zone_buttons: Dictionary = {}
var current_zone: String = "all"
var chaos_display_container: HBoxContainer
var game_manager: Node

func _ready() -> void:
	_create_ui()

func setup(gm: Node) -> void:
	game_manager = gm

func _create_ui() -> void:
	var zone_style := StyleBoxFlat.new()
	zone_style.bg_color = Color("#0f1624")
	zone_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", zone_style)
	
	var zone_margin := MarginContainer.new()
	zone_margin.add_theme_constant_override("margin_left", 15)
	zone_margin.add_theme_constant_override("margin_right", 15)
	zone_margin.add_theme_constant_override("margin_top", 10)
	zone_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(zone_margin)
	
	var zone_vbox := VBoxContainer.new()
	zone_vbox.add_theme_constant_override("separation", 8)
	zone_margin.add_child(zone_vbox)
	
	var zone_title := Label.new()
	zone_title.text = "🗺️ ZONE FILTER"
	zone_title.add_theme_font_size_override("font_size", 16)
	zone_title.add_theme_color_override("font_color", Color("#00d9ff"))
	zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_vbox.add_child(zone_title)
	
	var zone_selector_container := HBoxContainer.new()
	zone_selector_container.add_theme_constant_override("separation", 8)
	zone_selector_container.alignment = BoxContainer.ALIGNMENT_CENTER
	zone_vbox.add_child(zone_selector_container)
	
	# Create zone buttons
	var zones = [
		{"id": "all", "emoji": "🌐", "name": "All", "color": Color("#4ecca3")},
		{"id": "downtown", "emoji": "🏙️", "name": "Downtown", "color": Color("#ff6b6b")},
		{"id": "industrial", "emoji": "🏭", "name": "Industrial", "color": Color("#ffd93d")},
		{"id": "residential", "emoji": "🏘️", "name": "Residential", "color": Color("#4ecca3")},
		{"id": "park", "emoji": "🌳", "name": "Park", "color": Color("#52b788")},
		{"id": "waterfront", "emoji": "🌊", "name": "Waterfront", "color": Color("#00d9ff")}
	]
	
	for zone_data in zones:
		var btn = _create_zone_button(zone_data)
		zone_selector_container.add_child(btn)
		zone_buttons[zone_data.id] = btn
	
	# Chaos displays
	chaos_display_container = HBoxContainer.new()
	chaos_display_container.name = "ChaosContainer"
	chaos_display_container.add_theme_constant_override("separation", 15)
	chaos_display_container.alignment = BoxContainer.ALIGNMENT_CENTER
	zone_vbox.add_child(chaos_display_container)
	
	for zone_id in ["downtown", "industrial", "residential", "park", "waterfront"]:
		var mini_chaos = _create_mini_chaos_display(zone_id)
		chaos_display_container.add_child(mini_chaos)

func _create_zone_button(zone_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = zone_data.emoji
	btn.custom_minimum_size = Vector2(60, 60)
	btn.add_theme_font_size_override("font_size", 28)
	btn.tooltip_text = zone_data.name
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.set_corner_radius_all(10)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = zone_data.color
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#1a2540")
	hover_style.set_corner_radius_all(10)
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = zone_data.color
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = zone_data.color.darkened(0.3)
	pressed_style.set_corner_radius_all(10)
	pressed_style.border_width_left = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = zone_data.color.lightened(0.3)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.pressed.connect(func(): _on_zone_selected(zone_data.id))
	
	return btn

func _create_mini_chaos_display(zone_id: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "ChaosDisplay_" + zone_id
	vbox.add_theme_constant_override("separation", 2)
	vbox.custom_minimum_size = Vector2(50, 0)
	
	var emoji := Label.new()
	emoji.text = _get_zone_emoji(zone_id)
	emoji.add_theme_font_size_override("font_size", 20)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji)
	
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1a1a2e")
	bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#4ecca3")
	bar.add_theme_stylebox_override("fill", fill_style)
	
	vbox.add_child(bar)
	
	var percent := Label.new()
	percent.name = "Percent"
	percent.text = "0%"
	percent.add_theme_font_size_override("font_size", 10)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(percent)
	
	return vbox

func _on_zone_selected(zone_id: String) -> void:
	print("Zone selected: %s" % zone_id)
	current_zone = zone_id
	
	# Update button visuals
	for id in zone_buttons.keys():
		var btn = zone_buttons[id]
		if id == zone_id:
			btn.modulate = Color(1.2, 1.2, 1.2)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)
	
	zone_changed.emit(zone_id)

func update_chaos_displays() -> void:
	if not game_manager or not game_manager.chaos_system or not chaos_display_container:
		return
	
	for zone_id in ["downtown", "industrial", "residential", "park", "waterfront"]:
		var display = chaos_display_container.get_node_or_null("ChaosDisplay_" + zone_id)
		if not display:
			continue
		
		var chaos_level = game_manager.chaos_system.get_chaos_level(zone_id)
		var chaos_color = game_manager.chaos_system.get_chaos_color(zone_id)
		
		var bar = display.get_node_or_null("Bar")
		var percent_label = display.get_node_or_null("Percent")
		
		if bar:
			bar.value = chaos_level
			var fill_style = bar.get_theme_stylebox("fill")
			if fill_style is StyleBoxFlat:
				fill_style.bg_color = chaos_color
		
		if percent_label:
			percent_label.text = "%.0f%%" % chaos_level
			percent_label.add_theme_color_override("font_color", chaos_color)

func _get_zone_emoji(zone: String) -> String:
	match zone:
		"downtown": return "🏙️"
		"industrial": return "🏭"
		"residential": return "🏘️"
		"park": return "🌳"
		"waterfront": return "🌊"
		_: return "📍"
