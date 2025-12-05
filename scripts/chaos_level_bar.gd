# res://scripts/chaos_level_bar.gd
# Compact horizontal chaos display for all zones - NOW CLICKABLE!
extends PanelContainer
class_name ChaosLevelBar

signal zone_clicked(zone_id: String)

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
	title.text = "🔥 ZONE CHAOS LEVELS (Click to Center Map)"
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
		var zone_button = _create_zone_button(zone)
		zones_container.add_child(zone_button)
		zone_displays[zone.id] = zone_button

func _create_zone_button(zone_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 65)
	
	# Normal style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#0f1624")
	btn_style.set_corner_radius_all(8)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color("#2a3a5e")
	btn.add_theme_stylebox_override("normal", btn_style)
	
	# Hover style
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#1a2540")
	hover_style.set_corner_radius_all(8)
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color("#00d9ff")
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color("#0d1a30")
	pressed_style.set_corner_radius_all(8)
	pressed_style.border_width_left = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = Color("#4ecca3")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	
	var container := VBoxContainer.new()
	container.name = "Container"
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(container)
	
	# Zone header (emoji + name)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(header)
	
	var emoji := Label.new()
	emoji.text = zone_data.emoji
	emoji.add_theme_font_size_override("font_size", 20)
	emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(emoji)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = zone_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_label)
	
	# Progress bar
	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(0, 20)
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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
	status_row.name = "StatusRow"
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 5)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(status_row)
	
	var percent_label := Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", Color("#4ecca3"))
	percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(percent_label)
	
	var separator := Label.new()
	separator.text = "•"
	separator.add_theme_font_size_override("font_size", 12)
	separator.add_theme_color_override("font_color", Color("#666666"))
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(separator)
	
	var tier_label := Label.new()
	tier_label.name = "TierLabel"
	tier_label.text = "STABLE"
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color("#4ecca3"))
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(tier_label)
	
	# Connect button click to emit signal
	btn.pressed.connect(func(): 
		print("========================================")
		print("🗺️ CHAOS BAR: Button pressed for zone: %s" % zone_data.id)
		print("   Signal exists: %s" % has_signal("zone_clicked"))
		print("   Emitting zone_clicked signal...")
		zone_clicked.emit(zone_data.id)
		print("   Signal emitted!")
		print("========================================")
	)
	
	return btn

func _update_display() -> void:
	if not game_manager:
		print("⚠️ CHAOS BAR: game_manager is null")
		return
	
	if not game_manager.chaos_system:
		print("⚠️ CHAOS BAR: chaos_system is null")
		return
	
	var chaos_info = game_manager.get_zone_chaos_info()
	
	if chaos_info.is_empty():
		print("⚠️ CHAOS BAR: chaos_info is empty!")
		return
	
	# Debug: Print chaos levels every 5 seconds
	if Engine.get_process_frames() % 300 == 0:
		print("📊 CHAOS BAR UPDATE:")
		for zone_id in chaos_info.keys():
			var data = chaos_info[zone_id]
			print("   %s: %.1f%% (%s)" % [zone_id.capitalize(), data.level, data.tier])
	
	for zone_id in zone_displays.keys():
		if not chaos_info.has(zone_id):
			print("⚠️ CHAOS BAR: No chaos info for zone: %s" % zone_id)
			continue
		
		var zone_data = chaos_info[zone_id]
		var btn = zone_displays[zone_id]
		
		if not is_instance_valid(btn):
			print("⚠️ CHAOS BAR: Invalid button for zone: %s" % zone_id)
			continue
		
		# Get container
		var container = btn.get_node_or_null("MarginContainer/Container")
		if not container:
			print("⚠️ CHAOS BAR: Container not found for zone: %s" % zone_id)
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
		else:
			print("⚠️ CHAOS BAR: ProgressBar not found for zone: %s" % zone_id)
		
		# Get status row
		var status_row = container.get_node_or_null("StatusRow")
		if status_row:
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
		else:
			print("⚠️ CHAOS BAR: StatusRow not found for zone: %s" % zone_id)
		
		# Get header
		var header = container.get_node_or_null("Header")
		if header:
			# Update name color if critical
			var name_label: Label = header.get_node_or_null("NameLabel")
			if name_label:
				if zone_data.tier == "CRITICAL":
					name_label.add_theme_color_override("font_color", Color("#ff3838"))
				else:
					name_label.add_theme_color_override("font_color", Color("#a8a8a8"))
		else:
			print("⚠️ CHAOS BAR: Header not found for zone: %s" % zone_id)

func _on_chaos_changed(_zone: String, _new_level: float) -> void:
	_update_display()

func _process(_delta: float) -> void:
	# Update display less frequently to reduce performance overhead
	if game_manager and game_manager.chaos_system:
		# Update every 10 frames instead of every frame
		if Engine.get_process_frames() % 10 == 0:
			_update_display()
