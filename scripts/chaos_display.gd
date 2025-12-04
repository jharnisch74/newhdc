# res://scripts/chaos_display.gd
# UI component to display chaos levels in each zone - NOW CLICKABLE!
extends PanelContainer

signal zone_clicked(zone_id: String)

var game_manager: Node
var zone_bars: Dictionary = {}

func _ready() -> void:
	_create_ui()

func setup(gm: Node) -> void:
	game_manager = gm
	
	if game_manager and game_manager.chaos_system:
		game_manager.chaos_system.chaos_level_changed.connect(_on_chaos_changed)
		_update_display()

func _create_ui() -> void:
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f1624")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#00d9ff")
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(280, 0)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "🔥 ZONE CHAOS LEVELS (Click to Center)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#ff6b6b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Create zone displays (now as BUTTONS)
	var zones = ["downtown", "industrial", "residential", "park", "waterfront"]
	for zone in zones:
		var zone_button = _create_zone_button(zone)
		vbox.add_child(zone_button)
		zone_bars[zone] = zone_button

func _create_zone_button(zone_name: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 65)
	
	# Normal style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#16213e")
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
	pressed_style.border_color = Color("#00d9ff")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	
	# Left side: Zone name and status
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 3)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_vbox)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = zone_name.capitalize()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(name_label)
	
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "STABLE"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color("#4ecca3"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(status_label)
	
	# Right side: Progress bar and percentage
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	right_vbox.custom_minimum_size = Vector2(110, 0)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_vbox)
	
	var percent_label := Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 13)
	percent_label.add_theme_color_override("font_color", Color("#4ecca3"))
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(percent_label)
	
	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(0, 18)
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1a1a2e")
	bg_style.set_corner_radius_all(9)
	progress.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#4ecca3")
	fill_style.set_corner_radius_all(9)
	progress.add_theme_stylebox_override("fill", fill_style)
	
	right_vbox.add_child(progress)
	
	# Connect button click to emit signal
	btn.pressed.connect(func(): 
		print("🗺️ Chaos zone clicked: %s" % zone_name)
		zone_clicked.emit(zone_name)
	)
	
	return btn

func _update_display() -> void:
	if not game_manager or not game_manager.chaos_system:
		return
	
	var chaos_info = game_manager.get_zone_chaos_info()
	
	for zone_name in zone_bars.keys():
		if not chaos_info.has(zone_name):
			continue
		
		var zone_data = chaos_info[zone_name]
		var btn = zone_bars[zone_name]
		
		# Update progress bar
		var progress: ProgressBar = btn.find_child("ProgressBar", true, false)
		if progress:
			progress.value = zone_data.level
			
			# Update color based on chaos level
			var fill_style: StyleBoxFlat = progress.get_theme_stylebox("fill")
			if fill_style:
				fill_style.bg_color = zone_data.color
		
		# Update percentage
		var percent_label: Label = btn.find_child("PercentLabel", true, false)
		if percent_label:
			percent_label.text = "%.0f%%" % zone_data.level
			percent_label.add_theme_color_override("font_color", zone_data.color)
		
		# Update status tier
		var status_label: Label = btn.find_child("StatusLabel", true, false)
		if status_label:
			status_label.text = zone_data.tier
			status_label.add_theme_color_override("font_color", zone_data.color)
		
		# Update zone name with emoji
		var name_label: Label = btn.find_child("NameLabel", true, false)
		if name_label:
			var emoji = ""
			match zone_data.tier:
				"CRITICAL":
					emoji = "🚨 "
				"HIGH":
					emoji = "💥 "
				"MEDIUM":
					emoji = "🔥 "
				"LOW":
					emoji = "⚠️ "
			name_label.text = emoji + zone_name.capitalize()

func _on_chaos_changed(_zone: String, _new_level: float) -> void:
	_update_display()

func _process(_delta: float) -> void:
	if game_manager and game_manager.chaos_system:
		_update_display()
