extends Node

var operator_tile_data : Array[TileModel] = [
	TileModel.new(1, 1, 1, "+", "res://assets/images/tile-plus.png"),
	TileModel.new(1, 1, 1, "-", "res://assets/images/tile-minus.png"),
	TileModel.new(2, 1, 1, "*", "res://assets/images/tile-mult.png"),
	TileModel.new(2, 1, 1, "/", "res://assets/images/tile-div.png"),
]

var numeric_tile_data : Array[TileModel] = [
	TileModel.new(0, 1, 1, "0", "res://assets/images/tile-0.png", "NUMBER"),
	TileModel.new(1, 1, 1, "1", "res://assets/images/tile-1.png", "NUMBER"),
	TileModel.new(2, 1, 1, "2", "res://assets/images/tile-2.png", "NUMBER"),
	TileModel.new(3, 1, 1, "3", "res://assets/images/tile-3.png", "NUMBER"),
	TileModel.new(4, 1, 1, "4", "res://assets/images/tile-4.png", "NUMBER"),
	TileModel.new(5, 1, 1, "5", "res://assets/images/tile-5.png", "NUMBER"),
	TileModel.new(6, 1, 1, "6", "res://assets/images/tile-6.png", "NUMBER"),
	TileModel.new(7, 1, 1, "7", "res://assets/images/tile-7.png", "NUMBER"),
	TileModel.new(8, 1, 1, "8", "res://assets/images/tile-8.png", "NUMBER"),
	TileModel.new(9, 1, 1, "9", "res://assets/images/tile-9.png", "NUMBER"),
]

# C0A8A08D

var indices_tile_data : Array[TileModel] = [
	TileModel.new(1, 1, 1, "pow(2, x)", "res://assets/images/tile-2x.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(4, x)", "res://assets/images/tile-4x.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (x + 1))", "res://assets/images/tile-2x+1.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (x - 1))", "res://assets/images/tile-2x-1.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (x + 2))", "res://assets/images/tile-2x+2.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (x - 2))", "res://assets/images/tile-2x-2.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (2 * x))", "res://assets/images/tile-22x.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (1 - x))", "res://assets/images/tile-21-x.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (2 * x + 1))", "res://assets/images/tile-22x+1.png", "INDICES"),
	TileModel.new(1, 1, 1, "pow(2, (2 * x - 1))", "res://assets/images/tile-22x-1.png", "INDICES"),
]

var selected_char: int = 0
var player_name: String = "Player"
var audio_state: int = 1

const SAVE_PATH: String = "user://save.data"

func save_data():
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file:
		file.store_8(selected_char)
		file.store_line(player_name)
		file.store_8(audio_state)
		file.close()
	
func load_data():
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	
	if file:
		selected_char = file.get_8()
		player_name = file.get_line()
		audio_state = file.get_8()
		
		if !audio_state:
			audio_state = 1
		
		file.close()
