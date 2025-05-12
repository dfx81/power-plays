class_name Game extends Control

var players: Dictionary[int, Variant] = {}
var player_tiles: Dictionary[int, Array] = {
	0: [],
	1: [],
	2: [],
}

var cur_tiles: Array = []
var turn: int = 0
var turn_passed: int = 0
@onready var bgm: AudioStreamPlayer = $BGM

var moves: int = 5
var discards: int = 5
var opponent_moves: int = 5
var opponent_discards: int = 5

var opponent_id: int = 0
var player_id: int = 0

@export var tile_scene : PackedScene
@onready var host_hand : Control = $"GameArea/Controls/Host Hand"
@onready var client_hand : Control = $"GameArea/Controls/Client Hand"
@onready var preview : Control = $"GameArea/Controls/Move Preview"

signal on_new_turn_start
signal disconnect_from_game
signal view_board
signal view_opponent
signal audio_muted
signal anim_place
signal anim_shake
signal anim_nod
signal game_start
signal game_end

var current_move : Array[Tile] = []
var current_move_eqn : String = ""
var current_move_score: int = 0
var game_state: String = "PLAY"

var your_score: int = 0
var opponent_score: int = 0

var challenge_skipped: bool = true
var running: bool = false

var ended: int = 0

func _ready() -> void:
	$BGM.volume_linear = 1
	setup()
	draw_tiles()
	show_hands()

func _process(_delta: float) -> void:
	%TurnLbl.text = str(turn)
	%PlayerScore.text = "   YOUR SCORE: %d" % your_score
	%PlayerMoves.text = "   %d MOVES, %d DISCARDS" % [moves, discards]
	%OpponentScore.text = "OPPONENT SCORE: %d   " % opponent_score
	%OpponentMoves.text = "%d MOVES, %d DISCARDS   " % [opponent_moves, opponent_discards]

func setup():
	player_id = multiplayer.get_unique_id()
	
	for i in players.keys():
		if i != player_id:
			opponent_id = i
			break
	
	for tile_group in player_tiles.values():
		tile_group.clear()
	
	on_new_turn_start.connect(turn_start)
	turn_start()

@rpc("any_peer", "call_local", "reliable")
func has_ended():
	ended += 1
	
	if ended >= 2:
		emit_signal("game_end")
		%GameResults.visible = true

func turn_start():
	if !running:
		running = true
		emit_signal("game_start")
	
	var your_turn: bool = turn % 2 == 0 if multiplayer.is_server() else turn % 2 != 0
	print("Your turn" if your_turn else "Opponent's turn")
	
	%TurnIndicator.text = "YOUR\nTURN" if your_turn else "OPPONENT'S\nTURN"
	
	if your_turn:
		emit_signal("view_board")
	else:
		emit_signal("view_opponent")
	
	%Animator.play("show_turn")

func draw_tiles(bonuses: int = -1):
	var has_eql: bool = false
	
	for tile in player_tiles[0]:
		var t: Tile = tile
		
		if t.data.component == "=":
			has_eql = true
			break
	
	if !has_eql && len(player_tiles[0]) < 3:
		var eql_tile: Tile = tile_scene.instantiate()
		eql_tile.data = TileModel.new()
		eql_tile.set_callbacks(selected, deselect)
		player_tiles[0].append(eql_tile)
		
	while len(player_tiles[0]) < 3:
		var tile: Tile = tile_scene.instantiate()
			
		tile.data = Globals.operator_tile_data.pick_random()
		tile.set_callbacks(selected, deselect)
		player_tiles[0].append(tile)
	
	while len(player_tiles[1]) < 3:
		var tile: Tile = tile_scene.instantiate()
			
		tile.data = Globals.numeric_tile_data.pick_random()
		tile.set_callbacks(selected, deselect)
		player_tiles[1].append(tile)
	
	while len(player_tiles[2]) < 3:
		var tile: Tile = tile_scene.instantiate()
			
		tile.data = Globals.indices_tile_data.pick_random()
		tile.set_callbacks(selected, deselect)
		player_tiles[2].append(tile)
	
	var all_tiles: Array = player_tiles[0] + player_tiles[1] + player_tiles[2]
	var entitled_bonuses: int = min(turn_passed, 3)
	
	if bonuses != -1:
		entitled_bonuses = bonuses
	
	
	print("Entitled bonus: " + str(entitled_bonuses))
	
	all_tiles.shuffle()
	
	for t in all_tiles:
		if t is Tile:
			if (!t.has_bonus) && entitled_bonuses > 0:
				var chance: int =  randi() % 4
				
				match (chance):
					0:
						t.data.tile_mult = 2
					1:
						t.data.tile_mult = 3
					2:
						t.data.move_mult = 2
					3:
						t.data.move_mult = 3
				
				t.has_bonus = true
				
				entitled_bonuses -= 1

