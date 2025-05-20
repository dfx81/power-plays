extends Node3D

var can_proceed: bool = false
var menu: PackedScene = preload("res://scenes/Menu.tscn")

func _ready():
	$Version.text = "V%s-%s-%s" % [ProjectSettings.get_setting("application/config/version"), OS.get_name(), RenderingServer.get_current_rendering_method()]
	
	$AudioStreamPlayer.volume_linear = .5
	Globals.load_data()
	
	var audio_bus: int = AudioServer.get_bus_index("Master")
	print(Globals.audio_state)
	AudioServer.set_bus_mute(audio_bus, Globals.audio_state != 1)
	
	if randf() >= .75:
		$Ghost.visible = true
	else:
		$Ghost.visible = false


func _on_control_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed && can_proceed:
			can_proceed = false
			$FadeAnimation.play("fade_out")
			await $FadeAnimation.animation_finished
			await get_tree().create_tween().tween_property($AudioStreamPlayer, "volume_linear", 0, 1).set_trans(Tween.TRANS_LINEAR).finished
			
			get_tree().change_scene_to_packed(menu)


func _on_splash_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "splash_op":
		can_proceed = true
		print("CAN PROCEED")
