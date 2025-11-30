# res://scripts/main.gd
# Simplified main script - UI structure now in scene file
extends Control

# UI Node References - assigned from scene
@onready var money_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/ResourceVBox/MoneyLabel
@onready var fame_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/ResourceVBox/FameLabel
@onready var title_label: Label = $MainMargin/MainLayout/HeaderPanel/MarginContainer/HBoxContainer/TitleLabel
@onready var content_container: CenterContainer = $MainMargin/MainLayout/ContentContainer
@onready var upgrade_button: Button = $MainMargin/MainLayout/ButtonBar/UpgradeButton
@onready var recruit_button: Button = $MainMargin/MainLayout/ButtonBar/RecruitButton

# Game Manager
var game_manager: Node

# Save Manager
var save_manager: Node

# Rapid Response System
var rapid_manager: RapidResponseManager
var rapid_ui: Control

# Upgrade and recruitment panels
var upgrade_panel: CanvasLayer
var recruitment_panel: CanvasLayer

func _ready() -> void:
	_initialize_game_manager()
	_initialize_save_manager()
	await _initialize_rapid_response()
	_setup_upgrade_panel()
	_setup_recruitment_panel()
	
	# Connect button signals
	upgrade_button.pressed.connect(_show_upgrade_panel)
	recruit_button.pressed.connect(_show_recruitment_panel)
	
	# Wait for UI to be laid out
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Try to load save
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
	
	# Connect references
	game_manager.money_label = money_label
	game_manager.fame_label = fame_label
	
	# Connect signals
	game_manager.hero_updated.connect(_on_hero_updated)

func _initialize_save_manager() -> void:
	save_manager = Node.new()
	save_manager.name = "SaveManager"
	save_manager.set_script(preload("res://scripts/save_manager_rapid.gd"))
	add_child(save_manager)
	
	save_manager.set_game_manager(game_manager)

func _initialize_rapid_response() -> void:
	# Create rapid response manager
	rapid_manager = RapidResponseManager.new(game_manager)
	rapid_manager.name = "RapidResponseManager"
	add_child(rapid_manager)
	
	# Store reference in game manager
	game_manager.rapid_manager = rapid_manager
	
	# Wait a frame for manager to be ready
	await get_tree().process_frame
	
	# Load rapid response UI scene
	var rapid_ui_scene = load("res://scenes/ui/rapid_response_ui.tscn")
	if rapid_ui_scene:
		rapid_ui = rapid_ui_scene.instantiate()
		rapid_ui.name = "RapidResponseUI"
		content_container.add_child(rapid_ui)
		
		# Wait for UI to be in tree
		await get_tree().process_frame
		
		# Setup UI
		if rapid_ui.has_method("setup"):
			rapid_ui.setup(rapid_manager, game_manager)
	else:
		push_error("Failed to load rapid_response_ui.tscn")
		# Fallback to code-based UI
		_create_fallback_ui()

func _create_fallback_ui() -> void:
	"""Fallback if scene file is missing"""
	rapid_ui = Control.new()
	rapid_ui.name = "RapidResponseUI"
	rapid_ui.set_script(preload("res://scripts/rapid_response_ui.gd"))
	content_container.add_child(rapid_ui)
	
	await get_tree().process_frame
	
	if rapid_ui.has_method("setup"):
		rapid_ui.setup(rapid_manager, game_manager)

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

func _show_upgrade_panel() -> void:
	if upgrade_panel and upgrade_panel.has_method("show_panel"):
		upgrade_panel.show_panel(game_manager)

func _show_recruitment_panel() -> void:
	if recruitment_panel and recruitment_panel.has_method("show_panel"):
		recruitment_panel.show_panel()
