# res://scripts/rapid_response_ui.gd
# Simplified mobile-friendly swipe-based mission UI
extends Control

var rapid_manager: RapidResponseManager
var game_manager: Node

# Components
var zone_selector: ZoneSelector
var mission_card: MissionCard

# UI Nodes
var accept_button: Button
var decline_button: Button
var active_missions_panel: VBoxContainer
var streak_label: Label
var stats_panel: HBoxContainer

# Hero selection overlay
var hero_selection_overlay: ColorRect
var hero_selection_panel: PanelContainer
var hero_buttons_container: VBoxContainer
var selected_hero: Hero = null

func _ready() -> void:
	_create_ui()
	_create_hero_selection_overlay()

func setup(rm: RapidResponseManager, gm: Node) -> void:
	rapid_manager = rm
	game_manager = gm
	
	# Setup components
	zone_selector.setup(game_manager)
	zone_selector.zone_changed.connect(_on_zone_changed)
	
	# Connect signals
	rapid_manager.mission_accepted.connect(_on_mission_accepted)
	rapid_manager.mission_declined.connect(_on_mission_declined)
	rapid_manager.streak_increased.connect(_on_streak_increased)
	rapid_manager.streak_broken.connect(_on_streak_broken)
	
	_update_mission_card()

func _create_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg := ColorRect.new()
	bg.color = Color("#0f1624")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_preset(PRESET_FULL_RECT)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Top stats bar
	_create_top_bar(vbox)
	
	# Zone selector component
	zone_selector = ZoneSelector.new()
	vbox.add_child(zone_selector)
	
	# Mission card component (center, large)
	var card_container := CenterContainer.new()
	card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(card_container)
	
	mission_card = MissionCard.new()
	mission_card.swiped_left.connect(_animate_decline)
	mission_card.swiped_right.connect(_show_hero_selection)
	mission_card.card_tapped.connect(_show_hero_selection)
	card_container.add_child(mission_card)
	
	# Accept/Decline buttons
	_create_action_buttons(vbox)
	
	# Active missions (bottom)
	_create_active_missions(vbox)

func _create_top_bar(parent: VBoxContainer) -> void:
	stats_panel = HBoxContainer.new()
	stats_panel.add_theme_constant_override("separation", 20)
	parent.add_child(stats_panel)
	
	# Streak
	streak_label = Label.new()
	streak_label.text = "🔥 Streak: 0"
	streak_label.add_theme_font_size_override("font_size", 24)
	streak_label.add_theme_color_override("font_color", Color("#ff8c42"))
	stats_panel.add_child(streak_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(spacer)
	
	# Available heroes
	var heroes_label := Label.new()
	heroes_label.name = "HeroesLabel"
	heroes_label.text = "👥 3/3"
	heroes_label.add_theme_font_size_override("font_size", 20)
	heroes_label.add_theme_color_override("font_color", Color("#4ecca3"))
	stats_panel.add_child(heroes_label)

func _create_action_buttons(parent: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 30)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(button_row)
	
	# Decline button (red X)
	decline_button = Button.new()
	decline_button.text = "❌\nDECLINE"
	decline_button.custom_minimum_size = Vector2(120, 120)
	decline_button.add_theme_font_size_override("font_size", 20)
	
	var decline_style := StyleBoxFlat.new()
	decline_style.bg_color = Color("#ff3838")
	decline_style.set_corner_radius_all(60)
	decline_button.add_theme_stylebox_override("normal", decline_style)
	
	var decline_hover := StyleBoxFlat.new()
	decline_hover.bg_color = Color("#cc2020")
	decline_hover.set_corner_radius_all(60)
	decline_button.add_theme_stylebox_override("hover", decline_hover)
	
	decline_button.pressed.connect(_on_decline_pressed)
	button_row.add_child(decline_button)
	
	# Accept button (green check)
	accept_button = Button.new()
	accept_button.text = "✅\nSELECT\nHERO"
	accept_button.custom_minimum_size = Vector2(120, 120)
	accept_button.add_theme_font_size_override("font_size", 18)
	
	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color("#4ecca3")
	accept_style.set_corner_radius_all(60)
	accept_button.add_theme_stylebox_override("normal", accept_style)
	
	var accept_hover := StyleBoxFlat.new()
	accept_hover.bg_color = Color("#45b393")
	accept_hover.set_corner_radius_all(60)
	accept_button.add_theme_stylebox_override("hover", accept_hover)
	
	accept_button.pressed.connect(_show_hero_selection)
	button_row.add_child(accept_button)

func _create_active_missions(parent: VBoxContainer) -> void:
	var active_header := Label.new()
	active_header.text = "🚀 ACTIVE MISSIONS"
	active_header.add_theme_font_size_override("font_size", 18)
	active_header.add_theme_color_override("font_color", Color("#00d9ff"))
	parent.add_child(active_header)
	
	active_missions_panel = VBoxContainer.new()
	active_missions_panel.add_theme_constant_override("separation", 5)
	parent.add_child(active_missions_panel)

func _update_mission_card() -> void:
	if not rapid_manager:
		return
	
	var mission = rapid_manager.get_current_mission()
	var best_hero = null
	
	if mission:
		best_hero = rapid_manager._find_best_hero_for_mission(mission)
	
	mission_card.update_mission(mission, best_hero)
	
	# Update available heroes count
	var heroes_label = stats_panel.get_node("HeroesLabel")
	var available = rapid_manager.get_available_heroes_count()
	heroes_label.text = "👥 %d/%d" % [available, game_manager.heroes.size()]
	
	# Enable/disable buttons
	accept_button.disabled = best_hero == null
	decline_button.disabled = mission == null

func _update_active_missions() -> void:
	for child in active_missions_panel.get_children():
		child.queue_free()
	
	if not rapid_manager:
		return
	
	for slot in rapid_manager.active_slots:
		var mission: Mission = slot.mission
		var hero: Hero = slot.hero
		var time_left: float = slot.time_remaining
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		active_missions_panel.add_child(row)
		
		var mission_label := Label.new()
		mission_label.text = "%s %s" % [mission.mission_emoji, mission.mission_name]
		mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mission_label)
		
		var timer := Label.new()
		timer.text = "⏱️ %.0fs" % time_left
		timer.add_theme_color_override("font_color", Color("#ff8c42"))
		row.add_child(timer)

