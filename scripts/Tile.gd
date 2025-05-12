class_name Tile extends Control

var data : TileModel
var selected : bool = false

@onready var texture : TextureRect = $TileGraphic
@onready var animator : AnimationPlayer = $AnimationPlayer
@onready var hover_highlight : ColorRect = $TileGraphic/Highlight

var selected_callback : Callable
var deselect_callback : Callable
var has_bonus: bool = false
var enabled: bool = false

func _process(_delta: float) -> void:
	texture.texture = load(data.texture_path)
	
	if has_bonus:
		match (data.tile_mult):
			2:
				self_modulate = Color.CORAL
			3:
				self_modulate = Color.CRIMSON
		
		match (data.move_mult):
			2:
				self_modulate = Color.AQUAMARINE
			3:
				self_modulate = Color.DARK_CYAN
	else:
		self_modulate = Color.WHITE

func set_callbacks(select_cb: Callable, deselect_cb: Callable) -> void:
	selected_callback = select_cb
	deselect_callback = deselect_cb

func toggle_tiles(enable: bool):
	enabled = enable

func _on_tile_graphic_mouse_entered() -> void:
	hover_highlight.visible = true

func _on_tile_graphic_mouse_exited() -> void:
	hover_highlight.visible = false

func _gui_input(event: InputEvent) -> void:
	if !enabled:
		return
		
	if event is InputEventMouseButton:
		if event.pressed:
			selected = !selected
			
			if selected:
				selected_callback.call(self)
			else:
				deselect_callback.call(self)
			
			animator.play("selected" if selected else "deselect")
			await animator.animation_finished

func _to_string() -> String:
	return data.component

func serialize() -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"score": data.score,
		"has_bonus": has_bonus,
		"tile_mult": data.tile_mult,
		"move_mult": data.move_mult,
		"component": data.component,
		"texture_path": data.texture_path,
		"type": data.type,
	}
	
	return result
