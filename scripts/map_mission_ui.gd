# res://scripts/map_mission_ui.gd
# Map-based mission interface with pan, zoom, and mission icons
extends Control

var rapid_manager: RapidResponseManager
var game_manager: Node

# Map state
var zoom: float = 1.0
var is_panning: bool = false
var drag_start_mouse_pos: Vector2
var drag_start_map_pos: Vector2

# Constants
const MIN_ZOOM = 0.5
const MAX_ZOOM = 3.0
const ZOOM_STEP = 0.1

# UI References
var map_viewport: Control
var map_container: Control
var mission_icons: Dictionary = {}
var zone_labels: Dictionary = {}
var selected_mission: Mission = null
var mission_detail_panel: PanelContainer
var hero_selection_container: VBoxContainer
var zoom_label: Label 
var selected_hero: Hero = null

# Zone data
var zones = {
	"downtown": { "name": "Downtown", "emoji": "🏙️", "rect": Rect2(0, 0, 50, 50), "label_pos": Vector2(25, 25), "color": Color("#ff6b6b") },
	"industrial": { "name": "Industrial", "emoji": "🏭", "rect": Rect2(50, 0, 50, 50), "label_pos": Vector2(75, 25), "color": Color("#ffd93d") },
	"residential": { "name": "Residential", "emoji": "🏘️", "rect": Rect2(0, 50, 100, 25), "label_pos": Vector2(50, 62.5), "color": Color("#4ecca3") },
	"park": { "name": "Park", "emoji": "🌳", "rect": Rect2(0, 75, 40, 25), "label_pos": Vector2(20, 87.5), "color": Color("#52b788") },
	"waterfront": { "name": "Waterfront", "emoji": "🌊", "rect": Rect2(40, 75, 60, 25), "label_pos": Vector2(70, 87.5), "color": Color("#00d9ff") }
}

func _ready() -> void:
	_create_ui()

func setup(rm: RapidResponseManager, gm: Node) -> void:
	rapid_manager = rm
	game_manager = gm
	
	if rapid_manager and rapid_manager.is_connected("mission_accepted", _on_mission_accepted):
		rapid_manager.mission_accepted.connect(_on_mission_accepted)
	if rapid_manager and rapid_manager.is_connected("mission_declined", _on_mission_declined):
		rapid_manager.mission_declined.connect(_on_mission_declined)
	
	_spawn_mission_icons()

