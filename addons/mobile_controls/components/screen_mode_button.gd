extends TextureRect

signal pressed

func _ready():
	pass
	#if not DisplayServer.is_touchscreen_available():
	#	$"..".hide()

func _gui_input(event):
	#TODO use actions for this, configured from ScreenGesture...
	if !event.is_released():	#Only seignal on release
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
	elif event is InputEventScreenTouch:
		pressed.emit()
