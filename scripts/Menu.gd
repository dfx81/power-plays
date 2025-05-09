extends Node3D

@export var game_scene: PackedScene

var peer: ENetMultiplayerPeer
var players: Dictionary[int, Variant] = {}
var matchmaking: bool = false
var game: Game = null

var has_error: bool = false

var you: int = 0
var opponent: int = 0
var game_running = false

func _ready() -> void:
	$BGM.volume_linear = 1
	%MainScreen.visible = true
	
	var network_access: bool = OS.request_permissions()
	
	if !network_access:
		%HostBtn.disabled = true
		%JoinBtn.disabled = true
		return
	
	multiplayer.peer_connected.connect(on_player_connected)
	multiplayer.peer_disconnected.connect(on_player_disconnected)
	multiplayer.connected_to_server.connect(on_server_connected)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connection_failed.connect(on_connection_failed)

@rpc("call_local", "reliable")
func load_game():
	var game_instance: Game = game_scene.instantiate()
	game_instance.players = players
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

func opponent_play_anim_place_tile():
	#$Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer").play("interact-right")
	pass
	
func opponent_play_anim_nod():
	#$Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer").play("emote-yes")
	pass

func opponent_play_anim_shake():
	#$Opponent.get_child(players[opponent]["char"]).get_node("AnimationPlayer").play("emote-no")
	pass

func view_board():
	$GameCamera.current = true
	game.visible = true
	
func view_opponent():
	$OpponentView.current = true
	game.visible = false

func end_game():
	game.queue_free()
	multiplayer.multiplayer_peer = null
	game = null
	get_tree().reload_current_scene()

func on_player_connected(id: int):
	send_info.rpc_id(id, Globals.player_name, Globals.selected_char)
	opponent = id
	
	if id != 1:
		%HostScreen.visible = false
	else:
		%MatchmakingScreen.visible = false
		
	$GuestCharacters.visible = true
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
	
	if multiplayer.is_server():
		load_game.rpc()

@rpc("any_peer", "reliable")
func send_info(username: String, selected_char: int) -> void:
	players[multiplayer.get_remote_sender_id()] = {
		"name": username,
		"char": selected_char
	}
	
	$GuestCharacters.get_children()[selected_char].visible = true
	$GuestName.text = username

func on_player_disconnected(id: int):
	if game_running:
		%DialogMessageLbl.text = players[id]["name"] + " disconnected"
		has_error = true
		$MessageDialog.visible = true

func on_server_connected():
	pass

func on_server_disconnected():
	if game_running:
		%DialogMessageLbl.text = "Disconnected from host"
		has_error = true
		$MessageDialog.visible = true
	
func on_connection_failed():
	if game_running:
		%DialogMessageLbl.text = "Connection failed"
		has_error = true
		$MessageDialog.visible = true

func _on_customize_btn_pressed() -> void:
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

func _on_confirm_char_btn_pressed() -> void:
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

func _on_prev_btn_pressed() -> void:
	var characters: Array[Node] = $CharacterSelect.get_children()
	characters[Globals.selected_char].visible = false
	Globals.selected_char -= 1
	
	if Globals.selected_char < 0:
		Globals.selected_char = len(characters) - 1
	
	characters[Globals.selected_char].visible = true

func _on_next_btn_pressed() -> void:
	var characters: Array[Node] = $CharacterSelect.get_children()
	characters[Globals.selected_char].visible = false
	Globals.selected_char += 1
	
	if Globals.selected_char >= len(characters):
		Globals.selected_char = 0
	
	characters[Globals.selected_char].visible = true

func _on_cancel_host_btn_pressed() -> void:
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

func _on_delete_char_btn_pressed() -> void:
	var cur_text: String = %HostCodeInput.text
	%HostCodeInput.text = cur_text.substr(0, len(cur_text) - 1)

func _on_join_game_btn_pressed() -> void:
	var host_code: String = %HostCodeInput.text
	
	host_code.strip_edges()
	
	if len(host_code) != 8:
		%ErrMessageLbl.text = "Please enter a valid code"
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

func _on_cancel_join_btn_pressed() -> void:
	%HostCodeInput.text = ""
	%JoinScreen.visible = false
	$AnimationPlayer.play_backwards("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$MainCamera.current = true
	%MainScreen.visible = true

func _on_key_pressed(key: String) -> void:
	%HostCodeInput.text += key if len(%HostCodeInput.text) < 8 else ""

func _on_host_btn_pressed() -> void:
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

func _on_join_btn_pressed() -> void:
	%MainScreen.visible = false
	$AnimationPlayer.play("main_door")
	$TransitionCam.current = true
	await $AnimationPlayer.animation_finished
	$PlayCamera.current = true
	%JoinScreen.visible = true

func _on_cancel_dialog_btn_pressed() -> void:
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

func _on_cancel_matchmake_btn_pressed() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		players.clear()
		peer = null
		matchmaking = false
	
	%MatchmakingScreen.visible = false
	%JoinScreen.visible = false


func _on_credits_btn_pressed() -> void:
	pass # Replace with function body.