# --- INPUT HANDLING (PAN & ZOOM) ---

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_panning = true
				drag_start_mouse_pos = event.global_position
				drag_start_map_pos = map_container.position
			else:
				is_panning = false
		
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_point(event.position, ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_point(event.position, -ZOOM_STEP)
	
	elif event is InputEventMouseMotion and is_panning:
		var diff = event.global_position - drag_start_mouse_pos
		map_container.position = drag_start_map_pos + diff
		_clamp_map_position()

func _zoom_at_point(pivot: Vector2, zoom_change: float) -> void:
	var old_zoom = zoom
	var new_zoom = clamp(zoom + zoom_change, MIN_ZOOM, MAX_ZOOM)
	
	if old_zoom == new_zoom:
		return
	
	zoom = new_zoom
	
	var mouse_offset_from_map_origin = pivot - map_container.position
	var scale_factor = new_zoom / old_zoom
	
	map_container.scale = Vector2(zoom, zoom)
	map_container.position = pivot - (mouse_offset_from_map_origin * scale_factor)
	
	_clamp_map_position()
	_update_zoom_label()

func _clamp_map_position() -> void:
	var viewport_size = map_viewport.size
	var map_size_scaled = map_container.custom_minimum_size * zoom
	
	var max_x = max(0.0, (viewport_size.x - map_size_scaled.x) / 2.0)
	var max_y = max(0.0, (viewport_size.y - map_size_scaled.y) / 2.0)
	
	var min_x = min(0.0, viewport_size.x - map_size_scaled.x)
	var min_y = min(0.0, viewport_size.y - map_size_scaled.y)
	
	map_container.position.x = clamp(map_container.position.x, min_x, max_x)
	map_container.position.y = clamp(map_container.position.y, min_y, max_y)

func _zoom_in() -> void:
	if map_viewport:
		var center = map_viewport.size / 2
		_zoom_at_point(center, ZOOM_STEP)

func _zoom_out() -> void:
	if map_viewport:
		var center = map_viewport.size / 2
		_zoom_at_point(center, -ZOOM_STEP)

func _update_zoom_label() -> void:
	if zoom_label:
		zoom_label.text = "%.0f%%" % (zoom * 100)

func _center_on_zone(zone_id: String) -> void:
	if not zones.has(zone_id):
		return
	
	var zone_data = zones[zone_id]
	var zone_rect = zone_data.rect
	
	var zone_center_percent = Vector2(
		zone_rect.position.x + zone_rect.size.x / 2.0,
		zone_rect.position.y + zone_rect.size.y / 2.0
	)
	var zone_center_pos = _percent_to_position(zone_center_percent)
	
	var viewport_center = map_viewport.size / 2.0
	var target_map_pos = viewport_center - (zone_center_pos * zoom)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(map_container, "position", target_map_pos, 0.5)
	tween.tween_callback(_clamp_map_position)

func _center_map() -> void:
	var viewport_size = map_viewport.size
	var content_size = map_container.custom_minimum_size
	map_container.position = (viewport_size - content_size) / 2
	_clamp_map_position()

func _percent_to_position(percent: Vector2) -> Vector2:
	return Vector2(
		map_container.custom_minimum_size.x * (percent.x / 100.0),
		map_container.custom_minimum_size.y * (percent.y / 100.0)
	)
	
# Part 2: UI Creation Functions

func _create_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	
	map_viewport = Control.new()
	map_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_viewport.clip_contents = true 
	map_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(map_viewport)
	
	map_container = Control.new()
	map_container.custom_minimum_size = Vector2(1440, 2560) 
	map_container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_viewport.add_child(map_container)
	
	var bg := ColorRect.new()
	bg.color = Color("#0f1624")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	map_container.add_child(bg)
	
	_create_grid_pattern()
	_create_zone_halos()
	_create_zone_labels()
	_create_zoom_controls()
	_create_mission_detail_panel()
	
	map_viewport.gui_input.connect(_on_map_input)
	call_deferred("_center_map")

func _create_grid_pattern() -> void:
	var grid := Control.new()
	grid.set_anchors_preset(PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.add_child(grid)
	
	grid.draw.connect(func():
		var grid_size = 50
		var color = Color(0.4, 0.7, 1.0, 0.1)
		var size_x = map_container.custom_minimum_size.x
		var size_y = map_container.custom_minimum_size.y
		
		for x in range(0, int(size_x), grid_size):
			grid.draw_line(Vector2(x, 0), Vector2(x, size_y), color, 1.0)
		
		for y in range(0, int(size_y), grid_size):
			grid.draw_line(Vector2(0, y), Vector2(size_x, y), color, 1.0)
	)

func _create_zone_halos() -> void:
	for zone_id in zones.keys():
		var zone_data = zones[zone_id]
		var rect = zone_data.rect
		
		var zone_rect := ColorRect.new()
		zone_rect.color = zone_data.color
		zone_rect.color.a = 0.2
		zone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var map_w = map_container.custom_minimum_size.x
		var map_h = map_container.custom_minimum_size.y
		
		var pos = Vector2(map_w * (rect.position.x / 100.0), map_h * (rect.position.y / 100.0))
		var size = Vector2(map_w * (rect.size.x / 100.0), map_h * (rect.size.y / 100.0))
		
		zone_rect.position = pos
		zone_rect.custom_minimum_size = size
		zone_rect.size = size
		
		map_container.add_child(zone_rect)
		
		var border := Control.new()
		border.position = pos
		border.custom_minimum_size = size
		border.size = size
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_container.add_child(border)
		
		border.draw.connect(func():
			var border_color = zone_data.color
			border_color.a = 0.6
			border.draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 3.0)
		)

func _create_zone_labels() -> void:
	for zone_id in zones.keys():
		var zone_data = zones[zone_id]
		var label_pos = _percent_to_position(zone_data.label_pos)
		
		var label_button := Button.new()
		label_button.custom_minimum_size = Vector2(160, 80)
		label_button.position = label_pos - Vector2(80, 40)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#16213e")
		style.bg_color.a = 0.9
		style.set_corner_radius_all(10)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = zone_data.color
		label_button.add_theme_stylebox_override("normal", style)
		
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color("#1a2540")
		hover_style.bg_color.a = 0.95
		hover_style.set_corner_radius_all(10)
		hover_style.border_width_left = 3
		hover_style.border_width_top = 3
		hover_style.border_width_right = 3
		hover_style.border_width_bottom = 3
		hover_style.border_color = zone_data.color.lightened(0.3)
		label_button.add_theme_stylebox_override("hover", hover_style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		label_button.add_child(margin)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)
		
		var emoji := Label.new()
		emoji.text = zone_data.emoji
		emoji.add_theme_font_size_override("font_size", 32)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(emoji)
		
		var name := Label.new()
		name.text = zone_data.name
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", Color.WHITE)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name)
		
		var chaos := Label.new()
		chaos.name = "ChaosLabel"
		#chaos.text = "🔥 0%"
		chaos.add_theme_font_size_override("font_size", 12)
		chaos.add_theme_color_override("font_color", zone_data.color)
		chaos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chaos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(chaos)
		
		label_button.pressed.connect(func(): _center_on_zone(zone_id))
		
		map_container.add_child(label_button)
		zone_labels[zone_id] = label_button

func _create_zoom_controls() -> void:
	var zoom_container := VBoxContainer.new()
	zoom_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoom_container.position = Vector2(get_viewport_rect().size.x - 80, get_viewport_rect().size.y - 250)
	zoom_container.add_theme_constant_override("separation", 10)
	add_child(zoom_container)
	
	var zoom_in := Button.new()
	zoom_in.custom_minimum_size = Vector2(60, 60)
	zoom_in.text = "+"
	zoom_in.add_theme_font_size_override("font_size", 32)
	zoom_in.pressed.connect(_zoom_in)
	zoom_container.add_child(zoom_in)
	
	var zoom_out := Button.new()
	zoom_out.custom_minimum_size = Vector2(60, 60)
	zoom_out.text = "−"
	zoom_out.add_theme_font_size_override("font_size", 32)
	zoom_out.pressed.connect(_zoom_out)
	zoom_container.add_child(zoom_out)
	
	zoom_label = Label.new()
	zoom_label.name = "ZoomLabel"
	zoom_label.text = "100%"
	zoom_label.add_theme_font_size_override("font_size", 14)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_container.add_child(zoom_label)
	
# Part 3: Mission Detail Panel Creation

func _create_mission_detail_panel() -> void:
	mission_detail_panel = PanelContainer.new()
	mission_detail_panel.visible = false
	mission_detail_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	mission_detail_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mission_detail_panel.offset_top = -550 
	add_child(mission_detail_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.bg_color.a = 0.98
	style.border_width_top = 4
	style.border_color = Color("#00d9ff")
	style.set_corner_radius_all(20)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	mission_detail_panel.add_theme_stylebox_override("panel", style)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 550)
	mission_detail_panel.add_child(scroll)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	scroll.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 5)
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_vbox)
	
	var mission_title := Label.new()
	mission_title.name = "MissionTitle"
	mission_title.text = "Mission Name"
	mission_title.add_theme_font_size_override("font_size", 26)
	mission_title.add_theme_color_override("font_color", Color("#00d9ff"))
	header_vbox.add_child(mission_title)
	
	var mission_desc := Label.new()
	mission_desc.name = "MissionDesc"
	mission_desc.text = "Mission description..."
	mission_desc.add_theme_font_size_override("font_size", 14)
	mission_desc.add_theme_color_override("font_color", Color("#a8a8a8"))
	mission_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	header_vbox.add_child(mission_desc)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(45, 45)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_close_mission_detail)
	header.add_child(close_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Stats grid
	var stats_grid := GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(stats_grid)
	
	var stat_data = [
		{"name": "RewardLabel", "icon": "💰", "value": "$150", "label": "Reward"},
		{"name": "FameLabel", "icon": "⭐", "value": "10", "label": "Fame"},
		{"name": "DurationLabel", "icon": "⏱️", "value": "30s", "label": "Duration"},
		{"name": "DifficultyLabel", "icon": "💪", "value": "Medium", "label": "Difficulty"}
	]
	
	for stat in stat_data:
		var stat_panel := PanelContainer.new()
		stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var stat_style := StyleBoxFlat.new()
		stat_style.bg_color = Color("#0f1624")
		stat_style.set_corner_radius_all(10)
		stat_style.border_width_left = 2
		stat_style.border_width_right = 2
		stat_style.border_width_top = 2
		stat_style.border_width_bottom = 2
		stat_style.border_color = Color("#2a3a5e")
		stat_panel.add_theme_stylebox_override("panel", stat_style)
		
		var stat_margin := MarginContainer.new()
		stat_margin.add_theme_constant_override("margin_left", 10)
		stat_margin.add_theme_constant_override("margin_right", 10)
		stat_margin.add_theme_constant_override("margin_top", 10)
		stat_margin.add_theme_constant_override("margin_bottom", 10)
		stat_panel.add_child(stat_margin)
		
		var stat_vbox := VBoxContainer.new()
		stat_vbox.add_theme_constant_override("separation", 3)
		stat_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stat_margin.add_child(stat_vbox)
		
		var icon_label := Label.new()
		icon_label.text = stat.icon
		icon_label.add_theme_font_size_override("font_size", 24)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_vbox.add_child(icon_label)
		
		var value_label := Label.new()
		value_label.name = stat.name
		value_label.text = stat.value
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", Color("#00d9ff"))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_vbox.add_child(value_label)
		
		var desc_label := Label.new()
		desc_label.text = stat.label
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color("#808080"))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_vbox.add_child(desc_label)
		
		stats_grid.add_child(stat_panel)
	
	# Specialty requirements
	var specialty_container := HBoxContainer.new()
	specialty_container.name = "SpecialtyContainer"
	specialty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	specialty_container.add_theme_constant_override("separation", 8)
	vbox.add_child(specialty_container)
	
	var specialty_label := Label.new()
	specialty_label.text = "🎯 Preferred:"
	specialty_label.add_theme_font_size_override("font_size", 14)
	specialty_label.add_theme_color_override("font_color", Color("#ffcc00"))
	specialty_container.add_child(specialty_label)
	
	var specialty_tags := HBoxContainer.new()
	specialty_tags.name = "SpecialtyTags"
	specialty_tags.add_theme_constant_override("separation", 6)
	specialty_container.add_child(specialty_tags)
	
	vbox.add_child(HSeparator.new())
	
	# Hero selection header
	var hero_header := HBoxContainer.new()
	vbox.add_child(hero_header)
	
	var hero_title := Label.new()
	hero_title.text = "👥 Select Hero"
	hero_title.add_theme_font_size_override("font_size", 20)
	hero_title.add_theme_color_override("font_color", Color("#00d9ff"))
	hero_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_header.add_child(hero_title)
	
	var recommended_label := Label.new()
	recommended_label.name = "RecommendedLabel"
	recommended_label.text = "✨ Best Match Highlighted"
	recommended_label.add_theme_font_size_override("font_size", 12)
	recommended_label.add_theme_color_override("font_color", Color("#4ecca3"))
	hero_header.add_child(recommended_label)
	
	hero_selection_container = VBoxContainer.new()
	hero_selection_container.add_theme_constant_override("separation", 10)
	vbox.add_child(hero_selection_container)
	
	vbox.add_child(HSeparator.new())
	
	# Bottom buttons
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 15)
	vbox.add_child(button_row)
	
	var decline_btn := Button.new()
	decline_btn.text = "❌ DECLINE"
	decline_btn.custom_minimum_size = Vector2(0, 55)
	decline_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline_btn.add_theme_font_size_override("font_size", 18)
	
	var decline_style := StyleBoxFlat.new()
	decline_style.bg_color = Color("#3a3a4e")
	decline_style.set_corner_radius_all(12)
	decline_btn.add_theme_stylebox_override("normal", decline_style)
	
	var decline_hover := StyleBoxFlat.new()
	decline_hover.bg_color = Color("#ff6b6b")
	decline_hover.set_corner_radius_all(12)
	decline_btn.add_theme_stylebox_override("hover", decline_hover)
	
	decline_btn.pressed.connect(func(): 
		rapid_manager.decline_mission()
		_close_mission_detail()
	)
	button_row.add_child(decline_btn)
	
	var accept_btn := Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "✅ ACCEPT MISSION"
	accept_btn.custom_minimum_size = Vector2(0, 55)
	accept_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_btn.add_theme_font_size_override("font_size", 20)
	
	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color("#4ecca3")
	accept_style.set_corner_radius_all(12)
	accept_btn.add_theme_stylebox_override("normal", accept_style)
	
	var accept_hover := StyleBoxFlat.new()
	accept_hover.bg_color = Color("#5efcb3")
	accept_hover.set_corner_radius_all(12)
	accept_btn.add_theme_stylebox_override("hover", accept_hover)
	
	accept_btn.pressed.connect(_on_accept_mission)
	button_row.add_child(accept_btn)
	