func _animate_decline() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.parallel().tween_property(mission_card, "position:x", mission_card.position.x - 500, 0.3)
	tween.parallel().tween_property(mission_card, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(_on_decline_pressed)
	tween.tween_callback(func():
		mission_card.position.x = 0
		mission_card.modulate.a = 1.0
	)

func _on_decline_pressed() -> void:
	if rapid_manager:
		rapid_manager.decline_mission()
		_update_mission_card()

func _on_zone_changed(zone_id: String) -> void:
	if rapid_manager:
		rapid_manager.set_zone_filter(zone_id)
		_update_mission_card()

func _on_mission_accepted(_mission: Mission) -> void:
	pass

func _on_mission_declined(_mission: Mission) -> void:
	pass

func _on_streak_increased(new_streak: int) -> void:
	streak_label.text = "🔥 Streak: %d" % new_streak
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	streak_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(streak_label, "scale", Vector2(1.0, 1.0), 0.5)

func _on_streak_broken() -> void:
	streak_label.text = "🔥 Streak: 0"
	streak_label.modulate = Color.RED
	
	var tween = create_tween()
	tween.tween_property(streak_label, "modulate", Color.WHITE, 0.5)

func _process(_delta: float) -> void:
	_update_active_missions()
	zone_selector.update_chaos_displays()

# Hero Selection Overlay
func _create_hero_selection_overlay() -> void:
	hero_selection_overlay = ColorRect.new()
	hero_selection_overlay.color = Color(0, 0, 0, 0.85)
	hero_selection_overlay.set_anchors_preset(PRESET_FULL_RECT)
	hero_selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hero_selection_overlay.visible = false
	add_child(hero_selection_overlay)
	
	hero_selection_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_hero_selection()
	)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	hero_selection_overlay.add_child(center)
	
	hero_selection_panel = PanelContainer.new()
	hero_selection_panel.custom_minimum_size = Vector2(400, 600)
	center.add_child(hero_selection_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.set_corner_radius_all(20)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color("#00d9ff")
	hero_selection_panel.add_theme_stylebox_override("panel", style)
	hero_selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	hero_selection_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var title := Label.new()
	title.text = "SELECT HERO"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#00d9ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_close_hero_selection)
	header.add_child(close_btn)
	
	vbox.add_child(HSeparator.new())
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 450)
	vbox.add_child(scroll)
	
	hero_buttons_container = VBoxContainer.new()
	hero_buttons_container.add_theme_constant_override("separation", 10)
	scroll.add_child(hero_buttons_container)

