extends Node3D

@export var game_scene: PackedScene

var peer: ENetMultiplayerPeer
var players: Dictionary[int, Variant] = {}
var matchmaking: bool = false
var game: Game = null

var moves: int = 5
var discards: int = 5

var has_error: bool = false

var you: int = 0
var opponent: int = 0
var game_running = false

func _ready() -> void:
	# Load audio settings
	var audio_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(audio_bus, Globals.audio_state != 1)
	%AudioToggle.button_pressed = Globals.audio_state == 2
	
	$BGM.volume_linear = 1
	%MainScreen.visible = true
	
	# Check for network perms (mobile)
	var network_access: bool = OS.request_permissions()
	
	if !network_access:
		%HostBtn.disabled = true
		%JoinBtn.disabled = true
		return
	
	# Multiplayer setup
	multiplayer.peer_connected.connect(on_player_connected)
	multiplayer.peer_disconnected.connect(on_player_disconnected)
	multiplayer.connected_to_server.connect(on_server_connected)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connection_failed.connect(on_connection_failed)

# Called when all players connected
# Simply load and setup the game instance
@rpc("call_local", "reliable")
func load_game(set_moves: int, set_discards: int):
	var game_instance: Game = game_scene.instantiate()
	game_instance.players = players
	game_instance.moves = set_moves
	game_instance.opponent_moves = set_moves
	game_instance.discards = set_discards
	game_instance.opponent_discards = set_discards
	game_instance.disconnect_from_game.connect(end_game)
	game_instance.view_board.connect(view_board)
	game_instance.view_opponent.connect(view_opponent)
	game_instance.anim_place.connect(opponent_play_anim_place_tile)
	game_instance.anim_nod.connect(opponent_play_anim_nod)
	game_instance.anim_shake.connect(opponent_play_anim_shake)
	game_instance.game_start.connect(game_started)
	game_instance.game_end.connect(game_ended)
	game = game_instance
	$GameCamera.add_child(game_instance, true)

func game_started():
	game_running = true

func game_ended():
	game.visible = true
	game_running = false

# Unused animations
func opponent_play_anim_place_tile():
	var animator: AnimationPlayer = $Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer")
	animator.play("interact-right")
	await animator.animation_finished
	animator.play("idle")
	pass

# Unused animations
func opponent_play_anim_nod():
	#$Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer").play("emote-yes")
	pass

# Unused animations
func opponent_play_anim_shake():
	#$Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer").play("emote-no")
	pass

# Toggle camera to board view
func view_board():
	$GameCamera.current = true
	%ResponseWait.visible = false
	game.visible = true

# Toggle camera to opponent view
func view_opponent():
	$OpponentView.current = true
	%ResponseWait.visible = true
	game.visible = false

# Cleanup after the game ends
func end_game():
	$AnimationPlayer.play_backwards("fade_in")
	await $AnimationPlayer.animation_finished
	game.fade_song()
	await game.audio_muted
	game.queue_free()
	multiplayer.multiplayer_peer = null
	game = null
	get_tree().reload_current_scene()

# Called after a player connects
func on_player_connected(id: int):
	send_info.rpc_id(id, Globals.player_name, Globals.selected_char)
	opponent = id
	
	if id != 1:
		%HostScreen.visible = false
	else:
		%MatchmakingScreen.visible = false
		
	$GuestCharacters.visible = true
	$MatchFoundSE.play()
	await $MatchFoundSE.finished
	$Room/AnimationPlayer.play("open_door")
	await $Room/AnimationPlayer.animation_finished
	$AnimationPlayer.play_backwards("fade_in")
	await get_tree().create_tween().tween_property($BGM, "volume_linear", 0, 1).set_trans(Tween.TRANS_LINEAR).finished
	$Room/AnimationPlayer.play_backwards("open_door")
	await $Room/AnimationPlayer.animation_finished
	$OpponentName.text = players[id]["name"]
	$OpponentName.visible = true
	$Opponent.get_children()[players[id]["char"]].visible = true
	$Opponent.visible = true
	if multiplayer.get_unique_id() == 1:
		$GameCamera.current = true
	else:
		$OpponentView.current = true
	
	$AnimationPlayer.play("fade_in")
	
	# Only host have authority to start a game
	if multiplayer.is_server():
		load_game.rpc(moves, discards)

