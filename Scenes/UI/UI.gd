extends Control

# References to UI elements
@onready var health_bars_container = $HealthBarsContainer
@onready var timer_label = $TimerLabel
@onready var prompt_input = $WeaponPromptContainer/PromptInput
@onready var forge_button = $WeaponPromptContainer/ForgeButton

# Dictionary to store health bars for each player
var player_health_bars = {}

# Round timer
var round_time_remaining = 0


func _ready():
	# Connect the Forge button
	forge_button.pressed.connect(_on_forge_button_pressed)

	# Set up prompt input placeholder
	prompt_input.placeholder_text = "Enter weapon prompt..."

	# Initialize timer display
	_update_timer_display()

	# Try to connect to RoundManager if it exists
	_connect_to_round_manager()

	print("UI initialized and ready")


func _connect_to_round_manager():
	# Look for RoundManager in the scene tree
	var round_manager = get_node_or_null("/root/RoundManager")
	if round_manager == null:
		# Try finding it as an autoload or in the main scene
		round_manager = get_tree().root.get_node_or_null("RoundManager")

	if round_manager:
		# Connect to round manager signals if they exist
		if round_manager.has_signal("round_time_updated"):
			round_manager.round_time_updated.connect(_on_round_time_updated)
		if round_manager.has_signal("round_started"):
			round_manager.round_started.connect(_on_round_started)
		if round_manager.has_signal("round_ended"):
			round_manager.round_ended.connect(_on_round_ended)
		print("Connected to RoundManager")
	else:
		print("RoundManager not found - timer will need manual updates")


# Called when a player joins the game
func add_player_health_bar(player_id: int, player_name: String = ""):
	if player_id in player_health_bars:
		return # Already exists

	# Create a container for this player's health bar
	var player_container = HBoxContainer.new()

	# Player name label
	var name_label = Label.new()
	name_label.text = player_name if player_name else "Player " + str(player_id)
	name_label.custom_minimum_size = Vector2(100, 0)
	player_container.add_child(name_label)

	# Health bar (ProgressBar)
	var health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.custom_minimum_size = Vector2(200, 20)
	health_bar.show_percentage = true
	player_container.add_child(health_bar)

	# Add to container
	health_bars_container.add_child(player_container)

	# Store reference
	player_health_bars[player_id] = {
		"container": player_container,
		"health_bar": health_bar,
		"name_label": name_label
	}

	print("Added health bar for player ", player_id)


# Called when player health changes (connected to Player.gd signal)
func _on_player_health_changed(player_id: int, new_health: float):
	if player_id not in player_health_bars:
		# Player doesn't exist yet, create their health bar
		add_player_health_bar(player_id)

	var health_bar = player_health_bars[player_id]["health_bar"]
	health_bar.value = new_health

	# Optional: Change color based on health
	if new_health <= 25:
		health_bar.modulate = Color(1, 0.3, 0.3) # Red
	elif new_health <= 50:
		health_bar.modulate = Color(1, 0.8, 0.3) # Orange
	else:
		health_bar.modulate = Color(1, 1, 1) # White


# Remove a player's health bar
func remove_player_health_bar(player_id: int):
	if player_id in player_health_bars:
		player_health_bars[player_id]["container"].queue_free()
		player_health_bars.erase(player_id)


# Round timer functions
func _on_round_time_updated(time_remaining: float):
	round_time_remaining = time_remaining
	_update_timer_display()


func _on_round_started(duration: float):
	round_time_remaining = duration
	_update_timer_display()


func _on_round_ended():
	timer_label.text = "Round Over!"


func _update_timer_display():
	var minutes = int(round_time_remaining) / 60
	var seconds = int(round_time_remaining) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]


# Weapon forging
func _on_forge_button_pressed():
	var prompt = prompt_input.text.strip_edges()

	if prompt.is_empty():
		print("No prompt entered")
		return

	# Try to find AIClient
	var ai_client = get_node_or_null("/root/AIClient")
	if ai_client == null:
		ai_client = get_tree().root.get_node_or_null("AIClient")

	if ai_client and ai_client.has_method("forge_weapon"):
		print("Forging weapon with prompt: ", prompt)
		ai_client.forge_weapon(prompt)

		# Clear the input
		prompt_input.text = ""

		# Optional: Show feedback
		_show_forge_feedback("Forging weapon...")
	else:
		print("AIClient not found - weapon forging unavailable")


func _show_forge_feedback(message: String):
	# Optional visual feedback when forging
	forge_button.text = message
	forge_button.disabled = true

	# Re-enable after a short delay
	await get_tree().create_timer(1.0).timeout
	forge_button.text = "Forge"
	forge_button.disabled = false


# Called when a weapon is spawned (connect to AIClient signal)
func _on_weapon_spawned(weapon_name: String, player_id: int):
	print("Weapon spawned: ", weapon_name, " for player ", player_id)
	# Optional: Show notification or visual feedback


# Public method for manual timer updates (if RoundManager doesn't have signals)
func update_timer(time_remaining: float):
	round_time_remaining = time_remaining
	_update_timer_display()


# Connect to players dynamically when they join
func connect_to_player(player: Node):
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
		print("Connected to player signals: ", player.name)


# Connect to AIClient signals
func connect_to_ai_client():
	var ai_client = get_node_or_null("/root/AIClient")
	if ai_client == null:
		ai_client = get_tree().root.get_node_or_null("AIClient")

	if ai_client and ai_client.has_signal("weapon_spawned"):
		ai_client.weapon_spawned.connect(_on_weapon_spawned)
		print("Connected to AIClient signals")
