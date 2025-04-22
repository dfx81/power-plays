extends Node2D

@export var menu_camera : Camera2D
@export var message_dialog : Control
@export var main_screen : Node2D
@export var host_screen : Node2D
@export var join_screen : Node2D

@export var game_scene : PackedScene

var peer: ENetMultiplayerPeer
var players: Dictionary[int, String] = {}
var user_name: String = ""
var matchmaking: bool = false

var game: Game = null

func _ready() -> void:
	var network_access: bool = OS.request_permissions()
	
	if !network_access:
		%HostBtn.disabled = true
		%JoinBtn.disabled = true
	
	peer = ENetMultiplayerPeer.new()
	multiplayer.peer_connected.connect(on_player_connected)
	multiplayer.peer_disconnected.connect(on_player_disconnected)
	multiplayer.connected_to_server.connect(on_server_connected)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connection_failed.connect(on_connection_failed)

func _process(_delta: float) -> void:
	if matchmaking and len(players.keys()) == 2 && multiplayer.is_server():
		matchmaking = false
		load_game.rpc()

@rpc("call_local", "reliable")
func load_game():
	var game_instance: Game = game_scene.instantiate()
	game_instance.players = players
	game_instance.disconnect_from_game.connect(end_game)
	%GameLayer.add_child(game_instance, true)
	game = game_instance

func end_game():
	game.queue_free()
	multiplayer.multiplayer_peer = null
	game = null
	get_tree().reload_current_scene()

func _on_host_btn_pressed() -> void:
	var address: String

	if OS.has_feature("windows"):
		if OS.has_environment("COMPUTERNAME"):
			address =  IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")), IP.TYPE_IPV4)
	elif OS.has_feature("x11"):
		if OS.has_environment("HOSTNAME"):
			address =  IP.resolve_hostname(str(OS.get_environment("HOSTNAME")), IP.TYPE_IPV4)
	elif OS.has_feature("OSX"):
		if OS.has_environment("HOSTNAME"):
			address =  IP.resolve_hostname(str(OS.get_environment("HOSTNAME")), IP.TYPE_IPV4)
	else:
		if OS.has_environment("HOSTNAME"):
			address =  IP.resolve_hostname(str(OS.get_environment("HOSTNAME")), IP.TYPE_IPV4)
	
	for interface in IP.get_local_interfaces():
		if interface["name"] == "wlan0":
			address = interface["addresses"][0]
			break
	
	var ip_parts: PackedStringArray = address.split(".")
	
	address = ""
	
	for part in ip_parts:
		address += ("%X" % int(part)).lpad(2, "0")
		
	%HostCodeLbl.text = "Host Code: %s" % address
	
	var tween : Tween = get_tree().create_tween()
	await tween.tween_property(menu_camera, "position", host_screen.position, 1).set_trans(Tween.TRANS_CIRC).finished
	
	peer.create_server(18000)
	
	multiplayer.multiplayer_peer = peer
	user_name = "PLAYER 1"
	
	players[multiplayer.get_unique_id()] = user_name
	matchmaking = true

func _on_cancel_btn_pressed() -> void:
	var tween : Tween = get_tree().create_tween()
	
	await tween.tween_property(menu_camera, "position", main_screen.position, 1).set_trans(Tween.TRANS_CIRC).finished
	
	if peer:
		multiplayer.multiplayer_peer = null
		players.clear()
		matchmaking = false


func _on_join_btn_pressed() -> void:
	var tween : Tween = get_tree().create_tween()
	
	await tween.tween_property(menu_camera, "position", join_screen.position, 1).set_trans(Tween.TRANS_CIRC).finished


func _on_join_game_btn_pressed() -> void:
	var host_code : String = $JoinScreen/Controls/HBoxContainer/HostCodeInput.text
	host_code.strip_edges()
	
	if len(host_code) != 8:
		%ErrMessageLbl.text = "Please enter a valid code"
		message_dialog.visible = true
	else:
		var address: String = str(host_code.substr(0, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(2, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(4, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(6, 2).to_lower().hex_to_int())
		
		user_name = "PLAYER 2"
		
		peer.create_client(address, 18000)
		multiplayer.multiplayer_peer = peer
		
		players[multiplayer.get_unique_id()] = user_name
		matchmaking = true

func on_player_connected(id: int) -> void:
	print("Connected with id " + str(id))
	add_player.rpc_id(id, user_name)
	print("%s: Connected with %d peers" % [user_name, len(players.keys())])
	print(players)

func on_player_disconnected(id: int) -> void:
	print("Peer id " + str(id) + " disconnected")
	players.erase(id)
	
	if game != null:
		game.on_disconnect()
	
func on_server_connected() -> void:
	print("Connected to server.")
	
func on_server_disconnected() -> void:
	print("Disconnected from server.")
	multiplayer.multiplayer_peer = null
	players.clear()
	matchmaking = false
	
	if game != null:
		game.on_disconnect()
	
func on_connection_failed() -> void:
	print("Connection failed")
	%ErrMessageLbl.text = "Cannot establish connection."
	message_dialog.visible = true
	players.clear()
	multiplayer.multiplayer_peer = null
	matchmaking = false
	
	if game != null:
		game.on_disconnect()

func _on_close_msg_btn_pressed() -> void:
	message_dialog.visible = false

@rpc("any_peer", "reliable")
func add_player(name_val: String):
	var new_peer: int = multiplayer.get_remote_sender_id()
	players[new_peer] = name_val
	print(user_name + ":" + str(players))


func _on_ip_btn_pressed(key: String) -> void:
	%HostCodeInput.text += key if len(%HostCodeInput.text) < 8 else ""


func _on_delete_char_btn_pressed() -> void:
	var cur_text: String = %HostCodeInput.text
	%HostCodeInput.text = cur_text.substr(0, len(cur_text) - 1)
