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
const ZOOM_STEP = 0.1 # Smaller step for smoother wheel zooming

# UI References
var map_viewport: Control # The clipping container (previously SubViewportContainer)
var map_container: Control # The moving map content
var mission_icons: Dictionary = {}
var zone_labels: Dictionary = {}
var selected_mission: Mission = null
var mission_detail_panel: PanelContainer
var hero_selection_container: VBoxContainer
var zoom_label: Label 
var selected_hero: Hero = null # Added for mission logic

# Zone data - (Kept your exact data)
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
	
	# Connect signals
	if rapid_manager and rapid_manager.is_connected("mission_accepted", _on_mission_accepted):
		rapid_manager.mission_accepted.connect(_on_mission_accepted)
	if rapid_manager and rapid_manager.is_connected("mission_declined", _on_mission_declined):
		rapid_manager.mission_declined.connect(_on_mission_declined)
	
	_spawn_mission_icons()

func _create_ui() -> void:
	# Main layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let mouse events pass through VBox
	add_child(vbox)
	
	# 1. Map Viewport (The Window / Clipping)
	map_viewport = Control.new()
	map_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_viewport.clip_contents = true 
	map_viewport.mouse_filter = Control.MOUSE_FILTER_STOP # Catch clicks/drags here
	vbox.add_child(map_viewport)
	
	# 2. Map Container (The Content)
	map_container = Control.new()
	map_container.custom_minimum_size = Vector2(1440, 2560) 
	map_container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_viewport.add_child(map_container)
	
	# Background
	var bg := ColorRect.new()
	bg.color = Color("#0f1624")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	map_container.add_child(bg)
	
	# Visual Elements
	_create_grid_pattern()
	_create_zone_halos()
	_create_zone_labels()
	
	# UI Overlays (Zoom, Panels)
	_create_zoom_controls()
	_create_mission_detail_panel()
	
	# Connect Input
	map_viewport.gui_input.connect(_on_map_input)
	
	# Center map initially
	call_deferred("_center_map")

func _center_map() -> void:
	# Center the map content within the viewport
	var viewport_size = map_viewport.size
	var content_size = map_container.custom_minimum_size
	map_container.position = (viewport_size - content_size) / 2
	_clamp_map_position()

