## General Control to handle multiple gestures; panning, zoom, rotating, double tap
## NO STATE IS HELD (pan or scale), only detects the gestures

@tool
extends Control
class_name ScreenGesture

@export_group("Gestures Configuration")
@export var consider_input_gesture_as_handled = true
## Timeout in milliseconds for two consecutive screen taps 
## from the same pointer to be considered a double tap (mouse only)
@export var double_tap_timeout : float = 500
## Timeout in milliseconds for detecting a long press / hold
@export var long_press_timeout : float = 1000
## Control only enabled when on a device with a touchscreen
@export var touchscreen_only: bool = false
## Multiple gestures can be reported at once (i.e. scale and pan in the same gesture)
@export var multi_gesture: bool = false

@export var region_color : Color = Color8(255, 255, 255, 30):
	set(value):
		region_color = value
		if clr_rct:
			clr_rct.color = value

## Determines UI
@export_subgroup("Gestures")
@export var gesture_pan_enabled: bool = true
@export var gesture_scale_enabled: bool = true
@export var gesture_rotate_enabled: bool = true

@export_subgroup("Floating Joystick")
#https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html#nodes
## Long presses will enable a floating joystick at the location, until the pointer is risen
## Path to the VirtualJoystick node to use
@export var floating_joystick_node: VirtualJoystick

@export_group("Mode Buttons")
@export var btn_pan: TextureButton
@export var btn_rotate: TextureButton
@export var btn_scale: TextureButton

@export var modulate_active: Color = Color.WHITE
@export var modulate_inactive: Color = Color.WHITE

@export_group("Debug")
## Show UI feedback at pointer location
@export var show_ui_feedback := false	#TODO add UI feeback (?)
## Print gesture debug info
@export var print_debug_gestures = true

## Gesture Signals
signal double_tap_gesture(target: Vector2)
signal long_press_gesture(gesture: Vector2)
signal pan_gesture(position: Vector2, direction: Vector2)
signal scale_gesture(position: Vector2, strength: float) #Also handles pan I guess, or merge both pan & scale
signal rotate_gesture(position: Vector2, direction: Vector2)
signal gesture_end() #Signifies the end of a previous set of gestures (useful for scale / pan combos)

class Pointer :
	var index : int
	var timestamp: float
	var position: Vector2
	
	func _init(i: int, time: float, pos: Vector2):
		index = i
		timestamp = time
		position = pos

enum ETouchScreenMode { PAN, ROTATE, SCALE }

class ScreenGestureState:
	var pointers : int = 0
	var last_pointer_down : Pointer = null
	var tscreen_mode := ETouchScreenMode.PAN

var state = ScreenGestureState.new()

var tmr_long_press: Timer
var clr_rct: ColorRect

func _ready():
	if touchscreen_only and not DisplayServer.is_touchscreen_available():
		modulate = Color(1, 1, 1, 0)
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
	
	if btn_pan:
		btn_pan.pressed.connect(_set_mode.bind(ETouchScreenMode.PAN))
	if btn_rotate:
		btn_rotate.pressed.connect(_set_mode.bind(ETouchScreenMode.ROTATE))
	if btn_scale:
		btn_scale.pressed.connect(_set_mode.bind(ETouchScreenMode.SCALE))
	
	if not Engine.is_editor_hint():
		_set_mode(ETouchScreenMode.PAN)
	
	#Build for addon
	tmr_long_press = Timer.new()
	tmr_long_press.name = "LongPressTimer"
	tmr_long_press.wait_time = 0.5
	tmr_long_press.one_shot = true
	tmr_long_press.timeout.connect(_long_press_timeout)
	add_child(tmr_long_press)
	
	clr_rct = ColorRect.new()
	clr_rct.name = "Region"
	clr_rct.color = region_color
	clr_rct.grow_vertical = Control.GROW_DIRECTION_BOTH
	clr_rct.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clr_rct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clr_rct.set_anchors_preset(PRESET_FULL_RECT)
	clr_rct.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(clr_rct)
	
	tmr_long_press.wait_time = long_press_timeout / 1000
	
	if floating_joystick_node and not Engine.is_editor_hint():
		_enable_fvj(false)

func _set_mode(mode: ETouchScreenMode):
	state.tscreen_mode = mode
	if btn_pan:
		btn_pan.modulate = modulate_active if mode == ETouchScreenMode.PAN else modulate_inactive
	if btn_rotate:
		btn_rotate.modulate = modulate_active if mode == ETouchScreenMode.ROTATE else modulate_inactive
	if btn_scale:
		btn_scale.modulate = modulate_active if mode == ETouchScreenMode.SCALE else modulate_inactive

func _toggle_touchscreen_mode():
	_set_mode(ETouchScreenMode.ROTATE if state.tscreen_mode == ETouchScreenMode.PAN else ETouchScreenMode.PAN)

var _feedback_position = null

func _draw() -> void:
	if _feedback_position is Vector2:
		draw_circle(_feedback_position, 20.0, Color.WHITE, true)

func _feedback(event: InputEvent):
	var is_pressed = event.is_pressed()
	#https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent-method-is-pressed
	if event is InputEventMouseMotion:
		#https://forum.godotengine.org/t/godot-mouse-input-pressure/83763
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			is_pressed = true
	if event is InputEventScreenDrag:
		is_pressed = event.pressure > 0
	if event.position and is_pressed:
		_feedback_position = event.position
	if not is_pressed:
		_feedback_position = null
	queue_redraw()