# Part 4: Mission Display and Hero Selection

func _show_mission_detail(mission: Mission) -> void:
	if not mission_detail_panel: return
	
	var title = mission_detail_panel.find_child("MissionTitle", true, false)
	if title: title.text = "%s %s" % [mission.mission_emoji, mission.mission_name]
	
	var desc = mission_detail_panel.find_child("MissionDesc", true, false)
	if desc: desc.text = mission.description
	
	var reward = mission_detail_panel.find_child("RewardLabel", true, false)
	if reward: reward.text = "$%d" % mission.money_reward
	
	var duration = mission_detail_panel.find_child("DurationLabel", true, false)
	if duration: duration.text = "%.0fs" % mission.base_duration
	
	var fame = mission_detail_panel.find_child("FameLabel", true, false)
	if fame: fame.text = "%d" % mission.fame_reward
	
	var difficulty = mission_detail_panel.find_child("DifficultyLabel", true, false)
	if difficulty: 
		difficulty.text = mission.get_difficulty_string().replace("⭐", "").strip_edges()
		difficulty.add_theme_color_override("font_color", mission.get_difficulty_color())
	
	# Update specialty tags
	var specialty_tags = mission_detail_panel.find_child("SpecialtyTags", true, false)
	if specialty_tags:
		for child in specialty_tags.get_children():
			child.queue_free()
		
		for spec in mission.preferred_specialties:
			var tag := PanelContainer.new()
			
			var tag_style := StyleBoxFlat.new()
			tag_style.bg_color = Color("#2a3a5e")
			tag_style.set_corner_radius_all(12)
			tag_style.border_width_left = 1
			tag_style.border_width_right = 1
			tag_style.border_width_top = 1
			tag_style.border_width_bottom = 1
			tag_style.border_color = Color("#ffcc00")
			tag.add_theme_stylebox_override("panel", tag_style)
			
			var tag_margin := MarginContainer.new()
			tag_margin.add_theme_constant_override("margin_left", 12)
			tag_margin.add_theme_constant_override("margin_right", 12)
			tag_margin.add_theme_constant_override("margin_top", 4)
			tag_margin.add_theme_constant_override("margin_bottom", 4)
			tag.add_child(tag_margin)
			
			var tag_label := Label.new()
			tag_label.add_theme_font_size_override("font_size", 12)
			
			match spec:
				Hero.Specialty.COMBAT:
					tag_label.text = "⚔️ Combat"
				Hero.Specialty.SPEED:
					tag_label.text = "⚡ Speed"
				Hero.Specialty.TECH:
					tag_label.text = "🔧 Tech"
				Hero.Specialty.RESCUE:
					tag_label.text = "🚑 Rescue"
				Hero.Specialty.INVESTIGATION:
					tag_label.text = "🔍 Investigation"
			
			tag_margin.add_child(tag_label)
			specialty_tags.add_child(tag)
	
	_populate_hero_selection(mission)
	
	mission_detail_panel.visible = true
	mission_detail_panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(mission_detail_panel, "modulate:a", 1.0, 0.3)