# Share player info to other players
@rpc("any_peer", "reliable")
func send_info(username: String, selected_char: int) -> void:
	players[multiplayer.get_remote_sender_id()] = {
		"name": username,
		"char": selected_char
	}
	
	$GuestCharacters.get_children()[selected_char].visible = true
	$GuestName.text = username

# Called when player disconnects. Ends the game if it's running
func on_player_disconnected(id: int):
	if game_running:
		$ErrorSE.play()
		%DialogMessageLbl.text = players[id]["name"] + " disconnected"
		has_error = true
		$MessageDialog.visible = true

# Unused
func on_server_connected():
	pass

# Similar to player disconnects
func on_server_disconnected():
	if game_running:
		$ErrorSE.play()
		%DialogMessageLbl.text = "Disconnected from host"
		has_error = true
		$MessageDialog.visible = true

# Connection to host failed
func on_connection_failed():
	$ErrorSE.play()
	%DialogMessageLbl.text = "Connection failed"
	has_error = true
	$MessageDialog.visible = true

# Open Customization screen
func _on_customize_btn_pressed() -> void:
	$ClickSE.play()
	var characters: Array[Node] = $CharacterSelect.get_children()
	%MainScreen.visible = false
	$CharacterSelect.visible = true
	%PlayerNameInput.text = Globals.player_name
	characters[Globals.selected_char].visible = true
	$AnimationPlayer.play("main_cust")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	%CustomizeScreen.visible = true
	$CustomizeCamera.current = true

# Save player info
func _on_confirm_char_btn_pressed() -> void:
	$ClickSE.play()
	var characters: Array[Node] = $CharacterSelect.get_children()
	Globals.player_name = %PlayerNameInput.text
	%CustomizeScreen.visible = false
	Globals.save_data()
	$AnimationPlayer.play_backwards("main_cust")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$CharacterSelect.visible = false
	characters[Globals.selected_char].visible = false
	%MainScreen.visible = true
	$MainCamera.current = true

# Controls in Customization screen
func _on_prev_btn_pressed() -> void:
	$ClickSE.play()
	var characters: Array[Node] = $CharacterSelect.get_children()
	characters[Globals.selected_char].visible = false
	Globals.selected_char -= 1
	
	if Globals.selected_char < 0:
		Globals.selected_char = len(characters) - 1
	
	characters[Globals.selected_char].visible = true

func _on_next_btn_pressed() -> void:
	$ClickSE.play()
	var characters: Array[Node] = $CharacterSelect.get_children()
	characters[Globals.selected_char].visible = false
	Globals.selected_char += 1
	
	if Globals.selected_char >= len(characters):
		Globals.selected_char = 0
	
	characters[Globals.selected_char].visible = true

