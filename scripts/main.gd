# res://scripts/main.gd
# Main script with map-based UI and chaos level display
extends Control

# UI Node References - assigned from scene
@onready var money_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/ResourceVBox/MoneyLabel
@onready var fame_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/ResourceVBox/FameLabel
@onready var title_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/TitleLabel
@onready var content_container: VBoxContainer = $MainMargin/MainLayout/ContentContainer 
@onready var upgrade_button: Button = $MainMargin/MainLayout/ButtonBar/UpgradeButton
@onready var recruit_button: Button = $MainMargin/MainLayout/ButtonBar/RecruitButton

# Game Manager
var game_manager: Node

# Save Manager
var save_manager: Node

# Rapid Response System
var rapid_manager: RapidResponseManager
var map_ui: Control
var mission_results_panel: Control 

# Chaos Level Bar
var chaos_bar: Control

# Upgrade and recruitment panels
var upgrade_panel: CanvasLayer
var recruitment_panel: CanvasLayer

func _ready() -> void:
	_initialize_game_manager()
	_initialize_save_manager()
	
	# Create chaos bar
	_create_chaos_bar()
	
	# Connect button signals
	upgrade_button.pressed.connect(_show_upgrade_panel)
	recruit_button.pressed.connect(_show_recruitment_panel)
	
	await _initialize_rapid_response()
	_setup_upgrade_panel()
	_setup_recruitment_panel()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Try to load save (Uncomment when ready)
	#if not save_manager.load_game():
	#	_initial_ui_update()
	#else:
	#	_refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_manager:
			save_manager.save_game()
		get_tree().quit()

func _initialize_game_manager() -> void:
	game_manager = Node.new()
	game_manager.name = "GameManager"
	game_manager.set_script(preload("res://scripts/game_manager_rapid.gd"))
	add_child(game_manager)
	
	game_manager.money_label = money_label
	game_manager.fame_label = fame_label
	
	game_manager.hero_updated.connect(_on_hero_updated)

func _initialize_save_manager() -> void:
	save_manager = Node.new()
	save_manager.name = "SaveManager"
	save_manager.set_script(preload("res://scripts/save_manager_rapid.gd"))
	add_child(save_manager)
	
	save_manager.set_game_manager(game_manager)

func _create_chaos_bar() -> void:
	"""Create and add the chaos level bar to the UI"""
	# Create chaos bar - use PanelContainer since that's what the script inherits from
	chaos_bar = PanelContainer.new()
	chaos_bar.name = "ChaosLevelBar"
	chaos_bar.set_script(preload("res://scripts/chaos_level_bar.gd"))
	
	# Add to content container (before other content)
	content_container.add_child(chaos_bar)
	content_container.move_child(chaos_bar, 0)  # Move to top
	
	# Setup after game manager is ready
	await get_tree().process_frame
	
	if chaos_bar.has_method("setup"):
		chaos_bar.setup(game_manager)

# Add this to your _initialize_rapid_response() function in main.gd
# After creating the map_ui and setting it up

func _initialize_rapid_response() -> void:
	rapid_manager = RapidResponseManager.new(game_manager)
	rapid_manager.name = "RapidResponseManager"
	add_child(rapid_manager)
	
	game_manager.rapid_manager = rapid_manager
	
	await get_tree().process_frame
	
	# 1. Create MAP UI
	map_ui = Control.new()
	map_ui.name = "MapMissionUI"
	map_ui.set_script(preload("res://scripts/map_mission_ui.gd"))
	map_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	content_container.add_child(map_ui)
	
	# 2. Create Mission Results Panel
	mission_results_panel = Control.new()
	mission_results_panel.name = "MissionResultsPanel"
	mission_results_panel.set_script(preload("res://scripts/mission_results_panel.gd"))
	mission_results_panel.custom_minimum_size = Vector2(0, 150)
	content_container.add_child(mission_results_panel)
	
	await get_tree().process_frame
	
	if map_ui.has_method("setup"):
		map_ui.setup(rapid_manager, game_manager)
	
	if mission_results_panel.has_method("setup"):
		mission_results_panel.setup(game_manager)
		
	game_manager.mission_completed.connect(mission_results_panel._on_mission_completed)
	
	# NEW: Connect chaos display to map centering
	# Find the chaos display in the scene (you'll need to get a reference to it)
	# If it's in the header or somewhere else in your UI:
	var chaos_display = find_chaos_display_in_tree()
	if chaos_display and chaos_display.has_signal("zone_clicked"):
		chaos_display.zone_clicked.connect(_on_chaos_zone_clicked)