func _populate_hero_selection(mission: Mission) -> void:
	for child in hero_selection_container.get_children():
		child.queue_free()
	
	if not game_manager: return
	
	# Find best hero for highlighting
	var best_hero: Hero = null
	var best_score = -999
	
	for hero in game_manager.heroes:
		var can_use = hero.is_available() and rapid_manager.get_hero_energy(hero.hero_id) >= rapid_manager.ENERGY_DRAIN_PER_MISSION
		if not can_use:
			continue
		
		var score = hero.get_power_rating()
		for spec in mission.preferred_specialties:
			if spec in hero.specialties:
				score += 15
		
		if score > best_score:
			best_score = score
			best_hero = hero
	
	for hero in game_manager.heroes:
		var can_use = hero.is_available() and rapid_manager.get_hero_energy(hero.hero_id) >= rapid_manager.ENERGY_DRAIN_PER_MISSION
		var is_best = (hero == best_hero)
		var hero_btn = _create_hero_button_improved(hero, mission, can_use, is_best)
		hero_selection_container.add_child(hero_btn)

func _close_mission_detail() -> void:
	selected_mission = null
	selected_hero = null
	
	var tween = create_tween()
	tween.tween_property(mission_detail_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): mission_detail_panel.visible = false)
	
# Part 5: Hero Button Creation - Part A

