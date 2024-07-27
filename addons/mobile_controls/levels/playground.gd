extends Node2D

@onready var joysticks = [
	$CanvasLayer/VBoxContainer/ScreenGesture/FloatingVirtualJoystick,
	$"CanvasLayer/VBoxContainer/DynamicOut Tests/AspectRatioContainer/LeftVirtualJoystick",
	$"CanvasLayer/VBoxContainer/DynamicOut Tests/RightVirtualJoystick"
]
@onready var dropdown = $"CanvasLayer/Joystick Readout/OptionButton"

func _ready() -> void:
	dropdown.clear()
	for joystick in joysticks:
		dropdown.add_item(joystick.name)


func _input(event: InputEvent) -> void:
	if event is not InputEventJoypadMotion:
		return
	
	if dropdown.selected > 0:
		if event.axis == joysticks[dropdown.selected].joy_axis_horizontal:
			$"CanvasLayer/Joystick Readout/XLabel".text = str(event.axis_value)
		elif event.axis == joysticks[dropdown.selected].joy_axis_vertical:
			$"CanvasLayer/Joystick Readout/YLabel".text = str(event.axis_value)
	#if event.axis == JoyAxis.JOY_AXIS_LEFT_X || event.axis == JoyAxis.JOY_AXIS_RIGHT_X || event.axis == JoyAxis.JOY_AXIS_TRIGGER_LEFT :
		
	#else:
		


func _print_received_gesture(gesture: String):
	print("		gesture received : ", gesture)


func _on_screen_gesture_double_tap_gesture(target):
	_print_received_gesture("double tap")


func _on_screen_gesture_gesture_end():
	_print_received_gesture("gesture end")


func _on_screen_gesture_long_press_gesture(gesture):
	_print_received_gesture("long press")


func _on_screen_gesture_pan_gesture(position, direction):
	_print_received_gesture("pan")
	$Camera2D.position -= direction#.normalized()


func _on_screen_gesture_rotate_gesture(position, direction):
	_print_received_gesture("rotate")
	$Camera2D.rotate(direction.angle() / 100)


func _on_screen_gesture_scale_gesture(position, strength):
	_print_received_gesture("scale")
