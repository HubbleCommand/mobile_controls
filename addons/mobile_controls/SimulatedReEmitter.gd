class_name SimulatedReEmitter
extends Node

class SimulatedEvent extends InputEventWithModifiers:
	const simulated = true

func _input(event):
	#There is massive issues here...
	var emulate_touch_from_mouse = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	var emulate_mouse_from_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")	#Default is true
	
	if event is InputEventScreenTouch:
		pass
		#var simulated_event = InputEventWithModifiers.new()
		#var simulated_event = InputEventMouseButton.new()
		#simulated_event.
		#Input.parse_input_event(simulated_event)
	elif event is InputEventScreenDrag:
		pass