func _create_hero_button_improved(hero: Hero, mission: Mission, can_use: bool, is_best: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 140)
	
	var style := StyleBoxFlat.new()
	if is_best and can_use:
		style.bg_color = Color("#1a2a3e")
		style.border_color = Color("#4ecca3")
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
	elif can_use:
		style.bg_color = Color("#0f1624")
		style.border_color = Color("#2a3a5e")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color("#1a1a1a")
		style.border_color = Color("#555555")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	if can_use:
		hover_style.bg_color = Color("#1a2540")
		hover_style.border_color = Color("#00d9ff") if is_best else Color("#4a5a7e")
		hover_style.border_width_left = 4
		hover_style.border_width_top = 4
		hover_style.border_width_right = 4
		hover_style.border_width_bottom = 4
	else:
		hover_style.bg_color = Color("#1a1a1a")
		hover_style.border_color = Color("#555555")
		hover_style.border_width_left = 2
		hover_style.border_width_top = 2
		hover_style.border_width_right = 2
		hover_style.border_width_bottom = 2
	hover_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	btn.add_child(margin)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)
	
	# Top Row: Name + Badge
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(name_row)
	
	var name_label := Label.new()
	name_label.text = "%s %s" % [hero.hero_emoji, hero.hero_name]
	name_label.add_theme_font_size_override("font_size", 18)
	if can_use:
		name_label.add_theme_color_override("font_color", Color("#00d9ff") if is_best else Color.WHITE)
	else:
		name_label.add_theme_color_override("font_color", Color("#666666"))
	name_row.add_child(name_label)
	
	if is_best and can_use:
		var best_badge := Label.new()
		best_badge.text = "✨ BEST"
		best_badge.add_theme_font_size_override("font_size", 12)
		best_badge.add_theme_color_override("font_color", Color("#4ecca3"))
		
		var badge_panel := PanelContainer.new()
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("#4ecca3")
		badge_style.bg_color.a = 0.2
		badge_style.set_corner_radius_all(8)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		
		var badge_margin := MarginContainer.new()
		badge_margin.add_theme_constant_override("margin_left", 8)
		badge_margin.add_theme_constant_override("margin_right", 8)
		badge_margin.add_theme_constant_override("margin_top", 2)
		badge_margin.add_theme_constant_override("margin_bottom", 2)
		badge_panel.add_child(badge_margin)
		badge_margin.add_child(best_badge)
		
		name_row.add_child(badge_panel)
	
	# Second Row: Stats
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	main_vbox.add_child(stats_row)
	
	var level_label := Label.new()
	level_label.text = "Lv.%d" % hero.level
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color("#ffcc00"))
	stats_row.add_child(level_label)
	
	var power_label := Label.new()
	power_label.text = "💪 %d" % hero.get_power_rating()
	power_label.add_theme_font_size_override("font_size", 13)
	power_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	stats_row.add_child(power_label)
	
	var str_label := Label.new()
	str_label.text = "⚔️ %d" % hero.get_total_strength()
	str_label.add_theme_font_size_override("font_size", 13)
	stats_row.add_child(str_label)
	
	var spd_label := Label.new()
	spd_label.text = "⚡ %d" % hero.get_total_speed()
	spd_label.add_theme_font_size_override("font_size", 13)
	stats_row.add_child(spd_label)
	
	var int_label := Label.new()
	int_label.text = "🧠 %d" % hero.get_total_intelligence()
	int_label.add_theme_font_size_override("font_size", 13)
	stats_row.add_child(int_label)
	
	# Third Row: Health + Stamina bars side by side
	var bars_row := HBoxContainer.new()
	bars_row.add_theme_constant_override("separation", 15)
	main_vbox.add_child(bars_row)
	
	# Health
	var health_vbox := VBoxContainer.new()
	health_vbox.add_theme_constant_override("separation", 3)
	health_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_row.add_child(health_vbox)
	
	var health_label := Label.new()
	health_label.text = "❤️ %.0f/%.0f" % [hero.current_health, hero.max_health]
	health_label.add_theme_font_size_override("font_size", 11)
	health_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	health_vbox.add_child(health_label)
	
	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 14)
	health_bar.max_value = hero.max_health
	health_bar.value = hero.current_health
	health_bar.show_percentage = false
	
	var hb_bg := StyleBoxFlat.new()
	hb_bg.bg_color = Color("#1a1a2e")
	hb_bg.set_corner_radius_all(7)
	health_bar.add_theme_stylebox_override("background", hb_bg)
	
	var hb_fill := StyleBoxFlat.new()
	hb_fill.bg_color = Color("#ff6b6b")
	hb_fill.set_corner_radius_all(7)
	health_bar.add_theme_stylebox_override("fill", hb_fill)
	
	health_vbox.add_child(health_bar)
	
	# Stamina
	var stamina_vbox := VBoxContainer.new()
	stamina_vbox.add_theme_constant_override("separation", 3)
	stamina_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_row.add_child(stamina_vbox)
	
	var stamina_label := Label.new()
	stamina_label.text = "💨 %.0f/%.0f" % [hero.current_stamina, hero.max_stamina]
	stamina_label.add_theme_font_size_override("font_size", 11)
	stamina_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	stamina_vbox.add_child(stamina_label)
	
	var stamina_bar := ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(0, 14)
	stamina_bar.max_value = hero.max_stamina
	stamina_bar.value = hero.current_stamina
	stamina_bar.show_percentage = false
	
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color("#1a1a2e")
	sb_bg.set_corner_radius_all(7)
	stamina_bar.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fill := StyleBoxFlat.new()
	if hero.current_stamina >= 20:
		sb_fill.bg_color = Color("#00d9ff")
	else:
		sb_fill.bg_color = Color("#ff6b6b")
	sb_fill.set_corner_radius_all(7)
	stamina_bar.add_theme_stylebox_override("fill", sb_fill)
	
	stamina_vbox.add_child(stamina_bar)
	
	# Continue to Part B...
	return _create_hero_button_part_b(btn, hero, mission, can_use, main_vbox)