func clear_hands():
	var hand: Control = host_hand if multiplayer.is_server() else client_hand
	
	for tile in hand.get_children():
		hand.remove_child(tile)

func show_hands():
	clear_hands()
	cur_tiles = player_tiles[0] + player_tiles[1] + player_tiles[2]
	
	for tile in cur_tiles:
		if multiplayer.is_server():
			host_hand.add_child(tile)
		else:
			client_hand.add_child(tile)
			
	for tile in cur_tiles:
		tile.toggle_tiles(turn % 2 == 0 if multiplayer.is_server() else turn % 2 != 0)
	
	host_hand.visible = multiplayer.is_server()
	client_hand.visible = !multiplayer.is_server()

func serialize(tile_data: Array[Tile]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for tile in tile_data:
		result.append(tile.serialize())
	
	return result

func deserialize(tile_data: Array[Dictionary]) -> Array[Tile]:
	var result: Array[Tile] = []
	
	for tile_dat in tile_data:
		var model: TileModel = TileModel.new()
		model.init_from_dict(tile_dat)
		var tile: Tile = tile_scene.instantiate()
		tile.data = model
		
		result.append(tile)
	
	return result

@rpc("any_peer", "reliable")
func submit_tiles(tiles: Array[Dictionary]):
	print("tiles submitted")
	var submitted_tiles: Array[Tile] = deserialize(tiles)
	current_move = submitted_tiles
	
	update_preview()
	
@rpc("any_peer", "call_local", "reliable")
func update_turn():
	turn += 1
	print("Current Turn:" + str(turn))
	on_new_turn_start.emit()
	show_hands()
	
@rpc("any_peer", "reliable")
func update_game_state(new_state: String, x_val: float = 0.0):
	game_state = new_state
	
	match (game_state):
		"VERIFY":
			%ChallengeResult.visible = false
			%ResponseResult.visible = false
			%"Challenge Container".visible = true
			emit_signal("view_board")
		"PLAY":
			if moves == 0 && opponent_moves == 0:
				has_ended.rpc()
				return
			
			%"Challenge Container".visible = false
			current_move.clear()
			update_preview()
			
			emit_signal("view_board")
		"SCORE":
			if !challenge_skipped:
				emit_signal("view_board")
			else:
				emit_signal("view_opponent")
			
			your_score += current_move_score
			send_player_data.rpc_id(opponent_id, your_score, moves, discards)
			current_move_score = 0
			print("YOUR SCORE:" + str(your_score))
			current_move.clear()
			update_preview()
			
			if moves <= 0 && opponent_moves <= 0:
				has_ended.rpc()
				emit_signal("game_end")
				return
		"CHALLENGED":
			$ChallengeSE.play()
			challenge_skipped = false
			%"Response Container".visible = true
			emit_signal("view_board")
		"SUCCESS":
			$CorrectSE.play()
			emit_signal("view_opponent")
			play_anim("anim_shake")
			await get_tree().create_timer(2).timeout
			emit_signal("view_board")
			%ResponseWait.visible = false
			%ChallengeLost.visible = false
			%ChallengeWon.visible = true
			
			%ChallengeResult.visible = true
			
			discards += 1
			send_player_data.rpc_id(opponent_id, your_score, moves, discards)
			
			if moves <= 0 && opponent_moves <= 0:
				%ChallengeResult.visible = false
				has_ended.rpc()
				return
		"FAIL":
			$WrongSE.play()
			emit_signal("view_opponent")
			play_anim("anim_nod")
			await get_tree().create_timer(2).timeout
			emit_signal("view_board")
			%ResponseWait.visible = false
			%ChallengeLost.visible = true
			%ChallengeLost.text = "Challenge Lost (X = " + str(x_val) + ")\nOpponent +10 pts"
			%ChallengeWon.visible = false
			
			%ChallengeResult.visible = true
			
			if moves <= 0 && opponent_moves <= 0:
				%ChallengeResult.visible = false
				has_ended.rpc()
				return

func selected(tile: Tile) -> void:
	$SelectSE.play()
	current_move.append(tile)
	update_preview()
	
func deselect(tile: Tile) -> void:
	# var pos: int = current_move.find(tile)
	$DeselectSE.play()
	current_move.erase(tile)
	update_preview()
	
func update_preview():
	reset_preview()
	
	for tile in current_move:
		var tile_texture: TextureRect = TextureRect.new()
		tile_texture.texture = load(tile.data.texture_path)
		tile_texture.size = Vector2i(128, 128)
		tile_texture.modulate = Color.TRANSPARENT
		
		var modulate_target: Color = Color.WHITE
		
		if tile.has_bonus:
			match (tile.data.tile_mult):
				2:
					modulate_target = Color.CORAL
				3:
					modulate_target = Color.CRIMSON
		
			match (tile.data.move_mult):
				2:
					modulate_target = Color.AQUAMARINE
				3:
					modulate_target = Color.DARK_CYAN
		
		tile_texture.self_modulate = modulate_target
		
		tile_texture.connect("tree_entered", func(): await get_tree().create_tween().tween_property(tile_texture, "modulate", modulate_target, .125).finished)
		preview.add_child(tile_texture)

func reset_preview():
	for item in preview.get_children():
		preview.remove_child(item)

func _on_submit_btn_pressed() -> void:
	var your_turn: bool = turn % 2 == 0 if multiplayer.is_server() else turn % 2 != 0
	
	if !your_turn:
		$ErrorSE.play()
		print("Not your turn")
		return
	
	current_move_eqn = ""
	
	if len(current_move) == 0:
		$ClickSE.play()
		print("Skipped")
		discards += 1
		moves -= 1
		turn_passed += 1
		send_player_data.rpc_id(opponent_id, your_score, moves, discards)
		remove_used_tiles(false)
		update_turn.rpc()
		challenge_skipped = true
		
		print("ENDED:" + str(moves <= 0 && opponent_moves <= 0))
		if moves <= 0 && opponent_moves <= 0:
			has_ended.rpc()
		
		update_game_state.rpc("PLAY")
		
	if len(current_move) < 3:
		$ErrorSE.play()
		print("invalid")
		return
	
	var valid: bool = true
	var has_indices: bool = false
	var has_eql: bool = false
	var last_tile: Tile = null
	
	for tile in current_move:
		var t: Tile = tile
		
		if t.data.type == "OPERATOR":
			if last_tile == null && t.data.component != "-":
				valid = false
				break
			elif last_tile == null && t.data.component == "=":
				valid = false
				break
			elif last_tile != null && last_tile.data.type == t.data.type && t.data.component != "-" && last_tile.data.component == "=":
				valid = false
			elif last_tile != null && t.data.type == last_tile.data.type && t.data.component == "-":
				current_move_eqn += t.data.component
			elif last_tile != null && t.data.type == last_tile.data.type:
				valid = false
			else:
				if t.data.component == "=":
					has_eql = true
				current_move_eqn += t.data.component
		elif t.data.type == "INDICES":
			has_indices = true
			if last_tile != null && last_tile.data.type == "NUMBER":
				current_move_eqn += "*" + t.data.component
			elif last_tile != null && last_tile.data.type == "INDICES":
				current_move_eqn += "*" + t.data.component
			else:
				current_move_eqn += t.data.component
		elif t.data.type == "NUMBER":
			if last_tile != null && last_tile.data.type == "INDICES":
				current_move_eqn += "*"
			
			current_move_eqn += t.data.component
		
		last_tile = tile
	
	if last_tile != null && last_tile.data.type == "OPERATOR":
		valid = false
	
	if valid and has_eql and has_indices:
		$ClickSE.play()
		print(current_move_eqn)
		moves -= 1
		print("%d moves left" % moves)
		current_move_score = calculate_eqn_score()
		submit_tiles.rpc_id(opponent_id, serialize(current_move))
		send_player_data.rpc_id(opponent_id, your_score, moves, discards)
		turn_passed += 1
		remove_used_tiles(false)
		challenge_skipped = true
		update_turn.rpc()
		update_game_state.rpc("VERIFY")
	else:
		$ErrorSE.play()
		print("invalid")

func remove_used_tiles(clear_preview: bool = true):
	var bonus: int = 0
	
	if len(current_move) > 0:
		var to_delete: Array[Tile] = []
		for group in player_tiles.values():
			for item in group:
				var tile: Tile = item
			
				if tile.selected:
					to_delete.append(tile)
	
		for tile in to_delete:
			for group in player_tiles.values():
				var grp: Array = group
				if tile in grp:
					if tile.has_bonus:
						bonus += 1
					grp.erase(tile)
		
		current_move = []
		
		if clear_preview:
			draw_tiles(bonus)
			reset_preview()
		else:
			draw_tiles()
		
		show_hands()

func _on_discard_btn_pressed() -> void:
	var your_turn: bool = turn % 2 == 0 if multiplayer.is_server() else turn % 2 != 0
	
	if !your_turn:
		$ErrorSE.play()
		print("Not your turn")
		return
	
	if len(current_move) == 0:
		$ErrorSE.play()
		print("No tiles to discard")
		return
	
	
	if discards > 0:
		remove_used_tiles()
		discards -= 1
		$RedrawSE.play()
		
		send_player_data.rpc_id(opponent_id, your_score, moves, discards)
	else:
		$ErrorSE.play()
		print("Out of discards")

func calculate_eqn_score() -> int:
	var tile_values: int = 0
	var mults: int = 1
	
	for tile in current_move:
		tile_values += tile.data.score * tile.data.tile_mult
		mults *= tile.data.move_mult
	
	var bingo: int = 2 if len(current_move) == 9 else 1
	
	return tile_values * mults * bingo

func _on_skip_challenge_btn_pressed() -> void:
	$ClickSE.play()
	update_game_state.rpc_id(opponent_id, "SCORE")
	update_game_state("PLAY")

@rpc("any_peer", "reliable")
func send_player_data(cur_score: int, cur_moves: int, cur_discards: int):
	opponent_score = cur_score
	opponent_moves = cur_moves
	opponent_discards = cur_discards

func _on_challenge_btn_pressed() -> void:
	$ClickSE.play()
	update_game_state.rpc_id(opponent_id, "CHALLENGED")
	%"Challenge Container".visible = false
	%ResponseWait.visible = true


func _on_no_solution_pressed() -> void:
	$WrongSE.play()
	update_game_state.rpc_id(opponent_id, "SUCCESS")
	%"Response Container".visible = false
	%SolutionInput.text = ""
	
	send_player_data(your_score, moves, discards)
	reset_preview()
	
	%ResponseWon.visible = false
	%ResponseLost.visible = true
	%ResponseResult.visible = true


func _on_submit_solution_pressed() -> void:
	var entered_val: String = %SolutionInput.text
	
	if len(entered_val) == 1 and (entered_val == "." or entered_val == "-"):
		return
	
	if entered_val.ends_with("."):
		%SolutionInput.text += "0"
	
	var expression: Expression = Expression.new()
	
	var eqn_parts: Array = current_move_eqn.split("=")
	
	var x_val: float = float(%SolutionInput.text)
	
	var lhs: String = "round(int(float(%s) * 1000) / 1000.0)" % eqn_parts[0]
	var rhs: String = "round(int(float(%s) * 1000) / 1000.0)" % eqn_parts[1]
	
	expression.parse(lhs, ["x",])
	var l_res: Variant = expression.execute([x_val,])
	var lhs_res: float = l_res if !expression.has_execute_failed() else -1
	
	if expression.has_execute_failed():
		print(expression.get_error_text())
		
	expression.parse(rhs, ["x",])
	var r_res: Variant = expression.execute([x_val,])
	var rhs_res: float = r_res if !expression.has_execute_failed() else -2 
	
	if expression.has_execute_failed():
		print(expression.get_error_text())
	
	if lhs_res == rhs_res:
		$CorrectSE.play()
		update_game_state.rpc_id(opponent_id, "FAIL", x_val)
		your_score += 10
		update_game_state("SCORE")
	else:
		$WrongSE.play()
		update_game_state.rpc_id(opponent_id, "SUCCESS")
	
	%ResponseWon.visible = lhs_res == rhs_res
	%ResponseLost.visible = lhs_res != rhs_res
	%ResponseResult.visible = true
	
	%"Response Container".visible = false
	%SolutionInput.text = ""

func _on_close_btn_pressed() -> void:
	$ClickSE.play()
	%ChallengeResult.visible = false
	reset_preview()
	
	if moves > 0:
		update_game_state("PLAY")
	
func _on_close_res_btn_pressed() -> void:
	$ClickSE.play()
	var your_turn: bool = turn % 2 == 0 if multiplayer.is_server() else turn % 2 != 0
	
	if !your_turn:
		emit_signal("view_opponent")
	else:
		emit_signal("view_board")
		
	%ResponseResult.visible = false
	reset_preview()
	
	if moves <= 0 && opponent_moves <= 0:
		has_ended.rpc()
		emit_signal("game_end")
		return

func _on_game_results_visibility_changed() -> void:
	your_score += discards * 10
	opponent_score += opponent_discards * 10
	
	if your_score > opponent_score:
		$WinSE.play()
		%Result.text = "YOU WIN"
	elif your_score < opponent_score:
		$LoseSE.play()
		%Result.text = "YOU LOST"
	else:
		$LoseSE.play()
		%Result.text = "DRAW"
		
	%PlayerResult.text = "You: %d pts" % your_score
	%OpponentResult.text = "Opponent: %d pts" % opponent_score
	emit_signal("game_end")

func on_disconnect():
	%GameDisconnect.visible = true

func _on_quit_pressed() -> void:
	$ClickSE.play()
	await $ClickSE.finished
	disconnect_from_game.emit()

func _on_num_btn_pressed(key: String) -> void:
	$ClickSE.play()
	var cur_val: String = %SolutionInput.text
	
	match (key):
		".":
			cur_val += "." if !cur_val.contains(".") else ""
		"-":
			if cur_val.contains("-"):
				cur_val = cur_val.replace("-", "")
			else:
				cur_val = "-" + cur_val
		_:
			cur_val += key
	
	%SolutionInput.text = cur_val

func _on_delete_btn_pressed() -> void:
	$ClickSE.play()
	var cur_val: String = %SolutionInput.text
	cur_val = cur_val.substr(0, len(cur_val) - 1)
	
	%SolutionInput.text = cur_val

func fade_song() -> void:
	await get_tree().create_tween().tween_property($BGM, "volume_linear", 0, 1).set_trans(Tween.TRANS_LINEAR).finished
	emit_signal("audio_muted")

@rpc("any_peer", "call_remote", "reliable")
func play_anim(anim_signal: String):
	emit_signal(anim_signal)
