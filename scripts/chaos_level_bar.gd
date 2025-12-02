# res://scripts/chaos_level_bar.gd
# Compact horizontal chaos display for all zones
extends PanelContainer
class_name ChaosLevelBar

var game_manager: Node
var zone_displays: Dictionary = {}

func _ready() -> void:
	_create_ui()

func setup(gm: Node) -> void:
	game_manager = gm
	
	if game_manager and game_manager.chaos_system:
		game_manager.chaos_system.chaos_level_changed.connect(_on_chaos_changed)
		_update_display()

func _create_ui() -> void:
	# Panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.bg_color.a = 0.95
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#00d9ff")
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(0, 80)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "🔥 ZONE CHAOS LEVELS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#ff6b6b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Horizontal container for all zones
	var zones_container := HBoxContainer.new()
	zones_container.add_theme_constant_override("separation", 15)
	zones_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(zones_container)
	
	# Create displays for each zone
	var zones = [
		{"id": "downtown", "emoji": "🏙️", "name": "Downtown"},
		{"id": "industrial", "emoji": "🏭", "name": "Industrial"},
		{"id": "residential", "emoji": "🏘️", "name": "Residential"},
		{"id": "park", "emoji": "🌳", "name": "Park"},
		{"id": "waterfront", "emoji": "🌊", "name": "Waterfront"}
	]
	
	for zone in zones:
		var zone_display = _create_zone_display(zone)
		zones_container.add_child(zone_display)
		zone_displays[zone.id] = zone_display

func _create_zone_display(zone_data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.custom_minimum_size = Vector2(120, 0)
	
	# Zone header (emoji + name)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(header)
	
	var emoji := Label.new()
	emoji.text = zone_data.emoji
	emoji.add_theme_font_size_override("font_size", 20)
	header.add_child(emoji)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = zone_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	header.add_child(name_label)
	
	# Progress bar
	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(0, 20)
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1a1a2e")
	bg_style.set_corner_radius_all(10)
	progress.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#4ecca3")
	fill_style.set_corner_radius_all(10)
	progress.add_theme_stylebox_override("fill", fill_style)
	
	container.add_child(progress)
	
	# Status row (percentage + tier)
	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 5)
	container.add_child(status_row)
	
	var percent_label := Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", Color("#4ecca3"))
	status_row.add_child(percent_label)
	
	var separator := Label.new()
	separator.text = "•"
	separator.add_theme_font_size_override("font_size", 12)
	separator.add_theme_color_override("font_color", Color("#666666"))
	status_row.add_child(separator)
	
	var tier_label := Label.new()
	tier_label.name = "TierLabel"
	tier_label.text = "STABLE"
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color("#4ecca3"))
	status_row.add_child(tier_label)
	
	return container

func _update_display() -> void:
	if not game_manager or not game_manager.chaos_system:
		return
	
	var chaos_info = game_manager.get_zone_chaos_info()
	
	for zone_id in zone_displays.keys():
		if not chaos_info.has(zone_id):
			continue
		
		var zone_data = chaos_info[zone_id]
		var container = zone_displays[zone_id]
		
		if not is_instance_valid(container):
			continue
		
		# Update progress bar
		var progress: ProgressBar = container.get_node_or_null("ProgressBar")
		if progress:
			progress.value = zone_data.level
			
			# Create a new StyleBoxFlat for the fill to force update
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = zone_data.color
			fill_style.set_corner_radius_all(10)
			progress.add_theme_stylebox_override("fill", fill_style)
		
		# Get all HBoxContainers (there should be two - header and status)
		var hbox_containers = []
		for child in container.get_children():
			if child is HBoxContainer:
				hbox_containers.append(child)
		
		# The second HBoxContainer should be the status row
		if hbox_containers.size() >= 2:
			var status_row = hbox_containers[1]
			
			# Update percentage
			var percent_label: Label = status_row.get_node_or_null("PercentLabel")
			if percent_label:
				percent_label.text = "%.0f%%" % zone_data.level
				percent_label.add_theme_color_override("font_color", zone_data.color)
			
			# Update tier
			var tier_label: Label = status_row.get_node_or_null("TierLabel")
			if tier_label:
				tier_label.text = zone_data.tier
				tier_label.add_theme_color_override("font_color", zone_data.color)
		
		# Update name color if critical (first HBoxContainer is header)
		if hbox_containers.size() >= 1:
			var header_row = hbox_containers[0]
			var name_label: Label = header_row.get_node_or_null("NameLabel")
			if name_label:
				if zone_data.tier == "CRITICAL":
					name_label.add_theme_color_override("font_color", Color("#ff3838"))
				else:
					name_label.add_theme_color_override("font_color", Color("#a8a8a8"))

func _on_chaos_changed(_zone: String, _new_level: float) -> void:
	_update_display()

func _process(_delta: float) -> void:
	# Update display less frequently to reduce performance overhead
	if game_manager and game_manager.chaos_system:
		# Update every 10 frames instead of every frame
		if Engine.get_process_frames() % 10 == 0:
			_update_display()

# Debug method to verify chaos levels
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_debug_print_chaos_levels()

func _debug_print_chaos_levels() -> void:
	if not game_manager or not game_manager.chaos_system:
		print("No chaos system available")
		return
	
	print("\n=== CHAOS LEVELS ===")
	for zone in ["downtown", "industrial", "residential", "park", "waterfront"]:
		var level = game_manager.chaos_system.get_chaos_level(zone)
		var tier = game_manager.chaos_system.get_chaos_tier(zone)
		print("%s: %.1f%% (%s)" % [zone.capitalize(), level, tier])
	print("===================\n")
