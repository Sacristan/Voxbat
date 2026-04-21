extends Control

const PORT := 7777

const ADJECTIVES := ["Iron", "Swift", "Dark", "Bold", "Grim", "Wild", "Sly", "Grim",
		"Rust", "Ash", "Stone", "Frost", "Bleak", "Dusk", "Pale", "Worn"]
const NOUNS := ["Wolf", "Fox", "Bear", "Hawk", "Crow", "Fist", "Blade", "Toad",
		"Mole", "Rat", "Newt", "Slug", "Wasp", "Moth", "Grub", "Bat"]

@onready var host_name_field: LineEdit = $CenterContainer/VBoxContainer/HostRow/HostNameField
@onready var host_btn: Button = $CenterContainer/VBoxContainer/HostRow/HostButton
@onready var refresh_btn: Button = $CenterContainer/VBoxContainer/BrowseHeader/RefreshButton
@onready var game_list_container: VBoxContainer = $CenterContainer/VBoxContainer/GameScrollContainer/GameListContainer
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_btn: Button = $CenterContainer/VBoxContainer/BackButton

var _hosted_game_key: String = ""
var _firebase_available: bool = false


func _ready() -> void:
	host_name_field.text = _random_name()
	host_btn.pressed.connect(_on_host_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	var db_url: String = Config.get_value("firebase.database_url")
	if db_url.is_empty():
		_set_status("Set firebase.database_url in config.json to enable game browser.")
		refresh_btn.disabled = true
	else:
		_firebase_available = true
		_refresh_game_list()


func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		_set_status("Failed to start server (port %d in use?)" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameState.is_multiplayer = true
	GameState.is_host = true
	GameState.my_peer_id = 1
	_set_ui_busy(true)
	_set_status("Hosting on port %d..." % PORT)

	if _firebase_available:
		var ip := await MasterServer.get_public_ip()
		if ip.is_empty():
			_set_status("Hosting on port %d — could not get public IP, game not listed." % PORT)
		else:
			var game_name := host_name_field.text.strip_edges()
			if game_name.is_empty():
				game_name = _random_name()
			_hosted_game_key = await MasterServer.register_game(game_name, ip, PORT)
			_set_status("Hosting on port %d — waiting for opponent..." % PORT)


func _join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		_set_status("Failed to connect to %s:%d" % [ip, PORT])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameState.is_multiplayer = true
	GameState.is_host = false
	_set_ui_busy(true)
	_set_status("Connecting to %s:%d..." % [ip, PORT])


func _on_refresh_pressed() -> void:
	_refresh_game_list()


func _on_peer_connected(_id: int) -> void:
	_set_status("Opponent connected! Starting...")
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connected_to_server() -> void:
	GameState.my_peer_id = multiplayer.get_unique_id()
	_set_status("Connected! Starting...")
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connection_failed() -> void:
	_set_status("Connection failed.")
	multiplayer.multiplayer_peer = null
	GameState.is_multiplayer = false
	GameState.is_host = false
	_set_ui_busy(false)


func _on_peer_disconnected(_id: int) -> void:
	_set_status("Opponent disconnected.")


func _on_back_pressed() -> void:
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	GameState.is_multiplayer = false
	GameState.is_host = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _refresh_game_list() -> void:
	refresh_btn.disabled = true
	_clear_game_list()
	var placeholder := Label.new()
	placeholder.text = "Loading..."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_list_container.add_child(placeholder)

	var games: Array = await MasterServer.list_games()
	_clear_game_list()

	if games.is_empty():
		var lbl := Label.new()
		lbl.text = "No games found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_list_container.add_child(lbl)
	else:
		for game in games:
			var btn := Button.new()
			btn.text = game.get("game_name", "?")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var ip: String = game.get("ip", "")
			btn.pressed.connect(func(): _join_game(ip))
			game_list_container.add_child(btn)

	refresh_btn.disabled = false


func _clear_game_list() -> void:
	for child in game_list_container.get_children():
		child.queue_free()


func _set_ui_busy(busy: bool) -> void:
	host_btn.disabled = busy
	refresh_btn.disabled = busy


func _set_status(text: String) -> void:
	status_label.text = text


func _random_name() -> String:
	return ADJECTIVES[randi() % ADJECTIVES.size()] + NOUNS[randi() % NOUNS.size()]