func _gui_input(event):
	var emulate_touch_from_mouse = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	var emulate_mouse_from_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")	#Default is true
	
	if show_ui_feedback:
		_feedback(event)
	
	match event.get_class():
		"InputEventMouseButton":
			#TODO need an action to map to here I guess, or something... i.e. only zoom when CTRL is pressed
			if event.pressed:
				var factor = 1 if event.factor == 0 else event.factor
				match event.button_index:
					MOUSE_BUTTON_WHEEL_UP:
						_pring_gesture_debug("scale", "mouse")
						scale_gesture.emit(event.position, factor)
					MOUSE_BUTTON_WHEEL_DOWN:
						_pring_gesture_debug("scale", "mouse")
						scale_gesture.emit(event.position, -factor)
					MOUSE_BUTTON_LEFT:
						state.pointers += 1
						if _detect_double_tap(state.last_pointer_down, event):
							double_tap_gesture.emit(event.position)
							tmr_long_press.stop()
						else:
							tmr_long_press.start()
						state.last_pointer_down = Pointer.new(-1, Time.get_ticks_msec(), event.position)
			elif event.button_index == MOUSE_BUTTON_LEFT:#Don't just ELSE here
				state.pointers -= 1
				if state.pointers == 0:
					gesture_end.emit()
					if floating_joystick_node.process_mode == ProcessMode.PROCESS_MODE_INHERIT:
						_enable_fvj(false)
				tmr_long_press.stop()
		"InputEventMouseMotion":
			tmr_long_press.stop()
			if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_pring_gesture_debug("rotate", "mouse")
				if consider_input_gesture_as_handled: get_viewport().set_input_as_handled()
				rotate_gesture.emit(event.position, event.relative)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && !Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_pring_gesture_debug("pan", "mouse")
				if consider_input_gesture_as_handled: get_viewport().set_input_as_handled()
				pan_gesture.emit(event.position, event.relative)
	# Screen part
	# I don't really like how when Magnify is triggered, so is the pan...
	# It might be better to just have a toggle button to switch between Pan & Rotate
	# But... this is fine for now...
		"InputEventPanGesture":
			if state.tscreen_mode == ETouchScreenMode.PAN:
				pan_gesture.emit(event.position, event.delta)
			else:
				rotate_gesture.emit(event.position, event.delta)
		"InputEventMagnifyGesture":
			_pring_gesture_debug("scale", "screen")
			scale_gesture.emit(event.position, event.factor)
	
	# Usually no index means that it's a "generic" gesture, so can probably ignore
	# i.e. dragging the mouse (InputEventMouseMotion) with no buttons pressed
	# previous events don't have indicies
	# TODO check for iOS
	print(event)
	if not "index" in event:
		print("returning due to no event index")
		return
	
	if event is InputEventScreenTouch:
		if event.is_pressed():
			state.last_pointer_down = Pointer.new(event.index, Time.get_ticks_msec(), event.position)
			state.pointers += 1
			if state.pointers > 1:
				_pring_gesture_debug("long press - stopping timer", "screen")
				tmr_long_press.stop()
			tmr_long_press.start()
		if !event.is_pressed():
			state.pointers -= 1
			if state.pointers == 0:
				gesture_end.emit()
				if floating_joystick_node.process_mode == ProcessMode.PROCESS_MODE_INHERIT:
					_enable_fvj(false)
			tmr_long_press.stop()
		if event.double_tap:
			_pring_gesture_debug("double tap", "screen")
			double_tap_gesture.emit(event.position)
			#tmr_long_press.stop()
	elif event is InputEventScreenDrag:
		tmr_long_press.stop()
		if state.tscreen_mode == ETouchScreenMode.PAN:
			pan_gesture.emit(event.position, event.relative)
		else:
			rotate_gesture.emit(event.position, event.relative)

## TODO remove this, it appears all inputs have double click detection (including mouse, making this not great
##	as it changes system-defined behavior)
func _detect_double_tap(last_event: Pointer, event: InputEvent) -> bool:
	if last_event != null and state.pointers == 1 \
		and Time.get_ticks_msec() - last_event.timestamp < double_tap_timeout \
		and abs(last_event.position.distance_to(event.position)) < 25 :
		_pring_gesture_debug("double tap")
		return true
	_pring_gesture_debug("double tap FAILED")
	return false

func _long_press_timeout():
	_pring_gesture_debug("long press - timeout")
	if state.pointers == 1:
		_pring_gesture_debug("long press")
		#TODO determine how to do this...
		if floating_joystick_node:
			_pring_gesture_debug("handling floating VirtualJoystick")
			_enable_fvj(true)
			floating_joystick_node.position = Vector2(
				state.last_pointer_down.position.x - (floating_joystick_node.get_rect().size.x / 2),
				state.last_pointer_down.position.y - (floating_joystick_node.get_rect().size.y / 2)
			)
		else:
			long_press_gesture.emit(state.last_pointer_down.position)
	else:
		print("not continuing with long press due to pointers count being " + str(state.pointers))

func _pring_gesture_debug(gesture : String, source: String = ""):
	if !print_debug_gestures:
		return
	if source.is_empty():	print("		gesture debug --- gesture : ", gesture)
	else:					print("		gesture debug --- gesture : ", gesture, " - from source : ", source)

func _enable_fvj(enable: bool):
	floating_joystick_node.modulate = Color(1, 1, 1, 1) if enable else Color(1, 1, 1, 0)
	floating_joystick_node.process_mode = ProcessMode.PROCESS_MODE_INHERIT if enable else ProcessMode.PROCESS_MODE_DISABLED
	if enable:
		floating_joystick_node.accept_next()
