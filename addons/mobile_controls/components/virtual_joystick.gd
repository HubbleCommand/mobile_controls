@tool
extends MarginContainer
#Images from https://godotengine.org/asset-library/asset/1787, code is mine
class_name VirtualJoystick

@export var margin: int = 20

@export var outline_texture: Texture2D:
	set(value):
		outline_texture = value
		if Engine.is_editor_hint():
			outline.texture = value
			notify_property_list_changed()
@export var point_texture: Texture2D:
	set(value):
		point_texture = value
		if Engine.is_editor_hint():
			point.texture = value
			notify_property_list_changed()

var outline : TextureRect
var point: TextureRect
var _input_pointer_index = -1	#"pointer" index like in Android with multiple pointers
#TODO can probably remove _down, as it seems there is always a pointer index
var _down := false				#Used to handle between TOUCH DOWN & PAN /DRAG events

enum EVisibilityMode { ALWAYS, TOUCHSCREEN_ONLY }
enum EPointerConstraintMode { DYNAMIC_IN, DYNAMIC_OUT }

@export var visibility_mode := EVisibilityMode.ALWAYS
@export var pointer_constraint_mode := EPointerConstraintMode.DYNAMIC_IN
@export var mark_input_as_handled = false

#TODO might be interesting to use InputEventJoypadMotion's from _input for UI feedback
#enum EFeedbackMode { NONE, JOYSTICK }
#@export var feedback_mode := EFeedbackMode.JOYSTICK

@export var joy_axis_horizontal : JoyAxis = JOY_AXIS_INVALID
@export var joy_axis_vertical : JoyAxis = JOY_AXIS_INVALID


func _ready():
	#init this node for addon
	add_theme_constant_override("margin_left", margin)
	add_theme_constant_override("margin_right", margin)
	add_theme_constant_override("margin_top", margin)
	add_theme_constant_override("margin_bottom", margin)
	
	#Create scene for addon
	outline = TextureRect.new()
	outline.name = "Outline"
	outline.texture = outline_texture
	
	point = TextureRect.new()
	point.name = "Point"
	point.texture = point_texture
	
	outline.add_child(point)
	#Maybe center point at start or something...
	add_child(outline)
	
	#configure nodes
	# I don't think there's anything to do here?
	if not DisplayServer.is_touchscreen_available() and visibility_mode == EVisibilityMode.TOUCHSCREEN_ONLY:
		hide()

func _reset_point():
	point.set_position(point.get_rect().size / 2)

func _set_point(position: Vector2):
	var limit = outline.get_rect().size.x
	var length
	#need global to compare to mouse position #outline.get_rect().position
	var center = outline.global_position + (outline.get_rect().size / 2)
	var offset = - (point.get_rect().size / 2)
	
	if pointer_constraint_mode == EPointerConstraintMode.DYNAMIC_IN:
		limit -= (point.get_rect().size.x) #- (point.get_rect().size.x / 2)
		length = outline.get_rect().size.x - (point.get_rect().size.x) - (point.get_rect().size.x / 2)
	
	elif pointer_constraint_mode == EPointerConstraintMode.DYNAMIC_OUT:
		length = outline.get_rect().size.x - (point.get_rect().size.x)
	
	var target
	var direction = center.direction_to(position)
	if position.distance_to(center) < limit / 2:
		target = position - point.get_rect().size / 2
	else:
		target = (direction * length) + center + offset
	
	var radius = outline.get_rect().size.x / 2
	var action_target = (direction * (position.distance_to(center) / radius))
	_send_input_event(HORIZONTAL, action_target.x)
	_send_input_event(VERTICAL, action_target.y)
	
	point.set_global_position(target)

#Need to set axis to something other than "Joy Axis Invalid", or get following error
#Condition "p_axis < JoyAxis::LEFT_X || p_axis > JoyAxis::MAX" is true.
func _send_input_event(orientation: Orientation, strength: float):
	var joystick_event = InputEventJoypadMotion.new()
	joystick_event.axis = joy_axis_horizontal if orientation == HORIZONTAL else joy_axis_vertical #JOY_AXIS_LEFT_X
	joystick_event.axis_value = strength #length / limit
	Input.parse_input_event(joystick_event)

func _event_in_area(event_position: Vector2) -> bool:
	var width = outline.get_rect().size.x
	#need global to compare to mouse position #outline.get_rect().position
	var center = outline.global_position + (outline.get_rect().size / 2)	
	return event_position.distance_to(center) <= width / 2

# We don't want to use gui_input as we still want gestures outside of this control
func _input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			if _event_in_area(event.position):
				_set_point(event.position)
				_down = true
				if "index" in event:
					_input_pointer_index = event.index
			#else:
			#	_reset_point()
			#	_down = false
		else :
			if "index" in event:
				if event.index != _input_pointer_index:
					_input_pointer_index = -1
					return
			_reset_point()
			_down = false
	
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _down:
			return
		
		if _input_pointer_index >= 0 and "index" in event:
			if _input_pointer_index == event.index:
				_set_point(event.position)
		else:
			_set_point(event.position)
