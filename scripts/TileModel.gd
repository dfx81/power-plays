class_name TileModel extends Node

var score : int = 1
var tile_mult : int = 1
var move_mult : int = 1
var component : String = "="
var texture_path: String = "res://assets/images/tile-eql.png"
var type: String = "OPERATOR"

func _init(score_val: int = 0, tile_mult_val: int = 1, move_mult_val: int = 1, component_val: String = "=", texture_path_val: String = "res://assets/images/tile-eql.png", type_val: String = "OPERATOR"):
	self.score = score_val
	self.tile_mult = tile_mult_val
	self.move_mult = move_mult_val
	self.component = component_val
	self.texture_path = texture_path_val
	self.type = type_val

func init_from_dict(dict: Dictionary[String, Variant]) -> void:
	score = dict["score"]
	tile_mult = dict["tile_mult"]
	move_mult = dict["move_mult"]
	component = dict["component"]
	texture_path = dict["texture_path"]
	type = dict["type"]
