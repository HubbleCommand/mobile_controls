## Virtual Joystick for use on touchscreens to emulate a controller joystick
@tool
extends MarginContainer
class_name VirtualJoystick

@export var margin: int = 20:
	set(value):
		margin = value
		_update_margin()

## If keep tracking user input once it has exited this Control 
@export var track_outside: bool = true

@export var texture_outline: Texture2D:
	set(value):
		texture_outline = value
		if Engine.is_editor_hint():
			_outline.texture = value
			notify_property_list_changed()
@export var texture_point: Texture2D:
	set(value):
		texture_point = value
		if Engine.is_editor_hint():
			_point.texture = value
			notify_property_list_changed()
@export var texture_point_pressed: Texture2D

var _outline : TextureRect
var _point: TextureRect
var _input_pointer_index = -1	#"pointer" index like in Android with multiple pointers
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
	_outline = TextureRect.new()
	_outline.name = "Outline"
	_outline.texture = texture_outline
	
	_point = TextureRect.new()
	_point.name = "Point"
	_point.texture = texture_point
	
	_outline.add_child(_point, InternalMode.INTERNAL_MODE_BACK)
	add_child(_outline, InternalMode.INTERNAL_MODE_BACK)
	_update_margin()
	_reset_point(false)
	
	if not DisplayServer.is_touchscreen_available() and visibility_mode == EVisibilityMode.TOUCHSCREEN_ONLY:
		hide()

func _update_margin():
	add_theme_constant_override("margin_left", margin)
	add_theme_constant_override("margin_right", margin)
	add_theme_constant_override("margin_top", margin)
	add_theme_constant_override("margin_bottom", margin)

func _reset_point(send: bool = true):
	_point.set_position((_outline.get_rect().size / 2) - (_point.get_rect().size / 2))
	
	if send:
		_send_input_event(HORIZONTAL, 0)
		_send_input_event(VERTICAL, 0)

func _set_point(position: Vector2):
	var limit = _outline.get_rect().size.x
	var radius_max = (_outline.get_rect().size.x / 2)
	var offset = - (_point.get_rect().size / 2)
	#need global to compare to mouse position #outline.get_rect().position
	# canvas items don't have the same helpers as Node2D / Node3D for converting between local and global space
	var center = _outline.global_position + (_outline.get_rect().size / 2)
	
	if pointer_constraint_mode == EPointerConstraintMode.DYNAMIC_IN:
		limit -= _point.get_rect().size.x
		radius_max -= _point.get_rect().size.x / 2
	
	var target
	var direction = center.direction_to(position)
	if position.distance_to(center) < limit / 2:
		target = position - _point.get_rect().size / 2
	else:
		target = (direction * radius_max) + center + offset
	
	var radius = _outline.get_rect().size.x / 2
	#re-fit into [-1, 1] range for input event
	var action_target = (direction * ((target + _point.get_rect().size / 2).distance_to(center) / radius_max))
	_send_input_event(HORIZONTAL, action_target.x)
	_send_input_event(VERTICAL, action_target.y)
	
	_point.set_global_position(target)

func _send_input_event(orientation: Orientation, strength: float):
	var joystick_event = InputEventJoypadMotion.new()
	joystick_event.axis = joy_axis_horizontal if orientation == HORIZONTAL else joy_axis_vertical #JOY_AXIS_LEFT_X
	joystick_event.axis_value = strength #length / limit
	Input.parse_input_event(joystick_event)

func _event_in_area(event_position: Vector2) -> bool:
	var width = _outline.get_rect().size.x
	#need global to compare to mouse position #outline.get_rect().position
	# cannot use relative position as described below
	# https://docs.godotengine.org/en/latest/classes/class_inputeventmouse.html#class-inputeventmouse-property-position
	var center = _outline.global_position + (_outline.get_rect().size / 2)	
	return event_position.distance_to(center) <= width / 2

## Fixes issue when Floating, will accept input events properly
## FOR INTERNAL PACKAGE USE ONLY, do not use unless you know what you are doing!
func accept_next():
	_down = true
	_switch_point_texture()

# We don't want to use gui_input as we still want gestures outside of this control
func _input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			if _event_in_area(event.position):
				_set_point(event.position)
				_down = true
				_switch_point_texture()
				if "index" in event:
					_input_pointer_index = event.index
		else :
			if "index" in event:
				if event.index != _input_pointer_index:
					_input_pointer_index = -1
					return
			_reset_point()
			_down = false
			_switch_point_texture()
	
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _down:
			return
		
		if not _event_in_area(event.position) and not track_outside:
			_reset_point()
			_down = false
			return
		
		if _input_pointer_index >= 0 and "index" in event:
			if _input_pointer_index == event.index:
				_set_point(event.position)
		else:
			_set_point(event.position)

func _switch_point_texture():
	if texture_point_pressed:
		_point.texture = texture_point_pressed if _down else texture_point