func _create_hero_button_part_b(btn: Button, hero: Hero, mission: Mission, can_use: bool, main_vbox: VBoxContainer) -> Button:
	# Fourth Row: Energy bar
	var energy_vbox := VBoxContainer.new()
	energy_vbox.add_theme_constant_override("separation", 3)
	main_vbox.add_child(energy_vbox)
	
	var energy_label := Label.new()
	energy_label.text = "⚡ Energy: %.0f%%" % rapid_manager.get_hero_energy(hero.hero_id)
	energy_label.add_theme_font_size_override("font_size", 11)
	energy_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	energy_vbox.add_child(energy_label)
	
	var energy_bar := ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(0, 14)
	energy_bar.max_value = 100
	energy_bar.value = rapid_manager.get_hero_energy(hero.hero_id)
	energy_bar.show_percentage = false
	
	var eb_bg := StyleBoxFlat.new()
	eb_bg.bg_color = Color("#1a1a2e")
	eb_bg.set_corner_radius_all(7)
	energy_bar.add_theme_stylebox_override("background", eb_bg)
	
	var eb_fill := StyleBoxFlat.new()
	if can_use:
		eb_fill.bg_color = Color("#4ecca3")
	else:
		eb_fill.bg_color = Color("#555555")
	eb_fill.set_corner_radius_all(7)
	energy_bar.add_theme_stylebox_override("fill", eb_fill)
	
	energy_vbox.add_child(energy_bar)
	
	# Fifth Row: Specialties
	var has_match = false
	var spec_row := HBoxContainer.new()
	spec_row.add_theme_constant_override("separation", 5)
	main_vbox.add_child(spec_row)
	
	var spec_label := Label.new()
	spec_label.text = "🎯 "
	spec_label.add_theme_font_size_override("font_size", 12)
	spec_row.add_child(spec_label)
	
	for spec in hero.specialties:
		var spec_icon := Label.new()
		var is_match = spec in mission.preferred_specialties
		
		match spec:
			Hero.Specialty.COMBAT:
				spec_icon.text = "⚔️"
			Hero.Specialty.SPEED:
				spec_icon.text = "⚡"
			Hero.Specialty.TECH:
				spec_icon.text = "🔧"
			Hero.Specialty.RESCUE:
				spec_icon.text = "🚑"
			Hero.Specialty.INVESTIGATION:
				spec_icon.text = "🔍"
		
		spec_icon.add_theme_font_size_override("font_size", 14)
		if is_match:
			spec_icon.modulate = Color("#ffcc00")
			has_match = true
		else:
			spec_icon.modulate = Color("#808080")
		
		spec_row.add_child(spec_icon)
	
	if has_match:
		var match_label := Label.new()
		match_label.text = " ✓ Match!"
		match_label.add_theme_font_size_override("font_size", 12)
		match_label.add_theme_color_override("font_color", Color("#ffcc00"))
		spec_row.add_child(match_label)
	
	# Status message
	if not can_use:
		var status := Label.new()
		if not hero.is_available():
			status.text = "❌ " + hero.get_status_text()
		else:
			status.text = "😓 Not enough energy (need 25%)"
		status.add_theme_font_size_override("font_size", 12)
		status.add_theme_color_override("font_color", Color("#ff6b6b"))
		main_vbox.add_child(status)
	
	if can_use:
		btn.pressed.connect(func(): _on_hero_selected(hero))
	else:
		btn.disabled = true
	
	return btn
	