# NEW: Handler for chaos display zone clicks
func _on_chaos_zone_clicked(zone_id: String) -> void:
	if map_ui and map_ui.has_method("_center_on_zone"):
		map_ui._center_on_zone(zone_id)

# NEW: Helper to find the chaos display in your scene tree
func find_chaos_display_in_tree() -> Node:
	# Adjust this path to match where your chaos display actually is
	# For example, if it's in the header:
	# return $MainMargin/MainLayout/HeaderPanel/ChaosDisplay
	
	# Or search recursively:
	return _find_node_by_script(self, "res://scripts/chaos_display.gd")

func _find_node_by_script(node: Node, script_path: String) -> Node:
	if node.get_script() and node.get_script().resource_path == script_path:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_script(child, script_path)
		if result:
			return result
	
	return null 

func _setup_upgrade_panel() -> void:
	call_deferred("_load_upgrade_panel")

func _load_upgrade_panel() -> void:
	var upgrade_scene = load("res://scenes/ui/upgrade_panel.tscn")
	if upgrade_scene:
		upgrade_panel = upgrade_scene.instantiate()
		add_child(upgrade_panel)
	else:
		print("Warning: upgrade_panel.tscn not found")

func _setup_recruitment_panel() -> void:
	call_deferred("_load_recruitment_panel")

func _load_recruitment_panel() -> void:
	recruitment_panel = CanvasLayer.new()
	recruitment_panel.name = "RecruitmentPanel"
	recruitment_panel.set_script(preload("res://scripts/recruitment_panel.gd"))
	add_child(recruitment_panel)
	
	if recruitment_panel.has_method("setup"):
		recruitment_panel.setup(game_manager, game_manager.recruitment_system)

func _initial_ui_update() -> void:
	money_label.text = "💰 Money: $%d" % game_manager.money
	fame_label.text = "⭐ Fame: %d" % game_manager.fame

func _refresh_ui() -> void:
	money_label.text = "💰 Money: $%d" % game_manager.money
	fame_label.text = "⭐ Fame: %d" % game_manager.fame

func _on_hero_updated(_hero: Hero) -> void:
	pass

func _input(event: InputEvent) -> void:
	# Debug hotkeys
	if event.is_action_pressed("ui_cancel"):
		if Input.is_key_pressed(KEY_F9):
			_debug_reset_heroes()
		elif Input.is_key_pressed(KEY_F8):
			_debug_delete_save()
		elif Input.is_key_pressed(KEY_F7):
			_show_upgrade_panel()
		elif Input.is_key_pressed(KEY_F6):
			_show_recruitment_panel()
		elif Input.is_key_pressed(KEY_F5):
			_debug_add_chaos()
		elif Input.is_key_pressed(KEY_F4):
			_debug_clear_chaos()

func _debug_reset_heroes() -> void:
	print("🔧 RESETTING ALL HEROES")
	for hero in game_manager.heroes:
		hero.is_on_mission = false
		hero.is_recovering = false
		hero.recovery_time_remaining = 0.0
		hero.current_mission_id = ""
		hero.current_health = hero.max_health
		hero.current_stamina = hero.max_stamina
	
	if rapid_manager:
		for hero_id in rapid_manager.hero_energy.keys():
			rapid_manager.hero_energy[hero_id] = 100.0
	
	print("  ✅ All heroes reset!")

func _debug_delete_save() -> void:
	print("🗑️ DELETING SAVE FILE")
	const SAVE_PATH = "user://hero_dispatch_save_rapid.json"
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("  ✅ Save deleted")
	
	get_tree().reload_current_scene()

func _debug_add_chaos() -> void:
	print("🔥 ADDING CHAOS TO ALL ZONES")
	if game_manager and game_manager.chaos_system:
		for zone in game_manager.chaos_system.zone_chaos.keys():
			var current = game_manager.chaos_system.zone_chaos[zone]
			game_manager.chaos_system.zone_chaos[zone] = min(100.0, current + 20.0)
			print("  %s: %.0f%% -> %.0f%%" % [zone, current, game_manager.chaos_system.zone_chaos[zone]])

func _debug_clear_chaos() -> void:
	print("✨ CLEARING CHAOS FROM ALL ZONES")
	if game_manager and game_manager.chaos_system:
		game_manager.chaos_system.reset()

func _show_upgrade_panel() -> void:
	if upgrade_panel and upgrade_panel.has_method("show_panel"):
		upgrade_panel.show_panel(game_manager)

func _show_recruitment_panel() -> void:
	if recruitment_panel and recruitment_panel.has_method("show_panel"):
		recruitment_panel.show_panel()