# Cancel matchmaking
func _on_cancel_host_btn_pressed() -> void:
	$ErrorSE.play()
	
	if peer:
		multiplayer.multiplayer_peer = null
		players.clear()
		peer = null
		matchmaking = false
	
	%HostScreen.visible = false
	$AnimationPlayer.play_backwards("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$MainCamera.current = true
	%MainScreen.visible = true

# Text input helper button functions
func _on_delete_char_btn_pressed() -> void:
	$ClickSE.play()
	var cur_text: String = %HostCodeInput.text
	%HostCodeInput.text = cur_text.substr(0, len(cur_text) - 1)

# Called when a player try to join a game
# Try to connect to the lobby
func _on_join_game_btn_pressed() -> void:
	$ClickSE.play()
	var host_code: String = %HostCodeInput.text
	
	host_code.strip_edges()
	
	if len(host_code) != 8:
		$ErrorSE.play()
		%DialogMessageLbl.text = "Please enter a valid code"
		$MessageDialog.visible = true
	else:
		var address: String = str(host_code.substr(0, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(2, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(4, 2).to_lower().hex_to_int()) + "." + str(host_code.substr(6, 2).to_lower().hex_to_int())
		
		peer = ENetMultiplayerPeer.new()
		peer.create_client(address, 18000)
		multiplayer.multiplayer_peer = peer
		
		players[multiplayer.get_unique_id()] = {
			"name": Globals.player_name,
			"char": Globals.selected_char
		}
		
		matchmaking = true
		%JoinScreen.visible = false
		%MatchmakingScreen.visible = true
		
	%HostCodeInput.text = ""

# Cancel matchmaking for clients
func _on_cancel_join_btn_pressed() -> void:
	$ErrorSE.play()
	%HostCodeInput.text = ""
	%JoinScreen.visible = false
	$AnimationPlayer.play_backwards("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$MainCamera.current = true
	%MainScreen.visible = true

# Text input helper button functions
func _on_key_pressed(key: String) -> void:
	$ClickSE.play()
	%HostCodeInput.text += key if len(%HostCodeInput.text) < 8 else ""

# Called when a player hosts a game
# Start a server and waits for player to connect
# Generate lobby code as IPv4 in 0-padded Hex form
func _on_host_btn_pressed() -> void:
	$ClickSE.play()
	players = {}
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
	
	if len(address) < 8:
		%DialogMessageLbl.text = "Please connect to a Wifi network."
		$MessageDialog.visible = true
		return
		
	%HostCodeLbl.text = "Host Code: %s" % address
	
	%MainScreen.visible = false
	$AnimationPlayer.play("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$PlayCamera.current = true
	%HostScreen.visible = true
	
	peer = ENetMultiplayerPeer.new()
	peer.create_server(18000)
	
	multiplayer.multiplayer_peer = peer
	
	players[multiplayer.get_unique_id()] = {
		"name": Globals.player_name,
		"char": Globals.selected_char
	}
	
	you = multiplayer.get_unique_id()
	
	matchmaking = true

# Called when Join button pressed
func _on_join_btn_pressed() -> void:
	$ClickSE.play()
	%MainScreen.visible = false
	$AnimationPlayer.play("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$PlayCamera.current = true
	%JoinScreen.visible = true

# Dialog cancel button callback
func _on_cancel_dialog_btn_pressed() -> void:
	$ClickSE.play()
	$MessageDialog.visible = false
	
	if has_error:
		$AnimationPlayer.play_backwards("fade_in")
		if game:
			game.fade_song()
			await game.audio_muted
		else:
			await get_tree().create_tween().tween_property($BGM, "volume_linear", 0, 1).set_trans(Tween.TRANS_LINEAR).finished
		
		await $AnimationPlayer.animation_finished
		get_tree().reload_current_scene()

# Called when matchmaking cancelled
func _on_cancel_matchmake_btn_pressed() -> void:
	$ClickSE.play()
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		players.clear()
		peer = null
		matchmaking = false
	
	%MatchmakingScreen.visible = false
	%JoinScreen.visible = true

# Called when Credit button pressed
func _on_credits_btn_pressed() -> void:
	$ClickSE.play()
	%MainScreen.visible = false
	$AnimationPlayer.play("main_window")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$CreditsCamera.current = true
	%CreditsScreen.visible = true

# Handle moves amount in the game settings on host
func _on_moves_setting_btn_pressed() -> void:
	$ClickSE.play()
	moves += 2
	
	if moves > 7:
		moves = 3
		
	%MovesSettingBtn.text = str(moves)

# Same as above but for discards
func _on_discard_setting_btn_pressed() -> void:
	$ClickSE.play()
	discards += 2
	
	if discards > 7:
		discards = 3
	
	%DiscardSettingBtn.text = str(discards)

# Toggle mute
func _on_audio_toggle_pressed() -> void:
	$ClickSE.play()
	
	if Globals.audio_state == 1:
		Globals.audio_state = 2
	else:
		Globals.audio_state = 1
	
	var audio_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(audio_bus, Globals.audio_state != 1)
	
	Globals.save_data()

# Close credits screen
func _on_close_credits_btn_pressed() -> void:
	%CreditsScreen.visible = false
	$AnimationPlayer.play_backwards("main_window")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$MainCamera.current = true
	%MainScreen.visible = true