# Part 6: Mission Icons and Event Handlers

func _spawn_mission_icons() -> void:
	if not rapid_manager:
		return
	
	for icon in mission_icons.values():
		icon.queue_free()
	mission_icons.clear()
	
	for mission in rapid_manager.mission_queue:
		_create_mission_icon(mission)

func _create_mission_icon(mission: Mission) -> void:
	var icon_btn := Button.new()
	icon_btn.custom_minimum_size = Vector2(64, 64)
	
	var zone_data = zones.get(mission.zone, zones["downtown"])
	var zone_rect = zone_data.rect
	
	var seed_val = mission.mission_id.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var random_x = zone_rect.position.x + rng.randf_range(5, zone_rect.size.x - 5)
	var random_y = zone_rect.position.y + rng.randf_range(5, zone_rect.size.y - 5)
	
	var pos = _percent_to_position(Vector2(random_x, random_y))
	icon_btn.position = pos - Vector2(32, 32)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2a2a3e")
	style.set_corner_radius_all(32)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 1, 1, 0.5)
	icon_btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#3a3a4e")
	hover_style.set_corner_radius_all(32)
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color("#00d9ff")
	icon_btn.add_theme_stylebox_override("hover", hover_style)
	
	icon_btn.text = mission.mission_emoji
	icon_btn.add_theme_font_size_override("font_size", 32)
	
	var badge := Label.new()
	badge.text = str(mission.difficulty + 1)
	badge.custom_minimum_size = Vector2(20, 20)
	badge.position = Vector2(44, -4)
	badge.add_theme_font_size_override("font_size", 12)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = mission.get_difficulty_color()
	badge_style.set_corner_radius_all(10)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.border_color = Color.WHITE
	
	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_panel.position = badge.position
	badge_panel.custom_minimum_size = badge.custom_minimum_size
	badge_panel.add_child(badge)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_btn.add_child(badge_panel)
	
	icon_btn.pressed.connect(func(): _on_mission_icon_clicked(mission))
	
	map_container.add_child(icon_btn)
	mission_icons[mission.mission_id] = icon_btn