# --- INPUT HANDLING (PAN & ZOOM) ---

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Panning Start/Stop
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_panning = true
				drag_start_mouse_pos = event.global_position
				drag_start_map_pos = map_container.position
			else:
				is_panning = false
		
		# Zooming (Mouse Wheel)
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_point(event.position, ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_point(event.position, -ZOOM_STEP)
	
	# Panning Movement
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
	
	# The Pivot Math
	var mouse_offset_from_map_origin = pivot - map_container.position
	var scale_factor = new_zoom / old_zoom
	
	map_container.scale = Vector2(zoom, zoom)
	
	# Move map so the pivot point remains under the cursor
	map_container.position = pivot - (mouse_offset_from_map_origin * scale_factor)
	
	_clamp_map_position()
	_update_zoom_label()

func _clamp_map_position() -> void:
	# Keep the map content boundaries visible within the viewport.
	var viewport_size = map_viewport.size
	var map_size_scaled = map_container.custom_minimum_size * zoom
	
	# Max Position: Highest (closest to 0) the map's top-left can go.
	# Centers map if it's smaller than the viewport (zoomed out).
	var max_x = max(0.0, (viewport_size.x - map_size_scaled.x) / 2.0)
	var max_y = max(0.0, (viewport_size.y - map_size_scaled.y) / 2.0)
	
	# Min Position: Lowest (most negative) the map's top-left can go.
	# Prevents the user from seeing the black void when zoomed in.
	var min_x = min(0.0, viewport_size.x - map_size_scaled.x)
	var min_y = min(0.0, viewport_size.y - map_size_scaled.y)
	
	# Apply Clamping
	map_container.position.x = clamp(map_container.position.x, min_x, max_x)
	map_container.position.y = clamp(map_container.position.y, min_y, max_y)

# --- ZOOM BUTTONS ---

func _zoom_in() -> void:
	# Zoom towards the center of the viewport
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
		
		var label_panel := PanelContainer.new()
		label_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		label_panel.position = label_pos - Vector2(80, 40)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#16213e")
		style.bg_color.a = 0.9
		style.set_corner_radius_all(10)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = zone_data.color
		label_panel.add_theme_stylebox_override("panel", style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		label_panel.add_child(margin)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		margin.add_child(vbox)
		
		var emoji := Label.new()
		emoji.text = zone_data.emoji
		emoji.add_theme_font_size_override("font_size", 32)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(emoji)
		
		var name := Label.new()
		name.text = zone_data.name
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", Color.WHITE)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name)
		
		var chaos := Label.new()
		chaos.name = "ChaosLabel"
		chaos.text = "🔥 0%"
		chaos.add_theme_font_size_override("font_size", 12)
		chaos.add_theme_color_override("font_color", zone_data.color)
		chaos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(chaos)
		
		map_container.add_child(label_panel)
		zone_labels[zone_id] = label_panel

func _create_zoom_controls() -> void:
	var zoom_container := VBoxContainer.new()
	zoom_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoom_container.position = Vector2(get_viewport_rect().size.x - 80, get_viewport_rect().size.y - 250)
	zoom_container.add_theme_constant_override("separation", 10)
	add_child(zoom_container)
	
	# Zoom in
	var zoom_in := Button.new()
	zoom_in.custom_minimum_size = Vector2(60, 60)
	zoom_in.text = "+"
	zoom_in.add_theme_font_size_override("font_size", 32)
	zoom_in.pressed.connect(_zoom_in)
	zoom_container.add_child(zoom_in)
	
	# Zoom out
	var zoom_out := Button.new()
	zoom_out.custom_minimum_size = Vector2(60, 60)
	zoom_out.text = "−"
	zoom_out.add_theme_font_size_override("font_size", 32)
	zoom_out.pressed.connect(_zoom_out)
	zoom_container.add_child(zoom_out)
	
	# Zoom level display
	zoom_label = Label.new()
	zoom_label.name = "ZoomLabel"
	zoom_label.text = "100%"
	zoom_label.add_theme_font_size_override("font_size", 14)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_container.add_child(zoom_label)

func _create_mission_detail_panel() -> void:
	mission_detail_panel = PanelContainer.new()
	mission_detail_panel.visible = false
	mission_detail_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	mission_detail_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mission_detail_panel.offset_top = -400 
	add_child(mission_detail_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.bg_color.a = 0.98
	style.border_width_top = 3
	style.border_color = Color("#00d9ff")
	style.set_corner_radius_all(20)
	mission_detail_panel.add_theme_stylebox_override("panel", style)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	mission_detail_panel.add_child(scroll)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Header with close button
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var mission_title := Label.new()
	mission_title.name = "MissionTitle"
	mission_title.text = "Mission Name"
	mission_title.add_theme_font_size_override("font_size", 24)
	mission_title.add_theme_color_override("font_color", Color("#00d9ff"))
	mission_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(mission_title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_close_mission_detail)
	header.add_child(close_btn)
	
	# Mission info
	var info_grid := GridContainer.new()
	info_grid.columns = 3
	info_grid.add_theme_constant_override("h_separation", 10)
	info_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(info_grid)
	
	for i in range(3):
		var info_panel := PanelContainer.new()
		info_panel.custom_minimum_size = Vector2(0, 80)
		info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var info_style := StyleBoxFlat.new()
		info_style.bg_color = Color("#0f1624")
		info_style.set_corner_radius_all(8)
		info_panel.add_theme_stylebox_override("panel", info_style)
		
		var info_vbox := VBoxContainer.new()
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		info_panel.add_child(info_vbox)
		
		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 20)
		
		var desc_label := Label.new()
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color("#a8a8a8"))
		
		if i == 0:
			value_label.name = "RewardLabel"
			value_label.text = "💰 $150"
			desc_label.text = "Reward"
		elif i == 1:
			value_label.name = "DurationLabel"
			value_label.text = "⏱️ 30s"
			desc_label.text = "Duration"
		else:
			value_label.name = "FameLabel"
			value_label.text = "⭐ 10"
			desc_label.text = "Fame"
		
		info_vbox.add_child(value_label)
		info_vbox.add_child(desc_label)
		info_grid.add_child(info_panel)
	
	vbox.add_child(HSeparator.new())
	
	# Hero selection
	var hero_title := Label.new()
	hero_title.text = "👥 Select Hero"
	hero_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(hero_title)
	
	hero_selection_container = VBoxContainer.new()
	hero_selection_container.add_theme_constant_override("separation", 8)
	vbox.add_child(hero_selection_container)
	
	# Accept button
	var accept_btn := Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "✅ ACCEPT MISSION"
	accept_btn.custom_minimum_size = Vector2(0, 60)
	accept_btn.add_theme_font_size_override("font_size", 20)
	
	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color("#4ecca3")
	accept_style.set_corner_radius_all(10)
	accept_btn.add_theme_stylebox_override("normal", accept_style)
	
	accept_btn.pressed.connect(_on_accept_mission)
	vbox.add_child(accept_btn)

func _spawn_mission_icons() -> void:
	if not rapid_manager:
		return
	
	# Clear existing icons
	for icon in mission_icons.values():
		icon.queue_free()
	mission_icons.clear()
	
	# Create icon for each mission in queue
	for mission in rapid_manager.mission_queue:
		_create_mission_icon(mission)

func _create_mission_icon(mission: Mission) -> void:
	var icon_btn := Button.new()
	icon_btn.custom_minimum_size = Vector2(64, 64)
	
	# Position based on zone - uses deterministic randomness
	var zone_data = zones.get(mission.zone, zones["downtown"])
	var zone_rect = zone_data.rect
	
	var seed_val = mission.mission_id.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var random_x = zone_rect.position.x + rng.randf_range(5, zone_rect.size.x - 5)
	var random_y = zone_rect.position.y + rng.randf_range(5, zone_rect.size.y - 5)
	
	var pos = _percent_to_position(Vector2(random_x, random_y))
	icon_btn.position = pos - Vector2(32, 32)
	
	# Style
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
	
	# Emoji
	icon_btn.text = mission.mission_emoji
	icon_btn.add_theme_font_size_override("font_size", 32)
	
	# Difficulty badge
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
	
	# Connect signal
	icon_btn.pressed.connect(func(): _on_mission_icon_clicked(mission))
	
	map_container.add_child(icon_btn)
	mission_icons[mission.mission_id] = icon_btn

func _on_mission_icon_clicked(mission: Mission) -> void:
	selected_mission = mission
	_show_mission_detail(mission)

func _show_mission_detail(mission: Mission) -> void:
	if not mission_detail_panel: return
	
	var title = mission_detail_panel.find_child("MissionTitle", true, false)
	if title: title.text = "%s %s" % [mission.mission_emoji, mission.mission_name]
	
	var reward = mission_detail_panel.find_child("RewardLabel", true, false)
	if reward: reward.text = "💰 $%d" % mission.money_reward
	
	var duration = mission_detail_panel.find_child("DurationLabel", true, false)
	if duration: duration.text = "⏱️ %.0fs" % mission.base_duration
	
	var fame = mission_detail_panel.find_child("FameLabel", true, false)
	if fame: fame.text = "⭐ %d" % mission.fame_reward
	
	_populate_hero_selection(mission)
	
	mission_detail_panel.visible = true
	mission_detail_panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(mission_detail_panel, "modulate:a", 1.0, 0.3)

func _populate_hero_selection(mission: Mission) -> void:
	for child in hero_selection_container.get_children():
		child.queue_free()
	
	if not game_manager: return
	
	for hero in game_manager.heroes:
		# Note: This requires is_available() and get_hero_energy() to be defined elsewhere
		var can_use = hero.is_available() and rapid_manager.get_hero_energy(hero.hero_id) >= rapid_manager.ENERGY_DRAIN_PER_MISSION
		var hero_btn = _create_hero_button(hero, can_use)
		hero_selection_container.add_child(hero_btn)

func _on_hero_selected(hero: Hero) -> void:
	selected_hero = hero

func _on_accept_mission() -> void:
	if not selected_mission or not selected_hero: return
	
	# Remove mission from queue
	rapid_manager.mission_queue.erase(selected_mission)
	rapid_manager._fill_mission_queue()
	
	# Drain hero energy
	rapid_manager.hero_energy[selected_hero.hero_id] -= rapid_manager.ENERGY_DRAIN_PER_MISSION
	
	# Start mission
	selected_mission.assigned_hero_ids.append(selected_hero.hero_id)
	selected_mission.start_mission([selected_hero])
	
	# Add to active slots
	rapid_manager.active_slots.append({
		"mission": selected_mission,
		"hero": selected_hero,
		"time_remaining": selected_mission.base_duration
	})
	
	# Update streak
	rapid_manager.current_streak += 1
	if rapid_manager.has_signal("streak_increased"):
		rapid_manager.streak_increased.emit(rapid_manager.current_streak)
	
	# Close panel and refresh icons
	_close_mission_detail()
	_spawn_mission_icons()

func _close_mission_detail() -> void:
	selected_mission = null
	selected_hero = null
	
	var tween = create_tween()
	tween.tween_property(mission_detail_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): mission_detail_panel.visible = false)

