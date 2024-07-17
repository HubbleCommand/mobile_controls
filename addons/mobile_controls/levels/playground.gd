extends Node2D


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


func _on_screen_gesture_rotate_gesture(position, direction):
	_print_received_gesture("rotate")


func _on_screen_gesture_scale_gesture(position, strength):
	_print_received_gesture("scale")