func _on_mission_icon_clicked(mission: Mission) -> void:
	selected_mission = mission
	_show_mission_detail(mission)

func _on_hero_selected(hero: Hero) -> void:
	selected_hero = hero

func _on_accept_mission() -> void:
	if not selected_mission or not selected_hero: return
	
	rapid_manager.mission_queue.erase(selected_mission)
	rapid_manager._fill_mission_queue()
	
	rapid_manager.hero_energy[selected_hero.hero_id] -= rapid_manager.ENERGY_DRAIN_PER_MISSION
	
	selected_mission.assigned_hero_ids.append(selected_hero.hero_id)
	selected_mission.start_mission([selected_hero])
	
	rapid_manager.active_slots.append({
		"mission": selected_mission,
		"hero": selected_hero,
		"time_remaining": selected_mission.base_duration
	})
	
	rapid_manager.current_streak += 1
	if rapid_manager.has_signal("streak_increased"):
		rapid_manager.streak_increased.emit(rapid_manager.current_streak)
	
	_close_mission_detail()
	_spawn_mission_icons()

func _on_mission_accepted(_mission: Mission) -> void:
	_spawn_mission_icons()

func _on_mission_declined(_mission: Mission) -> void:
	_spawn_mission_icons()

func _process(_delta: float) -> void:
	if game_manager and game_manager.chaos_system:
		for zone_id in zone_labels.keys():
			var label_button = zone_labels[zone_id]
			var chaos_label = label_button.find_child("ChaosLabel", true, false)
			if chaos_label and game_manager.chaos_system.has_method("get_chaos_level"):
				var chaos_level = game_manager.chaos_system.get_chaos_level(zone_id)
				chaos_label.text = "🔥 %.0f%%" % chaos_level
	
	if rapid_manager:
		var current_ids = {}
		for mission in rapid_manager.mission_queue:
			current_ids[mission.mission_id] = true
		
		var to_remove = []
		for mission_id in mission_icons.keys():
			if not current_ids.has(mission_id):
				mission_icons[mission_id].queue_free()
				to_remove.append(mission_id)
		
		for mission_id in to_remove:
			mission_icons.erase(mission_id)
		
		for mission in rapid_manager.mission_queue:
			if not mission_icons.has(mission.mission_id):
				_create_mission_icon(mission)
