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

## Determines UI
@export_subgroup("Gestures")
@export var gesture_pan_enabled: bool = true
@export var gesture_scale_enabled: bool = true
@export var gesture_rotate_enabled: bool = true

@export_subgroup("Floating Joystick")
## Long presses will enable a floating joystick at the location, until the pointer is risen
@export var floating_joystick_enabled: bool = false
#https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html#nodes
## Path to the VirtualJoystick node to use
@export var floating_joystick_node: VirtualJoystick

@export_group("Textures")
@export var mode_button_minimum_size : Vector2i:
	set(value):
		mode_button_minimum_size = value
		if btn_mode:
			btn_mode.custom_minimum_size = value
			btn_mode.get_parent().set_anchors_preset(PRESET_TOP_RIGHT)

@export var region_color : Color = Color8(255, 255, 255, 30):
	set(value):
		region_color = value
		if clr_rct:
			clr_rct.color = value

#TODO export all texture variants for TextureButton
#TODO USE PATH OF BUTTONS like with FloatingVirtualJoystick
@export var pan_icon: Texture2D = load("res://addons/mobile_controls/icons/pan_icon.svg")
@export var rotate_icon: Texture2D = load("res://addons/mobile_controls/icons/rotate_icon.svg")


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
var btn_mode: TextureButton
var clr_rct: ColorRect

func _ready():
	if touchscreen_only and not DisplayServer.is_touchscreen_available():
		modulate = Color(1, 1, 1, 0)
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
	
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
	
	var container = MarginContainer.new()
	container.name = "ButtonModeMarginContainer"
	btn_mode = TextureButton.new()
	btn_mode.name = "ButtonMode"
	btn_mode.ignore_texture_size = true
	btn_mode.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	btn_mode.custom_minimum_size = mode_button_minimum_size
	btn_mode.pressed.connect(_toggle_touchscreen_mode)
	
	var margin_value = 20
	add_theme_constant_override("margin_top", margin_value)
	add_theme_constant_override("margin_left", margin_value)
	add_theme_constant_override("margin_bottom", margin_value)
	add_theme_constant_override("margin_right", margin_value)
	
	add_child(container)
	container.add_child(btn_mode)
	_toggle_touchscreen_mode()
	
	tmr_long_press.wait_time = long_press_timeout / 1000
	
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_WIDTH, 0.0)
	if floating_joystick_node and not Engine.is_editor_hint():
		_enable_fvj(false)

func _toggle_touchscreen_mode():
	var resource : Texture2D
	if state.tscreen_mode == ETouchScreenMode.PAN:
		state.tscreen_mode = ETouchScreenMode.ROTATE
		resource = rotate_icon
	else:
		state.tscreen_mode = ETouchScreenMode.PAN
		resource = pan_icon
	btn_mode.texture_normal = resource

func _gui_input(event):
	var emulate_touch_from_mouse = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	var emulate_mouse_from_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")	#Default is true
	
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
		if floating_joystick_enabled:
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