func _show_hero_selection() -> void:
	if not rapid_manager or not game_manager:
		return
	
	var mission = rapid_manager.get_current_mission()
	if not mission:
		return
	
	for child in hero_buttons_container.get_children():
		child.queue_free()
	
	for hero in game_manager.heroes:
		var can_use = hero.is_available() and rapid_manager.get_hero_energy(hero.hero_id) >= rapid_manager.ENERGY_DRAIN_PER_MISSION
		var hero_btn := _create_hero_button(hero, mission, can_use)
		hero_buttons_container.add_child(hero_btn)
	
	hero_selection_overlay.visible = true
	hero_selection_overlay.modulate.a = 0.0
	hero_selection_panel.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(hero_selection_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(hero_selection_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_hero_button(hero: Hero, mission: Mission, can_use: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	if can_use:
		style.bg_color = Color("#0f1624")
		style.border_color = Color("#4ecca3")
	else:
		style.bg_color = Color("#1a1a1a")
		style.border_color = Color("#555555")
	
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1, 1, 1, 0.1)
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	panel.add_child(btn)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 5)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_vbox)
	
	var name_label := Label.new()
	name_label.text = "%s %s (Lv.%d)" % [hero.hero_emoji, hero.hero_name, hero.level]
	name_label.add_theme_font_size_override("font_size", 18)
	if can_use:
		name_label.add_theme_color_override("font_color", Color("#00d9ff"))
	else:
		name_label.add_theme_color_override("font_color", Color("#666666"))
	left_vbox.add_child(name_label)
	
	var stats_label := Label.new()
	stats_label.text = "💪 %d  ⚡ %d  🧠 %d" % [hero.get_total_strength(), hero.get_total_speed(), hero.get_total_intelligence()]
	stats_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(stats_label)
	
	var has_match = false
	for spec in mission.preferred_specialties:
		if spec in hero.specialties:
			has_match = true
			break
	
	if has_match:
		var match_label := Label.new()
		match_label.text = "✨ Specialty Match!"
		match_label.add_theme_font_size_override("font_size", 14)
		match_label.add_theme_color_override("font_color", Color("#ffcc00"))
		left_vbox.add_child(match_label)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 5)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_vbox)
	
	var energy_label := Label.new()
	energy_label.text = "Energy"
	energy_label.add_theme_font_size_override("font_size", 12)
	energy_label.add_theme_color_override("font_color", Color("#a8a8a8"))
	right_vbox.add_child(energy_label)
	
	var energy_bar := ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(120, 20)
	energy_bar.max_value = 100
	energy_bar.value = rapid_manager.get_hero_energy(hero.hero_id)
	
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("#1a1a2e")
	energy_bar.add_theme_stylebox_override("background", bar_bg)
	
	var bar_fill := StyleBoxFlat.new()
	if can_use:
		bar_fill.bg_color = Color("#4ecca3")
	else:
		bar_fill.bg_color = Color("#555555")
	energy_bar.add_theme_stylebox_override("fill", bar_fill)
	
	right_vbox.add_child(energy_bar)
	
	var energy_text := Label.new()
	energy_text.text = "%.0f%%" % rapid_manager.get_hero_energy(hero.hero_id)
	energy_text.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(energy_text)
	
	if not can_use:
		var status := Label.new()
		if not hero.is_available():
			status.text = "❌ " + hero.get_status_text()
		else:
			status.text = "😓 Not enough energy"
		status.add_theme_font_size_override("font_size", 12)
		status.add_theme_color_override("font_color", Color("#ff6b6b"))
		left_vbox.add_child(status)
	
	if can_use:
		btn.pressed.connect(func(): _on_hero_selected(hero))
	else:
		btn.disabled = true
	
	return panel

func _on_hero_selected(hero: Hero) -> void:
	selected_hero = hero
	_close_hero_selection()
	_on_accept_with_hero(hero)

func _close_hero_selection() -> void:
	if not hero_selection_overlay.visible:
		return
	
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(hero_selection_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_property(hero_selection_panel, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_callback(func(): hero_selection_overlay.visible = false)

func _on_accept_with_hero(hero: Hero) -> void:
	if not rapid_manager:
		return
	
	var mission = rapid_manager.get_current_mission()
	if not mission:
		return
	
	if rapid_manager.active_slots.size() >= rapid_manager.MAX_ACTIVE_SLOTS:
		game_manager.update_status("❌ All mission slots full!")
		return
	
	rapid_manager.mission_queue.erase(mission)
	rapid_manager._fill_mission_queue()
	
	rapid_manager.hero_energy[hero.hero_id] -= rapid_manager.ENERGY_DRAIN_PER_MISSION
	if rapid_manager.hero_energy[hero.hero_id] <= 0:
		rapid_manager.hero_energy[hero.hero_id] = 0
		rapid_manager.hero_energy_depleted.emit(hero)
	
	mission.assigned_hero_ids.append(hero.hero_id)
	mission.start_mission([hero])
	
	rapid_manager.active_slots.append({
		"mission": mission,
		"hero": hero,
		"time_remaining": mission.base_duration
	})
	
	rapid_manager.current_streak += 1
	if rapid_manager.current_streak > rapid_manager.best_streak:
		rapid_manager.best_streak = rapid_manager.current_streak
	rapid_manager.streak_increased.emit(rapid_manager.current_streak)
	
	print("✅ MISSION ACCEPTED: %s by %s (Streak: %d)" % [mission.mission_name, hero.hero_name, rapid_manager.current_streak])
	
	rapid_manager.mission_accepted.emit(mission)
	
	_update_mission_card()
	_update_active_missions()
