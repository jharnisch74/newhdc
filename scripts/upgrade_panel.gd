# res://scripts/upgrade_panel.gd
extends CanvasLayer

# UI References
@onready var overlay: ColorRect = $Overlay
@onready var close_button: Button = $Overlay/CenterContainer/UpgradeWindow/MarginContainer/VBoxContainer/Header/CloseButton
@onready var upgrade_list: VBoxContainer = $Overlay/CenterContainer/UpgradeWindow/MarginContainer/VBoxContainer/ScrollContainer/UpgradeList
@onready var cost_label: Label = $Overlay/CenterContainer/UpgradeWindow/MarginContainer/VBoxContainer/CostLabel

# Data
var game_manager: Node
var hero_expansion_states: Dictionary = {} 

# Constants
const HEADER_COLOR = Color("#16213e")
const FONT_COLOR = Color("#00d9ff")
const UPGRADE_COLOR = Color("#4ecca3")
const UPGRADE_HOVER_COLOR = Color("#45b393")

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	overlay.gui_input.connect(_on_overlay_input)

func show_panel(gm: Node) -> void:
	game_manager = gm
	visible = true
	_populate_upgrades()

func hide_panel() -> void:
	visible = false

func _on_close_pressed() -> void:
	hide_panel()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var window = $Overlay/CenterContainer/UpgradeWindow
		var window_rect = Rect2(window.global_position, window.size)
		if not window_rect.has_point(event.position):
			hide_panel()

func _populate_upgrades() -> void:
	# Capture current expanded state
	var current_states: Dictionary = {}
	for child in upgrade_list.get_children():
		if child is Button and child.has_meta("hero_name"):
			var hero_name = child.get_meta("hero_name")
			var next_child_index = child.get_index() + 1
			if next_child_index < upgrade_list.get_child_count():
				var upgrade_content = upgrade_list.get_child(next_child_index)
				if upgrade_content is VBoxContainer:
					current_states[hero_name] = upgrade_content.visible
	
	# Clear existing items
	for child in upgrade_list.get_children():
		child.queue_free()
	
	if not game_manager:
		return
	
	hero_expansion_states = current_states
	
	# Create a collapsible section for each hero
	for hero in game_manager.heroes:
		_create_hero_collapsible_section(hero)
	
	# Update cost label
	var total_money = game_manager.money
	cost_label.text = "💰 Available: $%d" % total_money

func _create_hero_collapsible_section(hero: Hero) -> void:
	# Header Button
	var toggle_button = Button.new()
	toggle_button.text = "%s %s (Lv.%d) - Power: %d" % [
		hero.hero_emoji, 
		hero.hero_name, 
		hero.level,
		hero.get_power_rating()
	]
	toggle_button.set_meta("hero_name", hero.hero_name)
	toggle_button.add_theme_font_size_override("font_size", 18)
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = HEADER_COLOR
	btn_style.set_corner_radius_all(5)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	toggle_button.add_theme_stylebox_override("normal", btn_style)
	toggle_button.add_theme_stylebox_override("hover", btn_style)
	toggle_button.add_theme_color_override("font_color", FONT_COLOR)

	upgrade_list.add_child(toggle_button)

	# Content Container
	var upgrade_content = VBoxContainer.new()
	var should_be_expanded = hero_expansion_states.get(hero.hero_name, false)
	upgrade_content.visible = should_be_expanded
	upgrade_content.add_theme_constant_override("separation", 8)
	
	# Hero Status Info
	var status_panel = _create_hero_status_panel(hero)
	upgrade_content.add_child(status_panel)
	
	# Add separator
	var sep = HSeparator.new()
	upgrade_content.add_child(sep)
	
	# Stat Upgrades
	var stats = [
		{"type": "strength", "label": "💪 Strength", "current": hero.get_total_strength()},
		{"type": "speed", "label": "⚡ Speed", "current": hero.get_total_speed()},
		{"type": "intelligence", "label": "🧠 Intelligence", "current": hero.get_total_intelligence()},
		{"type": "max_health", "label": "❤️ Max Health", "current": int(hero.max_health)},
		{"type": "max_stamina", "label": "⚡ Max Stamina", "current": int(hero.max_stamina)}
	]
	
	for stat in stats:
		var item = _create_upgrade_item(hero, stat.type, stat.label, stat.current)
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 15)
		margin_container.add_child(item)
		upgrade_content.add_child(margin_container)
	
	upgrade_list.add_child(upgrade_content)
	
	# Connect toggle
	toggle_button.pressed.connect(func(): 
		upgrade_content.visible = !upgrade_content.visible
	)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	upgrade_list.add_child(spacer)