func _on_mission_accepted(_mission: Mission) -> void:
	_spawn_mission_icons()

func _on_mission_declined(_mission: Mission) -> void:
	_spawn_mission_icons()

func _percent_to_position(percent: Vector2) -> Vector2:
	return Vector2(
		map_container.custom_minimum_size.x * (percent.x / 100.0),
		map_container.custom_minimum_size.y * (percent.y / 100.0)
	)

func _create_hero_button(hero: Hero, can_use: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f1624") if can_use else Color("#1a1a1a")
	style.border_color = Color("#4ecca3") if can_use else Color("#555555")
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = "%s %s (Lv.%d)" % [hero.hero_emoji, hero.hero_name, hero.level]
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var energy_bar := ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(200, 16)
	energy_bar.max_value = 100
	# This line assumes rapid_manager.get_hero_energy is implemented
	energy_bar.value = rapid_manager.get_hero_energy(hero.hero_id) 
	vbox.add_child(energy_bar)
	
	if can_use:
		btn.pressed.connect(func(): _on_hero_selected(hero))
	else:
		btn.disabled = true
	
	return btn

func _process(_delta: float) -> void:
	# Update chaos labels
	if game_manager and game_manager.chaos_system:
		for zone_id in zone_labels.keys():
			var label_panel = zone_labels[zone_id]
			var chaos_label = label_panel.find_child("ChaosLabel", true, false)
			if chaos_label and game_manager.chaos_system.has_method("get_chaos_level"):
				var chaos_level = game_manager.chaos_system.get_chaos_level(zone_id)
				chaos_label.text = "🔥 %.0f%%" % chaos_level
	
	# Icon Cleanup/Update
	if rapid_manager:
		var current_ids = {}
		for mission in rapid_manager.mission_queue:
			current_ids[mission.mission_id] = true
		
		# Remove icons for missions no longer in queue
		var to_remove = []
		for mission_id in mission_icons.keys():
			if not current_ids.has(mission_id):
				mission_icons[mission_id].queue_free()
				to_remove.append(mission_id)
		
		for mission_id in to_remove:
			mission_icons.erase(mission_id)
		
		# Add icons for new missions
		for mission in rapid_manager.mission_queue:
			if not mission_icons.has(mission.mission_id):
				_create_mission_icon(mission)
