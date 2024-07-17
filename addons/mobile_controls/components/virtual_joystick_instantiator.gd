extends Control

var scene: Node

"""
There is an interesting pattern from another virtual joystick addon
https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot/blob/Main/addons/virtual_joystick/virtual_joystick_instantiator.gd
However, that pattern doesn't work great with exports (as is to be expected)
See the virtual_joystick_instantiator.gd class
"""
#is this needed?
func _enter_tree() -> void:
	scene = preload("virtual_joystick.tscn").instantiate()
	add_child(scene)

func _exit_tree() -> void:
	scene.free()
