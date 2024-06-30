@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Green color taken from Control node
	# Joystick icons based off of InputEventJoypadMotion (previously JoyAxis)
	add_custom_type("VirtualJoystick", "MarginContainer", preload("./components/virtual_joystick.gd"), preload("./icons/VirtualJoystick.svg"))
	# Floating has background similar to MakeFloating
	#add_custom_type("FloatingVirtualJoystick", "MarginContainer", preload("./components/floating_virtual_joystick.gd"), preload("./icons/FloatingVirtualJoystick.svg"))
	
	#Screen gesture based on InputEventScreen* phone parts, and hand taken from XRHandModifier3D
	add_custom_type("ScreenGesture", "Control", preload("./components/screen_gesture.gd"), preload("./icons/ScreenGesture.svg"))


func _exit_tree() -> void:
	remove_custom_type("VirtualJoystick")
	#remove_custom_type("FloatingVirtualJoystick")
	remove_custom_type("ScreenGesture")
