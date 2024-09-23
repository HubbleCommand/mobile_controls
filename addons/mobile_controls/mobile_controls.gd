@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("VirtualJoystick", "MarginContainer", preload("./components/virtual_joystick.gd"), preload("./icons/VirtualJoystick.svg"))
	add_custom_type("ScreenGesture", "Control", preload("./components/screen_gesture.gd"), preload("./icons/ScreenGesture.svg"))
	add_custom_type("TextureButtonMobile", "BaseButton", preload("./components/texture_button_mobile.gd"), preload("./icons/TouchScreenControlButton.svg"))


func _exit_tree() -> void:
	remove_custom_type("VirtualJoystick")
	remove_custom_type("ScreenGesture")
	remove_custom_type("TextureButtonMobile")