func _create_hero_status_panel(hero: Hero) -> PanelContainer:
	var panel = PanelContainer.new()
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0f1624")
	panel_style.set_corner_radius_all(8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("#4ecca3")
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Status
	var status_label = Label.new()
	status_label.text = "Status: " + hero.get_status_text()
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)
	
	# Health bar
	var health_container = VBoxContainer.new()
	health_container.add_theme_constant_override("separation", 3)
	vbox.add_child(health_container)
	
	var health_label = Label.new()
	health_label.text = "❤️ Health: %.0f / %.0f" % [hero.current_health, hero.max_health]
	health_label.add_theme_font_size_override("font_size", 12)
	health_container.add_child(health_label)
	
	var health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 16)
	health_bar.max_value = hero.max_health
	health_bar.value = hero.current_health
	health_bar.show_percentage = false
	
	var health_bg = StyleBoxFlat.new()
	health_bg.bg_color = Color("#1a1a2e")
	health_bar.add_theme_stylebox_override("background", health_bg)
	
	var health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("#ff6b6b")
	health_bar.add_theme_stylebox_override("fill", health_fill)
	
	health_container.add_child(health_bar)
	
	# Stamina bar
	var stamina_container = VBoxContainer.new()
	stamina_container.add_theme_constant_override("separation", 3)
	vbox.add_child(stamina_container)
	
	var stamina_label = Label.new()
	stamina_label.text = "⚡ Stamina: %.0f / %.0f" % [hero.current_stamina, hero.max_stamina]
	stamina_label.add_theme_font_size_override("font_size", 12)
	stamina_container.add_child(stamina_label)
	
	var stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(0, 16)
	stamina_bar.max_value = hero.max_stamina
	stamina_bar.value = hero.current_stamina
	stamina_bar.show_percentage = false
	
	var stamina_bg = StyleBoxFlat.new()
	stamina_bg.bg_color = Color("#1a1a2e")
	stamina_bar.add_theme_stylebox_override("background", stamina_bg)
	
	var stamina_fill = StyleBoxFlat.new()
	stamina_fill.bg_color = Color("#00d9ff")
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	
	stamina_container.add_child(stamina_bar)
	
	# Experience
	var exp_label = Label.new()
	exp_label.text = "✨ Experience: %d / %d" % [hero.experience, hero.exp_to_next_level]
	exp_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(exp_label)
	
	var exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(0, 12)
	exp_bar.max_value = hero.exp_to_next_level
	exp_bar.value = hero.experience
	exp_bar.show_percentage = false
	
	var exp_bg = StyleBoxFlat.new()
	exp_bg.bg_color = Color("#1a1a2e")
	exp_bar.add_theme_stylebox_override("background", exp_bg)
	
	var exp_fill = StyleBoxFlat.new()
	exp_fill.bg_color = Color("#ffd700")
	exp_bar.add_theme_stylebox_override("fill", exp_fill)
	
	vbox.add_child(exp_bar)
	
	# Specialties
	var spec_label = Label.new()
	var spec_text = "🎯 Specialties: "
	var spec_names = []
	for spec in hero.specialties:
		match spec:
			Hero.Specialty.COMBAT:
				spec_names.append("Combat")
			Hero.Specialty.SPEED:
				spec_names.append("Speed")
			Hero.Specialty.TECH:
				spec_names.append("Tech")
			Hero.Specialty.RESCUE:
				spec_names.append("Rescue")
			Hero.Specialty.INVESTIGATION:
				spec_names.append("Investigation")
	spec_text += ", ".join(spec_names)
	spec_label.text = spec_text
	spec_label.add_theme_font_size_override("font_size", 12)
	spec_label.add_theme_color_override("font_color", Color("#ffcc00"))
	vbox.add_child(spec_label)
	
	return panel

func _create_upgrade_item(hero: Hero, stat_type: String, label_text: String, current_value: int) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.alignment = HBoxContainer.ALIGNMENT_CENTER
	
	# Stat label
	var stat_label = Label.new()
	stat_label.text = "%s: %d" % [label_text, current_value]
	stat_label.add_theme_font_size_override("font_size", 16)
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(stat_label)
	
	# Cost label
	var cost = hero.get_upgrade_cost(stat_type)
	var cost_lbl = Label.new()
	cost_lbl.text = "$%d" % cost
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", UPGRADE_COLOR)
	container.add_child(cost_lbl)
	
	# Upgrade button
	var upgrade_btn = Button.new()
	upgrade_btn.text = "UPGRADE"
	upgrade_btn.custom_minimum_size = Vector2(100, 0)
	
	var can_afford = game_manager and game_manager.money >= cost
	upgrade_btn.disabled = not can_afford
	
	if can_afford:
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = UPGRADE_COLOR
		btn_style_normal.set_corner_radius_all(5)
		upgrade_btn.add_theme_stylebox_override("normal", btn_style_normal)
		
		var btn_style_hover = StyleBoxFlat.new()
		btn_style_hover.bg_color = UPGRADE_HOVER_COLOR
		btn_style_hover.set_corner_radius_all(5)
		upgrade_btn.add_theme_stylebox_override("hover", btn_style_hover)
	else:
		upgrade_btn.add_theme_color_override("font_color", Color("#666666"))
	
	upgrade_btn.pressed.connect(func(): _on_upgrade_pressed(hero, stat_type))
	container.add_child(upgrade_btn)
	
	return container

func _on_upgrade_pressed(hero: Hero, stat_type: String) -> void:
	if game_manager:
		if game_manager.upgrade_hero_stat(hero, stat_type):
			_populate_upgrades()
