extends BaseButton


"""
TODO here

I don't think passing the events to the button would be the wisest here
	the only way to do that well would be to send an InputEvent
	
	as setting the pressed status of the button doesn't really work

Better would be to automatically scale the Node2D TouchScreenButton within this node's region
"""
@export var button: Button

func _ready() -> void:
	if button:
		button.pressed.connect(_button_pressed)

func _button_pressed():
	print("pressed button")

#this is only for mouse events, not touch
func _gui_input(event: InputEvent) -> void:
	print("Gui event: %s" % event)

func _input(event: InputEvent) -> void:
	if "position" in event:
		if get_global_rect().has_point(event.position):
			print("input within area")
			print(event)
			
			if event.is_pressed() or event.pressed:
				if button:
					button.button_pressed = true
